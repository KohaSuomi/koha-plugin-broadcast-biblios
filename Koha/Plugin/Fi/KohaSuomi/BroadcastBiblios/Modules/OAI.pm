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

sub verbose {
    my ($self) = @_;
    return shift->{_params}->{verbose};
}

sub getSetSpec {
    my ($self) = @_;
    return shift->{_params}->{set_spec};
} 

sub getSetName {
    my ($self) = @_;
    return shift->{_params}->{set_name};
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

sub getNoComponents {
    my ($self) = @_;
    return shift->{_params}->{no_components};
}

sub getHostsWithComponents {
    my ($self) = @_;
    return shift->{_params}->{hosts_with_components};
}

sub getBibliosClass {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new($self->{_params});
}

sub buildOAI {
    my ($self) = @_;
    my @biblios = $self->processDuplicateFromBibliosArray();
    return unless @biblios;
    my $set_id = $self->findOAISet();
    print "Adding biblios to OAI set ".$self->getSetSpec."\n" if $self->verbose();
    AddOAISetsBiblios({$set_id => \@biblios});
}

sub processDuplicateFromBibliosArray {
    my ($self) = @_;
    my @biblios = $self->getBibliosClass()->importedRecords($self->getDate(), $self->getNoComponents(), $self->getHostsWithComponents);

    my @results;
    foreach my $biblionumber (@biblios) {
        my $result = getOAISetsBiblio($biblionumber, $self->getSetSpec, $self->getSetName);
        if (scalar(@$result) == 0) {
            print "Adding biblio ".$biblionumber." to OAI set ".$self->getSetSpec."\n" if $self->verbose();
            push @results, $biblionumber;
        }
    }
    return @results;
}

sub findOAISet {
    my ($self) = @_;

    my $spec = $self->getSetSpec();
    my $name = $self->getSetName();

    return $self->getOAISet()->{id} || AddOAISet({
        spec => $spec,
        name => $name,
    });
}

sub getOAISet {
    my ($self) = @_;
    my $set = GetOAISetBySpec($self->getSetSpec()) || {};
    return $set;
}

sub getOAISetsBiblio {
    my ($biblionumber, $spec, $name) = @_;

    my $dbh = C4::Context->dbh;
    my $query = qq{
        SELECT oai_sets.*
        FROM oai_sets
          LEFT JOIN oai_sets_biblios ON oai_sets_biblios.set_id = oai_sets.id
        WHERE biblionumber = ?
        AND spec = ?
        AND name = ?
    };
    my $sth = $dbh->prepare($query);

    $sth->execute($biblionumber, $spec, $name);
    return $sth->fetchall_arrayref({});
}

1;