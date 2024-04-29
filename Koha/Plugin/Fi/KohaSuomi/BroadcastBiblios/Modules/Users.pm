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
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Config;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler;
use C4::Context;
use Crypt::JWT qw(encode_jwt decode_jwt);
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

sub getSecret {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Config->new()->getSecret;
}

sub getEndpoint {
    my ($self) = @_;
    return shift->{_params}->{endpoint};
}

sub getPath {
    my ($self) = @_;
    return $self->getConfig->{restUrl}.$self->getEndpoint;
}

sub ua {
    my ($self) = @_;
    return Mojo::UserAgent->new;
}

sub listUsers {
    my ($self) = @_;
    my $users = $self->db->listUsers;
    my $response = [];
    foreach my $user (@$users) {
        push @$response, {id => $user->{id}, username => $user->{username}, auth_type => $user->{auth_type}, broadcast_interface => $user->{broadcast_interface}};
    }
    return $response;
}

sub getUser {
    my ($self, $user_id) = @_;
    my $user = $self->db->getUserByUserId($user_id);
    if (!$user) {
        die {message => "User not found", status => 404};
    }
    return {id => $user->{id}, username => $user->{username}, auth_type => $user->{auth_type}, client_id => $user->{client_id}, client_secret => $user->{client_secret}, access_token_url => $user->{access_token_url}, broadcast_interface => $user->{broadcast_interface}, linked_borrowernumber => $user->{linked_borrowernumber}};
}

sub getInterfaceUserByPatronId {
    my ($self, $interface_name, $patron_id) = @_;
    my $user = $self->db->getBroadcastInterfaceUser($interface_name, $patron_id);
    if (!$user) {
        die {message => "User not found", status => 404};
    }
    return $user->{id};
}

sub addUser {
    my ($self, $params) = @_;
    my $user = $self->db->getUserByUsername($params->{username});
    if ($user->{username} && $user->{username} eq $params->{username}) {
        die {message => "User already exists", status => 409};
    }
    if ($params->{password}) {
        $params->{password} = encode_jwt(payload => $params->{password}, alg => 'HS256', key => $self->getSecret);
    }
    $self->db->insertUser($params);
    return {message => "User added", status => 201};
}

sub updateUser {
    my ($self, $user_id, $params) = @_;
    my $user = $self->db->getUserByUserId($user_id);
    if (!$user) {
        die {error => "User not found", status => 404};
    }
    if ($params->{password}) {
        $params->{password} = encode_jwt(payload => $params->{password}, alg => 'HS256', key => $self->getSecret);
    }
    $self->db->updateUser($user_id, $params);
    return {message => "User updated", status => 200};
}

sub deleteUser {
    my ($self, $user_id) = @_;
    my $user = $self->db->getUserByUserId($user_id);
    if (!$user) {
        die {error => "User not found", status => 404};
    }
    $self->db->deleteUser($user_id);
    return {message => "User deleted", status => 200};
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
    my $password = eval { decode_jwt(token => $user->{password}, key => $self->getSecret)};
    if ($@) {
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception("Generic", 500, {message => "Error while decoding password " . $@});
    }
    my $authentication = $user->{username} . ":" . $password;
    my $path = Mojo::URL->new($self->getPath)->userinfo($authentication);
    my $headers = {'Content-Type' => 'application/json'};
    return ($path, $headers);
}

sub OAUTH2 {
    my ($self, $user) = @_;
    my $headers = {'Content-Type' => 'application/json', 'Authorization' => 'Bearer ' . $self->getAccessToken($user)};
    return ($self->getPath, $headers);
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
        print "Error while refreshing token " . $tx->res->error->{message} . " " . $tx->res->body . "\n";
        $self->db->updateAccessToken($user->{id}, undef, undef);
        return 0;
    }

    my $res = $tx->res->json;
    $self->db->updateAccessToken($user->{id}, $res->{access_token}, time() + $res->{expires_in});

    return $res->{access_token};
}

1;
