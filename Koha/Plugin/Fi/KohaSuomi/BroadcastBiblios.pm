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

use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Broadcast;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastQueue;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::OAI;

## Here we set our plugin version
our $VERSION = "2.5.0";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Tietuesiirtäjä',
    author          => 'Johanna Räisä',
    date_authored   => '2021-09-09',
    date_updated    => '2023-10-20',
    minimum_version => '21.11.00.0000',
    maximum_version => '',
    version         => $VERSION,
    description     => 'Tietueiden lähetys ja vastaanotto Kohassa',
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
    my $exportapis = YAML::XS::Load(Encode::encode_utf8($self->retrieve_data('exportapis')));
    my $importapi = YAML::XS::Load(Encode::encode_utf8($self->retrieve_data('importapi')));
    my $importinterface = $self->retrieve_data('importinterface');
    my $dropdown;
    if ($exportapis && $importapi && haspermission(C4::Context->userenv->{'id'}, {'editcatalogue' => 'edit_catalogue'})) {
        my $pluginpath = $self->get_plugin_http_path();
        $dropdown = '<div id="pushApp">
            <div class="btn-group" style="margin-left: 5px;">
            <button class="btn btn-default dropdown-toggle" data-toggle="dropdown"><i class="fa fa-upload"></i> Vie/Tuo <span class="caret"></span></button>
            <ul id="pushInterfaces" class="dropdown-menu">';
        foreach my $api (@{$exportapis}) {
            $dropdown .= '<li><a href="#" @click="openModal($event)"
            data-host="'.$api->{host}.'" 
            data-basepath="'.$api->{basePath}.'" 
            data-searchpath="'.$api->{searchPath}.'"
            data-reportpath="'.$api->{reportPath}.'"
            data-token="'.Digest::SHA::hmac_sha256_hex($api->{apiToken}).'"
            data-type="'.$api->{type}.'"
            data-interface="'.$api->{interface}.'"
            data-toggle="modal" data-target="#pushRecordOpModal">'.$api->{interfaceName}.'</a></li>';
        }
        $dropdown .= '<li><a href="#" id="importInterface" class="import hidden"
            data-host="'.$importapi->{host}.'" 
            data-basepath="'.$importapi->{basePath}.'" 
            data-searchpath="'.$importapi->{searchPath}.'"
            data-reportpath="'.$importapi->{reportPath}.'"
            data-activation="'.$importapi->{activation}.'"
            data-token="'.Digest::SHA::hmac_sha256_hex($importapi->{apiToken}).'"
            data-type="'.$importapi->{type}.'">'.$importapi->{interface}.'</a></li>';
        $dropdown .= '</ul></div>';
        if ($importinterface) {
            $dropdown .= '<div class="btn-group"><input type="hidden" id="importBroadcastInterface" value="'.$importinterface.'" /><i v-if="loader" class="fa fa-spinner fa-spin" style="font-size:14px; margin-left: 10px; margin-top: 10px;"></i><span v-if="activated" style="margin-left: 10px;"><i class="fa fa-link text-success" style="font-size:18px; margin-top:7px;" :title="activated"></i></span></div><div v-if="active" class="btn-group" style="margin-left: 5px;"><button class="btn btn-default" @click="activateRecord()"><i class="fa fa-refresh"></i> Aktivoi tietue</button></div>';
        }
        $dropdown .= '<div><input type="hidden" id="biblioId" value="'.$biblionumber.'" /></div>';
        $dropdown .= '<recordmodal></recordmodal>';
        $dropdown .= '<script src="'.$pluginpath.'/includes/vue.min.js"></script>';
        $dropdown .= '<script src="'.$pluginpath.'/includes/vuex.min.js"></script>';
        $dropdown .= '<script src="'.$pluginpath.'/includes/axios.min.js"></script>';
        $dropdown .= '<script src="'.$pluginpath.'/includes/moment-with-locales.min.js"></script>';
        $dropdown .= '<script src="'.$pluginpath.'/js/push.js"></script></div>';
    }
    return $dropdown;
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

    my $spec_str = $self->mbf_read('openapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
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
        config => $self->{config},
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
    };

    my $queue = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastQueue->new($params);
    $queue->processQueue();
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
        `broadcast_biblio_id` int(11) NOT NULL,
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
        `password` varchar(50) DEFAULT NULL,
        `client_id` varchar(50) DEFAULT NULL,
        `client_secret` varchar(50) DEFAULT NULL,
        `access_token` varchar(100) DEFAULT NULL,
        `token_expires` int(11) DEFAULT NULL,
        `access_token_url` varchar(255) DEFAULT NULL,
        `grant_type` varchar(50) DEFAULT 'client_credentials',
        `linked_borrowernumber` int(11) DEFAULT NULL,
        `created_on` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `linked_borrowernumber` (`linked_borrowernumber`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");
}

1;

