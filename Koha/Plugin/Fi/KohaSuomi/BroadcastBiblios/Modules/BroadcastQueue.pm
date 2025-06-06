package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastQueue;

# Copyright 2023 Koha-Suomi Oy
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
use utf8;
use Carp;
use Scalar::Util qw( blessed );
use Try::Tiny;
use Koha::DateUtils qw( dt_from_string );
use C4::Context;
use POSIX qw(strftime);
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Database;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Search;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::CompareRecords;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MarcXMLToJSON;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MarcJSONToXML;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ComponentParts;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::REST;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MergeRecords;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::Identifiers;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Melinda;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler;
use JSON;
use Encode;
use C4::Biblio qw( AddBiblio ModBiblio GetFrameworkCode);
use MARC::Field;

=head new

    my $broadcastLog = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastQueue->new($params);

=cut

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;

}

sub verbose {
    my ($self) = @_;
    return $self->{_params}->{verbose};
}

sub getBroadcastInterface {
    shift->{_params}->{broadcast_interface};
}

sub getUserId {
    shift->{_params}->{user_id};
}

sub getType {
    shift->{_params}->{type};
}

sub updateRecord {
    shift->{_params}->{update};
}

sub db {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Database->new;
}

sub user {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::User->new;
}

sub compareRecords {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::CompareRecords->new;
}

sub getMarcXMLToJSON {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MarcXMLToJSON->new;
}

sub getMarcJSONToXML {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MarcJSONToXML->new;
}

sub getComponentParts {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ComponentParts->new;
}

sub getActiveRecords {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords->new;
}

sub mergeRecords {
    my ($self, $interface) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MergeRecords->new({interface => $interface, verbose => $self->verbose});
}

sub getIdentifier {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::Identifiers->new;
}

sub getRecord {
    my ($self, $marcxml) = @_;
    my $biblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new();
    return $biblios->getRecord($marcxml);
}

sub getDiff {
    my ($self, $localmarcxml, $broadcastmarcxml) = @_;
    return $self->compareRecords->getDiff($self->getMarcXMLToJSON->toJSON($localmarcxml), $self->getMarcXMLToJSON->toJSON($broadcastmarcxml));
}

sub ua {
    my ($self) = @_;
    return Mojo::UserAgent->new;
}

sub transferRecord {
    my ($self, $biblio_id, $broadcast_biblio_id, $marcxml, $componentparts) = @_;
    my $queueStatus = $self->db->getQueuedRecordByBiblioId($biblio_id, $self->getType);
    if ($queueStatus && ($queueStatus->{status} eq 'pending' || $queueStatus->{status} eq 'processing')) {
        print "Record ".$biblio_id." is already in queue\n" if $self->verbose;
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 409, {message => "Record ".$biblio_id." is already in queue"});
    };
    try {
        my $record = $self->getRecord($marcxml);
        if ($record) {
            my $parts;
            if ($componentparts) {
                foreach my $part (@$componentparts) {
                    my $marc = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MarcJSONToXML->new({marcjson => $part->{marcjson}});
                    push @$parts, {
                        biblionumber => $part->{biblionumber},
                        marcxml => Encode::decode_utf8($marc->toXML()),
                    };
                }
            }

            my $diff;
            if ($self->getType eq 'import') {
                my $localrecord = Koha::Biblios->find($biblio_id);
                $diff = $self->getDiff($localrecord->metadata->metadata, $marcxml);
            }

            $self->db->insertToQueue({
                broadcast_interface => $self->getBroadcastInterface,
                user_id => $self->getUserId,
                type => $self->getType,
                broadcast_biblio_id => $broadcast_biblio_id,
                biblio_id => $biblio_id,
                marc => $marcxml,
                componentparts => $parts ? to_json($parts) : undef,
                diff => $diff ? $diff : undef,
                hostrecord => $parts ? 1 : 0,
            });
        } else {
            Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 500, {message => "Failed to transfer the record"});
        }
    } catch {
        my $exception = $_;
        print "Error while importing record $biblio_id: $exception\n";
    }
}

sub pushToRest {
    my ($self, $config, $activerecord, $broadcastrecord) = @_;
    my $users = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Users->new({config => $config, endpoint => '/api/v1/contrib/kohasuomi/broadcast/queue'});
    my ($path, $headers) = $users->getAuthentication($self->getUserId);
    my $tx = $self->ua->post($path => $headers => json => {
        active_biblio => $activerecord,
        broadcast_biblio => $broadcastrecord,
        broadcast_interface => $self->getBroadcastInterface,
        user_id => $self->getUserId,
        type => $self->getType,
    });

    if ($tx->res->code eq '200' || $tx->res->code eq '201' || $tx->res->code eq '204') {
        my $response = $tx->res->json;
        print "Pushed record ".$broadcastrecord->{biblionumber}." to ".$config->{name}." with response: ". $response->{message}."\n";
    } else {
        my $error = $tx->res->json || $tx->res->error;
        my $errormessage = $error->{message} if $error->{message};
        $errormessage = $error->{error} if $error->{error};
        print "Failed to push record ".$broadcastrecord->{biblionumber}." to ".$config->{name}.": ".$errormessage."\n";
    }
}

sub setToQueue {
    my ($self, $activerecord, $broadcastrecord) = @_;

    my $queueStatus = $self->db->getQueuedRecordByBiblioId($activerecord->{biblionumber}, $self->getType);
    if ($queueStatus && ($queueStatus->{status} eq 'pending' || $queueStatus->{status} eq 'processing')) {
        print "Broadcast record ".$broadcastrecord->{biblionumber}." is already in queue\n" if $self->verbose;
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 409, {message => "Broadcast record ".$broadcastrecord->{biblionumber}." is already in queue"});
    };
    try {
        my $return = {status => 201, message => "Success"};
        my $encodingLevel = $self->compareEncodingLevels($activerecord->{metadata}, $broadcastrecord->{marcxml});
        if ($encodingLevel eq 'lower') {
            $self->db->insertToQueue($self->processParams($activerecord, $broadcastrecord));
        } elsif ($encodingLevel eq 'equal') {
            my $timestamp = $self->compareTimestamps($activerecord->{metadata}, $broadcastrecord->{marcxml});
            if ($timestamp) {
                $self->db->insertToQueue($self->processParams($activerecord, $broadcastrecord));
            } elsif (!$timestamp && $broadcastrecord->{componentparts}) {
                # If broadcast record has component parts, then we need to check if local record has component parts
                $self->processNewComponentPartsToQueue($activerecord->{biblionumber}, $broadcastrecord->{componentparts});
                $return = {status => 200, message => "Equal encoding level and timestamp, checking component parts"};
            } else {
                print "Local record ".$activerecord->{biblionumber}." has equal encoding level and greater timestamp than broadcast record ".$broadcastrecord->{biblionumber}."\n" if $self->verbose;
                $return = {status => 204, message => "Local record ".$activerecord->{biblionumber}." has equal encoding level and greater timestamp than broadcast record ".$broadcastrecord->{biblionumber}};
            }
        } else {
            if ($broadcastrecord->{componentparts}) {
                # If broadcast record has component parts, then we need to check if local record has component parts
                $self->processNewComponentPartsToQueue($activerecord->{biblionumber}, $broadcastrecord->{componentparts});
                $return = {status => 200, message => "Local record ".$activerecord->{biblionumber}." has greater encoding level, checking component parts"};
            } else {
                print "Local record ".$activerecord->{biblionumber}." has greater encoding level than broadcast record ".$broadcastrecord->{biblionumber}."\n" if $self->verbose;
                $return = {status => 204, message => "Local record ".$activerecord->{biblionumber}." has greater encoding level than broadcast record ".$broadcastrecord->{biblionumber}};
            }
        }
        return $return;
    } catch {
        my $error = $_;
        print "Error while setting record ".$broadcastrecord->{biblionumber}." to queue: $error\n";
    }
}

sub getQueue {
    my ($self, $status, $biblio_id, $page, $limit) = @_;
    my $results = $self->db->getQueue($status, $biblio_id, $page, $limit);
    my $res;
    foreach my $result (@$results) {
        my $diff = $result->{diff} ? from_json($result->{diff}) : undef;
        my $parts;
        my $componentparts = $result->{componentparts};
        $componentparts = eval { from_json($componentparts) } if $componentparts;
        foreach my $part (@$componentparts) {
            push @$parts, {
                biblionumber => $part->{biblionumber},
                marcjson => $self->getMarcXMLToJSON->toJSON($part->{marcxml}),
            };
        }
        push @$res, {
            id => $result->{id},
            broadcast_interface => $result->{broadcast_interface},
            type => $result->{type},
            biblio_id => $result->{biblio_id},
            itemtype => $self->getBiblioItemType($result->{biblio_id}),
            marcjson => $self->getMarcXMLToJSON->toJSON($result->{marc}),
            componentparts => $self->getComponentParts->sortComponentParts($parts),
            status => $result->{status},
            statusmessage => $result->{statusmessage} ? $result->{statusmessage} : undef,
            diff => $diff,
            transfered_on => $result->{transfered_on},
            created_on => $result->{created_on},
        };
    }
    my $count = $self->db->countQueue($status, $biblio_id);
    return {results => $res, count => $count};
}

sub checkBiblionumberQueueStatus {
    my ($self, $biblionumber) = @_;
    my $queue = $self->db->getQueuedRecordByBiblionumber($biblionumber, $self->getType);
    return $queue->{status};
}

sub processQueue {
    my ($self) = @_;

    if ($self->getType eq "export") {
        $self->processExportQueue;
    } elsif ($self->getType eq "import") {
        $self->processImportQueue;
    } else {
        print "Starting to process export queue\n" if $self->verbose;
        $self->processExportQueue;
        print "Starting to process import queue\n" if $self->verbose;
        $self->processImportQueue;
    }
}

sub processImportQueue {
    my ($self) = @_;
    my $queue = $self->db->getPendingQueue('import');
    foreach my $queue (@$queue) {
        $self->db->updateQueueStatus($queue->{id}, 'processing', undef);
        my $biblio_id = $queue->{biblio_id};
        my $frameworkcode = GetFrameworkCode( $biblio_id );
        try {
            my $record = $self->getRecord($queue->{marc});

            if ($record) {
                my $mergedrecord = $self->mergeRecords()->merge($record, undef);
                if ($biblio_id) {
                    unless (Koha::Biblios->find($biblio_id)) {
                        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 404, {message => "Biblio record not found"});
                    }
                    my $f942 = $self->get942Field($biblio_id);
                    if ($queue->{hostrecord} || $queue->{componentparts}) {
                        $self->processImportComponentParts($biblio_id, from_json($queue->{componentparts}));
                    }
                    $mergedrecord = $self->add942ToBiblio($mergedrecord, $f942);
                    my $success = &ModBiblio($mergedrecord, $biblio_id, $frameworkcode, {
                                overlay_context => {
                                    source       => 'z3950'
                                }
                            });
                    if ($success) {
                        print "Updated record $biblio_id\n" if $self->verbose;
                    } else {
                        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 500, {message => "Failed to update the record"});
                    }
                    $self->db->updateQueueStatus($queue->{id}, 'completed', $success);
                    $self->getActiveRecords->activeRecordUpdatedByBiblionumber($biblio_id);
                } else {
                    my ($biblionumber, $biblioitemnumber) = &AddBiblio($mergedrecord, '');
                    if ($biblionumber) {
                        print "Added a record $biblionumber\n" if $self->verbose;
                        $self->db->updateQueueStatusAndBiblioId($queue->{id}, $biblionumber, 'completed', 'Record added');
                    } else {
                        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 500, {message => "Failed to add a record"});
                    }

                }
            }
        } catch {
            my $exception = $_;
            my $error_message = eval { $exception->error } || $exception;
            $self->db->updateQueueStatus($queue->{id}, 'failed', $error_message);
            print "Error while processing import queue: $error_message\n";
        }
    }
}

sub processExportQueue {
    my ($self) = @_;
    my $queue = $self->db->getPendingQueue('export');
    foreach my $queue (@$queue) {
        my $starttime = strftime("%Y-%m-%d %H:%M:%S", localtime(time()));
        print "Starting to process record ".$queue->{biblio_id}." at ".$starttime."\n" if $self->verbose;
        my $target_id = $queue->{broadcast_biblio_id};
        $self->db->updateQueueStatus($queue->{id}, 'processing', undef);
        try {
            if ($target_id) {
                $self->putQueueRecord($queue, $target_id);
            } else {
                $target_id = $self->postQueueRecord($queue);
            }

            if ($self->updateRecord && $target_id) {
                my $newrecord = $self->mergeRecords($queue->{broadcast_interface})->addSystemControlNumber($self->getRecord($queue->{marc}), $target_id);
                $self->mergeRecords($queue->{broadcast_interface})->appendSystemControlNumber($newrecord);
                $self->mergeRecords($queue->{broadcast_interface})->updateControlNumberAndIdentifier($newrecord, $target_id);
                $self->updateLocalRecord($queue->{biblio_id}, $newrecord);
            }

            my $endtime = strftime("%Y-%m-%d %H:%M:%S", localtime(time()));
            print "Finished processing record ".$queue->{biblio_id}." at ".$endtime."\n" if $self->verbose;
        } catch {
            my $exception = $_;
            my $error_message = eval { $exception->error } || $exception;
            $self->db->updateQueueStatus($queue->{id}, 'failed', $error_message);
            my $endtime = strftime("%Y-%m-%d %H:%M:%S", localtime(time()));
            print "Finished processing record ".$queue->{biblio_id}." at ".$endtime."\n" if $self->verbose;
        }
    }
}

sub processExportComponentParts {
    my ($self, $interface, $method, $host_id, $componentparts, $broadcastcomponentparts, $user_id) = @_;

    $componentparts = $self->getComponentParts->sortComponentParts($componentparts);
    $broadcastcomponentparts = $self->getComponentParts->sortComponentParts($broadcastcomponentparts);
    if ($method eq 'PUT' && scalar @$broadcastcomponentparts > 0 && scalar @$componentparts != scalar @$broadcastcomponentparts) {
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 409, {message => "Component parts count mismatch, local: ".scalar @$componentparts.", broadcast: ".scalar @$broadcastcomponentparts});
    }

    my $rest = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::REST->new({interface => $interface});
    my $process_success = 1;
    for (my $i = 0; $i < scalar @$componentparts; $i++) {
        my $queue;
        last unless $process_success;
        try {
            my $componentpart = $componentparts->[$i];
            my $biblio_id = $componentpart->{biblionumber};
            my $db_record = Koha::Biblios->find($biblio_id);
            my $comprecord = $self->getRecord($db_record->metadata->metadata);
            my $broadcast_biblio_id;

            if ($method eq 'PUT' && scalar @$broadcastcomponentparts > 0) {
                $broadcast_biblio_id = $broadcastcomponentparts->[$i]->{biblionumber};
            }

            $comprecord = $self->mergeRecords($interface)->updateHostComponentPartLink($comprecord, $host_id);

            my $marcxml = $comprecord->as_xml_record;
            $self->db->insertToQueue({
                broadcast_interface => $interface,
                user_id => $user_id,
                type => 'export',
                broadcast_biblio_id => $broadcast_biblio_id,
                biblio_id => $biblio_id,
                marc => $marcxml,
                componentparts => undef,
                diff => undef,
                hostrecord => 0,
            });
            print "Added component part $biblio_id to export queue\n" if $self->verbose;
            $queue = $self->db->getQueuedRecordByBiblioId($biblio_id, 'export');
            $self->db->updateQueueStatus($queue->{id}, 'processing', undef);
            if ($broadcast_biblio_id) {
                $self->putQueueRecord($queue, $broadcast_biblio_id);
            } else {
                $broadcast_biblio_id = $self->postQueueRecord($queue);
            }
            if ($self->updateRecord && $broadcast_biblio_id) {
                my $newrecord = $self->mergeRecords($queue->{broadcast_interface})->addSystemControlNumber($self->getRecord($queue->{marc}), $broadcast_biblio_id);
                $self->mergeRecords($queue->{broadcast_interface})->appendSystemControlNumber($newrecord);
                $self->mergeRecords($queue->{broadcast_interface})->updateControlNumberAndIdentifier($newrecord, $broadcast_biblio_id);
                $self->updateLocalRecord($queue->{biblio_id}, $newrecord);
            }
        } catch {
            my $exception = $_;
            my $error_message = eval { $exception->error } || $exception;
            $self->db->updateQueueStatus($queue->{id}, 'failed', $error_message);
            $process_success = 0;
        }
    }

    if ($process_success) {
        print "Component parts processed successfully\n" if $self->verbose;
    } else {
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 500, {message => "Failed to process component parts"});
    }
}

sub postQueueRecord {
    my ($self, $queue) = @_;

    my $rest = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::REST->new({interface => $queue->{broadcast_interface}, verbose => $self->verbose});
    my $search = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Search->new();
    my $target_id;
    my $mergedrecord = $self->mergeRecords($queue->{broadcast_interface})->merge($self->getRecord($queue->{marc}), undef);
    my $marcxml = $mergedrecord->as_xml_record;
    my $marc = $queue->{broadcast_interface} =~ /Melinda|Vaari/i ? $self->getMarcXMLToJSON->toJSON($marcxml) : Encode::encode_utf8($marcxml);

    my $postResponse = $rest->apiCall({type => 'POST', data => {body => $marc}, user_id => $queue->{user_id}});
    if ($postResponse->is_success) {
        $target_id = $postResponse->headers->header('record-id') if $postResponse->headers->header('record-id');
        print "Target id: $target_id\n" if $self->verbose;
        if ($queue->{componentparts} && $target_id) {
            $self->processExportComponentParts($queue->{broadcast_interface}, 'POST', $target_id, from_json($queue->{componentparts}), undef, $queue->{user_id});
        }
        print "Pushed record to ".$queue->{broadcast_interface}." with response: ". $postResponse->message."\n";
        $self->db->updateQueueStatus($queue->{id}, 'completed', $postResponse->message);
        $self->db->removeComponentPartsFromHostRecord($queue->{id}); # Remove component parts from host after successful add
    } else {
        my $message = $postResponse->{message};
        $message .= " ".$postResponse->json->{message} if $postResponse->json && $postResponse->json->{message};
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception($queue->{broadcast_interface}, $postResponse->code, {message => $message});
    }

    return $target_id;
}

sub putQueueRecord {
    my ($self, $queue, $target_id) = @_;

    my $rest = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::REST->new({interface => $queue->{broadcast_interface}, verbose => $self->verbose});
    my $search = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Search->new();

    my $getResponse = $search->searchFromInterface($queue->{broadcast_interface}, undef, $target_id, $queue->{user_id});
    if ($getResponse->{marcjson}) {
        print "Got record ".$target_id." from ".$queue->{broadcast_interface}."\n";
        my $record = $getResponse->{marcjson};
        my $remoterecord = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MarcJSONToXML->new({marcjson => $record});
        if ($self->compareExportEncodingLevels($queue->{marc}, $remoterecord->toXML) eq 'lower') {
            Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 500, {message => "Local record ".$queue->{biblio_id}." has lower encoding level than broadcast record ".$queue->{broadcast_biblio_id}});
        } elsif ($self->compareTimestamps($queue->{marc}, $remoterecord->toXML) ) {
            print "Local record ".$queue->{biblio_id}." has lower timestamp than broadcast record ".$queue->{broadcast_biblio_id}."\n" if $self->verbose;
            Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 500, {message => "Local record ".$queue->{biblio_id}." has lower timestamp than broadcast record ".$queue->{broadcast_biblio_id}});
        } else {
            my $mergedrecord = $self->mergeRecords($queue->{broadcast_interface})->merge($self->getRecord($queue->{marc}), $self->getRecord($remoterecord->toXML));

            if ($queue->{hostrecord} || $queue->{componentparts}) {
                $self->processExportComponentParts($queue->{broadcast_interface}, 'PUT', $target_id, from_json($queue->{componentparts}), $getResponse->{componentparts}, $queue->{user_id});
            }

            my $marcxml = $mergedrecord->as_xml_record;
            my $marc = $queue->{broadcast_interface} =~ /Melinda|Vaari/i ? $self->getMarcXMLToJSON->toJSON($marcxml) : Encode::encode_utf8($marcxml);
            my $putResponse = $rest->apiCall({type => 'PUT', data => {biblio_id => $target_id, body => $marc}, user_id => $queue->{user_id}});
            if ($putResponse->is_success) {
                print "Updated record ".$queue->{broadcast_biblio_id}." in ".$queue->{broadcast_interface}." with response: ". $putResponse->message."\n";
                $self->db->updateQueueStatus($queue->{id}, 'completed', $putResponse->message);
                $self->db->removeComponentPartsFromHostRecord($queue->{id}); # Remove component parts from host after successful update
            } else {
                my $message = $putResponse->{message};
                $message .= " ".$putResponse->json->{message} if $putResponse->json && $putResponse->json->{message};
                Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception($queue->{broadcast_interface}, $putResponse->code, {message => $message});
            }
        }
    } else {
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception($queue->{broadcast_interface}, $getResponse->code, {message => $getResponse->{message}});
    }
}

sub processImportComponentParts {
    my ($self, $biblio_id, $broadcastcomponentparts) = @_;
    $broadcastcomponentparts = $self->getComponentParts->sortComponentParts($broadcastcomponentparts);
    my $localcomponentparts = $self->getComponentParts->fetch($biblio_id);
    my $f942 = $self->get942Field($biblio_id);
    if ($localcomponentparts) {
        unless (scalar @{$broadcastcomponentparts} == scalar @{$localcomponentparts}) {
            Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 409, {message => "Component parts count mismatch, broadcast: ".scalar @{$broadcastcomponentparts}.", local: ".scalar @{$localcomponentparts}});
        }
        $localcomponentparts = $self->getComponentParts->sortComponentParts($localcomponentparts);
        my $localcomponentpartscount = scalar @{$localcomponentparts};
        for (my $i = 0; $i < $localcomponentpartscount; $i++) {
            my $localcomponentpart = $localcomponentparts->[$i];
            my $biblionumber = $localcomponentpart->{biblionumber};
            my $broadcastcomponentpart = $broadcastcomponentparts->[$i];
            my $frameworkcode = GetFrameworkCode( $biblionumber );
            my $record = $self->getRecord($broadcastcomponentpart->{marcxml});
            if ($record) {
                my $mergedrecord = $self->mergeRecords()->merge($record, undef);
                my $local942 = $self->get942Field($biblionumber);
                $f942 = $local942 if $local942;
                $mergedrecord = $self->add942ToBiblio($mergedrecord, $f942);
                my $success = &ModBiblio($mergedrecord, $biblionumber, $frameworkcode, {
                            overlay_context => {
                                source       => 'z3950'
                            }
                        });
                if ($success) {
                    print "Updated component part $biblionumber\n" if $self->verbose;
                } else {
                    Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 500, {message => "Failed to update component part $biblionumber"});
                }
            } else {
                Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 500, {message => "Failed to update component part $biblionumber"});
            }
        }
    } else {
        my $broadcastcomponentpartscount = scalar @{$broadcastcomponentparts};
        for (my $i = 0; $i < $broadcastcomponentpartscount; $i++) {
            my $broadcastcomponentpart = $broadcastcomponentparts->[$i];
            my $record = $self->getRecord($broadcastcomponentpart->{marcxml});
            if ($record) {
                my $mergedrecord = $self->mergeRecords()->merge($record, undef);
                $mergedrecord = $self->add942ToBiblio($mergedrecord, $f942);
                my ($biblionumber, $biblioitemnumber) = &AddBiblio($mergedrecord, '');
                if ($biblionumber) {
                    print "Added component part $biblionumber\n" if $self->verbose;
                } else {
                    Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 500, {message => "Failed to add component part"});
                }
            } else {
                Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 500, {message => "Failed to add component part ".$broadcastcomponentpart->{biblionumber}});
            }
        }
    }
}

sub processNewComponentPartsToQueue {
    my ($self, $biblio_id, $broadcastcomponentparts) = @_;
    my $localcomponentparts = $self->getComponentParts->fetch($biblio_id);
    my $f942 = $self->get942Field($biblio_id);
    unless ($localcomponentparts) {
        $broadcastcomponentparts = $self->getComponentParts->sortComponentParts($broadcastcomponentparts);
        foreach my $broadcastcomponentpart (@$broadcastcomponentparts) {
            my $biblionumber = $broadcastcomponentpart->{biblionumber};
            my $inQueue = $self->checkBiblionumberQueueStatus($biblionumber);
            if ($inQueue && ($inQueue eq 'pending' || $inQueue eq 'processing')) {
                print "Broadcast record $biblionumber is already in queue\n" if $self->verbose;
                next;
            }
            my $record = $self->getRecord($broadcastcomponentpart->{marcxml});
            if ($record) {
                my $host = Koha::Biblios->find($biblio_id);
                my $match = $self->compareRecords->matchComponentPartToHost($record, $self->getRecord($host->metadata->metadata));
                if ($match) {
                    $record = $self->add942ToBiblio($record, $f942);
                    $broadcastcomponentpart->{marcxml} = $record->as_xml();
                    $self->db->insertToQueue($self->processParams({}, $broadcastcomponentpart));
                } else {
                    die "Mismatch between component part $biblionumber and host record $biblio_id\n";
                }
            } else {
                die "Failed to add component part $biblionumber to queue\n";
            }
        }
    }

}

sub updateLocalRecord {
    my ($self, $biblio_id, $record) = @_;
    my $frameworkcode = GetFrameworkCode( $biblio_id );
    my $f942 = $self->get942Field($biblio_id);
    $record = $self->add942ToBiblio($record, $f942);
    my $success = &ModBiblio($record, $biblio_id, $frameworkcode, {
                overlay_context => {
                    source       => 'z3950'
                }
            });
    if ($success) {
        print "Updated local record $biblio_id\n" if $self->verbose;
    } else {
        Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Exceptions::Handler->handle_exception('Generic', 500, {message => "Failed to update the record $biblio_id"});
    }
}

sub processParams {
    my ($self, $activerecord, $broadcastrecord) = @_;

    my $params = {
        broadcast_interface => $self->getBroadcastInterface,
        user_id => $self->getUserId,
        type => $self->getType,
    };

    $params->{broadcast_biblio_id} = $broadcastrecord->{biblionumber};
    $params->{biblio_id} = $activerecord->{biblionumber} if $activerecord->{biblionumber};
    $params->{marc} = $broadcastrecord->{marcxml};
    my $diff = $self->getDiff($activerecord->{metadata}, $broadcastrecord->{marcxml}) if $activerecord->{metadata};
    $params->{diff} = $diff ne "{}" ? $diff : undef if $diff;
    $params->{hostrecord} = $params->{componentparts} ? 1 : 0;
    $params->{componentparts} = $broadcastrecord->{componentparts} ? to_json($broadcastrecord->{componentparts}) : undef;

    return $params;
}

sub compareEncodingLevels {
    my ($self, $localmarc, $broadcastmarc) = @_;
    my $localEncoding = $self->getEncodingLevel($localmarc);
    my $broadcastEncoding = $self->getEncodingLevel($broadcastmarc);
    return $self->compareRecords->compareEncodingLevels($localEncoding, $broadcastEncoding);
}

sub compareExportEncodingLevels {
    my ($self, $localmarc, $broadcastmarc) = @_;
    my $localEncoding = $self->getEncodingLevel($localmarc);
    my $broadcastEncoding = $self->getEncodingLevel($broadcastmarc);
    if ($localEncoding->{encodingLevel} eq '4' && $broadcastEncoding->{encodingLevel} eq '3') {
        return "equal";
    } else {
        return $self->compareRecords->compareEncodingLevels($localEncoding, $broadcastEncoding);
    } 
}

sub compareTimestamps {
    my ($self, $localmarc, $broadcastmarc) = @_;
    my $localTimestamp = $self->getTimestamp($localmarc);
    my $broadcastTimestamp = $self->getTimestamp($broadcastmarc);
    print "Local timestamp: $localTimestamp, broadcast timestamp: $broadcastTimestamp\n" if $self->verbose;
    if ($localTimestamp < $broadcastTimestamp) {
        # If local timestamp is lower than broadcast timestamp, then we can update the record
        return 1;
    }
    return 0;
}

sub getTimestamp {
    my ($self, $marcxml) = @_;
    my $record = $self->getRecord($marcxml);
    my $timestamp = $record->field('005')->data();
    $timestamp =~ s/\.//g;
    return $timestamp;
}

sub getEncodingLevel {
    my ($self, $marcxml) = @_;
    my $record = $self->getRecord($marcxml);
    my $leader = $record->leader();
    my $encodingLevel = substr($leader, 17, 1);
    my $encodingStatus = substr($leader, 5, 1);
    return {encodingLevel => $encodingLevel, encodingStatus => $encodingStatus};
}

sub addItemTypeToBiblio {
    my ($self, $record, $biblionumber) = @_;
    my $itemtype = $self->getBiblioItemType($biblionumber);
    if ($itemtype) {
        my $itemtypefield = MARC::Field->new('942', ' ', ' ', 'c' => $itemtype);
        $record->insert_fields_ordered($itemtypefield);
    } else {
        die "Failed to get itemtype for biblionumber $biblionumber\n";
    }

    return $record;
}

sub add942ToBiblio {
    my ($self, $record, $f942) = @_;

    if ($f942 && $f942->subfield('c')) {
        my @f942 = $record->field('942');
        foreach my $f (@f942) {
            print "Found 942 field ".$f->as_formatted().", removing it\n" if $self->verbose;
        }
        $record->delete_fields(@f942) if @f942;
        print "Adding ".$f942->as_formatted()." field to record\n" if $self->verbose;
        $record->insert_fields_ordered($f942);
    }

    return $record;
}

sub get942Field {
    my ($self, $biblionumber) = @_;
    my $record = Koha::Biblios->find($biblionumber);
    my $f942 = $self->getRecord($record->metadata->metadata)->field('942');

    if ($f942 && $f942->subfield('c')) {
        return $f942;
    }

    if ($self->getBiblioItemType($biblionumber)) {
        return MARC::Field->new('942', ' ', ' ', 'c' => $self->getBiblioItemType($biblionumber));
    }
    return undef;
}

sub getBiblioItemType {
    my ($self, $biblionumber) = @_;
    my $biblio = Koha::Biblios->find($biblionumber);
    return $biblio->itemtype if $biblio;
    return undef;
}

1;