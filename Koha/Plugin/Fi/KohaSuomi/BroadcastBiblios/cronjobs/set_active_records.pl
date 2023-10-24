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
use YAML::XS;


my $help = 0;
my $chunks = 200;
my $all = 0;
my $biblionumber;
my $verbose = 0;
my $limit = 0;
my $interface;

GetOptions(
    'h|help'                     => \$help,
    'v|verbose'                  => \$verbose,
    'all'                        => \$all,
    'c|chunks:i'                 => \$chunks,
    'b|biblionumber:i'           => \$biblionumber,
    'l|limit:i'                  => \$limit,
    'i|interface:s'              => \$interface,

);

my $usage = <<USAGE;
    Broadcast biblios to REST endpoint

    -h, --help              This message.
    -v, --verbose           Verbose.
    --all                   Process all biblios.
    -c, --chunks            Process biblios in chunks, default is 200.
    -b, --biblionumber      Start sending from defined biblionumber.
    -l, --limit             Limiting the results of biblios.
    -i, --interface         Interface to use for broadcasting.

USAGE

if ($help) {
    print $usage;
    exit 0;
}

my $configPath = $ENV{"KOHA_CONF"};
my($file, $path, $ext) = fileparse($configPath);
my $configfile = eval { YAML::XS::LoadFile($path.'broadcast-config.yaml') };

my $params = {
    all => $all,
    chunks => $chunks,
    limit => $limit,
    page => 1,
    verbose => $verbose,
};

if ($interface) {
    $params->{config} = $configfile->{$interface};
}

my $plugin = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios->new($params);

$plugin->set_active();