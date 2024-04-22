package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler;

use strict;
use warnings;
use Koha::Logger;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Generic;

sub handle_exception {
    my ($self, $interface, $status, $exception) = @_;

    # Handle the exception based on its type
    if ($interface eq 'Melinda') {
        # Handle custom exception
        $self->handle_melinda_exception($status, $exception);
    } else {
        # Handle other exceptions
        $self->handle_generic_exception($status, $exception);
    }
}

sub handle_melinda_exception {
    my ($self, $status, $exception) = @_;

    # Handle the Melinda exception
    if ($status eq '409') {
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda::Conflict->throw( $exception->{message} );
    } else {
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda->throw( $exception->{message} );
    }

    display_error("Melinda Exception: " . $exception->{message});
}

sub handle_generic_exception {
    my ($self, $status, $exception) = @_;

    # Handle the generic exception
    Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Generic->throw( $exception->{message} );
    display_error("Generic Exception: " . $exception->{message});
}

sub display_error {
    my ($message) = @_;

    # Display the error message
    print "$message \n";
}

1;