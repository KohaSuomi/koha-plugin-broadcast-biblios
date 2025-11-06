package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios;

## It's good practice to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);
## We will also need to include any Koha libraries we want to access
use C4::Context;
use C4::Auth qw( haspermission );
use utf8;

use YAML::XS;
use Encode;
use Mojo::JSON qw(decode_json);
use UUID 'uuid';

use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Broadcast;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastQueue;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::OAI;

## Here we set our plugin version
our $VERSION = "2.6.0";

my $lang = C4::Languages::getlanguage() || 'en';
my $name = "";
my $description = "";
if ( $lang eq 'sv-SE' ) {
    $name = "Postning av poster";
    $description = "Skicka och ta emot poster i Koha. (Lokala databaser, Täti)";
} elsif ( $lang eq 'fi-FI' ) {
    $name = "Tietuesiirtäjä";
    $description = "Tietueiden lähetys ja vastaanotto Kohassa. (Paikalliskannat, Täti)";
} else {
    $name = "Broadcast Biblios";
    $description = "Sending and receiving records in Koha.";
}

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => $name,
    author          => 'Johanna Räisä',
    date_authored   => '2021-09-09',
    date_updated    => '2025-11-06',
    minimum_version => '25.05.00.0000',
    maximum_version => '',
    version         => $VERSION,
    description     => $description,
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

    $self->{logTable} = $self->get_qualified_table_name('log');

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
        $self->{start_time} = $args->{start_time};
        $self->{blocked_encoding_level} = $args->{blocked_encoding_level};
        $self->{block_component_parts} = $args->{block_component_parts};
        
    }

    if ($args->{directory}) {
        $self->{directory} = $args->{directory};
    }

    if ($args->{database}) {
        $self->{database} = $args->{database};
    }

    if ($args->{date}) {
        $self->{date} = $args->{date};
    }

    if ($args->{config}) {
        $self->{config} = $args->{config};
    }

    if ($args->{type}) {
        $self->{type} = $args->{type};
    }

    $self->{cgi} = CGI->new();

    return $self;
}

sub report {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'report.tt' });

    $template->param(
        notifyfields => $self->retrieve_data('notifyfields')
    );

    print $cgi->header(-charset    => 'utf-8');
    print $template->output();
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template({ file => 'config.tt' });

        ## Grab the values we already have for our settings, if any exist
        $template->param(
            exportapis => $self->retrieve_data('exportapis'),
            importapi => $self->retrieve_data('importapi'),
            notifyfields => $self->retrieve_data('notifyfields'),
            importinterface => $self->retrieve_data('importinterface'),
        );

        print $cgi->header(-charset    => 'utf-8');
        print $template->output();
    }
    else {
        my $exportapis = $cgi->param('exportapis');
        my $importapi = $cgi->param('importapi');
        my $notifyfields = $cgi->param('notifyfields');
        my $importinterface = $cgi->param('importinterface');
        $self->store_data(
            {
                exportapis          => $exportapis,
                importapi           => $importapi,
                notifyfields        => $notifyfields,
                importinterface     => $importinterface,
            }
        );
        $self->go_home();
    }
}

## This method allows you to add new html elements to the catalogue toolbar.
## You'll want to return a string of raw html here, most likely a button or other
## toolbar element of some form. See bug 20968 for more details.
sub intranet_catalog_biblio_enhancements_toolbar_button {
    my ( $self ) = @_;

    my $biblionumber = $self->{'cgi'}->param('biblionumber');
    my $patron_id = C4::Context->userenv->{'number'};
    my $dropdown;
    if (haspermission(C4::Context->userenv->{'id'}, {'editcatalogue' => 'edit_catalogue'})) {
        my $pluginpath = $self->get_plugin_http_path();
        $dropdown = '<div id="broadcastApp"><record-component :biblio_id="'.$biblionumber.'" :patron_id="'.$patron_id.'"></record-component></div>';
        $dropdown .= '<script src="https://cdnjs.cloudflare.com/ajax/libs/vue/3.4.15/vue.global.min.js" integrity="sha512-YX1AhLUs26nJDkqXrSgg6kjMat++etdfsgcphWSPcglBGp/sk5I0/pKuu/XIfOCuzDU4GHcOB1E9LlveutWiBw==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>';
        $dropdown .= '<script src="https://cdnjs.cloudflare.com/ajax/libs/vue-demi/0.14.6/index.iife.min.js" integrity="sha512-4bZPx/4GmRQW9DcQEbYpO4nLPaIceJ/gfouiSkpLCrrYYKFC9W+dk5dCT5WaDkRoWIMyG+Zw853iFABZgatpYw==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>';
        $dropdown .= '<script src="https://cdnjs.cloudflare.com/ajax/libs/pinia/2.1.7/pinia.iife.min.js" integrity="sha512-o2oH6iY7StQR/0l/6CJpuET6bT1RyGQWUpu1nWLIcGuFZnV4iOlSvtgUrO+i4x3QtoZSve8SAb1LplJWEZTj0w==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>';
        $dropdown .= '<script src="https://cdnjs.cloudflare.com/ajax/libs/vue-i18n/9.10.2/vue-i18n.global.prod.min.js" integrity="sha512-UUOWezsNQ8nhUaGbOuPDdwRouiCjpa9ALauSMzT84F46gilrYGxb++H8a3Ez0iTgTfBDoZ6csW5aw+msdwnifA==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>';
        $dropdown .= '<script src="'.$pluginpath.'/includes/axios.min.js"></script>';
        $dropdown .= '<script src="'.$pluginpath.'/includes/moment-with-locales.min.js"></script>';
        $dropdown .= '<script> var pageLang = "'.C4::Languages::getlanguage( $self->{'cgi'} ).'"; </script>';
        $dropdown .= '<script type="module" src="'.$pluginpath.'/js/app.js"></script>';
    }
    return $dropdown;
}

## If your plugin needs to add some javascript in the staff intranet, you'll want
## to return that javascript here. Don't forget to wrap your javascript in
## <script> tags. By not adding them automatically for you, you'll have a
## chance to include other javascript files if necessary.
sub intranet_js {
    my ( $self ) = @_;

    my $pluginpath = $self->get_plugin_http_path();
    my $scripts = '<script src="'.$pluginpath.'/js/restore.js"></script>';
    return $scripts;
}

## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
sub install() {
    my ( $self, $args ) = @_;

    $self->create_log_table();
    $self->create_active_records_table();
    $self->create_queue_table();
    $self->create_users_table();
    $self->create_secret();
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

    # my $dbh = C4::Context->dbh;

    # my $log_table = $self->{logTable};
    # C4::Context->dbh->do("DROP TABLE $log_table");

    return 1;
}

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_dir = $self->mbf_dir();
    my $spec_file = $spec_dir . '/openapi.yaml';

    my $schema = JSON::Validator::Schema::OpenAPIv2->new;
    $schema->resolve( $spec_file );

    return $schema->bundle->data;
}

sub api_namespace {
    my ( $self ) = @_;
    
    return 'kohasuomi';
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
        log_table => $self->{logTable},
        start_time => $self->{start_time},
        blocked_encoding_level => $self->{blocked_encoding_level},
        block_component_parts => $self->{block_component_parts},
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

sub fetch_broadcast {
    my ( $self ) = @_;

    my $broadcast = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Broadcast->new({
        all => $self->{all},
        verbose => $self->{verbose},
        blocked_encoding_level => $self->{blocked_encoding_level},
        block_component_parts => $self->{block_component_parts},
    });

    my $params = {
        chunks => $self->{chunks},
        biblionumber => $self->{biblionumber},
        limit => $self->{limit},
        page => $self->{page},
        timestamp => undef
    };

    $broadcast->fetchBroadcastBiblios($params);

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
        endpoint => $self->{endpoint},
        headers => $self->{headers},
        database => $self->{database}
    };
    if ($self->{all}) {
        $activeRecords->getAllActiveRecords($params);
    } else {
        $activeRecords->getActiveRecordsByBiblionumber($params);
    }

}

sub set_active {
    my ( $self ) = @_;

    my $params = {
        chunks => $self->{chunks},
        biblionumber => $self->{biblionumber},
        limit => $self->{limit},
        page => $self->{page},
        all => $self->{all},
        verbose => $self->{verbose},
        config => $self->{config},
    };

    my $activeRecords = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords->new($params);
    $activeRecords->setActiveRecords();

}

sub build_oai {
    my ( $self ) = @_;

    my $params = {
        verbose => $self->{verbose},
        date => $self->{date},
        set_spec => $self->{set_spec},
        set_name => $self->{set_name},
        no_components => $self->{no_components},
        hosts_with_components => $self->{hosts_with_components},
    };

    my $oai = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::OAI->new($params);
    $oai->buildOAI();

}

sub update_active {
    my ( $self ) = @_;

    my $params = {
        verbose => $self->{verbose},
        page => $self->{page},
        limit => $self->{limit},
        chunks => $self->{chunks},
        config => $self->{config}
    };

    my $activeRecords = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords->new($params);
    $activeRecords->processNewActiveRecords();
}

sub process_queue {
    my ( $self ) = @_;
    my $params = {
        verbose => $self->{verbose},
        type => $self->{type},
        update => $self->{update},
    };

    my $queue = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastQueue->new($params);
    $queue->processQueue();
}

sub create_secret {
    my ( $self ) = @_;

    my $old_secret = $self->retrieve_data('secret');
    if ($old_secret) {
        warn "Secret already exists";
        return;
    }
    my $secret = uuid();
    $self->store_data({secret => $secret});
}

sub create_log_table {
    my ( $self ) = @_;

    my $dbh = C4::Context->dbh;
    my $log_table = $self->get_qualified_table_name('log');
    $dbh->do("CREATE TABLE IF NOT EXISTS `$log_table` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `biblionumber` int(11) NOT NULL,
        `type` ENUM('export','import') DEFAULT 'import',
        `updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `type` (`type`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");
}

sub create_active_records_table {
    my ( $self ) = @_;

    my $dbh = C4::Context->dbh;
    my $activerecords_table = $self->get_qualified_table_name('activerecords');
    $dbh->do("CREATE TABLE IF NOT EXISTS `$activerecords_table` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `biblionumber` int(11) NOT NULL,
        `remote_biblionumber` int(11) DEFAULT NULL,
        `identifier_field` varchar(255) NOT NULL,
        `identifier` varchar(255) NOT NULL,
        `blocked` tinyint(1) NOT NULL DEFAULT 0,
        `updated_on` datetime DEFAULT NULL,
        `created_on` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        FOREIGN KEY (`biblionumber`) REFERENCES `biblio_metadata` (`biblionumber`) ON DELETE CASCADE,
        UNIQUE INDEX(biblionumber, identifier_field, identifier)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");
}

sub create_queue_table {
    my ( $self ) = @_;

    my $dbh = C4::Context->dbh;
    my $table = $self->get_qualified_table_name('queue');
    $dbh->do("CREATE TABLE IF NOT EXISTS `$table` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `user_id` int(11) NOT NULL,
        `type` ENUM('export','import') DEFAULT 'import',
        `broadcast_interface` varchar(30) NOT NULL,
        `biblio_id` int(11) DEFAULT NULL,
        `status` ENUM('pending','processing','completed','failed') DEFAULT 'pending',
        `statusmessage` varchar(255) DEFAULT NULL,
        `broadcast_biblio_id` varchar(50) DEFAULT NULL,
        `hostrecord` tinyint(1) NOT NULL DEFAULT 0,
        `componentparts` longtext DEFAULT NULL,
        `marc` longtext NOT NULL,
        `diff` longtext DEFAULT NULL,
        `transfered_on` datetime DEFAULT NULL,
        `created_on` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `user_id` (`user_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");
}

sub create_users_table {
    my ( $self ) = @_;

    my $dbh = C4::Context->dbh;
    my $table = $self->get_qualified_table_name('users');
    $dbh->do("CREATE TABLE IF NOT EXISTS `$table` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `auth_type` ENUM('basic', 'oauth') DEFAULT 'basic',
        `broadcast_interface` varchar(30) NOT NULL,
        `username` varchar(50) DEFAULT NULL,
        `password` varchar(255) DEFAULT NULL,
        `client_id` varchar(50) DEFAULT NULL,
        `client_secret` varchar(50) DEFAULT NULL,
        `access_token` varchar(100) DEFAULT NULL,
        `token_expires` int(11) DEFAULT NULL,
        `access_token_url` varchar(255) DEFAULT NULL,
        `grant_type` varchar(50) DEFAULT 'client_credentials',
        `linked_borrowernumber` int(11) DEFAULT NULL,
        `created_on` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `linked_borrowernumber` (`linked_borrowernumber`),
        CONSTRAINT `interface_username` UNIQUE (`broadcast_interface`, `username`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");
}

sub upgrade_db {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;
    my $log_table = $self->get_qualified_table_name('log');
    my $activerecords_table = $self->get_qualified_table_name('activerecords');
    my $queue_table = $self->get_qualified_table_name('queue');
    my $users_table = $self->get_qualified_table_name('users');

    if ($VERSION eq "2.5.0") {
        $dbh->do("ALTER TABLE `$log_table` ADD `type` ENUM('export','import') DEFAULT 'import' AFTER `biblionumber`");
    }

    if ($VERSION eq "2.5.1") {
        $dbh->do("ALTER TABLE `$log_table` MODIFY `type` ENUM('export','import','old') DEFAULT 'import'");
    }

    if ($VERSION eq "2.5.2") {
        $dbh->do("ALTER TABLE `$queue_table` MODIFY `broadcast_biblio_id` varchar(50) DEFAULT NULL");
        $dbh->do("ALTER TABLE `$users_table` MODIFY `password` varchar(255) DEFAULT NULL");
    }
}

1;

