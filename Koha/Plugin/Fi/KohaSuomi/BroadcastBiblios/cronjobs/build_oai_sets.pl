#!/usr/bin/perl

# Copyright 2018 KohaSuomi
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
use Mojolicious::Lite;


my $help = 0;
my $verbose = 0;
my $date = '';
my $set_spec = '';
my $set_name = '';

GetOptions(
    'h|help'                     => \$help,
    'v|verbose'                  => \$verbose,
    'd|date:s'                   => \$date,
    'set_spec:s'                 => \$set_spec,
    'set_name:s'                 => \$set_name,


);

my $usage = <<USAGE;
    Broadcast biblios to REST endpoint

    -h, --help              This message.
    -v, --verbose           Verbose.
    -d, --date              Find imported on a selected date, default is today.
    --set_spec              Set spec for OAI set.
    --set_name              Set name for OAI set.

USAGE

if ($help) {
    print $usage;
    exit 0;
}

my $plugin = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios->new({
    verbose => $verbose,
    date => $date,
    set_spec => $set_spec,
    set_name => $set_name,
});

$plugin->build_oai();