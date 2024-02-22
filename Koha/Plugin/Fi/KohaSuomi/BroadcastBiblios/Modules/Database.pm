package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Database;

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
use JSON;
use Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios;
use C4::Context;

=head new

    my $db = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Database->new($params);

=cut

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{_params} = $params;
    bless($self, $class);
    return $self;

}

sub plugin {
    my ($self) = @_;
    return Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios->new;
}

sub logs {
    my ($self) = @_;
    return $self->plugin->get_qualified_table_name('log');
}

sub activerecords {
    my ($self) = @_;
    return $self->plugin->get_qualified_table_name('activerecords');
}

sub queue {
    my ($self) = @_;
    return $self->plugin->get_qualified_table_name('queue');
}

sub users {
    my ($self) = @_;
    return $self->plugin->get_qualified_table_name('users');
}

sub dbh {
    my ($self) = @_;
    return C4::Context->dbh;
}

=head ActiveRecords

    Active recods database functions
    
        my $activeRecord = $db->getActiveRecordByBiblionumber($biblionumber);
        my $activeRecord = $db->getActiveRecordByIdentifier($identifier, $identifier_field);
        $db->insertActiveRecord($biblionumber, $identifier, $identifier_field, $updated_on);
=cut

sub getActiveRecordById {
    my ($self, $id) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("SELECT ar.*, bm.metadata FROM " . $self->activerecords . " AS ar JOIN biblio_metadata AS bm ON ar.biblionumber = bm.biblionumber WHERE ar.id = ?");
    $sth->execute($id);
    my $result = $sth->fetchrow_hashref;
    $sth->finish();
    return $result;
}

sub getActiveRecordByBiblionumber {
    my ($self, $biblionumber) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("SELECT ar.*, bm.metadata FROM " . $self->activerecords . " AS ar JOIN biblio_metadata AS bm ON ar.biblionumber = bm.biblionumber WHERE ar.biblionumber = ?");
    $sth->execute($biblionumber);
    my $result = $sth->fetchrow_hashref;
    $sth->finish();
    return $result;
}

sub getActiveRecordByIdentifier {
    my ($self, $identifier, $identifier_field) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("SELECT ar.*, bm.metadata FROM " . $self->activerecords . " AS ar JOIN biblio_metadata AS bm ON ar.biblionumber = bm.biblionumber WHERE identifier = ? AND identifier_field = ?");
    $sth->execute($identifier, $identifier_field);
    my $result = $sth->fetchrow_hashref;
    $sth->finish();
    return $result;
}

sub insertActiveRecord {
    my ($self, $biblionumber, $identifier, $identifier_field, $updated_on, $blocked) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("INSERT INTO " . $self->activerecords . " (biblionumber, identifier, identifier_field, updated_on, blocked) VALUES (?, ?, ?, ?, ?)");
    $sth->execute($biblionumber, $identifier, $identifier_field, $updated_on, $blocked);
    my $id = $sth->{mysql_insertid};
    $sth->finish();
    return $id;
}

sub updateActiveRecordRemoteBiblionumber {
    my ($self, $id, $remote_biblionumber) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("UPDATE " . $self->activerecords . " SET remote_biblionumber = ? WHERE id = ?");
    $sth->execute($remote_biblionumber, $id);
    $sth->finish();
}

sub activeRecordUpdated {
    my ($self, $id) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("UPDATE " . $self->activerecords . " SET updated_on = NOW() WHERE id = ?");
    $sth->execute($id);
    $sth->finish();
}

sub getPendingActiveRecords {
    my ($self) = @_;
    my $dbh = $self->dbh;
    my $query = "SELECT ar.*, bm.metadata FROM " . $self->activerecords . " AS ar JOIN biblio_metadata AS bm ON ar.biblionumber = bm.biblionumber WHERE updated_on is null";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my $results = $sth->fetchall_arrayref({});
    $sth->finish();
    return $results;
}

sub updateActiveRecord {
    my ($self, $id, $params) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("UPDATE " . $self->activerecords . " SET identifier = ?, identifier_field = ?, blocked = ? WHERE id = ?");
    $sth->execute($params->{identifier}, $params->{identifier_field}, $params->{blocked}, $id);
    $sth->finish();
}

sub updateActiveRecordBlocked {
    my ($self, $id, $blocked) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("UPDATE " . $self->activerecords . " SET blocked = ? WHERE id = ?");
    $sth->execute($blocked, $id);
    $sth->finish();
}

=head Queue

    Queue database functions
        
            my $queue = $db->getPendingQueue($type);
            $db->insertToQueue($params);
            $db->updateQueueStatus($id, $status, $statusmessage);

=cut

sub getPendingQueue {
    my ($self, $type) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("SELECT * FROM " . $self->queue . " WHERE status = 'pending' and type = ? ORDER BY id ASC");
    $sth->execute($type);
    my $results = $sth->fetchall_arrayref({});
    $sth->finish();
    return $results;
}

sub getQueue {
    my ($self, $status, $biblio_id, $page, $limit) = @_;
    my $dbh = $self->dbh;
    my $query = "SELECT * FROM " . $self->queue;

    if ($status && !$biblio_id) {
        $query .= " WHERE status = ?";
    } elsif ($biblio_id && !$status) {
        $query .= " WHERE biblio_id = ?";
    } elsif ($status && $biblio_id) {
        $query .= " WHERE status = ? AND biblio_id = ?";
    }
    my $orderBy = $status eq 'pending' || $status eq 'processing' ? 'created_on' : 'transfered_on';
    if ($page && $limit) {
        $query .= " ORDER BY ".$orderBy." DESC LIMIT " . ($page-1)*$limit . ", " . $limit;
    } else {
        $query .= " ORDER BY ".$orderBy." DESC";
    }

    my $sth = $dbh->prepare($query);
    if ($status && !$biblio_id) {
        $sth->execute($status);
    } elsif ($biblio_id && !$status) {
        $sth->execute($biblio_id);
    } elsif ($status && $biblio_id) {
        $sth->execute($status, $biblio_id);
    } else {
        $sth->execute();
    }
    my $results = $sth->fetchall_arrayref({});
    $sth->finish();
    return $results;
}

sub getQueuedRecordByBiblionumber {
    my ($self, $biblionumber, $interface) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("SELECT * FROM " . $self->queue . " WHERE broadcast_biblio_id = ? AND broadcast_interface = ? order by id desc limit 1");
    $sth->execute($biblionumber, $interface);
    my $result = $sth->fetchrow_hashref;
    $sth->finish();
    return $result;
}

sub countQueue {
    my ($self, $status, $biblio_id) = @_;
    my $dbh = $self->dbh;
    my $query = "SELECT COUNT(*) FROM " . $self->queue;
    if ($status && !$biblio_id) {
        $query .= " WHERE status = ?";
    } elsif ($biblio_id && !$status) {
        $query .= " WHERE biblio_id = ?";
    } elsif ($status && $biblio_id) {
        $query .= " WHERE status = ? AND biblio_id = ?";
    }
    my $sth = $dbh->prepare($query);
    if ($status && !$biblio_id) {
        $sth->execute($status);
    } elsif ($biblio_id && !$status) {
        $sth->execute($biblio_id);
    } elsif ($status && $biblio_id) {
        $sth->execute($status, $biblio_id);
    } else {
        $sth->execute();
    }
    my $result = $sth->fetchrow;
    $sth->finish();
    return $result;
}

sub insertToQueue {
    my ($self, $params) = @_;
    my $dbh = $self->dbh;
    my $query = "INSERT INTO " . $self->queue . " (user_id, type, broadcast_interface, biblio_id, broadcast_biblio_id, hostrecord, componentparts, marc, diff) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
    my $sth = $dbh->prepare($query);
    $sth->execute($params->{user_id}, $params->{type}, $params->{broadcast_interface}, $params->{biblio_id}, $params->{broadcast_biblio_id}, $params->{hostrecord}, $params->{componentparts}, $params->{marc}, $params->{diff});
    $sth->finish();
}

sub updateQueueStatus {
    my ($self, $id, $status, $statusmessage) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("UPDATE " . $self->queue . " SET status = ?, statusmessage = ?, transfered_on = NOW() WHERE id = ?");
    $sth->execute($status, $statusmessage, $id);
    $sth->finish();
}

sub updateQueueStatusAndBiblioId {
    my ($self, $id, $biblio_id, $status, $statusmessage) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("UPDATE " . $self->queue . " SET biblio_id = ?, status = ?, statusmessage = ?, transfered_on = NOW() WHERE id = ?");
    $sth->execute($biblio_id, $status, $statusmessage, $id);
    $sth->finish();
}

sub getLastBiblioTransferedOn {
    my ($self, $biblio_id) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("SELECT transfered_on FROM " . $self->queue . " WHERE broadcast_biblio_id = ? ORDER BY transfered_on DESC LIMIT 1");
    $sth->execute($biblio_id);
    my $result = $sth->fetchrow_hashref;
    $sth->finish();
    return $result;
}

=head Logs

    Log database functions
            
            $db->setBroadcastLog($biblionumber, $timestamp, $type);
            my $log = $db->getBroadcastLogByBiblionumber($biblionumber);
            my $log = $db->getBroadcastLogByTimestamp($timestamp);
            my $log = $db->getBroadcastLogLatest();
    
=cut

sub setBroadcastLog {
    my ($self, $biblionumber, $timestamp, $type) = @_;

    my $dbh = $self->dbh;
    my $query = "INSERT INTO ".$self->logs." (biblionumber, updated, type) VALUES (?,?,?);";
    my $sth = $dbh->prepare($query);
    $sth->execute($biblionumber, $timestamp, $type) or die $sth->errstr;
    
}

sub getBroadcastLogByBiblionumber {
    my ($self, $biblionumber) = @_;

    my $dbh = $self->dbh;
    my $query = "SELECT * FROM ".$self->logs." WHERE biblionumber = ?;";
    my $sth = $dbh->prepare($query);
    $sth->execute($biblionumber) or die $sth->errstr; 
    my $data = $sth->fetchrow_hashref;

    return $data;
}

sub getBroadcastLogByTimestamp {
    my ($self, $timestamp) = @_;

    my $dbh = $self->dbh;
    my $query = "SELECT * FROM ".$self->logs." WHERE updated = ?;";
    my $sth = $dbh->prepare($query);
    $sth->execute($timestamp) or die $sth->errstr;
    my $data = $sth->fetchrow_hashref;
    
    return $data;
    
}

sub getBroadcastLogLatest {
    my ($self, $type) = @_;

    my $dbh = $self->dbh;
    my $query = "SELECT * FROM ".$self->logs." WHERE type = ? order by id desc limit 1;";
    my $sth = $dbh->prepare($query);
    $sth->execute($type) or die $sth->errstr;
    my $data = $sth->fetchrow_hashref;
    
    return $data;
    
}

=head Users

    User database functions
        
        my $user = $db->getUserByUserId($user_id);
        my $user = $db->getBroadcastInterfaceUser($interface, $linked_borrowernumber);
        $db->insertUser($params);
        $db->updateUser($user_id, $params);
        $db->updateAccessToken($user_id, $access_token, $token_expiry);
        my $access_token = $db->getAccessToken($user_id);

=cut

sub insertUser {
    my ($self, $params) = @_;
    my $dbh = $self->dbh;
    my $query = "INSERT INTO " . $self->users . " (auth_type, broadcast_interface, username, password, client_id, client_secret, linked_borrowernumber) VALUES (?, ?, ?, ?, ?, ?, ?)";
    my $sth = $dbh->prepare($query);
    $sth->execute($params->{auth_type}, $params->{broadcast_interface}, $params->{username}, $params->{password}, $params->{client_id}, $params->{client_secret}, $params->{linked_borrowernumber});
    $sth->finish();
}

sub updateUser {
    my ($self, $user_id, $params) = @_;
    my $dbh = $self->dbh;
    my $query = "UPDATE " . $self->users . " SET auth_type = ?, broadcast_interface = ?, username = ?, password = ?, client_id = ?, client_secret = ?, linked_borrowernumber = ? WHERE id = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute($params->{auth_type}, $params->{broadcast_interface}, $params->{username}, $params->{password}, $params->{client_id}, $params->{client_secret}, $params->{linked_borrowernumber}, $user_id);
    $sth->finish();
}

sub updateAccessToken {
    my ($self, $user_id, $access_token, $token_expires) = @_;
    my $dbh = $self->dbh;
    my $query = "UPDATE " . $self->users . " SET access_token = ?, token_expires = ? WHERE id = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute($access_token, $token_expires, $user_id);
    $sth->finish();
}

sub getAccessToken {
    my ($self, $user_id) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("SELECT access_token FROM " . $self->users . " WHERE id = ?");
    $sth->execute($user_id);
    my $result = $sth->fetchrow_hashref;
    $sth->finish();
    return $result;
}

sub getUserByUserId {
    my ($self, $user_id) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("SELECT * FROM " . $self->users . " WHERE id = ?");
    $sth->execute($user_id);
    my $result = $sth->fetchrow_hashref;
    $sth->finish();
    return $result;
}

sub getBroadcastInterfaceUser {
    my ($self, $interface, $linked_borrowernumber) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("SELECT * FROM " . $self->users . " WHERE broadcast_interface = ? AND linked_borrowernumber = ?");
    $sth->execute($interface, $linked_borrowernumber);
    my $result = $sth->fetchrow_hashref;
    $sth->finish();
    return $result;
}

1;