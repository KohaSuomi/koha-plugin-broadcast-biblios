package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Controllers::ActiveRecordController;

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
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Config;
use Try::Tiny;
use Koha::Logger;

=head1 API

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    my $logger = Koha::Logger->get({ interface => 'api' });

    try {

        my $activeRecords = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords->new();
        my $biblio_id = $c->validation->param('biblio_id');
        my $activeRecord = $activeRecords->getActiveRecordByBiblionumber($biblio_id);

        unless ($activeRecord) {
            return $c->render(status => 404, openapi => {error => "Activation not found for ".$biblio_id});
        }

        return $c->render(status => 200, openapi => $activeRecord);
    } catch {
        my $error = $_;
        $logger->error($error);
        return $c->render(status => 500, openapi => {error => "Something went wrong, check the logs"});
    }
}

sub find {
    my $c = shift->openapi->valid_input or return;

    my $logger = Koha::Logger->get({ interface => 'api' });

    try {

        my $activeRecords = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords->new({table => 'activerecords'});
        my $identifier = $c->validation->param('identifier');
        my $identifier_field = $c->validation->param('identifier_field');
        my $activeRecord = $activeRecords->getActiveRecordByIdentifier($identifier, $identifier_field);

        unless ($activeRecord) {
            return $c->render(status => 404, openapi => {error => "Activation not found for ".$identifier." ".$identifier_field});
        }

        if ($activeRecord && $activeRecord->{blocked}) {
            return $c->render(status => 403, openapi => {error => "Record is blocked"});
        }

        return $c->render(status => 200, openapi => $activeRecord);
    } catch {
        my $error = $_;
        $logger->error($error);
        return $c->render(status => 500, openapi => {error => "Something went wrong, check the logs"});
    }
}

sub add {
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

        my $config = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Config->new();
        my $params->{config} = $config->getInterfaceConfig($body->{broadcast_interface});
        
        my $activeRecords = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords->new($params);

        my $response = $activeRecords->setActiveRecord($biblio);

        if ($response->{status} != 201) {
            return $c->render(status => $response->{status}, openapi => { error => $response->{message} });
        } else {
            return $c->render(status => 201, openapi => { message => "Success" });
        }
    } catch {
        my $error = $_;
        $logger->error($error);
        return $c->render(status => 500, openapi => {error => "Something went wrong, check the logs"});
    }
}

sub update {
    my $c = shift->openapi->valid_input or return;

    my $logger = Koha::Logger->get({ interface => 'api' });

    try {

        my $biblio_id = $c->validation->param('biblio_id');
        my $body = $c->req->json;
        my $activeRecords = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords->new();
        my $activeRecord = $activeRecords->getActiveRecordByBiblionumber($biblio_id);

        unless ($activeRecord) {
            return $c->render(status => 404, openapi => {error => "Activation not found for ".$biblio_id});
        }

        my $update = $activeRecords->updateActiveRecord($activeRecord->{id}, $body);

        return $c->render(status => 200, openapi => {message => "Success"});
    } catch {
        my $error = $_;
        $logger->error($error);
        return $c->render(status => 500, openapi => {error => "Something went wrong, check the logs"});
    }
}

1;