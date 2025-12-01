package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler;

use Modern::Perl;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Generic;
use Koha::Logger;
use Data::Dumper;

sub handle_exception {
    my ($self, $interface, $status, $exception) = @_;

    # Handle the exception based on its type
    if ($interface eq 'Melinda' || $interface eq 'Vaari') {
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
    } elsif ($status eq '422') {
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda::UnprocessableEntity->throw( $exception->{message} );
    } else {
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda->throw( $exception->{message} );
    }

    display_error("Melinda Exception: " . $exception->{message});
}

sub handle_generic_exception {
    my ($self, $status, $exception) = @_;

    if ($status eq '401') {
        # Handle the unauthorized exception
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Generic::Unauthorized->throw( $exception->{message} );
    } elsif ($status eq '404') {
        # Handle the not found exception
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Generic::NotFound->throw( $exception->{message} );
    } elsif ($status eq '409') {
        # Handle the conflict exception
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Generic::Conflict->throw( $exception->{message} );
    } else {
        # Handle the generic exception
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Generic->throw( $exception->{message} );
    }
    display_error("Generic Exception: " . $exception->{message});
}

sub display_api_error {
    my ($self, $c, $error) = @_;

    # Log the error
    my $logger = Koha::Logger->get({ interface => 'api' });
    $logger->error(Data::Dumper->Dump([$error], ['error']));

    if ($error->isa('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Generic::Unauthorized')) {
        # Return the unauthorized error message
        return $c->render(status => 401, openapi => {error => $error->{message}});
    }

    if ($error->isa('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Generic::NotFound')) {
        # Return the not found error message
        return $c->render(status => 404, openapi => {error => $error->{message}});
    }

    if ($error->isa('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Generic::Conflict')) {
        # Return the conflict error message
        return $c->render(status => 409, openapi => {error => $error->{message}});
    }

    if ($error->isa('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda::Conflict')) {
        # Return the conflict error message
        return $c->render(status => 409, openapi => {error => $error->{message}});
    }

    if ($error->isa('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda::UnprocessableEntity')) {
        # Return the unprocessable entity error message
        return $c->render(status => 422, openapi => {error => $error->{message}});
    }

    if ($error->isa('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda')) {
        # Return the Melinda error message
        return $c->render(status => 500, openapi => {error => $error->{message}});
    }

    # Return the error message
    return $c->render(status => 500, openapi => {error => "Something went wrong, check the logs"});
}

sub display_error {
    my ($message) = @_;

    # Display the error message
    print "$message \n";
}

1;