package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::REST;

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
use utf8;
use Carp;
use Scalar::Util qw( blessed );
use Try::Tiny;
use C4::Context;
use MARC::Record;
use DateTime;
use Mojo::UserAgent;
use Koha::Logger;
use XML::LibXML;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MarcXMLToJSON;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Config;

=head new

    my $rest = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::REST->new($params);

=cut

sub new {
    my ($class, $params) = _validateNew(@_);
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;

}

sub _validateNew {
    my ($class, $params) = @_;
    unless ($params->{interface}) {
        die "Missing interface parameter";
    }

    return @_;
}

sub interface {
    my ($self) = @_;
    return shift->{_params}->{interface};
}

sub verbose {
    my ($self) = @_;
    return shift->{_params}->{verbose};
}

sub getConfig {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Config->new->getInterfaceConfig($self->interface);
}

sub ua {
    my ($self) = @_;
    my $ua = Mojo::UserAgent->new;
    $ua->proxy->https("socks://127.0.0.1:1337");
    return $ua;
}

sub MarcXMLToJSON {
    my ($self, $marcxml) = @_;
    my $marcjson = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MarcXMLToJSON->new();
    return $marcjson->toJSON($marcxml);
}

sub users {
    my ($self, $endpoint) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Users->new({config => $self->getConfig, endpoint => $endpoint});
}

sub apiCall {
    my ($self, $params) = @_;

    $params = $self->interfaceActions($self->interface, $params);
    my $user_id = $params->{user_id} || $self->getConfig->{defaultUser};
    my $type = $params->{type};
    my $data = $params->{data};
    my $format = $params->{format};

    my $restEndpoint = $self->getConfig->{$self->getRESTEndpoint($type)};
    my $path = $self->parseRestData($restEndpoint, $data);
    my $headers;
    ($path, $headers) = $self->users($path)->getAuthentication($user_id);
    $headers = $self->headers($type, $headers);
    my $method = $self->getConfig->{$self->getRESTMethod($type)} ? $self->getConfig->{$self->getRESTMethod($type)} : $type;
    $method = lc($method);
    my $body = $params->{data}->{body};
    
    my $response = $self->call($method, $path, $headers, $format, $body)->result;
    return $response;
}

sub getRESTEndpoint {
    my ($self, $type) = @_;
    return {
        SEARCH => "restSearch",
        GET => "restGet",
        POST => "restAdd",
        PUT => "restUpdate",
        DELETE => "restDelete"
    }->{$type};

}

sub getRESTMethod {
    my ($self, $type) = @_;
    return {
        SEARCH => "restSearchMethod",
        GET => "restGetMethod",
        POST => "restAddMethod",
        PUT => "restUpdateMethod",
        DELETE => "restDeleteMethod"
    }->{$type};

}

sub parseRestData {
    my ($self, $path, $data) = @_;
    $path =~ s/{biblio_id}/$data->{biblio_id}/g;
    $path =~ s/%7Bbiblio_id%7D/$data->{biblio_id}/g;
    return $path;
}

sub headers {
    my ($self, $type, $headers) = @_;
    
    if ($type eq "GET" || $type eq "SEARCH") {
        $headers->{"Accept"} = "application/marc-in-json" unless $self->interface =~ /Melinda/i;
        $headers->{"Accept"} = "application/json" if $self->interface =~ /Melinda/i;
        
    }

    return $headers;
}

sub call {
    my ($self, $method, $path, $headers, $format, $body) = @_;
    my $response = $self->ua->inactivity_timeout(180)->$method($path => $headers);
    $response = $self->ua->inactivity_timeout(180)->$method($path => $headers => $body) if defined $body && $body;
    $response = $self->ua->inactivity_timeout(180)->$method($path => $headers => $format => $body) if defined $format && ($format eq "json" || $format eq "form") && defined $body && $body;
    print Data::Dumper::Dumper $response->result if $response->result->is_error && $self->verbose();
    return $response;
}

sub interfaceActions {
    my ($self, $interface, $params) = @_;

    if ($interface =~ /Melinda/i) {
        $params->{format} = "json";
    }

    return $params;
}

1;