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

=head1 API

=cut

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