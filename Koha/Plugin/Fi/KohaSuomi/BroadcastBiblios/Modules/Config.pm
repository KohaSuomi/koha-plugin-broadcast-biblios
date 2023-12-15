package Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Config;

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
use File::Basename;
use YAML::XS;

=head new

    my $config = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Config->new($params);

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
    return shift->{_params}->{verbose};
}

sub interface {
    my ($self) = @_;
    return shift->{_params}->{interface};
}

sub getConfig {
    my ($self) = @_;

    my $configPath = $ENV{"KOHA_CONF"};
    my($file, $path, $ext) = fileparse($configPath);
    my $configfile = eval { YAML::XS::LoadFile($path.'broadcast-config.yaml') };
    if ($@) {
        warn "Error loading config file: $@";
        return undef;
    }
    return $configfile->{$self->interface} if $configfile->{$self->interface};
    return $configfile;
}

1;