package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ComponentParts;

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
use Koha::Biblios;
use C4::Context;
use MARC::Record;

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

sub fetch {
    my ($self, $biblionumber) = @_;

    my $biblio = Koha::Biblios->find($biblionumber);
    my $componentparts = $biblio->get_marc_components(C4::Context->preference('MaxComponentRecords'));
    my $components;
    foreach my $componentpart (@{$componentparts}) {
        my $biblionumber = $componentpart->subfield('999', 'c')+0;
        push @$components, {biblionumber => $biblionumber, marcxml => $componentpart->as_xml_record()};
    }
    return $components;
}

1;