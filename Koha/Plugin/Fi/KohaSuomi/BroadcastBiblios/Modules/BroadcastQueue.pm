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
use Carp;
use Scalar::Util qw( blessed );
use Try::Tiny;
use Koha::DateUtils qw( dt_from_string );
use C4::Context;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Database;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Search;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::CompareRecords;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::MarcXMLToJSON;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ComponentParts;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios;
use JSON;
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

sub getComponentParts {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ComponentParts->new;
}

sub getActiveRecords {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords->new;
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

sub pushToRest {
    my ($self, $config, $activerecord, $broadcastrecord) = @_;
    my $users = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Users->new({config => $config->{rest}, endpoint => 'setToQueue'});
    my ($path, $headers) = $users->getAuthentication($self->getUserId);
    my $tx = $self->ua->post($path => $headers => json => {
        active_biblio => $activerecord,
        broadcast_biblio => $broadcastrecord,
        broadcast_interface => $self->getBroadcastInterface,
        user_id => $self->getUserId,
        type => $self->getType,
    });

    if ($tx->res->code eq '200' || $tx->res->code eq '201') {
        print "Pushed record ".$broadcastrecord->{biblio}->{biblionumber}." to ".$config->{interface_name}."\n";
    } else {
        my $error = $tx->res->json || $tx->res->error;
        my $errormessage = $error->{message} ? $error->{message} : $error;
        print "Failed to push record ".$broadcastrecord->{biblio}->{biblionumber}." to ".$config->{interface_name}.": ".$errormessage."\n";
    }
}

sub setToQueue {
    my ($self, $activerecord, $broadcastrecord) = @_;

    my $queueStatus = $self->checkBiblionumberQueueStatus($broadcastrecord->{biblio}->{biblionumber});
    if ($queueStatus eq 'pending' || $queueStatus eq 'processing') {
        print "Local record ".$activerecord->{biblionumber}." is already in queue\n" if $self->verbose;
        return;
    };

    my $encodingLevel = $self->compareEncodingLevels($activerecord->{metadata}, $broadcastrecord->{biblio}->{marcxml});
    if ($encodingLevel eq 'lower') {
        $self->db->insertToQueue($self->processParams($activerecord, $broadcastrecord));
    } elsif ($encodingLevel eq 'equal') {
        my $timestamp = $self->compareTimestamps($activerecord->{metadata}, $broadcastrecord->{biblio}->{marcxml});
        if ($timestamp) {
            $self->db->insertToQueue($self->processParams($activerecord, $broadcastrecord));
        }
    } else {
        print "Local record ".$activerecord->{biblionumber}." has greater encoding level than broadcast record ".$broadcastrecord->{biblio}->{biblionumber}."\n" if $self->verbose;
    }
}

sub getQueue {
    my ($self, $status, $biblio_id, $page, $limit) = @_;
    my $results = $self->db->getQueue($status, $biblio_id, $page, $limit);
    my $res;
    foreach my $result (@$results) {
        my $diff = $result->{diff} ? from_json($result->{diff}) : undef;
        my $parts;
        my $componentparts = $result->{componentparts} ? from_json($result->{componentparts}) : undef;
        foreach my $part (@$componentparts) {
            push @$parts, {
                biblionumber => $part->{biblionumber},
                marcjson => $self->getMarcXMLToJSON->toJSON($part->{marcxml}),
            };
        }
        push @$res, {
            id => $result->{id},
            biblio_id => $result->{biblio_id},
            itemtype => $self->getBiblioItemType($result->{biblio_id}),
            marcjson => $self->getMarcXMLToJSON->toJSON($result->{marc}),
            componentparts => $self->sortComponentParts($parts),
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
    my $queue = $self->db->getQueuedRecordByBiblionumber($biblionumber);
    return $queue->{status};
}

sub processQueue {
    my ($self) = @_;

    if ($self->getType eq "export") {
        $self->processExportQueue;
    } elsif ($self->getType eq "import") {
        $self->processImportQueue;
    }
}

sub processImportQueue {
    my ($self) = @_;
    my $queue = $self->db->getPendingQueue('import');
    foreach my $queue (@$queue) {
        $self->db->updateQueueStatus($queue->{id}, 'processing', undef);
        my $biblionumber = $queue->{biblio_id};
        my $frameworkcode = GetFrameworkCode( $biblionumber );
        try {
            my $record = $self->getRecord($queue->{marc});

            if ($record) {
                if ($queue->{hostrecord}) {
                    $self->processImportComponentParts($biblionumber, from_json($queue->{componentparts}));
                }
                my $success = &ModBiblio($record, $biblionumber, $frameworkcode, {
                            overlay_context => {
                                source       => 'z3950'
                            }
                        });
                if ($success) {
                    print "Updated record $biblionumber\n" if $self->verbose;
                } else {
                    die "Failed to update record $biblionumber\n";
                }
                $self->db->updateQueueStatus($queue->{id}, 'completed', $success);
                $self->getActiveRecords->activeRecordUpdatedByBiblionumber($biblionumber);
            }
        } catch {
            my $error = $_;
            $self->db->updateQueueStatus($queue->{id}, 'failed', $error);
            print "Error while processing import queue: $error\n";
        }
    }
}

sub processExportQueue {
    my ($self) = @_;
    my $queue = $self->db->getPendingQueue('export');
    foreach my $queue (@$queue) {
        warn Data::Dumper::Dumper $queue;
    }
}

sub processImportComponentParts {
    my ($self, $biblio_id, $broadcastcomponentparts) = @_;
    $broadcastcomponentparts = $self->sortComponentParts($broadcastcomponentparts);
    my $localcomponentparts = $self->getComponentParts->fetch($biblio_id);
    my $f942 = $self->get942Field($biblio_id);
    if ($localcomponentparts) {
        unless (scalar @{$broadcastcomponentparts} == scalar @{$localcomponentparts}) {
            die "Component parts count mismatch, broadcast: ".scalar @{$broadcastcomponentparts}.", local: ".scalar @{$localcomponentparts}."\n";
        }
        $localcomponentparts = $self->sortComponentParts($localcomponentparts);
        my $localcomponentpartscount = scalar @{$localcomponentparts};
        for (my $i = 0; $i < $localcomponentpartscount; $i++) {
            my $localcomponentpart = $localcomponentparts->[$i];
            my $biblionumber = $localcomponentpart->{biblionumber};
            my $broadcastcomponentpart = $broadcastcomponentparts->[$i];
            my $frameworkcode = GetFrameworkCode( $biblionumber );
            my $record = $self->getRecord($broadcastcomponentpart->{marcxml});
            if ($record) {
                $record = $self->add942ToBiblio($record, $f942);
                my $success = &ModBiblio($record, $biblionumber, $frameworkcode, {
                            overlay_context => {
                                source       => 'z3950'
                            }
                        });
                if ($success) {
                    print "Updated component part $biblionumber\n" if $self->verbose;
                } else {
                    die "Failed to update component part $biblionumber\n";
                }
            } else {
                die "Failed to update component part $biblionumber\n";
            }
        }
    } else {
        my $broadcastcomponentpartscount = scalar @{$broadcastcomponentparts};
        for (my $i = 0; $i < $broadcastcomponentpartscount; $i++) {
            my $broadcastcomponentpart = $broadcastcomponentparts->[$i];
            my $record = $self->getRecord($broadcastcomponentpart->{marcxml});
            if ($record) {
                $record = $self->add942ToBiblio($record, $f942);
                my ($biblionumber, $biblioitemnumber) = &AddBiblio($record, '');
                if ($biblionumber) {
                    print "Added component part $biblionumber\n" if $self->verbose;
                } else {
                    die "Failed to add component part ".$broadcastcomponentpart->{biblionumber}."\n";
                }
            } else {
                die "Failed to add component part ".$broadcastcomponentpart->{biblionumber}."\n";
            }
        }
    }
}

sub processParams {
    my ($self, $activerecord, $broadcastrecord) = @_;

    my $params = {
        broadcast_interface => $self->getBroadcastInterface,
        user_id => $self->getUserId,
        type => $self->getType,
        biblio_id => $activerecord->{biblionumber},
        broadcast_biblio_id => $broadcastrecord->{biblio}->{biblionumber},
        marc => $broadcastrecord->{biblio}->{marcxml},
        componentparts => $broadcastrecord->{componentparts} ? to_json($broadcastrecord->{componentparts}) : undef,
    };
    my $diff = $self->getDiff($activerecord->{metadata}, $broadcastrecord->{biblio}->{marcxml});
    $params->{diff} = $diff ne "{}" ? $diff : undef;
    $params->{hostrecord} = $params->{componentparts} ? 1 : 0;

    return $params;
}

sub compareEncodingLevels {
    my ($self, $localmarc, $broadcastmarc) = @_;
    my $localEncoding = $self->getEncodingLevel($localmarc);
    my $broadcastEncoding = $self->getEncodingLevel($broadcastmarc);
    return $self->compareRecords->compareEncodingLevels($localEncoding, $broadcastEncoding);
}

sub compareTimestamps {
    my ($self, $localmarc, $broadcastmarc) = @_;
    my $localTimestamp = $self->getTimestamp($localmarc);
    my $broadcastTimestamp = $self->getTimestamp($broadcastmarc);
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
    my $record = MARC::Record->new_from_xml($marcxml);
    my $leader = $record->leader();
    my $encodingLevel = substr($leader, 17, 1);
    my $encodingStatus = substr($leader, 5, 1);
    return {encodingLevel => $encodingLevel, encodingStatus => $encodingStatus};
}

sub sortComponentParts {
    my ($self, $componentparts) = @_;
    my @sorted = sort { $a->{biblionumber} <=> $b->{biblionumber} } @{$componentparts};
    return \@sorted;
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
    
    if ($f942) {
        $record->insert_fields_ordered($f942);
    }
    
    return $record;
}

sub get942Field {
    my ($self, $biblionumber) = @_;
    my $record = Koha::Biblios->find($biblionumber);
    my $f942 = $self->getRecord($record->metadata->metadata)->field('942');
    return $f942;
}

sub getBiblioItemType {
    my ($self, $biblionumber) = @_;
    my $biblio = Koha::Biblios->find($biblionumber);
    return $biblio->itemtype;
}

1;