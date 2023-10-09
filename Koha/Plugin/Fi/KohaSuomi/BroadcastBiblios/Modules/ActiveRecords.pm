package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords;

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
use POSIX 'strftime';
use Koha::DateUtils qw( dt_from_string );
use File::Basename;
use MARC::Record;
use MARC::File::XML;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Database;
use Mojo::UserAgent;
use JSON;

=head new

    my $activeRecords = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords->new($params);

=cut

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;

}

sub getTimestamp {
    return strftime "%Y-%m-%d %H:%M:%S", ( localtime(time - 5*60) );
}

sub getParams {
    my ($self) = @_;
    my $params = $self->{_params};
    unless ($params->{all}) {
        $params->{timestamp} = $self->getTimestamp();
    }
    return shift->{_params};
}

sub db {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Database->new;
}

sub getActiveRecordByIdentifier {
    my ($self, $identifier, $identifier_field) = @_;
    my $result = $self->db->getActiveRecordByIdentifier($identifier, $identifier_field);
    return $result;
}

sub setActiveRecords {
    my ($self) = @_;
    my $params = $self->getParams();
    my $pageCount = 1;
    while ($pageCount >= $params->{page}) {
        my $newbiblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new($params);
        my $biblios = $newbiblios->fetch();
        my $count = 0;
        foreach my $biblio (@{$biblios}) {
            $count++;
            next if $self->db->getActiveRecordByBiblionumber($biblio->{biblionumber});
            next if $self->checkComponentPart(MARC::Record::new_from_xml($biblio->{metadata}, 'UTF-8'));
            my ($identifier, $identifier_field) = $self->getActiveField($biblio);
            next unless $identifier && $identifier_field;
            my $update_on = $params->{all} ? $biblio->{timestamp} : undef;
            $self->db->insertActiveRecord($biblio->{biblionumber}, $identifier, $identifier_field, $update_on);
        }
        print "$count biblios processed!\n";
        if ($count eq $params->{chunks}) {
            $pageCount++;
            $params->{page} = $pageCount;
        } else {
            $pageCount = 0;
        }
    }

}

sub getActiveRecordsByBiblionumber {
    my ($self, $params) = @_;
    my $pageCount = 1;
    my $interface = $params->{interface};
    my $sqlFile = $params->{directory}."/activeRecordsPatch".$interface.".sql";
    open(my $efh, '>', $sqlFile);
    print $efh "";
    close $efh;
    while ($pageCount >= $params->{page}) {
        my $newbiblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new($params);
        my $biblios = $newbiblios->fetch();
        my $count = 0;
        foreach my $biblio (@{$biblios}) {
            $count++;
            next if $self->checkComponentPart(MARC::Record::new_from_xml($biblio->{metadata}, 'UTF-8'));
            my ($identifier, $identifier_field) = $self->getActiveField($biblio);
            my $target_id = $biblio->{biblionumber};
            my $updated = $biblio->{timestamp};
            if (!$self->activated($params->{endpoint}, $params->{headers}, $interface, $target_id) && $identifier && $identifier_field) {
                my $sqlstring = "INSERT INTO ".$params->{database}.".activerecords (interface_name, identifier_field, identifier, target_id, updated) VALUES ('$interface', '$identifier_field', '$identifier', '$target_id', '$updated');";   
                open(my$fh, '>>', $sqlFile);
                print $fh $sqlstring."\n";
                close $fh;
            }
        }
        print "$count biblios processed!\n";
        if ($count eq $params->{chunks}) {
            $pageCount++;
            $params->{page} = $pageCount;
        } else {
            $pageCount = 0;
        }
    }
}

sub getAllActiveRecords {
    my ($self, $params) = @_;
    my $pageCount = 1;
    my $interface = $params->{interface};
    my $sqlFile = $params->{directory}."/activeRecordsPatch".$interface.".sql";
    open(my $efh, '>', $sqlFile);
    print $efh "";
    close $efh;
    while ($pageCount >= $params->{page}) {
        my $newbiblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new($params);
        my $biblios = $newbiblios->fetch();
        my $count = 0;
        foreach my $biblio (@{$biblios}) {
            my ($identifier, $identifier_field) = $self->getActiveField($biblio);
            my $target_id = $biblio->{biblionumber};
            my $updated = $biblio->{timestamp};
            if ($identifier && $identifier_field) {
                my $sqlstring = "INSERT INTO ".$params->{database}.".activerecords (interface_name, identifier_field, identifier, target_id, updated) VALUES ('$interface', '$identifier_field', '$identifier', '$target_id', '$updated');";   
                open(my$fh, '>>', $sqlFile);
                print $fh $sqlstring."\n";
                close $fh;
            }
            
            $count++;
        }
        print "$count biblios processed!\n";
        if ($count eq $params->{chunks}) {
            $pageCount++;
            $params->{page} = $pageCount;
        } else {
            $pageCount = 0;
        }
    }
}

sub getActiveField {
    my ($self, $biblio) = @_;
    my $record = MARC::Record::new_from_xml($biblio->{metadata}, 'UTF-8');
    my $activefield;
    my $fieldname;

    if ($record->field('035')) {
        my @f035 = $record->field( '035' );
        foreach my $f035 (@f035) {
            if($f035->subfield('a') =~ /FI-MELINDA/) {
                $activefield = $f035->subfield('a');
                $fieldname = '035a';
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

sub fetchActiveFields {
    my ($self, $biblio) = @_;
    my $record = MARC::Record::new_from_xml($biblio->{metadata}, 'UTF-8');
    my @activefields;

    if ($record->field('035')) {
        my @f035 = $record->field( '035' );
        foreach my $f035 (@f035) {
            if($f035->subfield('a') =~ /FI-MELINDA/) {
                push @activefields, {identifier_field => '035a', identifier => $f035->subfield('a')};
            }
        }
    }

    if ($record->field('020')) {
        my @f020 = $record->field( '020' );
        foreach my $f020 (@f020) {
            if ($f020->subfield('a')) {
                my $activefield = $f020->subfield('a');
                $activefield =~ s/-//gi;
                push @activefields, {identifier_field => '020a', identifier => $activefield};
            }
        }

    }

    if ($record->field( '024')) {
        my @f024 = $record->field( '024' );
        foreach my $f024 (@f024) {
            if ($f024->subfield('a') && $f024->indicator('1') eq '3') {
                push @activefields, {identifier_field => '024a', identifier => $f024->subfield('a')};
                last;
            } elsif ($f024->subfield('a')) {
                push @activefields, {identifier_field => '024a', identifier => $f024->subfield('a')};
                last;
            }
        }
    }
    
    if ($record->field('003') && $record->field('003')->data =~ /FI-BTJ/) {
        my $allfons = $record->field( '003')->data.'|'.$record->field( '001')->data;
        push @activefields, {identifier_field => '003|001', identifier => $allfons};
    }

    return \@activefields;
}

sub checkBlock {
    my ($self, $biblio) = @_;
    my $record = MARC::Record::new_from_xml($biblio->{metadata}, 'UTF-8');
    return $record->subfield('942', "b");
}

sub checkEncodingLevel {
    my ($self, $record) = @_;

    my $encoding_level = substr( $record->leader(), 17 , 1 );
    return $encoding_level;
}

sub checkComponentPart {
    my ($self, $record) = @_;
    return 1 if $record->subfield('773', "w");
    return 0;
}

sub activated {
    my ($self, $endpoint, $headers, $interface, $target_id) = @_;

    my $ua = Mojo::UserAgent->new;
    my $tx = $ua->get($endpoint."/".$interface."/".$target_id => $headers);
    return 0 unless $tx->res->code eq '200' || $tx->res->code eq '201';
    return 1;
}


1;