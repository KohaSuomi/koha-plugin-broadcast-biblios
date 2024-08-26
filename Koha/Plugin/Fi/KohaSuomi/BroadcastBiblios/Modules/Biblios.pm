package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios;

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
use Koha::Biblio::Metadatas;
use Koha::Database;
use Koha::DateUtils qw(dt_from_string);
use POSIX qw( strftime );
use MARC::Record;
use Koha::Logger;
use XML::LibXML;
use Koha::ActionLogs;
use C4::Biblio qw( ModBiblioMarc TransformMarcToKoha );

=head new

    my $biblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new($params);

=cut

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;

}

sub getPage {
    return shift->{_params}->{page};
}

sub getChunks {
    return shift->{_params}->{chunks};
}

sub getLimit {
    return shift->{_params}->{limit};
}

sub getBiblionumber {
    return shift->{_params}->{biblionumber};
}

sub getTimestamp {
    return shift->{_params}->{timestamp};
}

sub skipRecords {
    return shift->{_params}->{skipRecords};
}

sub fetch {
    my ($self) = @_;
    print "Starting offset ". $self->getPage() ." as from ". $self->getTimestamp() . "!\n";
    my $terms;
    $terms = {timestamp => { '>' => $self->getTimestamp() }} if $self->getTimestamp();
    $terms = {biblionumber => {'>=' => $self->getBiblionumber()}} if $self->getBiblionumber();
    my $fetch = {
        page => $self->getPage,
        rows => $self->getChunks
    };
    $fetch = {rows => $self->getLimit()} if defined $self->getLimit() && $self->getLimit();

    my $biblios = Koha::Biblio::Metadatas->search($terms, $fetch)->unblessed;

    if ($self->skipRecords) {
        for (my $i = 0; $i < scalar(@$biblios); $i++) {
            if (!$self->checkActionLog($biblios->[$i]->{biblionumber}, $biblios->[$i]->{timestamp})) {
                $biblios->[$i]->{skip} = 1;
            }
        }
    }

    return $biblios;
}

sub importedRecords {
    my ($self, $batchdate, $no_components, $hosts_with_components) = @_;
    print "Fetch imported records from $batchdate\n";
    my $marcflavour = C4::Context->preference('marcflavour');
    my $start = dt_from_string($batchdate.' 00:00:00');
    my $end = dt_from_string($batchdate.' 23:59:00');
    my $schema = Koha::Database->new->schema;
    my @biblios = $schema->resultset('ImportRecord')->search({status => 'imported', upload_timestamp => {-between => [
                Koha::Database->new->schema->storage->datetime_parser->format_datetime( $start ),
                Koha::Database->new->schema->storage->datetime_parser->format_datetime( $end ),
            ]}
            },{
                join => 'import_biblio',
                '+select' => ['import_biblio.matched_biblionumber'],
                '+as' => ['biblionumber'],
                group_by => 'import_biblio.matched_biblionumber'
            })->get_column('biblionumber')->all;

    my $componentparts = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ComponentParts->new();
    if ($no_components) {
        my @no_components;
        foreach my $biblio_id (@biblios){
            my $components = $componentparts->fetch($biblio_id);
            unless($components){
                push @no_components, $biblio_id;
            }
        }
        return @no_components;
    } elsif ($hosts_with_components) {
        my @hosts_with_components;
        foreach my $biblio_id (@biblios){
            my $components = $componentparts->fetch($biblio_id);
            if($components){
                push @hosts_with_components, $biblio_id;
                foreach my $components (@$components){
                    push @hosts_with_components, $components->{biblionumber};
                }
            }
        }
        return @hosts_with_components;
    } else {
        return @biblios;
    }
}

sub getRecord {
    my ($self, $marcxml) = @_;

    my $record = eval {MARC::Record::new_from_xml($marcxml, 'UTF-8')};
    if ($@) {
        die "Error while parsing MARC RECORD: $@";
        return;
    }

    return $record;
}

sub restoreRecordFromActionLog {
    my ($self, $action_id) = @_;

    my $action_log = Koha::ActionLogs->find($action_id);
    my (undef, $marc) = split('=>\s*', $action_log->info);
    my $biblionumber = $action_log->object;
    my @marc_lines = split('\n', $marc);
    my $marc_record = MARC::Record->new();
    my $last_tag;
    foreach my $line (@marc_lines) {
        
        if ($line =~ /LDR/) {
            $line =~ s/^LDR //;
            $marc_record->leader($line);

        }
        elsif ($line =~ /^00\d/) {
            my $tag = substr($line, 0, 3);
            my $value = substr($line, 4);
            $value =~ s/^\s+//; # Remove whitespace from the beginning of the value
            my $field = MARC::Field->new($tag, $value);
            $marc_record->append_fields($field);
            $last_tag = $tag;
        } elsif ($line =~ /^\d/) {
            my $tag = substr($line, 0, 3);
            my $ind1 = substr($line, 4, 1);
            my $ind2 = substr($line, 5, 1);
            my $subfield = substr($line, 6);
            $subfield =~ s/^\s+//; # Remove whitespace from the beginning of the value
            my $code = substr($subfield, 1, 1);
            my $data = substr($subfield, 2);
            my $field = MARC::Field->new($tag, $ind1, $ind2, $code => $data);
            $marc_record->append_fields($field);
            $last_tag = $tag;
        } else {
            $line =~ s/^\s+//; # Remove whitespace from the beginning of the value
            my $code = substr($line, 1, 1);
            my $data = substr($line, 2);
            my @fields = $marc_record->field( $last_tag );
            foreach my $field (@fields) {
                if (!$field->subfield($code)) {
                    $field->add_subfields( $code => $data );
                }
            }
        }
    }
    
    my $biblio_id = eval { ModBiblioMarc( $marc_record, $biblionumber ) };
    if ($@) {
        warn "Error: $@";
    } else {
        my $dbh = C4::Context->dbh;
        my $biblio = C4::Biblio::TransformMarcToKoha({ record => $marc_record });
        my $frameworkcode = C4::Biblio::GetFrameworkCode($biblio_id);
        C4::Biblio::_koha_modify_biblio($dbh, $biblio, $frameworkcode);
        C4::Biblio::_koha_modify_biblioitem_nonmarc($dbh, $biblio);
        return $biblio_id;
    }
}

sub checkBlock {
    my ($self, $record) = @_;
    return 1 if $record->subfield('942', 'b');
    return 0;
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

sub checkActionLog {
    my ($self, $biblionumber, $timestamp) = @_;

    my $updatelog = Koha::ActionLogs->search(
        {
            module => 'CATALOGUING',
            action => 'MODIFY',
            object => $biblionumber,
            timestamp => { '>=', $timestamp },
            script => 'update_totalissues.pl'
        },
    )->unblessed;
    
    if (scalar(@$updatelog) > 0 ){
        return 0;
    }

    return 1;
}

sub diff005toTimestamp {
    my ($self, $record, $timestamp) = @_;

    my $field = $record->field('005');
    my $date = $field->data();
    $date =~ s/[^0-9]//g;
    $timestamp = dt_from_string($timestamp);
    my $date_string = strftime( "%Y%m%d%H%M%S", localtime($timestamp->epoch) ) . '0';
    return $date_string cmp $date;

}

1;