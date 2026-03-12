#!/usr/bin/perl

# populate_test_data.pl - Create test data for OAI set cleaning script
# This script creates:
# - Test OAI sets
# - Test biblios (some as component parts, some regular)
# - Links between biblios and OAI sets

BEGIN {
    use FindBin;
    eval { require "$FindBin::Bin/../../Koha/kohalib.pl" };
}

use Modern::Perl;
use Getopt::Long;
use C4::Context;
use C4::Biblio qw( AddBiblio );
use MARC::Record;
use MARC::Field;

# Parameters
my $verbose = 0;
my $help = 0;
my $clean = 0;

GetOptions(
    'v|verbose' => \$verbose,
    'h|help'    => \$help,
    'clean'     => \$clean,
);

my $usage = <<USAGE;
Create test data for OAI set cleaning script

Usage: perl populate_test_data.pl [options]

Options:
    -v, --verbose   Verbose output
    -h, --help      Show this help
    --clean         Remove test data instead of creating it

Examples:
    # Create test data
    perl populate_test_data.pl --verbose
    
    # Remove test data
    perl populate_test_data.pl --clean --verbose
USAGE

if ($help) {
    print $usage;
    exit 0;
}

my $dbh = C4::Context->dbh;

if ($clean) {
    print "Cleaning up test data...\n";
    cleanup_test_data();
} else {
    print "Creating test data...\n";
    create_test_data();
}

sub cleanup_test_data {
    my $set_name = 'TEST-Kaunokirjallisuus';
    
    # Find test set
    my $set_query = "SELECT id FROM oai_sets WHERE name = ?";
    my $sth = $dbh->prepare($set_query);
    $sth->execute($set_name);
    my $set = $sth->fetchrow_hashref;
    
    unless ($set) {
        print "Test set '$set_name' not found, nothing to clean.\n";
        return;
    }
    
    my $set_id = $set->{id};
    
    # Get biblios in this set
    my $biblio_query = "SELECT biblionumber FROM oai_sets_biblios WHERE set_id = ?";
    $sth = $dbh->prepare($biblio_query);
    $sth->execute($set_id);
    
    my @biblios;
    while (my $row = $sth->fetchrow_hashref) {
        push @biblios, $row->{biblionumber};
    }
    
    print "Found " . scalar(@biblios) . " test biblios\n" if $verbose;
    
    # Delete from oai_sets_biblios (will cascade from FK)
    my $delete_link = "DELETE FROM oai_sets_biblios WHERE set_id = ?";
    $dbh->do($delete_link, undef, $set_id);
    print "Deleted links from oai_sets_biblios\n" if $verbose;
    
    # Delete biblios
    foreach my $biblionumber (@biblios) {
        # Delete from biblio_metadata
        $dbh->do("DELETE FROM biblio_metadata WHERE biblionumber = ?", undef, $biblionumber);
        # Delete from biblioitems
        $dbh->do("DELETE FROM biblioitems WHERE biblionumber = ?", undef, $biblionumber);
        # Delete from biblio
        $dbh->do("DELETE FROM biblio WHERE biblionumber = ?", undef, $biblionumber);
        print "Deleted biblio $biblionumber\n" if $verbose;
    }
    
    # Delete the set
    my $delete_set = "DELETE FROM oai_sets WHERE id = ?";
    $dbh->do($delete_set, undef, $set_id);
    
    print "Cleanup complete! Removed " . scalar(@biblios) . " biblios and 1 OAI set.\n";
}

sub create_test_data {
    # Create test OAI set
    my $set_name = 'TEST-Kaunokirjallisuus';
    my $set_spec = 'TEST:fiction';
    
    print "Creating OAI set: $set_name\n" if $verbose;
    
    # Check if set already exists
    my $check_query = "SELECT id FROM oai_sets WHERE name = ?";
    my $sth = $dbh->prepare($check_query);
    $sth->execute($set_name);
    
    my $set_id;
    if (my $existing = $sth->fetchrow_hashref) {
        $set_id = $existing->{id};
        print "OAI set already exists with ID: $set_id\n";
    } else {
        my $insert_set = "INSERT INTO oai_sets (spec, name) VALUES (?, ?)";
        $dbh->do($insert_set, undef, $set_spec, $set_name);
        $set_id = $dbh->last_insert_id(undef, undef, 'oai_sets', undef);
        print "Created OAI set with ID: $set_id\n";
    }
    
    # Create test biblios
    my @biblios_to_create = (
        # Regular biblios (NOT component parts)
        {
            title => 'Taru sormusten herrasta',
            author => 'Tolkien, J.R.R.',
            is_component => 0,
        },
        {
            title => 'Hobitti',
            author => 'Tolkien, J.R.R.',
            is_component => 0,
        },
        {
            title => 'Kalevala',
            author => 'Lönnrot, Elias',
            is_component => 0,
        },
        {
            title => 'Tuntematon sotilas',
            author => 'Linna, Väinö',
            is_component => 0,
        },
        {
            title => 'Seitsemän veljestä',
            author => 'Kivi, Aleksis',
            is_component => 0,
        },
        # Component parts (articles in journals, chapters in books, etc.)
        {
            title => 'Artikkeli 1: Fantasiakirjallisuuden merkitys',
            author => 'Virtanen, Matti',
            is_component => 1,
            host_title => 'Kirjallisuuslehti 2026',
        },
        {
            title => 'Artikkeli 2: Tolkienin vaikutus moderniin fantasiaan',
            author => 'Korhonen, Anna',
            is_component => 1,
            host_title => 'Kirjallisuustutkimus 15(2)',
        },
        {
            title => 'Luku 3: Hobittien historia',
            author => 'Nieminen, Pekka',
            is_component => 1,
            host_title => 'Keskimaan käsikirja',
        },
        {
            title => 'Essee: Kalevalan kieli',
            author => 'Salminen, Liisa',
            is_component => 1,
            host_title => 'Suomalainen kulttuuriperintö',
        },
        {
            title => 'Artikkeli 3: Sota-ajan kuvaus suomalaisessa kirjallisuudessa',
            author => 'Mäkinen, Jari',
            is_component => 1,
            host_title => 'Historiallinen aikakauskirja 2026',
        },
    );
    
    my @created_biblios;
    
    foreach my $biblio_data (@biblios_to_create) {
        my $biblionumber = create_test_biblio($biblio_data);
        push @created_biblios, {
            biblionumber => $biblionumber,
            title => $biblio_data->{title},
            is_component => $biblio_data->{is_component},
        };
        
        # Link to OAI set
        my $link_query = "INSERT INTO oai_sets_biblios (biblionumber, set_id) VALUES (?, ?)";
        $dbh->do($link_query, undef, $biblionumber, $set_id);
        
        if ($verbose) {
            my $type = $biblio_data->{is_component} ? 'COMPONENT' : 'REGULAR';
            print "  Created $type biblio $biblionumber: $biblio_data->{title}\n";
        }
    }
    
    # Summary
    my $total = scalar(@created_biblios);
    my $components = grep { $_->{is_component} } @created_biblios;
    my $regular = $total - $components;
    
    print "\n" . "=" x 70 . "\n";
    print "TEST DATA CREATED SUCCESSFULLY\n";
    print "=" x 70 . "\n";
    print "OAI Set:            $set_name (ID: $set_id)\n";
    print "Total biblios:      $total\n";
    print "Regular biblios:    $regular\n";
    print "Component parts:    $components\n";
    print "=" x 70 . "\n\n";
    
    print "To remove test data:\n";
    print "  perl populate_test_data.pl --clean --verbose\n\n";
}

sub create_test_biblio {
    my ($data) = @_;
    
    # Create MARC record
    my $record = MARC::Record->new();
    $record->encoding('UTF-8');
    
    # Leader
    $record->leader('00000nam a2200000 a 4500');
    
    # 008 - Fixed-Length Data Elements
    my $date = '260312';  # YYMMDD
    my $field008 = $date . 's2026    fi ||||      000 0 fin c';
    $record->append_fields(
        MARC::Field->new('008', $field008)
    );
    
    # 020 - ISBN (optional)
    $record->append_fields(
        MARC::Field->new('020', ' ', ' ', 
            'a' => '978-951-' . int(rand(90000) + 10000) . '-' . int(rand(10))
        )
    );
    
    # 100 - Main Entry-Personal Name (Author)
    if ($data->{author}) {
        $record->append_fields(
            MARC::Field->new('100', '1', ' ',
                'a' => $data->{author}
            )
        );
    }
    
    # 245 - Title Statement
    $record->append_fields(
        MARC::Field->new('245', '1', '0',
            'a' => $data->{title}
        )
    );
    
    # 260 - Publication, Distribution, etc.
    $record->append_fields(
        MARC::Field->new('260', ' ', ' ',
            'a' => 'Helsinki :',
            'b' => 'Testikirjat Oy,',
            'c' => '2026.'
        )
    );
    
    # 300 - Physical Description
    $record->append_fields(
        MARC::Field->new('300', ' ', ' ',
            'a' => int(rand(500) + 50) . ' s.'
        )
    );
    
    # 773 - Host Item Entry (for component parts)
    if ($data->{is_component} && $data->{host_title}) {
        # Add random host biblionumber to make it look realistic
        my $host_biblionumber = int(rand(90000) + 10000);
        
        $record->append_fields(
            MARC::Field->new('773', '0', ' ',
                't' => $data->{host_title},
                'w' => "(FI-test)$host_biblionumber"
            )
        );
    }
    
    # Add the biblio using Koha's AddBiblio
    my ($biblionumber, $biblioitemnumber) = AddBiblio($record, '');
    
    return $biblionumber;
}

print "Done!\n";
exit 0;
