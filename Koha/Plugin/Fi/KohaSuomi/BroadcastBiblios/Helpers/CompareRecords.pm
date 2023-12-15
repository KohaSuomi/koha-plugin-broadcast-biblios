package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::CompareRecords;

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

=head new

    my $compare = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::Compare->new($params);

=cut

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;
}

sub compareEncodingLevels {
    my ($self, $local, $broadcast) = @_;

    my $local_level = $local->{encodingLevel};
    my $broadcast_level = $broadcast->{encodingLevel};
    my $local_status = $local->{encodingStatus};
    my $broadcast_status = $broadcast->{encodingStatus};
    my $encoding_level;

    if ((int($local_level) > int($broadcast_level)) || $local_level eq 'u' || $local_level eq 'z') {
        # If the local record's number is greater than broadcast record's or local record's status is u or z, the encoding level is lower
        $encoding_level = 'lower';   
    } elsif (int($local_level) == int($broadcast_level)) {
        if ($local_status eq 'c' && $broadcast_status eq 'n') {
            # If the local record's number is equal to broadcast record's and the local record's status is c and the broadcast record's status is n, the encoding level is greater
            $encoding_level = 'greater';
        } elsif ($local_status eq 'n' && $broadcast_status eq 'c') {
            # If the local record's number is equal to broadcast record's and the local record's status is n and the broadcast record's status is c, the encoding level is lower
            $encoding_level = 'lower';
        } else {
            # If the local record's number is equal to broadcast record's, the encoding level is equal
            $encoding_level = 'equal';
        }

    } else {
        # If the local record's number is lower than broadcast record's, the encoding level is greater
        $encoding_level = 'greater'; 
    }

    return $encoding_level;

}

sub getDiff {
    my ($self, $old, $new) = @_;

    return unless $old && $new;

    my %diff;

    my $records;
    push @{$records}, $old;
    push @{$records}, $new;

    my ($oldfields, $oldtags) = $self->comparePrepare($old);
    my ($newfields, $newtags) = $self->comparePrepare($new);

    my @uniqtags = (@{$oldtags}, @{$newtags}); 

    @uniqtags = uniq @uniqtags;
    @uniqtags = sort @uniqtags;

    my @candidates;
    for(my $ri=0 ; $ri<scalar(@$records) ; $ri++) {
        my $r = $records->[$ri];
        foreach my $tag (@uniqtags) {
            $candidates[$ri]->{$tag} = [];
            foreach my $field (@{$r->{fields}}) {
                if ($field->{tag} eq $tag) {
                    push @{$candidates[$ri]->{$tag}}, $field;
                }
            }
        }
    }
    my $index = 0;
    foreach my $candidate (@candidates) {
        foreach my $key (sort(keys(%$candidate))) {
            $diff{$key}->{$index} = $candidate->{$key};
        }
        $index++;
    }
    my %output;
    foreach my $key (sort(keys(%diff))) {
        my @oldfield = @{$diff{$key}->{0}};
        my @newfield = @{$diff{$key}->{1}};
        my $oldfieldcount = scalar(@oldfield);
        my $newfieldcount = scalar(@newfield);
        if ($oldfieldcount == $newfieldcount) {
            for(my $oi=0 ; $oi<scalar(@oldfield) ; $oi++) {
                my $diff = $self->valuesDiff($oldfield[$oi], $newfield[$oi]);
                if ($diff) {
                    push @{$output{$key}->{old}},  $oldfield[$oi];
                    push @{$output{$key}->{new}},  $newfield[$oi];
                }
            }
        } elsif ($oldfieldcount > $newfieldcount && $newfieldcount != 0) {
            for(my $oi=0 ; $oi<scalar(@oldfield) ; $oi++) {
                if ($oldfield[$oi] && !$newfield[$oi]) {
                    push @{$output{$key}->{remove}},  $oldfield[$oi];
                } else {
                    my $diff = $self->valuesDiff($oldfield[$oi], $newfield[$oi]);
                    if ($diff) {
                        push @{$output{$key}->{remove}},  $oldfield[$oi];
                        push @{$output{$key}->{add}},  $newfield[$oi];
                    }
                }
            }
        } elsif ($oldfieldcount < $newfieldcount && $oldfieldcount != 0) {
            for(my $oi=0 ; $oi<scalar(@newfield) ; $oi++) {
                if (!$oldfield[$oi] && $newfield[$oi]) {
                    push @{$output{$key}->{add}},  $newfield[$oi];
                } else {
                    my $diff = $self->valuesDiff($oldfield[$oi], $newfield[$oi]);
                    if ($diff) {
                        push @{$output{$key}->{remove}},  $oldfield[$oi];
                        push @{$output{$key}->{add}},  $newfield[$oi];
                    }
                }
            }
        } elsif ($oldfieldcount > $newfieldcount && $newfieldcount == 0) {
            @{$output{$key}->{remove}} = @oldfield;
        } elsif ($oldfieldcount < $newfieldcount && $oldfieldcount == 0) {
            @{$output{$key}->{add}} = @newfield;
        }
    }

    return to_json(\%output);
}

sub valuesDiff {
    my ($self, $firstvalue, $secondvalue) = @_;

    my $bol = 0;
    if ($firstvalue->{ind1} && $secondvalue->{ind1} && $firstvalue->{ind1} ne $secondvalue->{ind1}) {
        $bol = 1;
    } elsif ($firstvalue->{ind2} && $secondvalue->{ind2} && $firstvalue->{ind2} ne $secondvalue->{ind2}) {
        $bol = 1;
    } else {
        if ($firstvalue->{subfields} && $secondvalue->{subfields}) {
            my $ne = $self->compareArrays($firstvalue->{subfields}, $secondvalue->{subfields});
            $bol = $ne; 
        } else {
            if ($firstvalue->{value} ne $secondvalue->{value}) {
                $bol = 1;
            }
        }
    }

    return $bol;
}

sub comparePrepare {
    my ($self, $record) = @_;
    my $fields;
    my $tags;

    foreach my $field (@{$record->{fields}}) {
        if (looks_like_number($field->{tag})) {
            push @{$tags}, $field->{tag};
            my $fieldvalues = $field->{tag}.'|';
            $fieldvalues .= '_ind1'.$field->{ind1}.'|' if defined $field->{ind1} && $field->{ind1} ne ' ';
            $fieldvalues .= '_ind2'.$field->{ind2}.'|' if defined $field->{ind2} && $field->{ind2} ne ' ';
            if ($field->{value}) {
                $fieldvalues .= $field->{value}
            } else {
                my @sorted =  sort { $a->{code} cmp $b->{code} } @{$field->{subfields}};
                foreach my $subfield (@sorted) {
                    $fieldvalues .= $subfield->{code}.$subfield->{value}.'|';
                }
            }
            push @{$fields}, $fieldvalues;
        }
    }
    
    return ($fields, $tags);
}

sub compareArrays {
    my ($self, $array1, $array2) = @_;

    my $notequal = 1;
    my $arr1string = '';
    my $arr2string = '';

    foreach my $arr1 (@{$array1}) {
        $arr1string .= $arr1->{code};
        $arr1string .= $arr1->{value};
    }

    foreach my $arr2 (@{$array2}) {
        $arr2string .= $arr2->{code};
        $arr2string .= $arr2->{value};
    }

    if ($arr1string eq $arr2string) {
        $notequal = 0;
    }

    return $notequal;
}

sub matchComponentPartToHost {
    my ($self, $component, $host) = @_;

    my $match = 0;
    my $host001 = $host->field('001')->data();
    my $host003 = $host->field('003')->data();
    my $hostcontrolfields = '('.$host003.')'.$host001;
    my $component773w = $component->subfield('773', 'w');
    my $component001 = $component->field('001')->data();
    my $component003 = $component->field('003')->data();

    if ($hostcontrolfields eq $component773w) {
        $match = 1;
    } elsif ($host003 eq $component003 && $host001 eq $component773w) {
        $match = 1;
    }

    return $match;
}


1;
