#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use C4::Context;
use MARC::Record;
use MARC::File::XML;
use Koha::Plugins;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Database;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios;
use Koha::ActionLogs;

my $file;
my $start_date;
my $end_date;
my @biblionumbers;
my $confirm;
my $verbose;

GetOptions(
    'verbose'        => \$verbose,
    'start_date=s'   => \$start_date,
    'end_date=s'     => \$end_date,
    'biblionumbers=s' => \@biblionumbers,
    'confirm'        => \$confirm,
) or die "Error in command line arguments\n";

if (!$start_date || !$end_date) {
    die "You must provide a start date and an end date in the format 'YYYY-MM-DD HH:MM:SS'\n";
}

my $db = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Database->new();
my $biblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new();

my $updated_log = $db->getBroadcastLogBetweenTimestamps($start_date, $end_date);
print "Found " . scalar(@{$updated_log}) . " records\n";

foreach my $log (@$updated_log) {
    #next unless grep { $_ == $log->{biblionumber} } @biblionumbers && !@biblionumbers;
    my $biblionumber = $log->{biblionumber};
    my $timestamp = $log->{updated};
    print "Biblionumber $biblionumber processed at $timestamp\n";
    my $previous_action = find_from_action_log($biblionumber, $timestamp);
    if ($previous_action && $previous_action->timestamp lt $timestamp) {
        print "Restoring record $biblionumber to previous state ".$previous_action->id." at ".$previous_action->timestamp."\n";
        print $previous_action->info . "\n" if $verbose;
        $biblios->restoreRecordFromActionLog($previous_action->id) if $confirm;
    }
}

sub find_from_action_log {
    my ($biblionumber) = @_;
    my $action = Koha::ActionLogs->search(
        { object => $biblionumber, module => 'CATALOGUING', action => 'MODIFY', info => { 'like' => 'biblio%'} }, 
        { order_by => { -desc => 'timestamp' } },
        { rows => 1 })->next;
    return $action;
}
    

