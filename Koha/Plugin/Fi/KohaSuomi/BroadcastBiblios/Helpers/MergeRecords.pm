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
use utf8;
use Carp;
use Scalar::Util qw( blessed looks_like_number );
use Try::Tiny;
use JSON;
use List::MoreUtils qw(uniq);
use Text::Unidecode qw( unidecode );
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
    my $merged = $queueRecord->clone();
    $merged = $self->appendSystemControlNumber($merged);

    my $filters = $self->KohaFilters();

    if (defined($interface) && $interface =~ /Melinda/i) {
        $filters = $self->MelindaMerge();
    } elsif (defined($interface) && $interface =~ /Vaari/i) {
        $filters = $self->VaariMerge();
    } elsif (defined($interface) && $interface =~ /Tati/i) {
        $filters = $self->TatiMerge();
    }

    if ($record) {
        my $keepFields = {};
        my $beforeField;
        foreach my $recordField ($record->fields) {
            my $tag_in_keep = grep { defined($_->{tag}) && $_->{tag} eq $recordField->tag } @{$filters->{keep}};
            if ($tag_in_keep) {
                if (looks_like_number($recordField->tag)) {
                    push @{$keepFields->{$recordField->tag}}, {before_field => $beforeField, field => $recordField};
                } else {
                    $merged->append_fields($recordField);
                }
            } else {
                foreach my $keep (@{$filters->{keep}}) {
                    foreach my $recordSubfields ($recordField->subfields) {
                        if (defined($keep->{code}) && $keep->{code} eq $recordSubfields->[0]) {
                            push @{$keepFields->{$recordField->tag}}, {before_field => $beforeField, field => $recordField};
                        }
                    }
                    
                }
            }
            $beforeField = $recordField;
        }
        foreach my $tag (sort keys %{$keepFields}) {
            my $fields = $keepFields->{$tag};
            foreach my $field (@{$fields}) {
                my @fields = $merged->field($field->{before_field}->tag);
                my $after_field;
                for (my $i = 0; $i < scalar @fields; $i++) {
                    if (unidecode($fields[$i]->as_string()) eq unidecode($field->{before_field}->as_string())) {
                        $after_field = $fields[$i];
                        last;
                    }
                }
                my @old_fields = $merged->field($field->{field}->tag);
                my $exists = 0;
                foreach my $old_field (@old_fields) {
                    if (unidecode($old_field->as_string()) eq unidecode($field->{field}->as_string())) {
                        $exists = 1;
                        last;
                    }
                }
                unless ($exists) {
                    if ($after_field) {
                        $merged->insert_fields_after($after_field, $field->{field});
                    } else {
                        $merged->insert_fields_ordered($field->{field});
                    }
                }
            }
        }
    }

    foreach my $add (@{$filters->{add}}) {
        my $field = MARC::Field->new($add->{tag}, $add->{ind1}, $add->{ind2}, %{$add->{subfields}});
        my @added = $merged->field($add->{tag});
        unless (grep { $_->subfield('a') eq $add->{subfields}->{a} } @added) {
            $merged->append_fields($field);
        }
    }

    foreach my $remove (@{$filters->{remove}}) {
        foreach my $field ($merged->fields) {
            if ($field->tag eq $remove->{tag}) {
                $merged->delete_field($field);
            }
        }
    }

    print $merged->as_formatted()."\n" if $self->verbose();
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
        {tag => '015'},
        {tag => '042'},
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
                'a' => 'TATI'
            }
        }
    );
    
    return {keep => \@keep, add => \@add, remove => \@remove};
}

sub VaariMerge {
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
        {tag => '015'},
        {tag => '042'},
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
                'a' => 'VAARI'
            }
        }
    );
    
    return {keep => \@keep, add => \@add, remove => \@remove};
}

sub TatiMerge {
    my ($self) = @_;
    my @keep = ();
    my @remove = (
        {tag => 'CAT'},
        {tag => 'LOW'},
        {tag => 'SID'},
        {tag => 'HLI'},
        {tag => 'DEL'},
        {tag => 'LDR'},
        {tag => 'STA'},
        {tag => 'COR'},
        {tag => '942'},
        {tag => '999'},
    );
    my @add = ();
    
    return {keep => \@keep, add => \@add, remove => \@remove};
}

sub KohaFilters {
    my ($self) = @_;
    my @keep = ();
    my @remove = (
        {tag => 'CAT'},
        {tag => 'LOW'},
        {tag => 'SID'},
        {tag => 'HLI'},
        {tag => 'DEL'},
        {tag => 'LDR'},
        {tag => 'STA'},
        {tag => 'COR'},
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
    my $found = 0;
    foreach my $field (@f035) {
        if ($field->subfield('a') eq $newf035) {
            $found = 1;
            last;
        }
    }

    if (!$found) {
        $record->insert_fields_ordered(MARC::Field->new('035', ' ', ' ', 'a' => $newf035));
    }

    return $record;
}

sub addSystemControlNumber {
    my ($self, $record, $target_id) = @_;

    my @f035 = $record->field('035');
    my $found = 0;

    if ($self->interface =~ /Melinda/i) {
        $target_id = '(FI-MELINDA)'.$target_id;
    } elsif ($self->interface =~ /Tati/i) {
        $target_id = '(FI-TATI)'.$target_id;
    }

    foreach my $field (@f035) {
        if ($field->subfield('a') eq $target_id) {
            $found = 1;
            last;
        }
    }

    if (!$found) {
        $record->insert_fields_ordered(MARC::Field->new('035', ' ', ' ', 'a' => $target_id));
    }

    return $record;
}

sub updateHostComponentPartLink {
    my ($self, $record, $host_id) = @_;

    my $f773 = $record->field('773');
    
    if ($self->interface =~ /Melinda/i) {
        $host_id = '(FI-MELINDA)'.$host_id;
        if ($record->subfield('773', 'w') ne $host_id) {
            $f773->update('w' => $host_id);
        }
    }

    return $record;
}

sub updateControlNumberAndIdentifier {
    my ($self, $record, $identifier) = @_;

    my $f001 = $record->field('001');
    my $f003 = $record->field('003');
    my $new003;

    if ($self->interface =~ /Melinda/i) {
        $new003 = 'FI-MELINDA';
    }

    if ($new003) {
        $f001->update($identifier);
        $f003->update($new003);   
    }

    return $record;
}

1;