#!/usr/bin/perl

# Copyright 2024 Koha-Suomi Oy
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
use Try::Tiny;
use Koha::Plugins;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Users;

my $help;
my $username;
my $broadcast_interface;
my $password;
my $client_id;
my $client_secret;
my $auth_type;

GetOptions(
    "h|help" => \$help,
    "username=s" => \$username,
    "broadcast_interface=s" => \$broadcast_interface,
    "password=s" => \$password,
    "client_id=s" => \$client_id,
    "client_secret=s" => \$client_secret,
    "auth_type=s" => \$auth_type
);

if ($help) {
    print "Usage: add_user.pl --username <username> --broadcast_interface <broadcast_interface> --auth_type <basic|oauth> [--password <password>] [--client_id <client_id>] [--client_secret <client_secret>]\n";
    exit;
}

# Validate input parameters
unless ($username && $broadcast_interface && $auth_type) {
    die "Missing required parameters. Usage: add_user.pl --username <username> --broadcast_interface <broadcast_interface> --auth_type <basic|oauth> [--password <password>] [--client_id <client_id>] [--client_secret <client_secret>]\n";
}

if ($auth_type eq 'oauth' && !$client_id && !$client_secret) {
    die "Missing required parameters for oauth. Usage: add_user.pl --username <username> --auth_type oauth --client_id <client_id> --client_secret <client_secret>\n";
}

if ($auth_type eq 'basic' && !$password) {
    die "Missing required parameters for basic auth. Usage: add_user.pl --username <username> --auth_type basic --password <password>\n";
}

# Create a new user
try {
    my $user = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Users->new();
    my $new_user = $user->addUser({
        username => $username,
        broadcast_interface => $broadcast_interface,
        password => $password,
        client_id => $client_id,
        client_secret => $client_secret,
        auth_type => $auth_type
    });
    print "User created successfully\n";
} catch {
    my $error = $_;
    die "Failed to create user: $error->{message}\n";
};
