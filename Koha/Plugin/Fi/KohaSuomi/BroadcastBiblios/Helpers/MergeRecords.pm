package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MergeRecords;

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
use Scalar::Util qw( blessed looks_like_number );
use Try::Tiny;
use JSON;
use List::MoreUtils qw(uniq);
use MARC::Record;
use MARC::Field;
=head new

    my $compare = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MergeRecords->new($params);

=cut

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;
}

sub interface {
    my ($self) = @_;
    return $self->{_params}->{interface};
}

sub verbose {
    my ($self) = @_;
    return $self->{_params}->{verbose};
}

sub merge {
    my ($self, $queueRecord, $record) = @_;

    my $interface = $self->interface();
    my $merged = $queueRecord;
    $merged = $self->appendSystemControlNumber($merged);

    my $filters = {};

    if ($interface =~ /Melinda/i) {
        $filters = $self->MelindaMerge();
    } elsif ($interface =~ /Tati/i) {
        $filters = $self->TatiMerge();
    }

    foreach my $recordField ($record->fields) {
        foreach my $keep (@{$filters->{keep}}) {
            if (defined($keep->{tag}) && $keep->{tag} eq $recordField->tag) {
                $merged->append_fields($recordField->tag);
            }
            foreach my $recordSubfields ($recordField->subfields) {
                if (defined($keep->{code}) && $keep->{code} eq $recordSubfields->[0]) {
                    $merged->insert_fields_ordered($recordField);
                }
            }
        }
    }

    foreach my $add (@{$filters->{add}}) {
        my $field = MARC::Field->new($add->{tag}, $add->{ind1}, $add->{ind2}, %{$add->{subfields}});
        unless ($merged->subfield($add->{tag}, %{$add->{subfields}})) {
            $merged->append_fields($field);
        }
    }

    foreach my $remove (@{$filters->{remove}}) {
        my $field = $merged->field($remove->{tag});
        $merged->delete_fields($field) if $field;
    }
    print $merged->as_formatted() if $self->verbose();
    return $merged;
}

sub MelindaMerge {
    my ($self) = @_;

    my @keep = (
        {tag => 'CAT'},
        {tag => 'LOW'},
        {tag => 'SID'},
        {tag => 'HLI'},
        {tag => 'DEL'},
        {tag => 'LDR'},
        {tag => 'STA'},
        {tag => 'COR'},
        {code => '5'},
        {code => '9'}
    );

    my @remove = (
        {tag => '001'},
        {tag => '003'},
        {tag => '942'},
        {tag => '999'}
    );

    my @add = (
        {
            tag => 'LOW',
            ind1 => ' ',
            ind2 => ' ',
            subfields => {
                'a' => 'FI-Tati'
            }
        }
    );
    
    return {keep => \@keep, add => \@add, remove => \@remove};
}

sub TatiMerge {
    my ($self) = @_;
    my @keep = ();
    my @remove = (
        {tag => '942'},
        {tag => '999'},
    );
    my @add = ();
    
    return {keep => \@keep, add => \@add, remove => \@remove};
}

sub appendSystemControlNumber {
    my ($self, $record) = @_;

    my $f001 = $record->field('001')->data;
    my $f003 = $record->field('003')->data;
    my $newf035 = '('.$f003.')'. $f001;
    my @f035 = $record->field('035');
    foreach my $field (@f035) {
        if ($field->subfield('a') ne $newf035) {
            $record->field('035')->add_subfields('a' => $newf035);
        }
    }
    return $record;
}

1;