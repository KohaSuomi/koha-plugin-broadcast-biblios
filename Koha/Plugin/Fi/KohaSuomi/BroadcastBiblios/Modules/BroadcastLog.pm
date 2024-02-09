package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastLog;

# Copyright 2021 Koha-Suomi Oy
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

=head new

    my $broadcastLog = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastLog->new($params);

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

sub setBroadcastLog {
    my ($self, $biblionumber, $timestamp, $type) = @_;

    $self->db->setBroadcastLog($biblionumber, $timestamp, $type);
    
}

sub getBroadcastLogByBiblionumber {
    my ($self, $biblionumber) = @_;
    return $self->db->getBroadcastLogByBiblionumber($biblionumber);
}

sub getBroadcastLogByTimestamp {
    my ($self, $timestamp) = @_;
    return $self->db->getBroadcastLogByTimestamp($timestamp);
}

sub getBroadcastLogLatestExport {
    my ($self) = @_;
    return $self->db->getBroadcastLogLatest('export');  
}

sub getBroadcastLogLatestImport {
    my ($self) = @_;
    return $self->db->getBroadcastLogLatest('import');  
}

sub getBroadcastLogLatestOld {
    my ($self) = @_;
    return $self->db->getBroadcastLogLatest('old');  
}

1;