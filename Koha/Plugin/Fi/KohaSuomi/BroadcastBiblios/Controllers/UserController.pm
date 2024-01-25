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
        if ($error->{status}) {
            return $c->render(status => $error->{status}, openapi => {error => $error->{message}});
        }
        return $c->render(status => 500, openapi => {error => $error->message});
    }
}

sub get {
    my $c = shift->openapi->valid_input or return;

    my $user_id = $c->param('user_id');
    try {
        my $users = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Users->new();
        my $response = $users->getUser($user_id);
        return $c->render(status => 200, openapi => $response);
    } catch {
        my $error = $_;
        if ($error->{status}) {
            return $c->render(status => $error->{status}, openapi => {error => $error->{message}});
        }
        return $c->render(status => 500, openapi => {error => $error->message});
    }

}

sub add {
    my $c = shift->openapi->valid_input or return;

    my $req  = $c->req->json;
    try {
        my $users = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Users->new();
        my $response = $users->addUser($req);
        return $c->render(status => 201, openapi => {message => "Success"});
    } catch {
        my $error = $_;
        if ($error->{status}) {
            return $c->render(status => $error->{status}, openapi => {error => $error->{message}});
        }
        warn Data::Dumper::Dumper($error);
        return $c->render(status => 500, openapi => {error => "Something went wrong"});
    }
}

sub update {
    my $c = shift->openapi->valid_input or return;

    my $user_id = $c->param('user_id');
    my $req  = $c->req->json;
    try {
        my $users = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Users->new();
        my $response = $users->updateUser($user_id, $req);
        return $c->render(status => 200, openapi => $response);
    } catch {
        my $error = $_;
        if ($error->{status}) {
            return $c->render(status => $error->{status}, openapi => {error => $error->{message}});
        }
        return $c->render(status => 500, openapi => {error => "Something went wrong"});
    }

}

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $user_id = $c->param('user_id');
    try {
        my $users = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Users->new();
        my $response = $users->deleteUser($user_id);
        return $c->render(status => 200, openapi => $response);
    } catch {
        my $error = $_;
        if ($error->{status}) {
            return $c->render(status => $error->{status}, openapi => {error => $error->{message}});
        }
        return $c->render(status => 500, openapi => {error => "Something went wrong"});
    }

}

1;