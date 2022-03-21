package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Controllers::BiblioController;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
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

use Mojo::Base 'Mojolicious::Controller';
use Koha::Biblios;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios;

=head1 API

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    my $biblio_id;
    my $biblioitemnumber;

    my $body = $c->req->body;
    unless ($body) {
        return $c->render(status => 400, openapi => {error => "Missing MARCXML body"});
    }

    my $record = eval {MARC::Record::new_from_xml( $body, "utf8", '')};
    if ($@) {
        return $c->render(status => 400, openapi => {error => $@});
    } else {
        my $biblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new();
        my $hostrecord = $biblios->getHostRecord($record);
        if ($hostrecord && $hostrecord->subfield('942','c')) {
            my $field = MARC::Field->new('942','','','c' => $hostrecord->subfield('942','c'));
            $record->append_fields($field);
        }
        ( $biblio_id, $biblioitemnumber ) = &AddBiblio($record, '');
    }
    if ($biblio_id) {
        return $c->render(status => 201, openapi => {biblio_id => 0+$biblio_id});
    } else {
        return $c->render(status => 400, openapi => {error => "unable to create record"});
    }
}

sub update {
    my $c = shift->openapi->valid_input or return;

    my $biblio_id = $c->validation->param('biblio_id');

    my $biblio = Koha::Biblios->find($biblio_id);
    unless ($biblio) {
        return $c->render(status => 404, openapi => {error => "Biblio not found"});
    }

    my $success;
    my $body = $c->req->body;
    my $record = eval {MARC::Record::new_from_xml( $body, "utf8", '')};
    if ($@) {
        return $c->render(status => 400, openapi => {error => $@});
    } else {
        my $frameworkcode = GetFrameworkCode( $biblio_id );
        if (C4::Context->preference("BiblioAddsAuthorities")){
            BiblioAutoLink($record, $frameworkcode);
        }
        my $biblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new();
        my $hostrecord = $biblios->getHostRecord($record);
        
        if ($hostrecord && $hostrecord->subfield('942','c')) {
            my $field = MARC::Field->new('942','','','c' => $hostrecord->subfield('942','c'));
            $record->append_fields($field);
        }
        $success = &ModBiblio($record, $biblio_id, $frameworkcode);
    }
    if ($success) {
        my $biblio = Koha::Biblios->find($biblio_id);
        return $c->render(status => 200, openapi => {biblio => $biblio});
    } else {
        return $c->render(status => 400, openapi => {error => "unable to update record"});
    }
}

sub getcomponentparts {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find($c->validation->param('biblio_id'));

    unless ($biblio) {
        return $c->render(status => 404, openapi => {error => "Biblio not found"});
    }

    my $bibliowrapper = {
        marcxml => $biblio->metadata->metadata,
        biblionumber => $biblio->biblionumber,

    };

    my $componentparts = $biblio->get_marc_components();
    my $components;
    foreach my $componentpart (@{$componentparts}) {
        my $biblionumber = $componentpart->subfield('999', 'c')+0;
        push @$components, {biblionumber => $biblionumber, marcxml => $componentpart->as_xml_record()};
    }
    
    return $c->render(status => 200, openapi => { biblio => $bibliowrapper, componentparts => $components });
}
1;