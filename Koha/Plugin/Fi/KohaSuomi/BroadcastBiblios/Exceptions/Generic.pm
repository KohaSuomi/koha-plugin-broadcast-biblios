package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Generic;

use strict;
use warnings;

use Koha::Exception;

use Exception::Class (
    'Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Generic' => {
        isa         => 'Koha::Exception',
        description => 'Generic Koha exception',
    },
    'Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Generic::Conflict' => {
        isa         => 'Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Generic',
        description => 'Conflict exception',
    },
);

=head1 NAME

Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Generic - Base class for Koha exceptions

=head1 Exceptions

=head2 Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Generic

Generic Koha exception

=cut

=head2 Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Generic::Conflict

Conflict exception

=cut

1;