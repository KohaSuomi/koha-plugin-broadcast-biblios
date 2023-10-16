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
use Koha::Logger;

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

sub getRecord {
    my ($self, $marcxml) = @_;
    my $biblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new();
    return $biblios->getRecord($marcxml);
}

sub getLogger {
    my ($self) = @_;
    return Koha::Logger->get( {interface => "broadcast"});
}

sub getDiff {
    my ($self, $localmarcxml, $broadcastmarcxml) = @_;
    return $self->compareRecords->getDiff($self->getMarcXMLToJSON->toJSON($localmarcxml), $self->getMarcXMLToJSON->toJSON($broadcastmarcxml));
}

sub setToQueue {
    my ($self, $localrecord, $broadcastrecord) = @_;
    my $encodingLevel = $self->compareEncodingLevels($localrecord->{metadata}, $broadcastrecord->{biblio}->{marcxml});
    if ($encodingLevel ne "greater") {
        $self->db->insertToQueue($self->processParams($localrecord, $broadcastrecord));
    }
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
        my $record = $self->getRecord($queue->{marc});

        if ($record) {
            my $success = &ModBiblio($record, $biblionumber, $frameworkcode, {
                        overlay_context => {
                            source       => 'z3950'
                        }
                    });
            if ($success) {
                if ($queue->{hostrecord}) {
                    $self->processImportComponentParts($biblionumber, from_json($queue->{componentparts}));
                }
                $self->getLogger->info("Updated record $biblionumber\n")
            } else {
                $self->getLogger->info("Failed to update record $biblionumber\n");
            }
            $self->db->updateQueueStatus($queue->{id}, 'completed', $success);
        } else {
            $self->db->updateQueueStatus($queue->{id}, 'failed', 'Record not found, check the logs');
            $self->getLogger->info("Failed to update record $biblionumber\n");
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
    if ($localcomponentparts) {
        $localcomponentparts = $self->sortComponentParts($localcomponentparts);
        my $localcomponentpartscount = scalar @{$localcomponentparts};
        for (my $i = 0; $i < $localcomponentpartscount; $i++) {
            my $localcomponentpart = $localcomponentparts->[$i];
            my $biblionumber = $localcomponentpart->{biblionumber};
            my $broadcastcomponentpart = $broadcastcomponentparts->[$i];
            my $frameworkcode = GetFrameworkCode( $biblionumber );
            my $record = $self->getRecord($broadcastcomponentpart->{marcxml});
            if ($record) {
                my $success = &ModBiblio($record, $biblionumber, $frameworkcode, {
                            overlay_context => {
                                source       => 'z3950'
                            }
                        });
                $self->getLogger->info("Updated component part $biblionumber\n") if $success;
            }
        }
    } else {
        my $broadcastcomponentpartscount = scalar @{$broadcastcomponentparts};
        for (my $i = 0; $i < $broadcastcomponentpartscount; $i++) {
            my $broadcastcomponentpart = $broadcastcomponentparts->[$i];
            my $record = $self->getRecord($broadcastcomponentpart->{marcxml});
            if ($record) {
                my ($biblionumber, $biblioitemnumber) = &AddBiblio($record, '');
                $self->getLogger->info("Added component part $biblionumber\n");
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
    $params->{hostrecord} = 1 if $params->{componentparts};

    return $params;
}

sub compareEncodingLevels {
    my ($self, $localmarc, $broadcastmarc) = @_;
    my $localEncoding = $self->getEncodingLevel($localmarc);
    my $broadcastEncoding = $self->getEncodingLevel($broadcastmarc);
    return $self->compareRecords->compareEncodingLevels($localEncoding, $broadcastEncoding);
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

1;