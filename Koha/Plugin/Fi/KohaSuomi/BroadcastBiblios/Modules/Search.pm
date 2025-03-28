package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Search;

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
use C4::Context;
use Koha::SearchEngine::Search;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::QueryParser;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::SRU;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler;
use Mojo::UserAgent;

=head new

    my $search = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Search->new($params);

=cut

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;

}

sub getConfig {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Config->new;
}

sub ua {
    my ($self) = @_;
    return Mojo::UserAgent->new;
}

sub getRecord {
    my ($self, $marcxml) = @_;

    my $biblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new();
    return $biblios->getRecord($marcxml);
}

sub getHostRecord {
    my ($self, $r) = @_;

    my $f773w = $r->subfield('773', 'w');
    my $f003;
    if ($f773w =~ /\((.*)\)/ ) { 
        $f003 = $1; 
        $f773w =~ s/\D//g;
    }
    my $cn = $f773w;
    my $cni = $r->field('003')->data();

    return undef unless $cn && $cni;

    my $query = "Control-number,ext:\"$cn\" AND cni,ext:\"$cni\"";

    my $searcher = Koha::SearchEngine::Search->new({index => $Koha::SearchEngine::BIBLIOS_INDEX});

    my ( $error, $results, $total_hits ) = $searcher->simple_search_compat( $query, 0, 10 );
    if ($error) {
        die "getHostRecord():> Searching ($query):> Returned an error:\n$error";
    }

    my $marcflavour = C4::Context->preference('marcflavour');

    if ($total_hits == 1) {
        my $record = $results->[0];
        return ref($record) ne 'MARC::Record' ? MARC::Record::new_from_xml($record, 'UTF-8', $marcflavour) : $record;
    }
    elsif ($total_hits > 1) {
        die "getHostRecord():> Searching ($query):> Returned more than one record?";
    }
    return undef;
}

sub findByIdentifier {
    my ($self, $identifier, $identifier_field) = @_;

    my $queryparser = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::QueryParser->new({
        interface => 'Koha',
        interfaceType => 'ElasticSearch',
        identifier => $identifier,
        identifierField => $identifier_field
    });
    my $query = $queryparser->query;

    my $searcher = Koha::SearchEngine::Search->new({index => $Koha::SearchEngine::BIBLIOS_INDEX});

    my ( $error, $results, $total_hits ) = $searcher->simple_search_compat( $query, 0, 10 );
    if ($error) {
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 500, {message => "Search: $query, returned an error"});
    }

    my $marcflavour = C4::Context->preference('marcflavour');

    if ($total_hits == 1) {
        my $record = $results->[0];
        return ref($record) ne 'MARC::Record' ? MARC::Record::new_from_xml($record, 'UTF-8', $marcflavour) : $record;
    }
    elsif ($total_hits > 1) {
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 409, {message => "Search: $query, returned more than one record"});
    }

    return undef;
}

sub searchFromInterface {
    my ($self, $interface_name, $identifiers, $biblio_id, $user_id) = @_;

    my $config = $self->getConfig->getInterfaceConfig($interface_name);
    if ($config->{sruUrl} && $config->{sruUrl} ne "") {
        push @$identifiers, {identifier => $biblio_id, identifier_field => "biblio_id"} if $biblio_id;
        foreach my $identifier (@$identifiers) {
            my $queryparser = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::QueryParser->new({
                interface => $interface_name,
                interfaceType => "SRU",
                identifier => $identifier->{identifier},
                identifierField => $identifier->{identifier_field}
            });
            my $query = $queryparser->query;
            if ($query) {
                my $params = {
                    url => $config->{sruUrl},
                    query => $query
                };
                if ($interface_name =~ /Melinda|Vaari/i) {
                    $params->{version} = "2.0";
                }
                my $sru = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::SRU->new($params);
                my $records = $sru->search();

                if (ref($records) eq "HASH") {
                    die {status => $records->{status}, message => "SRU search failed: ".$records->{message}};
                }

                my $componentparts = [];
                if ($records) {
                    my $record = $records->[0];
                    if ($interface_name =~ /Melinda|Vaari/i && $record->{fields}) {
                        $componentparts = $self->searchSRUComponentParts($config->{sruUrl}, $record);
                    }
                    
                    return {marcjson => $record, componentparts => $componentparts};
                }
            }
        }
    } else {
        my $users = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Users->new({config => $config, endpoint => $config->{restSearch}});
        my ($path, $headers) = $users->getAuthentication($user_id);
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 401, {message => "Authentication failed"}) unless $path && $headers;
        $headers->{"Accept"} = "application/marc-in-json";
        my $ua = $self->ua;
        my $method = $config->{restSearchMethod};
        my $response = $ua->$method($path => $headers => json => {identifiers => $identifiers, biblio_id => $biblio_id})->result;
        if ($response->is_success) {
            return $response->json;
        } else {
            my $message = $response->json->{error} ? $response->json->{error} : $response->message;
            Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', $response->code, {message => $message});
        }

    }
    
    return undef;

}

sub searchSRUComponentParts {
    my ($self, $url, $record) = @_;

    my $startRecord = 1;
    my $maximumRecords = 25;
    my @results = ();
    my $f001;
    foreach my $field (@{$record->{fields}}) {
        if ($field->{tag} eq "001") {
            $f001 = $field->{value};
            last;
        }
    }
    while ($startRecord > 0) {
        my $sru = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::SRU->new({
            startRecord => $startRecord,
            maximumRecords => $maximumRecords,
            url => $url,
            query => "melinda.partsofhost=".$f001
        });
        my $records = $sru->search();

        if ($records) {
            foreach my $record (@$records) {
                my $biblio_id;
                foreach my $field (@{$record->{fields}}) {
                    if ($field->{tag} eq "001") {
                        $biblio_id = $field->{value};
                        last;
                    }
                }
                push @results, {marcjson => $record, biblionumber => $biblio_id};
            }
        }

        if (scalar(@$records) < $maximumRecords) {
            $startRecord = 0;
            last;
        } else {
            $startRecord += $maximumRecords;
        }
    }

    return \@results;
}

1;