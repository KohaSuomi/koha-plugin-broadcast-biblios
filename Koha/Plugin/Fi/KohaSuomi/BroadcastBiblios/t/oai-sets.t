#!/usr/bin/perl

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
use FindBin qw($Bin);
use lib "$Bin/../../../../../..";

use Test::More tests => 4;
use Test::MockModule;
use Test::MockObject;

BEGIN {
    use_ok( 'Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::OAI' );
}

subtest 'OAI module instantiation' => sub {
    plan tests => 3;
    
    my $oai = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::OAI->new({
        set_spec => 'test:spec',
        set_name => 'Test Set Name',
        date => '2026-03-12',
        verbose => 1
    });
    
    ok( $oai, 'OAI object created' );
    isa_ok( $oai, 'Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::OAI' );
    is( $oai->getSetSpec(), 'test:spec', 'Set spec is correctly stored' );
};

subtest 'OAI set parameters' => sub {
    plan tests => 5;
    
    my $oai = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::OAI->new({
        set_spec => 'broadcast:melinda',
        set_name => 'Broadcast to Melinda',
        date => '2026-03-12',
        verbose => 1,
        no_components => 1
    });
    
    is( $oai->getSetSpec(), 'broadcast:melinda', 'Set spec is retrieved correctly' );
    is( $oai->getSetName(), 'Broadcast to Melinda', 'Set name is retrieved correctly' );
    is( $oai->getDate(), '2026-03-12', 'Date is retrieved correctly' );
    is( $oai->verbose(), 1, 'Verbose flag is retrieved correctly' );
    is( $oai->getNoComponents(), 1, 'No components flag is retrieved correctly' );
};

# Test 3: Verify getOAISetsBiblio query behavior with mock database
subtest 'getOAISetsBiblio query' => sub {
    plan tests => 3;
    
    # Mock the database connection
    my $c4_context_module = Test::MockModule->new('C4::Context');
    
    my $executed_query;
    my @executed_params;
    
    my $mock_sth = Test::MockObject->new();
    $mock_sth->mock('execute', sub {
        my ($self, @params) = @_;
        @executed_params = @params;
        return 1;
    });
    $mock_sth->mock('fetchall_arrayref', sub {
        return [{ id => 1, spec => 'test:spec', name => 'Test', biblionumber => 123 }];
    });
    
    my $mock_dbh = Test::MockObject->new();
    $mock_dbh->mock('prepare', sub {
        my ($self, $query) = @_;
        $executed_query = $query;
        return $mock_sth;
    });
    
    $c4_context_module->mock('dbh', sub { return $mock_dbh; });
    
    # Call the static method
    my $result = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::OAI::getOAISetsBiblio(123, 'test:spec', 'Test Set');
    
    ok( $executed_query =~ /SELECT oai_sets\.\*/, 'Query selects from oai_sets' );
    ok( $executed_query =~ /LEFT JOIN oai_sets_biblios/, 'Query joins oai_sets_biblios' );
    is_deeply( \@executed_params, [123, 'test:spec', 'Test Set'], 'Correct parameters passed to query' );
};


