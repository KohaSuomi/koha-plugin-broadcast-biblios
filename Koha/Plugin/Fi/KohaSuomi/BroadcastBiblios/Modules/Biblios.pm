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
use MARC::Record;
use Koha::Logger;
use XML::LibXML;

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

    return $biblios;
}

sub importedRecords {
    my ($self, $batchdate) = @_;
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

    return @biblios;
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

1;