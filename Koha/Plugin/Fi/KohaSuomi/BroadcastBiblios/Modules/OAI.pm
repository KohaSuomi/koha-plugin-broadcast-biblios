package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::OAI;

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
use Koha::Biblios;
use C4::Context;
use MARC::Record;
use DateTime;
use C4::OAI::Sets;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios;

=head new

    my $oai = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::OAI->new($params);

=cut

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;

}

sub getDate {
    my ($self) = @_;
    my $date;

    if ($self->{_params}->{date}) {
        $date = $self->{_params}->{date};
    } else {
        $date = DateTime->now->ymd;
    }

    return $date;
}

sub getBibliosClass {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new($self->{_params});
}

sub buildOAI {
    my ($self) = @_;
    my @biblios = $self->getBibliosClass()->importedRecords($self->getDate());
    my $set_id = $self->createOAISet();
    AddOAISetsBiblios({$set_id => \@biblios});
}

sub createOAISet {
    my ($self) = @_;

    my $spec = 'dailyset-'. $self->getDate();
    my $name = 'Daily set '. $self->getDate();

    return $self->getOAISet()->{id} || AddOAISet({
        spec => $spec,
        name => $name,
    });
}

sub getOAISet {
    my ($self) = @_;
    my $set = GetOAISetBySpec('dailyset-'. $self->getDate());
    return $set if $set;
}

1;