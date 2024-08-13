package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MarcXMLToJSON;

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
use Mojo::JSON qw(to_json);

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;
}

sub toJSON {
    my ($self, $marc) = @_;
    my $marcxml = $self->xmlToHash($marc);
    my $json;
    $json->{leader} = $marcxml->{"leader"} if $marcxml->{"leader"};
    $json->{fields} = $self->formatFields($marcxml->{"controlfield"}, $marcxml->{"datafield"}) if $marcxml->{"controlfield"} || $marcxml->{"datafield"};
    return $json;
}

sub formatFields {
    my ($self, $controlfields, $datafields) = @_;
    my @fields;
    if ($controlfields) {
        foreach my $controlfield (@$controlfields) {
            push @fields, {tag => $controlfield->{"tag"}, value => $controlfield->{"value"}};
        }
    }
    if ($datafields) {
        foreach my $datafield (@$datafields) {
            my @subfields;
            foreach my $subfield (@{$datafield->{"subfield"}}) {
                push @subfields, {code => $subfield->{"code"}, value => $subfield->{"value"}};
            }
            push @fields, {tag => $datafield->{"tag"}, ind1 => $datafield->{"ind1"}, ind2 => $datafield->{"ind2"}, subfields => \@subfields};
        }
    }
    return \@fields;
}

sub xmlToHash {
    my ($self, $res) = @_;
    my $hash;
    if ($res) {
        my $xml = eval { XML::LibXML->load_xml(string => $res)};
        my $valid;
        for my $node ($xml->findnodes(q{//*})) {
            if ($node->nodeName eq "leader") {
                $valid = 1;
                last;
            }
        }
        if ($valid) {
            my @leader = $xml->getElementsByTagName('leader');
            my @controlfields = $xml->getElementsByTagName('controlfield');
            my @datafields = $xml->getElementsByTagName('datafield');
            $hash->{leader} = $leader[0]->textContent;
            
            my @cf;
            foreach my $controlfield (@controlfields) {
                push @cf, {tag => $controlfield->getAttribute("tag"), value => $controlfield->textContent}
            }
            $hash->{controlfield} = \@cf;
            
            my @df;
            foreach my $datafield (@datafields) {
                my @subfields = $datafield->getElementsByTagName("subfield");
                my @sf;
                foreach my $subfield (@subfields){
                    push @sf, {code => $subfield->getAttribute("code"), value => $self->revertEscapeXML($subfield->textContent)};
                }
                push @df, {tag => $datafield->getAttribute("tag"), ind1 => $datafield->getAttribute("ind1"), ind2 => $datafield->getAttribute("ind2"), subfield => \@sf}
            }
            $hash->{datafield} = \@df;
        }
    }

    return $hash;
}

sub revertEscapeXML {
    my ($self, $string) = @_;
    $string =~ s/&lt;/</sg;
    $string =~ s/&gt;/>/sg;
    $string =~ s/&amp;/&/sg;
    $string =~ s/&quot;/"/sg;
    $string =~ s/&apos;/'/sg;
    return $string;
}

1;