package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Broadcast;

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
use Digest::SHA qw(hmac_sha256_hex);
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Koha::DateUtils qw( dt_from_string );
use MARC::Record;
use Data::Dumper;
use Koha::Logger;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ComponentParts;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastLog;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ComponentParts;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::Identifiers;

=head new

    my $broadcast = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Broadcast->new($params);

=cut

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;

}

sub _validateNew {
    my ($class, $params) = @_;
    unless ($params->{endpoint}) {
        die "Missing endpoint parameter";
    }

    unless ($params->{headers}) {
        die "Missing headers parameter";
    }
    return @_;
}

sub verbose {
    return shift->{_params}->{verbose};
}

sub getEndpoint {
    return shift->{_params}->{endpoint};
}

sub getEndpointType {
    return shift->{_params}->{endpoint_type};
}

sub getInactivityTimeout {
    return shift->{_params}->{inactivity_timeout};
}

sub getHeaders {
    return shift->{_params}->{headers};
}

sub getInterface {
    return shift->{_params}->{interface};
}

sub getAll {
    return shift->{_params}->{all};
}

sub getStageType {
    return shift->{_params}->{stage_type};
}

sub getLogTable {
    return shift->{_params}->{log_table};
}

sub getStartTime {
    return shift->{_params}->{start_time};
}

sub getUpdateTime {
    my ($self, $updated) = @_; 

    return $self->getTimestamp() unless $updated;
    return $updated unless $self->getStartTime();

    my $hour = (localtime(time))[2];
    if ($self->getStartTime() >= $hour) {
        return $self->getTimestamp();
    } else {
        return $updated;
    }
}

sub broadcastLog {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastLog->new({table => $self->getLogTable});
}

sub getTimestamp {
    return strftime "%Y-%m-%d %H:%M:%S", ( localtime(time - 5*60) );
}

sub activeRecords {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ActiveRecords->new();
}

sub componentParts {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ComponentParts->new();
}

sub blockByEncodingLevel {
    my ($self, $biblio) = @_;

    my $blockedLevel = shift->{_params}->{blocked_encoding_level};
    if ($blockedLevel) {
        my @levels = split('|', $blockedLevel);
        my $encodingLevel = $self->activeRecords()->checkEncodingLevel($biblio);

        foreach my $level (@levels) {
            if ($level eq $encodingLevel) {
                return 1;
            }
        }

        if ($blockedLevel eq $encodingLevel) {
            return 1;
        }
    }

    return 0;
}

sub blockComponentParts {
    my ($self, $biblio) = @_;
    
    my $block = shift->{_params}->{block_component_parts};

    if ($block) {
        return $self->activeRecords()->checkComponentPart($biblio);
    }

    return 0;
}

sub getRecord {
    my ($self, $biblio) = @_;

    my $biblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new();
    return $biblios->getRecord($biblio->{metadata});
}

sub getIdentifiers {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Helpers::Identifiers->new();
}

sub getConfig {
    my ($self) = @_;
    my $config = shift->{_params}->{config};
    return $config;
}

sub configKeys {
    my ($self) = @_;
    
    my $config = shift->{_params}->{config};
    my @keys;
    foreach my $key (keys %{$config}) {
        push @keys, $key;
    }

    return \@keys;
}

sub fetchBroadcastBiblios {
    my ($self, $params) = @_;
    my $pageCount = 1;
    my $latest = $self->broadcastLog()->getBroadcastLogLatestImport();
    my $timestamp = $self->getUpdateTime($latest->{updated});
    $params->{timestamp} = $timestamp if !$self->getAll();
    my $configKeys = $self->configKeys;
    while ($pageCount >= $params->{page}) {
        my $newbiblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new($params);
        my $biblios = $newbiblios->fetch();
        my $count = 0;
        my $lastnumber;
        my ($error, $response);
        foreach my $biblio (@{$biblios}) {
            if ($self->verbose > 1) {
                print "Processing: $biblio->{biblionumber}\n";
            }
            $count++;
            $self->broadcastLog()->setBroadcastLog($biblio->{biblionumber}, $biblio->{timestamp}, 'import');
            try {
                my $record = $self->getRecord($biblio);
                return unless $record;
                return if $self->blockComponentParts($record);
                return if $self->blockByEncodingLevel($record);
                my $componentsArr = $self->componentParts->fetch($biblio->{biblionumber});
                my $bibliowrapper = {
                    biblio => {
                        marcxml => $biblio->{metadata},
                        biblionumber => $biblio->{biblionumber},
                    },
                    componentparts => $componentsArr || undef
                };
                my $identifiers = $self->getIdentifiers->fetchIdentifiers($biblio->{metadata});
                my $success;
                foreach my $configKey (@$configKeys) {
                    my $config = $self->getConfig->{$configKey};
                    next unless $config->{type} eq 'import';
                    my $record_found = 0;
                    foreach my $identifier (@$identifiers) {
                        my $activeBiblio = $self->_getActiveRecord($config, $identifier->{identifier}, $identifier->{identifier_field});
                        if ($activeBiblio) {
                            my $broadcastQueue = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastQueue->new({broadcast_interface => $config->{interface_name}, user_id => $config->{user_id}, type => 'import'});
                            $broadcastQueue->pushToRest($config, $activeBiblio, $bibliowrapper);
                            $record_found = 1;
                            last;
                        }
                    }
                    unless ($record_found) {
                        print "No record found for $biblio->{biblionumber} with $config->{interface_name}\n" if $self->verbose;
                    }
                }
            } catch {
                my $error = $_;
                print "Broadcast for biblionumber ".$biblio->{biblionumber}." failed with: $error\n";
            };

            $lastnumber = $biblio->{biblionumber};
        }
        print "last processed biblio $lastnumber\n" if $lastnumber;
        print "$count biblios processed!\n";
        if ($count eq $params->{chunks}) {
            $pageCount++;
            $params->{page} = $pageCount;
        } else {
            $pageCount = 0;
        }
    }
}


sub broadcastBiblios {
    my ($self, $params) = @_;
    my $pageCount = 1;
    my $latest = $self->broadcastLog()->getBroadcastLogLatest();
    my $timestamp = $self->getUpdateTime($latest->{updated});
    $params->{timestamp} = $timestamp if !$self->getAll();
    while ($pageCount >= $params->{page}) {
        my $newbiblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new($params);
        my $biblios = $newbiblios->fetch();
        my $count = 0;
        my $lastnumber;
        my @pusharray;
        my ($error, $response);
        foreach my $biblio (@{$biblios}) {
            if ($self->verbose > 1) {
                print "Processing: $biblio->{biblionumber}\n";
            }
            $count++;
            try {
                my $record = $self->getRecord($biblio);
                return unless $record;
                return if $self->blockComponentParts($record);
                return if $self->blockByEncodingLevel($record);
                my $componentsArr = $self->componentParts->fetch($biblio->{biblionumber});
                $biblio->{componentparts_count} = scalar @{$componentsArr} if $componentsArr && @{$componentsArr};
                my $requestparams = $self->getEndpointParameters($biblio);
                my $success;
                if ($self->getEndpointType eq 'identifier_activation') { 
                    if ($requestparams) {
                        push @pusharray, $requestparams;
                    } else {
                        $self->_verboseResponse('No valid identifier!', undef, $biblio->{biblionumber});
                    }
                } else {
                    ($error, $response) = $self->_restRequestCall($requestparams, undef);
                    $success = $self->_verboseResponse($error, $response, $biblio->{biblionumber});
                }
                $self->broadcastLog()->setBroadcastLog($biblio->{biblionumber}, $biblio->{timestamp}) if !$self->getAll();
                $self->_loopComponentParts($biblio, $componentsArr, $success);
            } catch {
                my $error = $_;
                print "Broadcast for biblionumber ".$biblio->{biblionumber}." failed with: $error\n";
            };

            $lastnumber = $biblio->{biblionumber};
        }
        if ($self->getEndpointType eq 'identifier_activation' && @pusharray) {
            ($error, $response) = $self->_restRequestCall(undef, @pusharray);
            if ($error) {
                print "Chunk push failed with: $error";
            }
        }
        print "last processed biblio $lastnumber\n" if $lastnumber;
        print "$count biblios processed!\n";
        if ($count eq $params->{chunks}) {
            $pageCount++;
            $params->{page} = $pageCount;
        } else {
            $pageCount = 0;
        }
    }
}

sub activateSingleBiblio {
    my ($self, $biblio) = @_;

    my $record = $self->getRecord($biblio);
    return {status => 400, message => "Record is broken!"} unless $record;

    my $componentsArr = $self->componentParts->fetch($biblio->{biblionumber});
    $biblio->{componentparts_count} = scalar @{$componentsArr} if $componentsArr && @{$componentsArr};

    my $requestparams = $self->getEndpointParameters($biblio);
    return {status => 404, message => "No valid identifier!"} unless $requestparams;
    my @pusharray;
    push @pusharray, $requestparams;
    my ($error, $response) = $self->_restRequestCall(undef, @pusharray);
    return {status => 400, message => $error} if $error;

    return {message => "Success"};

}

sub getLastRecord {
    my ($self) = @_;

    my $ua = Mojo::UserAgent->new;
    my $tx = $ua->inactivity_timeout($self->getInactivityTimeout)->get($self->getEndpoint.'/lastrecord' => $self->getHeaders => form => {interface => $self->getInterface});
    my $response = decode_json($tx->res->body);

    return $response->{target_id};
}

sub getEndpointParameters {
    my ($self, $biblio) = @_;
    if ($self->getEndpointType eq 'export') {
        return $self->_getExportEndpointParameters($biblio);
    }

    if ($self->getEndpointType eq 'active') {
        return $self->_getActiveEndpointParameters($biblio);
    }

    if ($self->getEndpointType eq 'identifier_activation') {
        return $self->_getActiveIdentifierEndpointParameters($biblio);
    }

    if ($self->getEndpointType eq 'broadcast') {
        return $self->_getBroadcastEndpointParameters($biblio);
    }
}

sub _getExportEndpointParameters {
    my ($self, $biblio, $target_id) = @_;

    my $restParams = $biblio->{parent_id} ? {marc => $biblio->{marcxml}, source_id => $biblio->{biblionumber}, interface => $self->getInterface, parent_id => $biblio->{parent_id}, force => 1} : {marc => $biblio->{marcxml}, source_id => $biblio->{biblionumber}, interface => $self->getInterface};
    $restParams->{updated} = {marc => $biblio->{marcxml}, source_id => $biblio->{biblionumber}, target_id => $target_id, interface => $self->getInterface, check => Mojo::JSON->true} if $self->getStageType eq 'update';
    
    return $restParams;
}

sub _getActiveEndpointParameters {
    my ($self, $biblio) = @_;

    my $restParams = {marcxml => $biblio->{metadata}, target_id => $biblio->{biblionumber}, interface_name => $self->getInterface};
    my $blocked = $self->activeRecords()->checkBlock($biblio);    
    $restParams->{blocked} = $blocked if length $blocked;
    $restParams->{updated} = $biblio->{timestamp} if $self->getAll;
    
    return $restParams;
}

sub _getActiveIdentifierEndpointParameters {
    my ($self, $biblio) = @_;

    my ($identifier, $identifier_field) = $self->activeRecords()->getActiveField($biblio);
    return unless $identifier && $identifier_field;

    my $restParams = {identifier => $identifier, identifier_field => $identifier_field, target_id => $biblio->{biblionumber}, interface_name => $self->getInterface};
    my $blocked = $self->activeRecords()->checkBlock($biblio);
    $restParams->{blocked} = $blocked if length $blocked;
    $restParams->{updated} = $biblio->{timestamp} if $self->getAll;

    return $restParams;
}

sub _getBroadcastEndpointParameters {
    my ($self, $biblio) = @_;
    my @fields = $self->activeRecords()->fetchActiveFields($biblio);
    return {marcxml => $biblio->{metadata}, source_id => $biblio->{biblionumber}, updated => $biblio->{timestamp}, activefields => @fields, componentparts_count => $biblio->{componentparts_count}};
}

sub _restRequestCall {
    my ($self, $params, @pusharray) = @_;

    my $ua = Mojo::UserAgent->new;
    my $tx = $ua->inactivity_timeout($self->getInactivityTimeout)->post($self->getEndpoint => $self->getHeaders => json => $params ? $params : \@pusharray);
    warn "Connection failed with: ".$tx->res->error->{message} || $tx->res->message unless $tx->res->code eq '200' || $tx->res->code eq '201';
    my $response = decode_json($tx->res->body);
    return ($response->{error}, undef) if $response->{error};
    return (undef, $response->{message});

}

sub _getActiveRecord {
    my ($self, $config, $identifier, $identifier_field) = @_;
    my $restConfig = $config->{rest};
    my $path = $restConfig->{baseUrl}.'/'.$restConfig->{findActiveBiblios}->{path}.'?identifier='.$identifier.'&identifier_field='.$identifier_field;
    my $ua = Mojo::UserAgent->new;
    my $tx = $ua->inactivity_timeout($restConfig->{inactivityTimeout})->get($path);
    unless ($tx->res->code eq '200' || $tx->res->code eq '201') {
        print "_getActiveRecord failed with: ".$tx->res->json->{error}."\n" if $self->verbose;
        return;
    }
    my $response = $tx->res->json;
    return $response;

}

sub _pushComponentParts {
    my ($self, $params) = @_;

    my $ua = Mojo::UserAgent->new;
    my $tx = $ua->inactivity_timeout($self->getInactivityTimeout)->post($self->getEndpoint.'/componentparts' => $self->getHeaders => json => $params);
    warn "Connection failed with: ".$tx->res->error->{message} || $tx->res->message unless $tx->res->code eq '200' || $tx->res->code eq '201';
    my $response = decode_json($tx->res->body);
    return ($response->{error}, undef) if $response->{error};
    return (undef, $response->{message});

}

sub _loopComponentParts {
    my ($self, $biblio, $componentsArr, $success) = @_;

    if ($self->getEndpointType eq 'broadcast' && ($componentsArr && @{$componentsArr}) && $success) {
        my $order = 0;
        foreach my $componentpart (@{$componentsArr}) {
            $order++;
            my ($error, $response) = $self->_pushComponentParts({source_id => $componentpart->{biblionumber}, parent_id => $biblio->{biblionumber}, marcxml => $componentpart->{marcxml}, part_order => $order});
            $self->_verboseResponse($error, $response, $componentpart->{biblionumber});
            $self->broadcastLog()->setBroadcastLog($componentpart->{biblionumber}, $biblio->{timestamp});
        }
    }
}

sub _verboseResponse {
    my ($self, $error, $response, $biblionumber) = @_;

    if ($error) {
        print "$biblionumber biblio failed with: $error!\n";
        return 0;
    }
    if ($self->verbose && defined $response && $response eq "Success") {
        print "$biblionumber biblio added succesfully\n";
        return 1;
    }

    return 0;
}

1;