package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastLog;

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
use Koha::DateUtils qw( dt_from_string );
use C4::Context;

=head new

    my $broadcastLog = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::BroadcastLog->new($params);

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

    unless ($params->{table}) {
        die "Missing database table name";
    }

    return @_;
}

sub getTable {
    return shift->{_params}->{table};
}

sub setBroadcastLog {
    my ($self, $biblionumber, $timestamp) = @_;

    my $dbh = C4::Context->dbh;
    my $table = $self->getTable();
    my $query = "INSERT INTO $table (biblionumber, updated) VALUES (?,?);";
    my $sth = $dbh->prepare($query);
    $sth->execute($biblionumber, $timestamp) or die $sth->errstr;
    
}

sub getBroadcastLogByBiblionumber {
    my ($self, $biblionumber) = @_;

    my $dbh = C4::Context->dbh;
    my $table = $self->getTable();
    my $query = "SELECT * FROM $table WHERE biblionumber = ?;";
    my $sth = $dbh->prepare($query);
    $sth->execute($biblionumber) or die $sth->errstr; 
    my $data = $sth->fetchrow_hashref;

    return $data;
}

sub getBroadcastLogByTimestamp {
    my ($self, $timestamp) = @_;

    my $dbh = C4::Context->dbh;
    my $table = $self->getTable();
    my $query = "SELECT * FROM $table WHERE updated = ?;";
    my $sth = $dbh->prepare($query);
    $sth->execute($timestamp) or die $sth->errstr;
    my $data = $sth->fetchrow_hashref;
    
    return $data;
    
}

sub getBroadcastLogLatest {
    my ($self) = @_;

    my $dbh = C4::Context->dbh;
    my $table = $self->getTable();
    my $query = "SELECT * FROM $table order by id desc limit 1;";
    my $sth = $dbh->prepare($query);
    $sth->execute() or die $sth->errstr;
    my $data = $sth->fetchrow_hashref;
    
    return $data;
    
}
1;