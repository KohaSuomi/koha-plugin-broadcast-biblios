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

sub queue {
    my $c = shift->openapi->valid_input or return;

    my $logger = Koha::Logger->get({ interface => 'api' });

    try {
        my $body = $c->req->body;
        my $queue = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastQueue->new($body);
        $queue->setToQueue();

        return $c->render(status => 200, openapi => {message => "Success"});
    } catch {
        my $error = $_;
        $logger->error($error);
        return $c->render(status => 500, openapi => {error => "Something went wrong, check the logs"});
    }
}

1;