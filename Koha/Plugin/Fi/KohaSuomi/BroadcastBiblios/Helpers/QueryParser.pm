package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::QueryParser;

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
use C4::Context;

=head new

    my $queryparser = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::QueryParser->new($params);

=cut

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;

}

sub getInterface {
    my ($self) = @_;
    return $self->{_params}->{interface};
}

sub getInterfaceType {
    my ($self) = @_;
    return $self->{_params}->{interfaceType};
}

sub getIdentifier {
    my ($self) = @_;
    return $self->{_params}->{identifier};
}

sub getIdentifierField {
    my ($self) = @_;
    return $self->{_params}->{identifierField};
}

sub query {
    my ($self) = @_;

    my $query;

    if ($self->getInterfaceType eq "SRU") {
        if ($self->getInterface =~ /Melinda/i) {
            $query = $self->melindaSRUSearch();
        } else {
            $query = $self->kohaSRUSearch();
        }
    } else {
        $query = $self->kohaElasticSearch();
    }

    return $query;
}

sub kohaElasticSearch {
    my ($self) = @_;

    my $identifier = $self->getIdentifier();
    my $identifierField = $self->getIdentifierField();
    my $identifier_field;
    my $query;
    $identifier_field = "system-control-field" if $identifierField eq "035a";
    $identifier_field = "isbn" if $identifierField eq "020a";
    $identifier_field = "identifier-other" if $identifierField eq "024a";
    if ($identifierField eq "003|001") {
        my @identifiers = split(/\|/, $identifier);
        my $cn = $identifiers[1];
        my $cni = $identifiers[0];
        return "Control-number,ext:\"$cn\" AND cni,ext:\"$cni\"";
    } else {
        return "$identifier_field,ext:\"$identifier\"";
    }

}

sub kohaSRUSearch {
    my ($self) = @_;
    return 'koha.systemcontrolnumber="'.$self->getIdentifier().'"' if $self->getIdentifierField eq "035a";
    return "dc.isbn=".$self->getIdentifier() if $self->getIdentifierField eq "020a";
    return "dc.identifier=".$self->getIdentifier() if $self->getIdentifierField eq "024a";
    if ($self->getIdentifierField eq "003|001") {
        my @identifiers = split(/\|/, $self->getIdentifier());
        my $cn = $identifiers[1];
        my $cni = $identifiers[0];
        return "koha.controlnumber=".$cn." AND "."koha.controlnumberidentifier=".$cni;
    }
}

sub melindaSRUSearch {
    my ($self) = @_;
    if ($self->getIdentifierField eq "035a" && $self->getIdentifier() =~ /FI-MELINDA/i) {
        my $identifier = $self->getIdentifier();
        $identifier =~ s/\D//g;
        return 'rec.id='.$identifier;
    }
    return "bath.isbn=".$self->getIdentifier() if $self->getIdentifierField eq "020a";
    return "dc.identifier=".$self->getIdentifier() if $self->getIdentifierField eq "024a";
}

1;