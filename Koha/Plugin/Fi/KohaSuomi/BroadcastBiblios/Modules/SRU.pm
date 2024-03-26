package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::SRU;

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
use C4::Context;
use MARC::Record;
use DateTime;
use Mojo::UserAgent;
use Koha::Logger;
use XML::LibXML;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MarcXMLToJSON;

=head new

    my $sru = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::SRU->new($params);

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
    unless ($params->{url}) {
        die "Missing url parameter";
    }

    unless ($params->{query}) {
        die "Missing query parameter";
    }
    return @_;
}

sub getUrl {
    my ($self) = @_;
    return $self->{_params}->{url};
}

sub getOperation {
    my ($self) = @_;
    return $self->{_params}->{operation} || "searchRetrieve";
}

sub getStartRecord {
    my ($self) = @_;
    return $self->{_params}->{startRecord};
}

sub getVersion {
    my ($self) = @_;
    return $self->{_params}->{version} || "1.1";
}

sub getMaximumRecords {
    my ($self) = @_;
    return $self->{_params}->{maximumRecords} || 1;
}

sub getRecordSchema {
    my ($self) = @_;
    return $self->{_params}->{recordSchema} || "marcxml";
}

sub getQuery {
    my ($self) = @_;
    return $self->{_params}->{query};
}

sub xmlPath {
    my ($self) = @_;
    return $self->{_params}->{xmlPath} || "/zs:searchRetrieveResponse/zs:records/zs:record/zs:recordData/*";
}

sub ua {
    my ($self) = @_;
    my $ua = Mojo::UserAgent->new;
    if ($ENV{MOJO_PROXY}) {
        $ua->proxy->http($ENV{MOJO_PROXY})->https($ENV{MOJO_PROXY});
    }
    return $ua;
}

sub MarcXMLToJSON {
    my ($self, $marcxml) = @_;
    my $marcjson = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MarcXMLToJSON->new();
    return $marcjson->toJSON($marcxml);
}

sub buildTX {
    my ($self, $method, $path) = @_;
    my $tx = $self->ua->build_tx($method => $path);
    $tx = $self->ua->start($tx);
    return $tx;
}

sub buildPath {
    my ($self) = @_;
    my $path = $self->getUrl();
    $path .= "?operation=".$self->getOperation();
    $path .= "&query=".$self->getQuery();
    $path .= "&version=".$self->getVersion();
    $path .= "&maximumRecords=".$self->getMaximumRecords();
    $path .= "&recordSchema=".$self->getRecordSchema();
    $path .= "&startRecord=".$self->getStartRecord() if $self->getStartRecord();
    return $path;
}

sub search {
    my ($self) = @_;

    my $path = $self->buildPath();
    my $res = $self->buildTX('GET', $path);
    my $records = $self->getRecords($res->res->body);
    return $records;
}

sub getRecords {
    my ($self, $res) = @_;

    my $xml = eval { XML::LibXML->load_xml(string => $res) };

    if ($@) {
        return { status => 400, message => $@ };
    }

    my @sruRecords = $xml->findnodes($self->xmlPath());
    my @records;

    for my $record (@sruRecords) {
        push @records, $self->MarcXMLToJSON($record->toString());
    }

    return \@records;
}

1;