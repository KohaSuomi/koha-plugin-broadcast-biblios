#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Koha::SearchEngine::Search;
use C4::Biblio;
use C4::Context;
use MARC::Field;
use MARC::Record;
use POSIX qw(strftime);

# Define options
my $help;
my $verbose;
my @vocabs;
my $lang;
my $confirm;
# Set $since_date to the first day of the previous month
my ($sec, $min, $hour, $mday, $mon, $year) = localtime();
$mon--; # Go to previous month
if ($mon < 0) {
    $mon = 11;
    $year--;
}
$year += 1900;
my $since_date = sprintf("%04d-%02d-01", $year, $mon + 1);

# Parse command-line options
GetOptions(
    'help|h'       => \$help,
    'verbose|v'    => \$verbose,
    'vocab=s@'     => \@vocabs,
    'lang=s'       => \$lang,
    'since_date=s' => \$since_date,
    'confirm'      => \$confirm,
) or die "Error in command line arguments. Use --help for usage.\n";

# Display help message
if ($help) {
    print <<'END_HELP';
Usage: update_finto_vocab.pl [options]

Options:
    --help, -h       Show this help message
    --verbose, -v    Enable verbose output
    --vocab          Specify the vocabulary to update. Is repeated for multiple vocabularies (stw, yso, yso-aika)
    --lang           Specify the language (fi, sv, en)
    --since_date     Specify the date since when to fetch updates (default: current date)
    --confirm        Confirm the changes before applying them

Description:
    This script updates the Finto vocabulary based on the specified options.
    It fetches data from the Finto API and processes it according to the provided parameters.
    The script requires the following parameters:
        --vocab: The vocabulary to update (stw, yso)
        --lang: The language to use (fi, sv, en)

END_HELP
    exit;
}

# Check if required arguments are provided
if (!@vocabs || !$lang) {
    die "Error: --vocab and --lang are required arguments. Use --help for usage.\n";
}
# Validate language
my %valid_languages = (
    'fi' => 1,
    'sv' => 1,
    'en' => 1,
);

my $map_lang_to_marc = {
    'fi' => 'fin',
    'sv' => 'swe',
    'en' => 'eng',
};

if (!exists $valid_languages{$lang}) {
    die "Error: Invalid language specified. Valid options are: fi, sv, en.\n";
}

foreach my $vocab (@vocabs) {
    
    print "Processing vocabulary: $vocab since $since_date\n";

    # Initialize user agent
    my $ua = Mojo::UserAgent->new;
    my $baseUrl = 'https://api.finto.fi/rest/v1/';
    my $modUrl = $baseUrl .'/'. $vocab.'/modified?lang=' . $lang;
    my $newUrl = $baseUrl .'/'. $vocab.'/new?lang=' . $lang; 

    # Make the API requests
    my $response_modified = $ua->get($modUrl)->result;
    if ($response_modified->is_error) {
        die "Error: Failed to fetch modified data from Finto API. Status: " . $response_modified->code . ", Message: " . $response_modified->message . "\n";
    }

    my $response_new = $ua->get($newUrl)->result;
    if ($response_new->is_error) {
        die "Error: Failed to fetch new data from Finto API. Status: " . $response_new->code . ", Message: " . $response_new->message . "\n";
    }

    # Combine the responses
    my $data_modified = decode_json($response_modified->body);
    my $data_new = decode_json($response_new->body);

    # Merge changeList arrays
    $data_modified->{changeList} = [
        @{$data_modified->{changeList} || []},
        @{$data_new->{changeList} || []}
    ];

    # Use the combined data
    my $data = $data_modified;
    my $dbh = C4::Context->dbh;
    my $count = 0;
    my $success = 0;

    # Process the data
    foreach my $item (@{$data->{changeList}}) {
        my $parsed_date = substr($item->{date}, 0, 10);
        next unless $since_date lt $parsed_date;
        my $uri = $item->{uri};
        my $prefLabel = $item->{prefLabel};
        my $replacedByURI = $item->{replacedBy};
        my $replacingLabel = $item->{replacingLabel};
        my $new_value = $replacingLabel || $prefLabel;
        my $results = _search_records($uri);
        if ($results) {
            foreach my $result (@$results) {
                my $biblio_id = $result->subfield('999', 'c');
                print "Found record $biblio_id for URI: $uri\n" if $verbose;
                my $record = _find_field_and_replace($result, $uri, $new_value, $replacedByURI, $vocab);
                next unless $record;
                $count++;
                if ($confirm) {
                    print "Updating record with biblionumber: $biblio_id\n";
                    my $biblionumber = eval { C4::Biblio::ModBiblioMarc( $record, $biblio_id ) };
                    if ($@) {
                        print "Error: $@";
                    } else {
                        my $dbh = C4::Context->dbh;
                        my $biblio = C4::Biblio::TransformMarcToKoha({ record => $record });
                        my $frameworkcode = C4::Biblio::GetFrameworkCode($biblionumber);
                        C4::Biblio::_koha_modify_biblio($dbh, $biblio, $frameworkcode);
                        C4::Biblio::_koha_modify_biblioitem_nonmarc($dbh, $biblio);
                        $success++;
                    }
                }
            }
        }
    }
    print "Processed $count records.\n" if $verbose;
    if ($success) {
        print "Successfully updated $success records.\n";
    } else {
        print "No records were updated.\n";
    }
    # Close the database connection
    $dbh->disconnect;
}

# Exit the script
exit 0;
# End of script
# Subroutines
sub _search_records {
    my ($uri) = @_;
    
    my $searcher = Koha::SearchEngine::Search->new({index => $Koha::SearchEngine::BIBLIOS_INDEX});
    my $query = "koha-auth-number,ext:\"$uri\"";
    my ( $error, $results, $total_hits ) = $searcher->simple_search_compat( $query, 0, 10 );
    if ($error) {
        print "Error: Searching ($query):> Returned an error:\n$error";
    }
    return $results;
}

sub _find_field_and_replace {
    my ($record, $uri, $new_value, $replaced_uri, $vocab) = @_;

    my $vocab_field = vocab_to_marc($vocab).'/'.$map_lang_to_marc->{$lang};
    my $updated = 0;
    foreach my $field ($record->fields()) {
        next if $field->tag < '010';
        if ($field->subfield('0') && $field->subfield('0') eq $uri && $field->subfield('2') eq $vocab_field) {
            my $subfield = $field->subfield('a');
            if ($subfield && $subfield ne $new_value) {
                print "Replacing ".$field->tag()."\$a $subfield with $new_value\n" if $verbose;
                my $new_uri = $replaced_uri || $uri;

                # Check if new_uri already exists in any $0 of the record
                my $uri_exists = 0;
                my $uri_value;
                foreach my $f ($record->fields()) {
                    next if $f->tag < '010';
                    if ($f->subfield('0') && $f->subfield('0') eq $new_uri && $f->subfield('2') eq $vocab_field) {
                        $uri_exists = 1;
                        $uri_value = $f->subfield('a');
                        last;
                    }
                }
                if ($uri_exists && $uri_value eq $new_value) {
                    print "New URI $new_uri already exists in record, skipping replacement and deletion.\n" if $verbose;
                    $record->delete_field($field);
                    $updated = 1;
                    next;
                }

                my @old_subfields = $field->subfields();
                my @new_subfields = map { @$_ } @old_subfields;
                @new_subfields = map { $_->[0] eq 'a' ? ('a' => $new_value) : $_->[0] eq '0' ? ('0' => $new_uri) : @$_ } @old_subfields;
                my $new_field = MARC::Field->new(
                    $field->tag,
                    $field->indicator(1),
                    $field->indicator(2),
                    @new_subfields,
                );
                print Data::Dumper::Dumper($new_field) if $verbose;
                $record->insert_fields_after($field, $new_field);
                $record->delete_field($field);
                $updated = 1;
            }
        }
    }
    return 0 unless $updated;
    return $record;
}

sub vocab_to_marc {
    my ($vocab) = @_;
    if ($vocab =~ /^([^-]+)/) {
        return $1;
    }
}