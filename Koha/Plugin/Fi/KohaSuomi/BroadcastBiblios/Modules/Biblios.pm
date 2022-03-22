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
    print "Starting broadcasting offset ". $self->getPage() ." as from ". $self->getTimestamp() . "!\n";
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

sub getHostRecord {
    my ($self, $r) = @_;

    my $f773w = $r->subfield('773', 'w');
    my $f003;
    if ($f773w =~ /\((.*)\)/ ) { 
        $f003 = $1; 
        $f773w =~ s/\D//g;
    }
    my $cn = $f773w;
    my $cni = $r->field('003')->data();

    return undef unless $cn && $cni;

    my $query = "Control-number,ext:\"$cn\" AND cni,ext:\"$cni\"";
    require Koha::SearchEngine::QueryBuilder;
    require Koha::SearchEngine::Search;

    my $builder  = Koha::SearchEngine::QueryBuilder->new({index => $Koha::SearchEngine::BIBLIOS_INDEX});
    my $searcher = Koha::SearchEngine::Search->new({index => $Koha::SearchEngine::BIBLIOS_INDEX});
    my @operands = $query;
    my @sortBy = 'id_asc';
    my (undef, $builtQuery, $simpleQuery) = $builder->build_query_compat(undef, \@operands, undef, undef, \@sortBy);
    my $results;
    my $error;
    my $resultSetSize = 0;
    my @servers = 'biblioserver';

    ($error, $results) = $searcher->search_compat($builtQuery, $simpleQuery, \@sortBy, \@servers, 1000, 0, undef, undef, undef, 'ccl');
    if ($error) {
        die "getHostRecord():> Searching ($query):> Returned an error:\n$error";
    }

    my $marcflavour = C4::Context->preference('marcflavour');
    $resultSetSize = $results->{biblioserver}->{hits};

    if ($resultSetSize == 1) {
        my $record = @{$results->{biblioserver}->{RECORDS}}[0];
        return ref($record) ne 'MARC::Record' ? MARC::Record::new_from_xml($record, 'UTF-8') : $record;
    }
    elsif ($resultSetSize > 1) {
        die "getHostRecord():> Searching ($query):> Returned more than one record?";
    }
    return undef;
}

# sub importedRecords {
#     print "Fetch imported records from $batchdate\n";
#     my $marcflavour = C4::Context->preference('marcflavour');
#     my $start = dt_from_string($batchdate.' 00:00:00');
#     my $end = dt_from_string($batchdate.' 23:59:00');
#     my $schema = Koha::Database->new->schema;
#     my $type = $stage_type eq "update" ? 'match_applied' : 'no_match';
#     my $dtf = Koha::Database->new->schema->storage->datetime_parser;
#     my @biblios = $schema->resultset('ImportRecord')->search({status => 'imported', overlay_status => $type, upload_timestamp => {-between => [
#                 $dtf->format_datetime( $start ),
#                 $dtf->format_datetime( $end ),
#             ]}});
    
#     my @data;
#     my @components;
#     foreach my $rs (@biblios) {
#         my $cols = { $rs->get_columns };
#         $cols->{biblionumber} = $schema->resultset('ImportBiblio')->search({import_record_id => $cols->{import_record_id}})->get_column("matched_biblionumber")->next;
#         if ($cols->{biblionumber}) {
#             $cols->{marcxml} = Koha::Biblio::Metadatas->find({biblionumber => $cols->{biblionumber}})->metadata;
#             my $componentparts = Koha::Biblios->find( {biblionumber => $cols->{biblionumber}} )->componentparts;
#             if ($componentparts) {
#                 foreach my $componentpart (@{$componentparts}) {
#                     push @components, {biblionumber => $componentpart->{biblionumber}, parent_id => $cols->{biblionumber}};
#                 }
#             }
#             push @data, {marcxml => $cols->{marcxml}, biblionumber => $cols->{biblionumber}};
#         }
#     }
#     foreach my $componentpart (@components) {
#         my $index;
#         foreach my $d (@data) {
#             if ($componentpart->{biblionumber} eq $d->{biblionumber}) {
#                 $data[$index]->{parent_id} = $componentpart->{parent_id};
#             }
#             $index++;
#         }
#     }
#     return @data;
# }

1;