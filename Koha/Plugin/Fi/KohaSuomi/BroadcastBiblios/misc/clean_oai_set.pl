#!/usr/bin/perl

# clean_oai_set.pl - Poista osakohteet OAI-setistä (moni-setti-versio)
# Copyright 2026

BEGIN {
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use Modern::Perl;
use Getopt::Long;
use C4::Context;
use Koha::Biblios;
use MARC::Record;
use Try::Tiny;
use File::Spec;
use POSIX qw(strftime);

my $set_names = '';   # Nyt voi olla useampi setti pilkuilla erotettuna
my $verbose   = 0;
my $dry_run   = 0;
my $help      = 0;
my $confirm   = 0;
my $restore   = 0;
my $backup_dir = '.';

GetOptions(
    'set-name=s' => \$set_names,
    'backup-dir=s' => \$backup_dir,
    'v|verbose'  => \$verbose,
    'dry-run'    => \$dry_run,
    'h|help'     => \$help,
    'confirm'    => \$confirm,
    'restore'    => \$restore,
);

my $usage = <<USAGE;
Poista osakohteet OAI-setistä

Käyttö: perl clean_oai_set.pl --set-name "Setti1,Setti2,Setti3" [optiot]

Parametrit:
    --set-name      OAI-setin nimi(t) pilkuilla erotettuna (PAKOLLINEN)
    --backup-dir    Hakemisto johon backup-tiedostot kirjoitetaan
    -v, --verbose   Yksityiskohtainen tulostus
    --dry-run       Näytä mitä tehtäisiin ilman muutoksia
    -h, --help      Näytä tämä ohje
    --restore       Palauta varmuuskopiotiedostosta (tarvitsee --backup-dir ja --set-name)
    --confirm       Vahvista ennen tietueiden poistoa (tarvitsee --dry-run pois päältä)

Esimerkki:
    perl clean_oai_set.pl --set-name "Kaunokirjallisuus,Historiikki" --verbose --dry-run
USAGE

if ($help) {
    print $usage;
    exit 0;
}

unless ($set_names) {
    die "VIRHE: --set-name parametri on pakollinen!\n\n$usage";
}

my @sets = split(/\s*,\s*/, $set_names);  # Jaa pilkuilla

my $dbh = C4::Context->dbh;

if ($restore) {
    print "Palautetaan setit varmuuskopiotiedostoista...\n";
    foreach my $set_name (@sets) {
        my $backup_file = File::Spec->catfile($backup_dir, "backup_${set_name}_*.txt");
        my @files = glob($backup_file);

        unless (@files) {
            warn "VIRHE: Varmuuskopiotiedostoa ei löytynyt setille '$set_name' hakemistosta '$backup_dir'\n";
            next;
        }

        my $latest_file = (sort { -M $a <=> -M $b } @files)[0];
        print "Löydetty varmuuskopiotiedosto: $latest_file\n";

        open my $fh, '<:encoding(UTF-8)', $latest_file
            or die "VIRHE: ei voitu avata varmuuskopiotiedostoa $latest_file: $!\n";

        my @biblionumbers_to_restore;
        while (my $line = <$fh>) {
            chomp $line;
            push @biblionumbers_to_restore, $line if $line =~ /^\d+$/;
        }
        close $fh;

        print "Palautetaan " . scalar(@biblionumbers_to_restore) . " tietuetta settiin '$set_name'...\n";

        # Hae OAI-setin ID
        my $set_query = "SELECT id FROM oai_sets WHERE name = ?";
        my $set_sth = $dbh->prepare($set_query);
        $set_sth->execute($set_name);
        my ($set_id) = $set_sth->fetchrow_array;

        unless ($set_id) {
            warn "VIRHE: OAI-settiä '$set_name' ei löytynyt!\n";
            next;
        }

        my $insert_query = "INSERT INTO oai_sets_biblios (set_id, biblionumber) VALUES (?, ?)";
        my $insert_sth = $dbh->prepare($insert_query);

        foreach my $biblionumber (@biblionumbers_to_restore) {
            try {
                if ($confirm) {
                    $insert_sth->execute($set_id, $biblionumber);
                    print "  Palautettu: $biblionumber\n" if $verbose;
                } else {
                    print "  Skipattu (tarvitsee --confirm): $biblionumber\n";
                }
            } catch {
                warn "VIRHE palautettaessa bibliota $biblionumber: $_\n";
            };
        }
        print "Palautus settiin '$set_name' valmis.\n";
    }
    print "\nKaikki setit palautettu.\n";
    exit 0;
}

# Käydään jokainen setti läpi
foreach my $set_name (@sets) {

    print "\n============================\n" if $verbose;
    print "Käsitellään OAI-settiä: $set_name\n" if $verbose;
    print "DRY-RUN tila - ei tehdä muutoksia\n" if $dry_run;

    # Hae OAI-setin ID
    my $set_query = "SELECT id, spec, name FROM oai_sets WHERE name = ?";
    my $set_sth = $dbh->prepare($set_query);
    $set_sth->execute($set_name);

    my $set = $set_sth->fetchrow_hashref;

    unless ($set) {
        warn "VIRHE: OAI-settiä '$set_name' ei löytynyt!\n";
        next;  # Jatka seuraavaan settiin
    }

    my $set_id   = $set->{id};
    my $set_spec = $set->{spec};

    print "Löydettiin setti: ID=$set_id, spec=$set_spec, name=$set_name\n" if $verbose;

    # Hae kaikki biblionumberit tästä setistä
    my $biblios_query = "SELECT biblionumber FROM oai_sets_biblios WHERE set_id = ?";
    my $biblios_sth = $dbh->prepare($biblios_query);
    $biblios_sth->execute($set_id);

    my @biblionumbers;
    while (my $row = $biblios_sth->fetchrow_hashref) {
        push @biblionumbers, $row->{biblionumber};
    }

    my $total_biblios = scalar(@biblionumbers);
    print "Setissä on $total_biblios tietuetta\n";

    if ($total_biblios == 0) {
        print "Setti on tyhjä, ei mitään tehtävää.\n";
        next;
    }

    my @component_parts;  # Lista poistettavista biblionumbereista
    my $checked = 0;

    print "\nTarkistetaan tietueet...\n" if $verbose;

    foreach my $biblionumber (@biblionumbers) {
        $checked++;

        if ($verbose && $checked % 100 == 0) {
            print "Tarkistettu $checked / $total_biblios tietuetta...\n";
        }

        my $biblio = Koha::Biblios->find($biblionumber);
        next unless $biblio;
        my $metadata = $biblio->metadata;
        next unless $metadata;
        
        try {

            my $record = MARC::Record::new_from_xml($metadata->metadata, 'UTF-8');
            if ($record->subfield('773','w')) {
                push @component_parts, $biblionumber;
                if ($verbose) {
                    my $title = $record->subfield('245','a') || 'Ei otsikkoa';
                    print "  Osakohde löydetty: $biblionumber - $title\n";
                }
            }

        } catch {
            warn "VIRHE käsiteltäessä bibliota $biblionumber: $_\n";
        };
    }

    my $components_found = scalar(@component_parts);
    print "\nLöydettiin $components_found osakohdetta\n";

    next if $components_found == 0;

    # ===== TÄHÄN LISÄTTY VARMUUSKOPIO TXT-TIEDOSTOON =====
    my $date = strftime("%Y%m%d_%H%M%S", localtime);
    my $filename = "backup_${set_name}_$date.txt";
    $filename =~ s/\s+/_/g;

    my $backup_file = File::Spec->catfile($backup_dir, $filename);

    open my $backup_fh, '>:encoding(UTF-8)', $backup_file
        or die "VIRHE: ei voitu avata varmuuskopiotiedostoa $backup_file: $!\n";

    foreach my $biblionumber (@component_parts) {
        print $backup_fh "$biblionumber\n";
    }

    close $backup_fh;
    print "Varmuuskopio biblionumbereista tallennettu tiedostoon: $backup_file\n";

    # =====================================================

    if ($dry_run) {
        print "DRY-RUN: Poistettaisiin $components_found osakohdetta setistä\n";
        print "\nAja ilman --dry-run flagia tehdäksesi muutokset.\n";
    } else {
        my $delete_query = "DELETE FROM oai_sets_biblios WHERE biblionumber = ? AND set_id = ?";
        my $delete_sth = $dbh->prepare($delete_query);

        my $deleted_count = 0;
        print "Poistetaan osakohdetta setistä...\n";

        foreach my $biblionumber (@component_parts) {
            try {
                if ($confirm) {
                    $delete_sth->execute($biblionumber, $set_id);
                    $deleted_count++;
                    print "  Poistettu: $biblionumber\n" if $verbose;
                } else {
                    print "  Skipattu (tarvitsee --confirm): $biblionumber\n";
                }

            } catch {
                warn "VIRHE poistettaessa bibliota $biblionumber: $_\n";
            };
        }

        print "\nPoistettu yhteensä $deleted_count osakohdetta setistä '$set_name'\n";
        print "\n" . "=" x 60 . "\n";
        print "YHTEENVETO\n";
        print "=" x 60 . "\n";
        print "OAI-setti:              $set_name (ID: $set_id)\n";
        print "Tarkastettuja tietueita: $total_biblios\n";
        print "Löydettyjä osakohteita: $components_found\n";
        if ($dry_run) {
            print "Tila:                   DRY-RUN (ei muutoksia)\n";
        } else {
            print "Poistettu setistä:      $deleted_count tietuetta\n";
            print "Tila:                   VALMIS\n";
        }
        print "=" x 60 . "\n";
    }
}

print "\nKaikki setit käsitelty.\n";