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
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastLog;
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
    return strftime "%Y-%m-%d 07:00:00", localtime;
}

sub getStartTime {
    my ($self) = @_;
    return 8;
}

sub getUpdateTime {
    my ($self, $updated) = @_; 

    return $self->getTimestamp() unless $updated;

    if ($updated lt strftime "%Y-%m-%d", localtime) {
        return $self->getTimestamp();
    } else {
        return $updated;
    }
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

sub getBiblios {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new();
}

sub broadcastLog {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastLog->new();
}

sub processNewActiveRecords {
    my ($self) = @_;
    my $activerecords = $self->db->getPendingActiveRecords();
    foreach my $activerecord (@$activerecords) {
        $self->processAddedActiveRecord($activerecord);
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
    my $latest = $self->broadcastLog()->getBroadcastLogLatestImport();
    my $timestamp = $self->getUpdateTime($latest->{updated});
    $params->{skipRecords} = $params->{all} ? 0 : 1;
    $params->{timestamp} = $timestamp if !$params->{all};
    while ($pageCount >= $params->{page}) {
        my $newbiblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new($params);
        my $biblios = $newbiblios->fetch();
        my $count = 0;
        foreach my $biblio (@{$biblios}) {
            if ($self->verbose) {
                print "Processing biblio ".$biblio->{biblionumber}."\n";
            }
            $count++;
            $self->broadcastLog()->setBroadcastLog($biblio->{biblionumber}, $biblio->{timestamp}, 'import') if !$params->{all};
            if ($biblio->{skip}) {
                print "Biblio ".$biblio->{biblionumber}." skipped!\n" if $self->verbose;
                next;
            }
            my $response = $self->setActiveRecord($biblio);
            unless ($response->{status} eq '201' || $response->{status} eq '200') {
                print "Error while processing biblio ".$biblio->{biblionumber}." with message: ".$response->{message}."\n";
            } else {
                print "Biblio ".$biblio->{biblionumber}." processed with: ".$response->{message}."\n" if $self->verbose;
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

sub setActiveRecord {
    my ($self, $biblio) = @_;
    my $params = $self->getParams();
    try {
        my $record = $self->getRecord($biblio->{metadata});
        return {status => 404, message => "Not found"} unless $record;
        return {status => 403, message => "Not a host record"} if $self->getBiblios->checkComponentPart($record);
        #return {status => 409, message => "Field 005 timestamp does not match with table timestamp"} if $self->getBiblios->diff005toTimestamp($record, $biblio->{timestamp}) && !$params->{all};
        my $activerecord = $self->getActiveRecordByBiblionumber($biblio->{biblionumber});
        if ($activerecord) {
            # Update active record identifiers if changed
            my ($identifier, $identifier_field) = $self->getIdentifiers->getIdentifierField($biblio->{metadata});
            if ($activerecord->{identifier} ne $identifier) {
                print "Updating active record identifiers for biblionumber: ".$activerecord->{biblionumber}."\n" if $self->verbose;
                $self->db->updateActiveRecordIdentifiers($activerecord->{id}, $identifier, $identifier_field);
            }
            # Update active record blocked status if changed
            my $record_block = $self->getBiblios()->checkBlock($record);
            if ($record_block) {
                $activerecord->{blocked} = $record_block;
                $self->db->updateActiveRecordBlocked($activerecord->{id}, $activerecord->{blocked});
            }
            if ($self->getConfig) {
                $self->processAddedActiveRecord($activerecord);
            }
            return {status => 200, message => "Already exists"};
        };
        my ($identifier, $identifier_field) = $self->getIdentifiers->getIdentifierField($biblio->{metadata});
        return {status => 400, message => "No valid identifiers"} unless $identifier && $identifier_field;
        my $update_on = $params->{all} ? $biblio->{timestamp} : undef;
        my $blocked = $self->getBiblios->checkBlock($record);
        my $activerecord_id = $self->db->insertActiveRecord($biblio->{biblionumber}, $identifier, $identifier_field, $update_on, $blocked);
        if ($self->getConfig) {
            $self->processAddedActiveRecord($self->db->getActiveRecordById($activerecord_id));
        }
        return {status => 201, message => "Success"};
    } catch {
        my $error = $_;
        return {status => 500, message => $error};
    }

}

sub processAddedActiveRecord {
    my ($self, $activerecord) = @_;

    $self->db->activeRecordUpdated($activerecord->{id});
    
    if ($activerecord->{blocked}) {
        print "Active record biblionumber: ".$activerecord->{biblionumber}." is blocked \n" if $self->verbose;
        return;
    }

    my @identifiers = $self->getIdentifiers->fetchIdentifiers($activerecord->{metadata});
    my $ua = Mojo::UserAgent->new;
    my $tx = $ua->post($self->getConfig->{restUrl}."/api/v1/contrib/kohasuomi/broadcast/biblios", {'Content-Type' => 'application/json'}, json => {identifiers => @identifiers, biblio_id => $activerecord->{remote_biblionumber}});
    if ($tx->res->code eq '200' || $tx->res->code eq '201') {
        $self->db->updateActiveRecordRemoteBiblionumber($activerecord->{id}, $tx->res->json->{biblionumber});
        my $queue = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastQueue->new({verbose => $self->verbose, broadcast_interface => $self->getConfig->{name}, user_id => $self->getConfig->{defaultUser}, type => 'import'});
        my $response = $queue->setToQueue($activerecord, $tx->res->json);
        print "Active record biblionumber: ".$activerecord->{biblionumber}." set to queue with message: ".$response->{message}."\n" if $self->verbose;
        $self->db->activeRecordUpdated($activerecord->{id});
    } else {
        my $error = $tx->res->json || $tx->error;
        my $errormessage = $error->{error} || $error->{message};
        print "REST error for active record biblionumber: ".$activerecord->{biblionumber}." with code ".$tx->res->code." and message: ".$errormessage."\n";
    }
}
# Deprecated
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
            next if $self->getBiblios->checkComponentPart(MARC::Record::new_from_xml($biblio->{metadata}, 'UTF-8'));
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
# Deprecated
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

sub activated {
    my ($self, $endpoint, $headers, $interface, $target_id) = @_;

    my $ua = Mojo::UserAgent->new;
    my $tx = $ua->get($endpoint."/".$interface."/".$target_id => $headers);
    return 0 unless $tx->res->code eq '200' || $tx->res->code eq '201';
    return 1;
}

1;