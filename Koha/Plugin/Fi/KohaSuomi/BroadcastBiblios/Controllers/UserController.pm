package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Controllers::UserController;

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

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';
use Try::Tiny;

use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Users;

=head1 API

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    try {
        my $users = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Users->new();
        my $response = $users->listUsers();
        return $c->render(status => 200, openapi => $response);
    } catch {
        my $error = $_;
        return $c->render(status => 400, openapi => {error => $error->message});
    }
}

sub set {
    my $c = shift->openapi->valid_input or return;

    my $req  = $c->req->json;
    try {
        my $config = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Config->new($req);
        $config->setConfig();
        return $c->render(status => 200, openapi => {message => "Success"});
    } catch {
        my $error = $_;
        return $c->render(status => 400, openapi => {error => $error->message});
    }
}

1;