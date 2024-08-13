package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MarcJSONToXML;

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
use Scalar::Util qw( blessed );
use Try::Tiny;
use XML::LibXML;

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;
}

sub getMarcJSON {
    my ($self) = @_;
    my $marcjson;
    if ($self->{_params}->{marcjson}) {
        $marcjson = $self->{_params}->{marcjson};
    } else {
        die "Missing marcjson parameter";
    }
    return $marcjson;
}

sub toXML {
    my ($self) = @_;
    my $marcjson = $self->getMarcJSON();
    my $format = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    $format .= "<record>\n";
    $format .= "\t<leader>".$marcjson->{leader}."</leader>\n" if ($marcjson->{leader});
    foreach my $field (@{$marcjson->{fields}}) {
        if (defined $field->{value}) {
            $format .= "\t<controlfield tag=\"".$field->{tag}."\">".$self->escapeChars($field->{value})."</controlfield>\n";
        } else {
            $format .= "\t<datafield tag=\"".$field->{tag}."\" ind1=\"".$field->{ind1}."\" ind2=\"".$field->{ind2}."\">\n";
            foreach my $subfield (@{$field->{subfields}}) {
                $format .= "\t\t<subfield code=\"".$subfield->{code}."\">".$self->escapeChars($subfield->{value})."</subfield>\n";
            }
            $format .= "\t</datafield>\n";
        }
    }
    $format .= "</record>";
    my $xml = XML::LibXML->load_xml(string => $format);
    return $xml->toString();

}

sub escapeChars {
    my ($self, $string) = @_;
    $string =~ s/</&lt;/sg;
    $string =~ s/>/&gt;/sg;
    $string =~ s/&/&amp;/sg;
    $string =~ s/"/&quot;/sg;
    $string =~ s/'/&apos;/sg;
    return $string;
}

1;