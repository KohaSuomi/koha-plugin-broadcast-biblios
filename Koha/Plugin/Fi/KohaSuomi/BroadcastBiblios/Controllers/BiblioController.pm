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
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Search;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::Identifiers;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ComponentParts;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MarcXMLToJSON;
use C4::Biblio qw( AddBiblio ModBiblio GetFrameworkCode BiblioAutoLink);
use C4::Context;
use Try::Tiny;
use Koha::Logger;

=head1 API

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    my $logger = Koha::Logger->get({ interface => 'api' });

    try {
        my $biblio = Koha::Biblios->find($c->validation->param('biblio_id'));

        unless ($biblio) {
            return $c->render(status => 404, openapi => {error => "Biblio not found"});
        }
        
        my $marcxml = $biblio->metadata->metadata;
        $biblio = $biblio->unblessed;
        $biblio->{serial} = $biblio->{serial} ? $biblio->{serial} : 0; # Don't know why null serial gives error even it is defined on Swagger
        $biblio->{marcxml} = $marcxml;
        return $c->render(status => 200, openapi => $biblio);
    } catch {
        my $error = $_;
        $logger->error($error);
        return $c->render(status => 500, openapi => {error => "Something went wrong, check the logs"});
    }
}

sub find {
    my $c = shift->openapi->valid_input or return;

    my $logger = Koha::Logger->get({ interface => 'api' });
    $c->req->headers->accept =~ m/application\/marc-in-json/ ? $c->stash('format', 'marcjson') : $c->stash('format', 'marcxml');
    try {
        my $format = $c->stash('format');
        my $body = $c->req->json;
        my $identifiers = $body->{identifiers};
        my $search = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Search->new();
        my $biblio_id = $body->{biblio_id};
        foreach my $identifier (@$identifiers) {
            $logger->info("Searching for identifier: ".$identifier->{identifier}." in field: ".$identifier->{identifier_field});
            my $bib = $search->findByIdentifier($identifier->{identifier}, $identifier->{identifier_field});
            next unless $bib;
            $biblio_id = $bib->subfield('999', 'c')+0;
            last if $bib;
        }

        my $biblio = Koha::Biblios->find($biblio_id);

        unless ($biblio) {
            return $c->render(status => 404, openapi => {error => "Biblio not found"});
        }
        my $response = _biblio_wrapper($format, $biblio, $identifiers);
        
        return $c->render(status => 200, openapi => $response);
    } catch {
        my $error = $_;
        $logger->error($error);
        return $c->render(status => 500, openapi => {error => "Something went wrong, check the logs"});
    }
}

sub search {
    my $c = shift->openapi->valid_input or return;

    my $logger = Koha::Logger->get({ interface => 'api' });

    try {
        my $biblio = Koha::Biblios->find($c->validation->param('biblio_id'));

        unless ($biblio) {
            return $c->render(status => 404, openapi => {error => "Biblio not found"});
        }
        my $body = $c->req->json;
        my $users = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Users->new();
        my $config = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Config->new();
        my $interface = $config->getInterfaceConfig($body->{interface_name});
        my $user_id = $interface->{type} eq 'import' ? $interface->{defaultUser} : $users->getInterfaceUserByPatronId($body->{interface_name}, $body->{patron_id});
        my $search = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Search->new();
        my $results = $search->searchFromInterface($body->{interface_name}, $body->{identifiers}, undef, $user_id);
        return $c->render(status => 200, openapi => $results);
    } catch {
        my $error = $_;
        $logger->error($error->{message});
        if ($error->{status}) {
            return $c->render(status => $error->{status}, openapi => {error => $error->{message}});
        } else {
            return $c->render(status => 500, openapi => {error => "Something went wrong, check the logs"});
        }
    }

}

sub add {
    my $c = shift->openapi->valid_input or return;

    my $logger = Koha::Logger->get({ interface => 'api' });

    try {

        my $biblio_id;
        my $biblioitemnumber;

        my $body = $c->req->json;
        unless ($body) {
            return $c->render(status => 400, openapi => {error => "Missing MARCXML body"});
        }

        my $record = eval {MARC::Record::new_from_xml( $body, "UTF-8", C4::Context->preference('marcflavour'))};
        if ($@) {
            return $c->render(status => 400, openapi => {error => $@});
        } else {
            my $search = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Search->new();
            my $hostrecord = $search->getHostRecord($record);
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
    } catch {
        my $error = $_;
        $logger->error($error);
        return $c->render(status => 500, openapi => {error => "Something went wrong, check the logs"});
    }
}

sub update {
    my $c = shift->openapi->valid_input or return;

    my $biblio_id = $c->validation->param('biblio_id');
    my $logger = Koha::Logger->get({ interface => 'api' });

    try {
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
            my $search = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Search->new();
            my $hostrecord = $search->getHostRecord($record);
            
            if ($hostrecord && $hostrecord->subfield('942','c')) {
                my $field = MARC::Field->new('942','','','c' => $hostrecord->subfield('942','c'));
                $record->append_fields($field);
            }
            $success = &ModBiblio($record, $biblio_id, $frameworkcode, {
                        overlay_context => {
                            source       => 'z3950'
                        }
                    });
        }
        if ($success) {
            my $biblio = Koha::Biblios->find($biblio_id);
            return $c->render(status => 200, openapi => {biblio => $biblio});
        } else {
            return $c->render(status => 400, openapi => {error => "unable to update record"});
        }
    } catch {
        my $error = $_;
        if ($error->isa('Mojo::Exception')) {
            $logger->error($error->to_string);
            return $c->render(status => 500, openapi => {error => $error->to_string});
        } else {
            $logger->error($error);
            return $c->render(status => 500, openapi => {error => "Something went wrong, check the logs"});
        }
    }
}

sub restore {
    my $c = shift->openapi->valid_input or return;

    my $logger = Koha::Logger->get({ interface => 'api' });

    try {
        my $action_id = $c->validation->param('action_id');
        my $biblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new();
        my $biblio_id = $biblios->restoreRecordFromActionLog($action_id);
        return $c->render(status => 200, openapi => {biblio_id => $biblio_id});
    } catch {
        my $error = $_;
        $logger->error($error);
        return $c->render(status => 500, openapi => {error => "Something went wrong, check the logs"});
    }
}

sub getBroadcastBiblio {
    my $c = shift->openapi->valid_input or return;

    my $logger = Koha::Logger->get({ interface => 'api' });
    $c->req->headers->accept =~ m/application\/marc-in-json/ ? $c->stash('format', 'marcjson') : $c->stash('format', 'marcxml');
    try {
        my $format = $c->stash('format');
        my $biblio = Koha::Biblios->find($c->validation->param('biblio_id'));
        my $convert = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MarcXMLToJSON->new();
        unless ($biblio) {
            return $c->render(status => 404, openapi => {error => "Biblio not found"});
        }
        my $identifierHelper = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::Identifiers->new;
        my @identifiers = $identifierHelper->fetchIdentifiers($biblio->metadata->metadata);
        my $response = _biblio_wrapper($format, $biblio, @identifiers);
        
        return $c->render(status => 200, openapi => $response);
    } catch {
        my $error = $_;
        $logger->error($error);
        return $c->render(status => 500, openapi => {error => "Something went wrong, check the logs"});
    }
}

sub getcomponentparts {
    my $c = shift->openapi->valid_input or return;

    my $logger = Koha::Logger->get({ interface => 'api' });

    try {

        my $biblio = Koha::Biblios->find($c->validation->param('biblio_id'));

        unless ($biblio) {
            return $c->render(status => 404, openapi => {error => "Biblio not found"});
        }

        my $bibliowrapper = {
            marcxml => $biblio->metadata->metadata,
            biblionumber => $biblio->biblionumber,

        };

        my $componentparts = $biblio->get_marc_components(C4::Context->preference('MaxComponentRecords'));
        my $components;
        foreach my $componentpart (@{$componentparts}) {
            my $biblionumber = $componentpart->subfield('999', 'c')+0;
            push @$components, {biblionumber => $biblionumber, marcxml => $componentpart->as_xml_record()};
        }
        
        return $c->render(status => 200, openapi => { biblio => $bibliowrapper, componentparts => $components });
    } catch {
        my $error = $_;
        $logger->error($error);
        return $c->render(status => 500, openapi => {error => "Something went wrong, check the logs"});
    }
}

sub activate {
    my $c = shift->openapi->valid_input or return;

    my $logger = Koha::Logger->get({ interface => 'api' });

    try {
        my $biblio = Koha::Biblios->find($c->validation->param('biblio_id'));
        my $body = $c->req->json;
        unless ($biblio) {
            return $c->render(status => 404, openapi => {error => "Biblio not found"});
        }

        my $marcxml = $biblio->metadata->metadata;
        $biblio = $biblio->unblessed;
        $biblio->{metadata} = $marcxml;

        my $record = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Broadcast->new({
            endpoint => $body->{endpoint}, 
            endpoint_type => $body->{endpoint_type},
            interface => $body->{interface}, 
            inactivity_timeout => $body->{inactivity_timeout} || 50,
            headers => {"Authorization" => $body->{apiKey}}
        });

        my $response = $record->activateSingleBiblio($biblio);

        if ($response->{status}) {
            return $c->render(status => $response->{status}, openapi => { error => $response->{message} });
        } else {
            return $c->render(status => 200, openapi => { message => "Success" });
        }
    } catch {
        my $error = $_;
        $logger->error($error);
        return $c->render(status => 500, openapi => {error => "Something went wrong, check the logs"});
    }
}

sub _biblio_wrapper {
    my ($format, $biblio, $identifiers) = @_;

    my $convert = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MarcXMLToJSON->new();
    my $componentParts = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ComponentParts->new();

    my $componentparts = $biblio->get_marc_components(C4::Context->preference('MaxComponentRecords'));
    my $components;
    foreach my $componentpart (@{$componentparts}) {
        my $biblionumber = $componentpart->subfield('999', 'c')+0;
        push @$components, {biblionumber => $biblionumber, $format => $format eq 'marcjson' ? $convert->toJSON($componentpart->as_xml_record()) : $componentpart->as_xml_record()};
    }

    my $bibliowrapper = {
        $format => $format eq 'marcjson' ? $convert->toJSON($biblio->metadata->metadata) : $biblio->metadata->metadata,
        biblionumber => $biblio->biblionumber,
        componentparts => $componentParts->sortComponentParts($components)
    };

    $bibliowrapper->{identifiers} = $identifiers if $identifiers;

    return $bibliowrapper;
}

1;