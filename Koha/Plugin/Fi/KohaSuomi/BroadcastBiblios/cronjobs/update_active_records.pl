#!/usr/bin/perl

# Copyright 2023 Koha-Suomi Oy
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}
use
  CGI; # NOT a CGI script, this is just to keep C4::Templates::gettemplate happy
use C4::Context;
use Modern::Perl;
use Getopt::Long;
use Carp;
use File::Basename;
use Fcntl qw( :DEFAULT :flock :seek );
use Koha::Plugins;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Config;


my $help = 0;
my $chunks = 200;
my $all = 0;
my $verbose = 0;
my $limit = 0;

GetOptions(
    'h|help'                     => \$help,
    'v|verbose'                  => \$verbose,
    'c|chunks:i'                 => \$chunks,
    'l|limit:i'                  => \$limit,

);

my $usage = <<USAGE;
    Broadcast biblios to REST endpoint

    -h, --help              This message.
    -v, --verbose           Verbose.
    -c, --chunks            Process biblios in chunks, default is 200.
    -l, --limit             Limiting the results of biblios.

USAGE

if ($help) {
    print $usage;
    exit 0;
}

my $configs = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Config->new({verbose => $verbose});
my $interface = $configs->getActivationInterface;

my $plugin = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios->new({
    chunks => $chunks,
    limit => $limit,
    page => 1,
    verbose => $verbose,
    config => $interface,
});

$plugin->update_active();