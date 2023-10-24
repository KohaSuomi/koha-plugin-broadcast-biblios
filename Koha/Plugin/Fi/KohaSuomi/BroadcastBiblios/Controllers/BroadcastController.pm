package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Controllers::BroadcastController;

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
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastQueue;
use Try::Tiny;
use Koha::Logger;

=head1 API

=cut

sub setToQueue {
    my $c = shift->openapi->valid_input or return;

    my $logger = Koha::Logger->get({ interface => 'api' });

    try {
        my $body = $c->req->json;
        my $queue = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastQueue->new({broadcast_interface => $body->{broadcast_interface}, type => $body->{type}, user_id => $body->{user_id}});
        $queue->setToQueue($body->{active_biblio}, $body->{broadcast_biblio});

        return $c->render(status => 201, openapi => {message => "Success"});
    } catch {
        my $error = $_;
        $logger->error($error);
        return $c->render(status => 500, openapi => {error => "Something went wrong, check the logs"});
    }
}

sub listQueue {
    my $c = shift->openapi->valid_input or return;

    my $logger = Koha::Logger->get({ interface => 'api' });

    try {
        my $status = $c->validation->param('status');
        my $page = $c->validation->param('page');
        my $limit = $c->validation->param('limit');
        my $biblio_id = $c->validation->param('biblio_id');
        my $queue = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastQueue->new();
        my $results = $queue->getQueue($status, $biblio_id, $page, $limit);

        return $c->render(status => 200, openapi => $results);
    } catch {
        my $error = $_;
        $logger->error($error);
        return $c->render(status => 500, openapi => {error => "Something went wrong, check the logs"});
    }
}

1;
