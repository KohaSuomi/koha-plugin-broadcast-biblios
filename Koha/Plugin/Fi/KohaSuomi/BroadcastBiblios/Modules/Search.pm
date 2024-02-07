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
        die "findByIdentifier():> Searching ($query):> Returned an error:\n$error";
    }

    my $marcflavour = C4::Context->preference('marcflavour');

    if ($total_hits == 1) {
        my $record = $results->[0];
        return ref($record) ne 'MARC::Record' ? MARC::Record::new_from_xml($record, 'UTF-8', $marcflavour) : $record;
    }
    elsif ($total_hits > 1) {
        die "findByIdentifier():> Searching ($query):> Returned more than one record?";
    }
    return undef;
}

sub searchFromInterface {
    my ($self, $interface_name, $identifiers) = @_;

    my $config = $self->getConfig->getInterfaceConfig($interface_name);
    if ($config->{sruUrl} && $config->{sruUrl} ne "") {
        foreach my $identifier (@$identifiers) {
            my $queryparser = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::QueryParser->new({
                interface => $interface_name,
                interfaceType => "SRU",
                identifier => $identifier->{identifier},
                identifierField => $identifier->{identifier_field}
            });
            my $query = $queryparser->query;
            my $sru = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::SRU->new({
                url => $config->{sruUrl},
                query => $query
            });
            my $records = $sru->search();
            if ($records) {
                return {marcjson => $records->[0]};
            }
        }
    }
    
    return undef;

}

1;