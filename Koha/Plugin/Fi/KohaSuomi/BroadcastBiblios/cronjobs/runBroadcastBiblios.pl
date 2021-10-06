#!/usr/bin/perl

# Copyright 2021 KohaSuomi
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
use Koha::Plugins;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Broadcast;

use Modern::Perl;
use FindBin;
use POSIX 'strftime';
use Carp;
use Koha::Biblios;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case);
use Fcntl qw( :DEFAULT :flock :seek );
use Mojolicious::Lite;


my $help = 0;
my $chunks = 200;
my $active = 0;
my $all = 0;
my $biblionumber;
my $verbose = 0;
my $limit = 0;
my $interface;
my $batchdate = strftime "%Y-%m-%d", ( localtime );
my $staged = 0;
my $stage_type;
my $target_field;
my $target_subfield = "";
my $field_check;
my $lastrecord = 0;
my $identifier_fetch = 0;
my $inactivity_timeout = 30;
my $start_time;
my $encoding_level;

GetOptions(
    'h|help'                     => \$help,
    'v|verbose'                  => \$verbose,
    'c|chunks:i'                 => \$chunks,
    'a|active'                   => \$active,
    'all'                        => \$all,
    'b|biblionumber:i'           => \$biblionumber,
    'l|limit:i'                  => \$limit,
    'i|interface:s'              => \$interface,
    's|staged'                   => \$staged,
    'batchdate:s'                => \$batchdate,
    't|type:s'                   => \$stage_type,
    'f|field:s'                  => \$target_field,
    'subfield:s'                 => \$target_subfield,
    'check:s'                    => \$field_check,
    'lastrecord'                 => \$lastrecord,
    'identifier'                 => \$identifier_fetch,
    'inactivity_timeout:i'       => \$inactivity_timeout,
    'start_time:i'               => \$start_time,
    'blocked_encoding_level:s'   => \$encoding_level,

);

my $usage = <<USAGE;
    Broadcast biblios to REST endpoint

    -h, --help              This message.
    -v, --verbose           Verbose.
    -c, --chunks            Process biblios in chunks, default is 200.
    -a, --active            Send active biblios.
    --all                   Send all biblios, default sends biblios from today.
    -b, --biblionumber      Start sending from defined biblionumber.
    -l, --limit             Limiting the results of biblios.
    -i, --interface         Interface name: with active add your system interface and with staged add remote.
    -s, --staged            Export staged records to interface.
    --batchdate             Import batch date, used with 'staged' parameter. Default is today.
    -t, --type              Stage type, used with 'staged' parameter. Add or update, default is add.
    -f, --field             Find target id from marcxml, used with 'staged' parameter and update type.
    --check                 Check that field contains some spesific identifier.
    --lastrecord            Automatically check which is lastly activated record.
    --identifier            Push to active records with identifier.
    --inactivity_timeout    Can be used to increase response waiting time, default is 30.
    --start_time            Define hour when to start broadcast.
    --blocked_encoding_level Block encoding level from broadcast. Add multiple values with pipe eg. "5|7|8"

USAGE

if ($help) {
    print $usage;
    exit 0;
}

if ($biblionumber && !$active) {
    print "Use biblionumber only with active parameter\n";
    exit 0;
}

if ($staged && $stage_type eq "update" && !$target_field && !$field_check) {
    print "Target id field and check are missing!\n";
    exit 0;
}



my $configPath = $ENV{"KOHA_CONF"};
my($file, $path, $ext) = fileparse($configPath);
my $config = plugin Config => {file => $path.'broadcast-config.conf'};

my $apikey = Digest::SHA::hmac_sha256_hex($config->{apiKey});
my $headers = {"Authorization" => $apikey};
my $last_itemnumber;

my $endpoint;
my $endpoint_type;

if ($staged) {
    $endpoint = $config->{exportEndpoint};
    $endpoint_type = 'export';
} else {
    if ($active && $identifier_fetch) {
        $endpoint = $config->{activeEndpoint}.'/identifier';
        $endpoint_type = 'identifier_activation';
    } elsif ($active) {
        $endpoint = $config->{activeEndpoint};
        $endpoint_type = 'active';
    } else {
        $endpoint = $config->{broadcastEndpoint};
        $endpoint_type = 'broadcast';
    }
}

my $plugin = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios->new({
    chunks => $chunks,
    biblionumber => $biblionumber,
    limit => $limit,
    page => 1,
    timestamp => undef,
    endpoint => $endpoint, 
    endpoint_type => $endpoint_type,
    interface => $interface, 
    inactivity_timeout => $inactivity_timeout,
    headers => $headers,
    all => $all,
    verbose => $verbose,
    start_time => $start_time,
    blocked_encoding_level => $encoding_level,
});

$plugin->run();