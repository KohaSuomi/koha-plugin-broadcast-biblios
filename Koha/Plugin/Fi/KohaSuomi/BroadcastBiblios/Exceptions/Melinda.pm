package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda;

use Modern::Perl;

use Koha::Exception;

use Exception::Class (

    'Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda' => {
        isa => 'Koha::Exception',
    },
    'Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda::Conflict' => {
        isa         => 'Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda',
        description => 'Conflict',
    },
    'Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda::UnprocessableEntity' => {
        isa         => 'Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda',
        description => 'Unprocessable Entity',
    }
);

=head1 NAME

Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda - Base class for Melinda exceptions

=head1 Exceptions


=head2 Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda

Generic Melinda exception

=head2 Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda::Conflict

Exception to be used when a conflict is detected

=cut

=head2 Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda::UnprocessableEntity

Exception to be used when an unprocessable entity is detected

=cut

1;
