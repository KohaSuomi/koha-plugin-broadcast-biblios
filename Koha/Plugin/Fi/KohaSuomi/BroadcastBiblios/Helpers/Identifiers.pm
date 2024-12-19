package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::Identifiers;

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
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios;
use C4::Context;

=head new

    my $identifiers = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::Identifiers->new($params);

=cut

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;
}

sub getRecord {
    my ($self, $marcxml) = @_;

    my $biblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new();
    return $biblios->getRecord($marcxml);
}

sub getIdentifierField {
    my ($self, $marc) = @_;
    my $record = $self->getRecord($marc);
    return unless $record;
    my $activefield;
    my $fieldname;

    if ($record->field('035')) {
        my @f035 = $record->field( '035' );
        foreach my $f035 (@f035) {
            if($f035->subfield('a') =~ /FI-MELINDA/) {
                $activefield = $f035->subfield('a');
                $fieldname = '035a';
                last;
            }
        }
    }

    if ($record->field('020') && !$activefield) {
        my @f020 = $record->field( '020' );
        foreach my $f020 (@f020) {
            if ($f020->subfield('a')) {
                $activefield = $f020->subfield('a');
                $activefield =~ s/-//gi;
                $fieldname = '020a';
                last;
            }
        }

    }

    if ($record->field( '024') && !$activefield) {
        my @f024 = $record->field( '024' );
        foreach my $f024 (@f024) {
            if ($f024->subfield('a') && $f024->indicator('1') eq '3') {
                $activefield = $f024->subfield('a');
                $activefield =~ s/-//gi;
                $fieldname = '024a';
                last;
            } elsif ($f024->subfield('a')) {
                $activefield = $f024->subfield('a');
                $activefield =~ s/-//gi;
                $fieldname = '024a';
                last;
            }
        }
    }
    if ($record->field('003') && $record->field('003')->data =~ /FI-BTJ/ && !$activefield) {
        $activefield = $record->field( '003')->data.'|'.$record->field( '001')->data;
        $fieldname = '003|001';
    }

    return ($activefield, $fieldname);
}

sub fetchIdentifiers {
    my ($self, $marc) = @_;
    my $record = $self->getRecord($marc);
    return unless $record;
    my @identifiers;

    if ($record->field('035')) {
        my @f035 = $record->field( '035' );
        foreach my $f035 (@f035) {
            if($f035->subfield('a') =~ /FI-MELINDA/) {
                push @identifiers, {identifier_field => '035a', identifier => $f035->subfield('a')};
            }
            if ($f035->subfield('z') && $f035->subfield('z') =~ /FI-MELINDA/) {
                push @identifiers, {identifier_field => '035z', identifier => $f035->subfield('z')};
            }
        }
    }

    if ($record->field('020')) {
        my @f020 = $record->field( '020' );
        foreach my $f020 (@f020) {
            if ($f020->subfield('a')) {
                my $activefield = $f020->subfield('a');
                $activefield =~ s/-//gi;
                push @identifiers, {identifier_field => '020a', identifier => $activefield};
            }
        }

    }

    if ($record->field( '024')) {
        my @f024 = $record->field( '024' );
        foreach my $f024 (@f024) {
            if ($f024->subfield('a') && $f024->indicator('1') eq '3') {
                push @identifiers, {identifier_field => '024a', identifier => $f024->subfield('a')};
                last;
            } elsif ($f024->subfield('a')) {
                push @identifiers, {identifier_field => '024a', identifier => $f024->subfield('a')};
                last;
            }
        }
    }
    
    if ($record->field('003') && $record->field('003')->data =~ /FI-BTJ/) {
        my $allfons = $record->field( '003')->data.'|'.$record->field( '001')->data;
        push @identifiers, {identifier_field => '003|001', identifier => $allfons};
    }

    return \@identifiers;
}

sub get001Identifier {
    my ($self, $marc) = @_;
    my $record = $self->getRecord($marc);
    return unless $record;
    my $f001;
    if ($record->field('001')) {
        $f001 = $record->field('001')->data;
    }
    return $f001;
}

1;