#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use C4::Context;
use MARC::Record;
use MARC::File::XML;

my $biblionumber;
my $file;
my $date;
my $verbose;

GetOptions(
    'verbose'        => \$verbose,
    'biblionumber=i' => \$biblionumber,
    'file=s'         => \$file,
    'date=s'         => \$date,
) or die "Error in command line arguments\n";

if (!$date) {
    die "You must provide a date in the format 'YYYY-MM-DD'\n";
}

if ($biblionumber) {
    process_biblionumber($biblionumber, $date);
} elsif ($file) {
    process_file($file, $date);
} else {
    die "You must provide either a biblionumber or a file of biblionumbers\n";
}

sub process_biblionumber {
    my ($biblionumber, $date) = @_;
    print $biblionumber . "\n";
    my $differences = compare_records($biblionumber, $date);
    if (@$differences) {
        print "Differences found for biblionumber $biblionumber:\n" if $verbose;
        if ($verbose) {
            foreach my $diff (@$differences) {
                print "CURRENT:\n$diff->{local}\n";
                print "BROADCAST:\n$diff->{broadcast}\n";
                print "-------------------------\n";
            }
        }
    } else {
        print "No differences found for biblionumber $biblionumber\n" if $verbose;
    }
}

sub process_file {
    my ($file, $date) = @_;
    open my $fh, '<', $file or die "Could not open file '$file': $!\n";
    while (my $line = <$fh>) {
        chomp $line;
        process_biblionumber($line, $date);
    }
    close $fh;
}

sub compare_records {
    my ($biblionumber, $date) = @_;
    my $metadata = find_metadata($biblionumber, $date);
    my $broadcast_transfer = find_broadcast_transfer($biblionumber, $date);
    my @differences;
    my $order = 0;
    my @metadata_fields = $metadata->fields;
    foreach my $broadcast ( $broadcast_transfer->fields ) {
        my $local = $metadata_fields[$order];
        if (!$local) {
            push @differences, { local => 'No local field', broadcast => $broadcast->as_formatted };
            next;
        }
        if ($broadcast->tag ne $local->tag) {
            push @differences, { local => $local->as_formatted, broadcast => $broadcast->as_formatted };
        } else {
            if ($broadcast->as_formatted ne $local->as_formatted) {
                push @differences, { local => $local->as_formatted, broadcast => $broadcast->as_formatted };
            }
        }
        $order++;
    }

    # Filter out differences if only in 005 tag
    @differences = grep {
        !($_->{local} =~ /^005/ && $_->{broadcast} =~ /^005/)
    } @differences;

    @differences = grep {
        $_->{local} =~ /^084/ && $_->{broadcast} =~ /^084/
    } @differences;

    return \@differences;
}

sub find_metadata {
    my ($biblionumber, $date) = @_;
    # Add your code to find action logs for a biblionumber here
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT metadata from biblio_metadata WHERE biblionumber = ?");
    $sth->execute($biblionumber);
    my $result = $sth->fetchrow_hashref;
    $sth->finish();
    my $marc_record = MARC::Record->new_from_xml($result->{metadata}, 'UTF-8');
    return $marc_record;

}

sub find_broadcast_transfer {
    my ($biblionumber, $date) = @_;
    # Add your code to find the latest broadcast update for a biblionumber here
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT marc FROM koha_plugin_fi_kohasuomi_broadcastbiblios_queue WHERE biblio_id = ? AND DATE(transfered_on) >= ? ORDER BY transfered_on DESC LIMIT 1");
    $sth->execute($biblionumber, $date);
    my $result = $sth->fetchrow_hashref;
    $sth->finish();
    my $marc_record = MARC::Record->new_from_xml($result->{marc}, 'UTF-8');
    return $marc_record;
}