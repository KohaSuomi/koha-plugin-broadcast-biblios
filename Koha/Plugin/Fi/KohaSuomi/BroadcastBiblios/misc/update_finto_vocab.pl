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
my $vocab;
my $lang;
my $type = 'modified';
my $confirm;
my $since_date = strftime("%Y-%m-%d", localtime());

# Parse command-line options
GetOptions(
    'help|h'       => \$help,
    'verbose|v'    => \$verbose,
    'vocab=s'      => \$vocab,
    'lang=s'       => \$lang,
    'type=s'       => \$type,
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
    --vocab          Specify the vocabulary to update
    --lang           Specify the language (fi, sv, en)
    --type           Specify the type of update (default: modified)
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
if (!$vocab || !$lang) {
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
# Validate vocabulary
my %valid_vocabularies = (
    'stw'   => 1,
    'yso'   => 1,
);
if (!exists $valid_vocabularies{$vocab}) {
    die "Error: Invalid vocabulary specified. Valid options are: stw, yso.\n";
}
# Initialize user agent
my $ua = Mojo::UserAgent->new;
my $baseUrl = 'https://api.finto.fi/rest/v1/';
my $getUrl = $baseUrl .'/'. $vocab.'/'.$type. '?lang=' . $lang;

# Make the API request
my $response = $ua->get($getUrl)->result;
if ($response->is_error) {
    die "Error: Failed to fetch data from Finto API. Status: " . $response->code . "\n";
}
# Decode the JSON response
my $data = decode_json($response->body);
my $dbh = C4::Context->dbh;
my $count = 0;
my $success = 0;
# Process the data
foreach my $item (@{$data->{changeList}}) {
    my $parsed_date = substr($item->{date}, 0, 10);
    next unless $since_date lt $parsed_date;
    my $uri = $item->{uri};
    my $prefLabel = $item->{prefLabel};
    my $results = _search_records($uri);
    if ($results) {
        foreach my $result (@$results) {
            my $biblio_id = $result->subfield('999', 'c');
            print "Found record $biblio_id for URI: $uri\n" if $verbose;
            my $record = _find_field_and_replace($result, $uri, $prefLabel);
            next unless $record;
            $count++;
            if ($confirm) {
                print "Updating record with biblionumber: $biblio_id\n" if $verbose;
                my $biblionumber = eval { ModBiblioMarc( $record, $biblio_id ) };
                if ($@) {
                    warn "Error: $@";
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
    my ($record, $uri, $new_value) = @_;

    return 0 if $record->subfield('041', 'a') && $record->subfield('041', 'a') ne $map_lang_to_marc->{$lang};
    foreach my $field ($record->fields()) {
        next if $field->tag < '010';
        if ($field->subfield('0') && $field->subfield('0') eq $uri) {
            my $subfield = $field->subfield('a');
            if ($subfield && $subfield ne $new_value) {
                print "Replacing ".$field->tag()."\$a $subfield with $new_value\n" if $verbose;
                my $new_field = MARC::Field->new($field->tag, $field->indicator(1), $field->indicator(2), 'a' => $new_value);
                $record->insert_fields_after($field, $new_field);
                $record->delete_field($field);
            }
        }
    }
    return $record;
}