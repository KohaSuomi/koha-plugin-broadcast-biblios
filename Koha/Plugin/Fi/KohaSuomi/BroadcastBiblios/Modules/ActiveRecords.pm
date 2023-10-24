package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords;

# Copyright 2021 Koha-Suomi Oy
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
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
use Carp;
use Scalar::Util qw( blessed );
use Try::Tiny;
use POSIX 'strftime';
use Koha::DateUtils qw( dt_from_string );
use File::Basename;
use MARC::Record;
use MARC::File::XML;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Database;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::Identifiers;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Users;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastQueue;
use Mojo::UserAgent;
use JSON;
use Koha::Logger;

=head new

    my $activeRecords = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords->new($params);

=cut

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;

}

sub verbose {
    return shift->{_params}->{verbose};
}

sub getTimestamp {
    return strftime "%Y-%m-%d %H:%M:%S", ( localtime(time - 5*60) );
}

sub getConfig {
    shift->{_params}->{config};
}

sub getParams {
    my ($self) = @_;
    my $params = $self->{_params};
    unless ($params->{all}) {
        $params->{timestamp} = $self->getTimestamp();
    }
    return shift->{_params};
}

sub getLogger {
    my ($self) = @_;
    return Koha::Logger->get( {interface => "broadcast"});
}

sub db {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Database->new;
}

sub getUsers {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Users->new;
}

sub getIdentifiers {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::Identifiers->new;
}

sub getRecord {
    my ($self, $marcxml) = @_;

    my $biblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new();
    return $biblios->getRecord($marcxml);
}

sub processNewActiveRecords {
    my ($self) = @_;
    my $activerecords = $self->db->getPendingActiveRecords();
    foreach my $activerecord (@$activerecords) {
        my @identifiers = $self->getIdentifiers->fetchIdentifiers($activerecord->{metadata});
        my $ua = Mojo::UserAgent->new;
        my $tx = $ua->post($self->getConfig->{rest}->{baseUrl}."/broadcast/biblios", {'Content-Type' => 'application/json'}, json => {identifiers => @identifiers, biblio_id => $activerecord->{remote_biblionumber}});
        if ($tx->res->code eq '200' || $tx->res->code eq '201') {
            $self->db->updateActiveRecordRemoteBiblionumber($activerecord->{id}, $tx->res->json->{biblio}->{biblionumber});
            my $queue = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastQueue->new({broadcast_interface => $self->getConfig->{interface_name}, user_id => $self->getConfig->{user_id}, type => 'import'});
            $queue->setToQueue($activerecord, $tx->res->json);
            $self->activeRecordUpdated($activerecord->{id});
        } else {
            my $error = $tx->res->json;
            $self->getLogger->error("REST error for active record id: ".$activerecord->{id}." with code ".$tx->res->code." and message: ".$error->{error}."\n");
        }
    }
}

sub activeRecordUpdated {
    my ($self, $id) = @_;
    $self->db->activeRecordUpdated($id);
}

sub activeRecordUpdatedByBiblionumber {
    my ($self, $biblionumber) = @_;
    my $activerecord = $self->getActiveRecordByBiblionumber($biblionumber);
    $self->activeRecordUpdated($activerecord->{id});
}

sub getActiveRecordByIdentifier {
    my ($self, $identifier, $identifier_field) = @_;
    return $self->db->getActiveRecordByIdentifier($identifier, $identifier_field);
}

sub getActiveRecordByBiblionumber {
    my ($self, $biblionumber) = @_;
    return $self->db->getActiveRecordByBiblionumber($biblionumber);
}

sub updateActiveRecord {
    my ($self, $id, $params) = @_;
    return $self->db->updateActiveRecord($id, $params);
}

sub setActiveRecords {
    my ($self) = @_;
    my $params = $self->getParams();
    my $pageCount = 1;
    while ($pageCount >= $params->{page}) {
        my $newbiblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new($params);
        my $biblios = $newbiblios->fetch();
        my $count = 0;
        foreach my $biblio (@{$biblios}) {
            if ($self->verbose) {
                print "Processing biblio ".$biblio->{biblionumber}."\n";
            }
            $count++;
            try {
                my $record = $self->getRecord($biblio->{metadata});
                return unless $record;
                return if $self->getActiveRecordByBiblionumber($biblio->{biblionumber});
                return if $self->checkComponentPart($record);
                my ($identifier, $identifier_field) = $self->getIdentifiers->getIdentifierField($biblio->{metadata});
                return unless $identifier && $identifier_field;
                my $update_on = $params->{all} ? $biblio->{timestamp} : undef;
                my $activerecord_id = $self->db->insertActiveRecord($biblio->{biblionumber}, $identifier, $identifier_field, $update_on);
                if ($self->getConfig) {
                    $self->processAddedActiveRecord($self->db->getActiveRecordById($activerecord_id));
                }
            } catch {
                print "Error while processing record ".$biblio->{biblionumber}.", check the logs!\n";
                $self->getLogger->error("Error while processing record ".$biblio->{biblionumber}." with error: ".$@."\n");
            }
        }
        print "$count biblios processed!\n";
        if ($count eq $params->{chunks}) {
            $pageCount++;
            $params->{page} = $pageCount;
        } else {
            $pageCount = 0;
        }
    }

}

sub processAddedActiveRecord {
    my ($self, $activerecord) = @_;
    my @identifiers = $self->getIdentifiers->fetchIdentifiers($activerecord->{metadata});
    my $ua = Mojo::UserAgent->new;
    my $tx = $ua->post($self->getConfig->{rest}->{baseUrl}."/broadcast/biblios", {'Content-Type' => 'application/json'}, json => {identifiers => @identifiers, biblio_id => $activerecord->{remote_biblionumber}});
    if ($tx->res->code eq '200' || $tx->res->code eq '201') {
        $self->db->updateActiveRecordRemoteBiblionumber($activerecord->{id}, $tx->res->json->{biblio}->{biblionumber});
        my $queue = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastQueue->new({broadcast_interface => $self->getConfig->{interface_name}, user_id => $self->getConfig->{user_id}, type => 'import'});
        $queue->setToQueue($activerecord, $tx->res->json);
        $self->db->activeRecordUpdated($activerecord->{id});
        $self->getLogger->info("Active record id:".$activerecord->{id}." update added to queue \n");
    } else {
        my $error = $tx->res->json;
        $self->getLogger->error("REST error for active record id: ".$activerecord->{id}." with code ".$tx->res->code." and message: ".$error->{error}."\n");
    }
}

sub getActiveRecordsByBiblionumber {
    my ($self, $params) = @_;
    my $pageCount = 1;
    my $interface = $params->{interface};
    my $sqlFile = $params->{directory}."/activeRecordsPatch".$interface.".sql";
    open(my $efh, '>', $sqlFile);
    print $efh "";
    close $efh;
    while ($pageCount >= $params->{page}) {
        my $newbiblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new($params);
        my $biblios = $newbiblios->fetch();
        my $count = 0;
        foreach my $biblio (@{$biblios}) {
            $count++;
            next if $self->checkComponentPart(MARC::Record::new_from_xml($biblio->{metadata}, 'UTF-8'));
            my ($identifier, $identifier_field) = $self->getIdentifiers->getIdentifierField($biblio->{metadata});
            my $target_id = $biblio->{biblionumber};
            my $updated = $biblio->{timestamp};
            if (!$self->activated($params->{endpoint}, $params->{headers}, $interface, $target_id) && $identifier && $identifier_field) {
                my $sqlstring = "INSERT INTO ".$params->{database}.".activerecords (interface_name, identifier_field, identifier, target_id, updated) VALUES ('$interface', '$identifier_field', '$identifier', '$target_id', '$updated');";   
                open(my$fh, '>>', $sqlFile);
                print $fh $sqlstring."\n";
                close $fh;
            }
        }
        print "$count biblios processed!\n";
        if ($count eq $params->{chunks}) {
            $pageCount++;
            $params->{page} = $pageCount;
        } else {
            $pageCount = 0;
        }
    }
}

sub getAllActiveRecords {
    my ($self, $params) = @_;
    my $pageCount = 1;
    my $interface = $params->{interface};
    my $sqlFile = $params->{directory}."/activeRecordsPatch".$interface.".sql";
    open(my $efh, '>', $sqlFile);
    print $efh "";
    close $efh;
    while ($pageCount >= $params->{page}) {
        my $newbiblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new($params);
        my $biblios = $newbiblios->fetch();
        my $count = 0;
        foreach my $biblio (@{$biblios}) {
            my ($identifier, $identifier_field) = $self->getIdentifiers->getIdentifierField($biblio->{metadata});
            my $target_id = $biblio->{biblionumber};
            my $updated = $biblio->{timestamp};
            if ($identifier && $identifier_field) {
                my $sqlstring = "INSERT INTO ".$params->{database}.".activerecords (interface_name, identifier_field, identifier, target_id, updated) VALUES ('$interface', '$identifier_field', '$identifier', '$target_id', '$updated');";   
                open(my$fh, '>>', $sqlFile);
                print $fh $sqlstring."\n";
                close $fh;
            }
            
            $count++;
        }
        print "$count biblios processed!\n";
        if ($count eq $params->{chunks}) {
            $pageCount++;
            $params->{page} = $pageCount;
        } else {
            $pageCount = 0;
        }
    }
}

sub checkBlock {
    my ($self, $biblio) = @_;
    my $record = MARC::Record::new_from_xml($biblio->{metadata}, 'UTF-8');
    return $record->subfield('942', "b");
}

sub checkEncodingLevel {
    my ($self, $record) = @_;

    my $encoding_level = substr( $record->leader(), 17 , 1 );
    return $encoding_level;
}

sub checkComponentPart {
    my ($self, $record) = @_;
    return 1 if $record->subfield('773', "w");
    return 0;
}

sub activated {
    my ($self, $endpoint, $headers, $interface, $target_id) = @_;

    my $ua = Mojo::UserAgent->new;
    my $tx = $ua->get($endpoint."/".$interface."/".$target_id => $headers);
    return 0 unless $tx->res->code eq '200' || $tx->res->code eq '201';
    return 1;
}


1;