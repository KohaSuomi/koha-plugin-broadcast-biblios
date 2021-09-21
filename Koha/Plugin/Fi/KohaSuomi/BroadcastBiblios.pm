package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios;

## It's good practice to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);
## We will also need to include any Koha libraries we want to access
use C4::Context;
use utf8;

use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Broadcast;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords;

## Here we set our plugin version
our $VERSION = "1.1.1";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Broadcast biblios',
    author          => 'Johanna Räisä',
    date_authored   => '2021-09-09',
    date_updated    => '2021-09-20',
    minimum_version => '17.05',
    maximum_version => '',
    version         => $VERSION,
    description     => 'Tool to broadcast biblios',
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual 
    my $self = $class->SUPER::new($args);

    $self->{logTable}  = $self->get_qualified_table_name('log');

    if ( $args->{page} && $args->{chunks}) {

        $self->{chunks} = $args->{chunks};
        $self->{biblionumber} = $args->{biblionumber};
        $self->{limit} = $args->{limit};
        $self->{page} = 1;
        $self->{timestamp} = $args->{timestamp};
        $self->{endpoint} = $args->{endpoint}; 
        $self->{endpoint_type} = $args->{endpoint_type};
        $self->{interface} = $args->{interface}; 
        $self->{inactivity_timeout} = $args->{inactivity_timeout};
        $self->{headers} = $args->{headers};
        $self->{all} = $args->{all};
        $self->{verbose} = $args->{verbose};
        
    }

    if ($args->{directory}) {
        $self->{directory} = $args->{directory};
    }

    return $self;
}

## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
sub install() {
    my ( $self, $args ) = @_;

    $self->create_log_table();

    return 1;
}

## This is the 'upgrade' method. It will be triggered when a newer version of a
## plugin is installed over an existing older version of a plugin
sub upgrade {
    my ( $self, $args ) = @_;

    return 1;
}

## This method will be run just before the plugin files are deleted
## when a plugin is uninstalled. It is good practice to clean up
## after ourselves!
sub uninstall() {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;

    my $log_table = $self->{logTable};
    C4::Context->dbh->do("DROP TABLE $log_table");

    return 1;
}

sub run {
    my ( $self ) = @_;

    my $broadcast = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Broadcast->new({
        endpoint => $self->{endpoint}, 
        endpoint_type => $self->{endpoint_type},
        interface => $self->{interface}, 
        inactivity_timeout => $self->{inactivity_timeout},
        headers => $self->{headers},
        all => $self->{all},
        verbose => $self->{verbose},
        log_table => $self->{logTable}
    });

    my $params = {
        chunks => $self->{chunks},
        biblionumber => $self->{biblionumber},
        limit => $self->{limit},
        page => $self->{page},
        timestamp => undef
    };

    $broadcast->broadcastBiblios($params);

}

sub get_active {
    my ( $self ) = @_;

    my $activeRecords = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords->new();

    my $params = {
        chunks => $self->{chunks},
        biblionumber => $self->{biblionumber},
        limit => $self->{limit},
        page => $self->{page},
        interface => $self->{interface},
        directory => $self->{directory},
    };

    $activeRecords->getAllActiveRecords($params);

}

sub create_log_table {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;
    my $log_table = $self->{logTable};
    $dbh->do("
        CREATE TABLE `$log_table` (
        `id` int(12) NOT NULL AUTO_INCREMENT,
        `biblionumber` int(11) NOT NULL,
        `updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
    ");
}

1;

