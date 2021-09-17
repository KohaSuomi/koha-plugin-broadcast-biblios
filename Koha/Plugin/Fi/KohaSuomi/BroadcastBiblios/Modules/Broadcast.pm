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
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastLog;

=head new

    my $broadcast = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Broadcast->new($params);

=cut

sub new {
    my ($class, $params) = _validateNew(@_);
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

sub broadcastLog {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastLog->new({table => $self->getLogTable});
}

sub getTimestamp {
    return strftime "%Y-%m-%d %H:%M:%S", ( localtime(time - 5*60) );
}

sub broadcastBiblios {
    my ($self, $params) = @_;
    my $pageCount = 1;
    my $latest = $self->broadcastLog()->getBroadcastLogLatest();
    $params->{timestamp} = $latest->{updated} || $self->getTimestamp() if !$self->getAll();
    while ($pageCount >= $params->{page}) {
        my $newbiblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new($params);
        my $biblios = $newbiblios->fetch($params->{page});
        my $count = 0;
        my $lastnumber;
        my @pusharray;
        my ($error, $response);
        foreach my $biblio (@{$biblios}) {
            my $requestparams = $self->getEndpointParameters($biblio);
            if ($self->getEndpointType eq 'identifier_activation') { 
                if ($requestparams) {
                    push @pusharray, $requestparams;
                } else {
                    $self->_verboseResponse('No valid identifier!', undef, $biblio->{biblionumber});
                }
            } else {
                ($error, $response) = $self->_restRequestCall($requestparams, undef);
                $self->_verboseResponse($error, $response, $biblio->{biblionumber});
            }
            $self->broadcastLog()->setBroadcastLog($biblio->{biblionumber}, $biblio->{timestamp}) if !$self->getAll();
            $count++;
            $lastnumber = $biblio->{biblionumber};
        }
        if ($self->getEndpointType eq 'identifier_activation' && @pusharray) {
            ($error, $response) = $self->_restRequestCall(undef, @pusharray);
            if ($error) {
                print "Chunk push failed with: $error";
            }
        }
        print "last processed biblio $lastnumber\n";
        print "$count biblios processed!\n";
        if ($count eq $params->{chunks}) {
            $pageCount++;
            $params->{page} = $pageCount;
        } else {
            $pageCount = 0;
        }
    }
}

# sub broadcastStaged {
#     my ($self) = @_;
#     my @biblios = import_records();
#     my $count = 0;
#     foreach my $biblio (@biblios) {
#         my $parameters;
#         if ($stage_type eq "update") {
#             my $record = MARC::Record::new_from_xml($biblio->{marcxml}, 'UTF-8');
#             if($record->field($target_field)) {
#                 my $target_id = $record->field($target_field)->subfield($target_subfield);
#                 if ($target_id =~ /$field_check/) {
#                     print "Target id ($target_id) found from $biblio->{biblionumber}!\n";
#                     $target_id =~ s/\D//g;
#                     $parameters = {marc => $biblio->{marcxml}, source_id => $biblio->{biblionumber}, target_id => $target_id, interface => $self->getInterface, check => Mojo::JSON->true};
#                 }
#             }
#         } else {
#             $parameters = $biblio->{parent_id} ? {marc => $biblio->{marcxml}, source_id => $biblio->{biblionumber}, interface => $self->getInterface, parent_id => $biblio->{parent_id}, force => 1} : {marc => $biblio->{marcxml}, source_id => $biblio->{biblionumber}, interface => $self->getInterface};
#         }
#         if ($parameters) {
#             my $tx = $ua->inactivity_timeout($inactivity_timeout)->post($endpoint => $headers => json => $parameters);
#             my $response = decode_json($tx->res->body);
#             my $error = $response->{error} || $tx->res->error->{message} if $response->{error} || $tx->res->error;
#             if ($error) {
#                 print "$biblio->{biblionumber} biblio failed with: $error!\n";
#             }
#             if ($verbose && defined $response->{message} && $response->{message} eq "Success") {
#                 print "$biblio->{biblionumber} biblio added succesfully\n";
#             }
#             $count++;
#         }
#     }

#     print "$count biblios processed!\n";
# }

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
    $restParams->{updated} = $biblio->{timestamp} if $self->getAll;
    
    return $restParams;
}

sub _getActiveIdentifierEndpointParameters {
    my ($self, $biblio) = @_;

    my ($identifier, $identifier_field) = $self->_getActiveField($biblio);
    return unless $identifier && $identifier_field;

    my $restParams = {identifier => $identifier, identifier_field => $identifier_field, target_id => $biblio->{biblionumber}, interface_name => $self->getInterface};
    $restParams->{updated} = $biblio->{timestamp} if $self->getAll;


    return $restParams;
}

sub _getBroadcastEndpointParameters {
    my ($self, $biblio) = @_;
    return {marcxml => $biblio->{metadata}, source_id => $biblio->{biblionumber}, updated => $biblio->{timestamp}};
}

sub _restRequestCall {
    my ($self, $params, @pusharray) = @_;

    my $ua = Mojo::UserAgent->new;
    my $tx = $ua->inactivity_timeout($self->getInactivityTimeout)->post($self->getEndpoint => $self->getHeaders => json => $params ? $params : \@pusharray);
    my $response = decode_json($tx->res->body);
    return ($response->{error}, undef) if $response->{error};
    return (undef, $response->{message});

}

sub _verboseResponse {
    my ($self, $error, $response, $biblionumber) = @_;

    if ($error) {
        print "$biblionumber biblio failed with: $error!\n";
    }
    if ($self->verbose && defined $response && $response eq "Success") {
        print "$biblionumber biblio added succesfully\n";
    }
}

sub _getActiveField {
    my ($self, $biblio) = @_;
    my $record = MARC::Record::new_from_xml($biblio->{metadata}, 'UTF-8');
    my $activefield;
    my $fieldname;

    if ($record->field('035')) {
        my @f035 = $record->field( '035' );
        foreach my $f035 (@f035) {
            if($f035->subfield('a') =~ /FI-MELINDA/) {
                $activefield = $f035->subfield('a');
                $fieldname = '035a';
            }
        }
    }

    if ($record->field('020') && !$activefield) {
        my @f020 = $record->field( '020' );
        foreach my $f020 (@f020) {
            if ($f020->subfield('a')) {
                $activefield = $f020->subfield('a');
                $activefield =~ s/-//gi;
                $fieldname = '020a';
            }
        }

    }

    if ($record->field( '024') && !$activefield) {
        my @f024 = $record->field( '024' );
        foreach my $f024 (@f024) {
            if ($f024->subfield('a') && $f024->indicator('1') eq '3') {
                $activefield = $f024->subfield('a');
                $fieldname = '024a';
                last;
            } elsif ($f024->subfield('a')) {
                $activefield = $f024->subfield('a');
                $fieldname = '024a';
                last;
            }
        }
    }
    if ($record->field(003) && $record->field( '003')->data =~ /FI-BTJ/ && !$activefield) {
        $activefield = $record->field( '003')->data.'|'.$record->field( '001')->data;
        $fieldname = '003|001';
    }

    return ($activefield, $fieldname);
}

1;