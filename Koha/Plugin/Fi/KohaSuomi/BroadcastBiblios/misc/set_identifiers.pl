#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use C4::Context;
use MARC::Record;
use MARC::File::XML;
use Koha::Plugins;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Database;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::Identifiers;
use Koha::ActionLogs;

my $help;
my $verbose;
my $field;
my $like;
my @biblionumbers;
my $confirm;

GetOptions(
    'help'            => \$help,
    'verbose'         => \$verbose,
    'field=s'         => \$field,
    'like=s'          => \$like,
    'biblionumbers=s' => \@biblionumbers,
    'confirm'         => \$confirm,
) or die "Error in command line arguments\n";

if ($help) {
    print "Usage: $0 --field <field> --like <like> OR --biblionumbers <biblionumbers>\n";
    exit;
}

my $db = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Database->new();

my $activeRecords;

if ($like eq 'FI-BTJ') {
    $like = '(FI-BTJ)%';
}

if (@biblionumbers) {
    foreach my $biblionumber (@biblionumbers) {
        my $activeRecord = $db->getActiveRecordByBiblionumber($biblionumber);
        push @$activeRecords, $activeRecord if $activeRecord;
    }
} elsif ($field && $like) {
    $activeRecords = $db->getActiveRecordsLike($like, $field);
} else {
    die "You must provide either a list of biblionumbers or a field and like\n";
}

my $identifiers = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::Identifiers->new();
my $count = 0;
foreach my $activeRecord (@$activeRecords) {
    my ($identifier, $identifier_field) = $identifiers->getIdentifierField($activeRecord->{metadata});
    print "Biblionumber $activeRecord->{biblionumber} has identifier $identifier in field $identifier_field\n" if $verbose;
    if ($confirm) {
        print "Updating biblionumber $activeRecord->{biblionumber} with identifier $identifier in field $identifier_field\n" if $verbose;
        $db->updateActiveRecordIdentifiers($activeRecord->{id}, $identifier, $identifier_field);
    }

    $count++;
}

print "Processed $count records\n";