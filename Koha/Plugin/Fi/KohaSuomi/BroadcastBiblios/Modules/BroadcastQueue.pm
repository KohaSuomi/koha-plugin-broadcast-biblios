package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastQueue;

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
use Koha::DateUtils qw( dt_from_string );
use C4::Context;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Database;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Search;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords;

=head new

    my $broadcastLog = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastQueue->new($params);

=cut

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;

}

sub getBroadcastInterface {
    shift->{_params}->{broadcast_interface};
}

sub getBroadcastBiblioId {
    shift->{_params}->{broadcast_biblio_id};
}

sub getBiblioId {
    shift->{_params}->{biblio_id};
}

sub getMarcRecord {
    shift->{_params}->{marc};
}

sub getLinkedBorrowernumber {
    shift->{_params}->{linked_borrowernumber};
}

sub db {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Database->new;
}

sub search {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Search->new;
}

sub user {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::User->new;
}

sub identifiers {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::Identifiers->new;
}

sub setToQueue {
    my ($self) = @_;

    my @identifiers = $self->identifiers->fetchIdentifiers($self->getMarcRecord);
    my $record = $self->findRecord($self->getIdentifiers);
    my $user = $self->user->getBroadcastInterfaceUser($self->getBroadcastInterface, undef);


}

sub findRecord {
    my ($self, @identifiers) = @_;

    foreach my $identifier (@identifiers) {
        my $record = $self->search->getRecordByIdentifier($identifier->{identifier}, $identifier->{identifier_field});
        return $record if $record;
    }

    return undef;
}

1;