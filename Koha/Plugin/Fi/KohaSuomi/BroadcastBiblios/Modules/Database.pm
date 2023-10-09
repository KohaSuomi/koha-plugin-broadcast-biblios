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

sub dbh {
    my ($self) = @_;
    return C4::Context->dbh;
}

sub getActiveRecordByBiblionumber {
    my ($self, $biblionumber) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("SELECT * FROM " . $self->activerecords . " WHERE biblionumber = ?");
    $sth->execute($biblionumber);
    my $result = $sth->fetchrow_hashref;
    $sth->finish();
    return $result;
}

sub getActiveRecordByIdentifier {
    my ($self, $identifier, $identifier_field) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("SELECT * FROM " . $self->activerecords . " WHERE identifier = ? AND identifier_field = ?");
    $sth->execute($identifier, $identifier_field);
    my $result = $sth->fetchrow_hashref;
    $sth->finish();
    return $result;
}

sub insertActiveRecord {
    my ($self, $biblionumber, $identifier, $identifier_field, $updated_on) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare("INSERT INTO " . $self->activerecords . " (biblionumber, identifier, identifier_field, updated_on) VALUES (?, ?, ?, ?)");
    $sth->execute($biblionumber, $identifier, $identifier_field, $updated_on);
    $sth->finish();
}

1;