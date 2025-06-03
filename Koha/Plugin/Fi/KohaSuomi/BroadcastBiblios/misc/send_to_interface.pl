#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use Koha::Plugins;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Config;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Broadcast;

# Define options
my $help;
my $verbose = 0;  # Default to non-verbose
my $file;
my @biblionumbers;
my $confirm = 0;  # Default to no confirmation
my $interface = '';

GetOptions(
    'help|h'      => \$help,
    'verbose|v'   => \$verbose,
    'biblionumber|b=s' => \@biblionumbers,
    'file|f=s' => \$file,
    'interface|i=s' => \$interface,
    'confirm|c'  => \$confirm,
) or die "Error in command line arguments\n";

if ($help) {
    print <<"END_HELP";
Usage: $0 [options]

Options:
  --help, -h           Show this help message
  --verbose, -v        Enable verbose output
  --biblionumber, -b <num>  Biblionumber(s) to send (can be specified multiple times)
  --file, -f <file>   File containing biblionumbers (optional)
  --interface, -i <if> Interface to send to
  --confirm, -c       Confirm sending (default is no confirmation)

END_HELP
    exit 0;
}

if ($file) {
    open my $fh, '<', $file or die "Could not open file '$file': $!";
    while (my $line = <$fh>) {
        chomp $line;
        push @biblionumbers, $line if $line =~ /^\d+$/;  # Only add valid biblionumbers
    }
    close $fh;
}
# Ensure we have biblionumbers and an interface
if (!@biblionumbers && !$file) {
    die "No biblionumbers provided. Use --biblionumber or --file to specify them.\n";
}
if (!@biblionumbers && $file) {
    die "No valid biblionumbers found in file '$file'.\n";
}
unless (@biblionumbers && $interface) {
    die "Both --biblionumber and --interface options are required. Use --help for usage.\n";
}

my $config = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Config->new();
my $interfaceConfig = $config->getInterfaceConfig($interface);
if (!$interfaceConfig) {
    die "Interface '$interface' not found in configuration.\n";
}
my $broadcast = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Broadcast->new({
    verbose => $verbose,  # Set to 1 for verbose output
});
# Simulate sending message to interface
foreach my $biblionumber (@biblionumbers) {
    $broadcast->sendToInterface($interfaceConfig, $biblionumber, $confirm);
}

print "All biblionumbers sent successfully.\n" if $confirm;