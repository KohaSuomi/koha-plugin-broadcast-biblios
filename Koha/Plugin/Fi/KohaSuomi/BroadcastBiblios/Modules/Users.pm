package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Users;

# Copyright 2023 Koha-Suomi Oy
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
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
use Carp;
use Scalar::Util qw( blessed );
use Try::Tiny;
use JSON;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Database;
use C4::Context;
use Crypt::JWT;
use Mojo::UserAgent;
use Koha::Logger;

=head new

    my $users = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Users->new($params);

=cut

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;

}

sub db {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Database->new;
}

sub getConfig {
    my ($self) = @_;
    return shift->{_params}->{config};
}

sub getEndpoint {
    my ($self) = @_;
    return shift->{_params}->{endpoint};
}

sub ua {
    my ($self) = @_;
    return Mojo::UserAgent->new;
}

sub getLogger {
    return Koha::Logger->get({instance => 'broadcast'});
}

sub addUser {

}

sub getAuthentication {
    my ($self, $user_id) = @_;

    my $user = $self->db->getUserByUserId($user_id);

    if ($user->{auth_type} eq "basic") {
        return $self->basicAuth($user);
    }

    if ($user->{auth_type} eq "oauth") {
        return $self->OAUTH2($user);
    }

    return 0;
}

sub basicAuth {
    my ($self, $user) = @_;
    my $endpoint = $self->getConfig->{baseUrl}.'/'.$self->getConfig->{$self->getEndpoint}->{path};
    my $authentication = $user->{username} . ":" . $user->{password};
    my $path = Mojo::URL->new($endpoint)->userinfo($authentication);
    my $headers = {'Content-Type' => 'application/json'};
    return ($path, $headers);
}

sub OAUTH2 {
    my ($self, $user) = @_;
    my $path = $self->getConfig->{baseUrl}.'/'.$self->getConfig->{$self->getEndpoint}->{path};
    my $headers = {'Content-Type' => 'application/json', 'Authorization' => 'Bearer ' . $self->getAccessToken($user)};
    return ($path, $headers);
}

sub getAccessToken {
    my ($self, $user) = @_;
    
    if ($user->{token_expires} < time()) {
        return $self->refreshAccessToken($user);
    } else {
        return $user->{access_token};
    }
}

sub refreshAccessToken {
    my ($self, $user) = @_;
    my $tx = $self->ua->post($user->{access_token_url} => form => {client_id => $user->{client_id}, client_secret => $user->{client_secret}, grant_type => $user->{grant_type}});
    
    if ($tx->res->error) {
        $self->getLogger->error($tx->res->error->{message} . " " . $tx->res->body);
        $self->db->updateAccessToken($user->{id}, undef, undef);
        return 0;
    }

    my $res = $tx->res->json;
    $self->db->updateAccessToken($user->{id}, $res->{access_token}, time() + $res->{expires_in});

    return $res->{access_token};
}

1;
