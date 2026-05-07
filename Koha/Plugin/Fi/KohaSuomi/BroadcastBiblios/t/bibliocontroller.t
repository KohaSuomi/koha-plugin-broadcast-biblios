#!/usr/bin/perl

# Copyright 2026 Koha-Suomi Oy
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

use Test::More tests => 6;
use Test::Mojo;
use Test::MockModule;
use MARC::Record;
use MARC::Field;
use C4::Biblio qw( AddBiblio ModBiblio GetFrameworkCode);
use C4::Context;
use Koha::Database;
use t::lib::TestBuilder;
use t::lib::Mocks;
use Koha::Biblios;

my $schema = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

# Mock RESTBasicAuth preference
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $t = Test::Mojo->new('Koha::REST::V1');

subtest 'get() tests' => sub {
    plan tests => 7;

    $schema->storage->txn_begin;

    # Create test patron with permissions
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }  # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    # Create a test biblio
    my $record = MARC::Record->new();
    $record->leader('00000nam a22000007a 4500');
    $record->append_fields(
        MARC::Field->new('001', 'TEST001'),
        MARC::Field->new('003', 'TEST'),
        MARC::Field->new('245', '', '', a => 'Test Title'),
        MARC::Field->new('020', '', '', a => '978-0-123456-78-9'),
    );
    my ($biblionumber) = AddBiblio($record, '');
    ok($biblionumber, 'Test biblio created with biblionumber ' . $biblionumber);

    # Test successful GET request
    $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/biblios/$biblionumber")
        ->status_is(200)
        ->json_has('/biblionumber')
        ->json_is('/biblionumber' => $biblionumber);

    # Test non-existent biblio
    my $non_existent_id = $biblionumber + 999;
    $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/biblios/$non_existent_id")
        ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'find() tests' => sub {
    plan tests => 8;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }
        }
    );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    # Create test biblio with identifiable ISBN
    my $isbn = '978-1-234567-89-0';
    my $record = MARC::Record->new();
    $record->leader('00000nam a22000007a 4500');
    $record->append_fields(
        MARC::Field->new('001', 'FIND001'),
        MARC::Field->new('003', 'TEST'),
        MARC::Field->new('245', '', '', a => 'Findable Book'),
        MARC::Field->new('020', '', '', a => $isbn),
    );
    my ($biblionumber) = AddBiblio($record, '');
    ok($biblionumber, 'Test biblio created');

    # Test finding by identifier with fallback biblio_id
    my $body = {
        biblio_id => $biblionumber,
        identifiers => [
            {
                identifier => $isbn,
                identifier_field => '020$a'
            }
        ]
    };

    $t->post_ok("//$userid:$password@/api/v1/contrib/kohasuomi/broadcast/biblios" 
        => json => $body)
        ->status_is(200)
        ->json_has('/biblionumber')
        ->json_has('/marcxml')
        ->json_is('/biblionumber' => $biblionumber);

    # Test with non-existent identifier and no biblio_id
    my $not_found_body = {
        identifiers => [
            {
                identifier => '999-9-999999-99-9',
                identifier_field => '020$a'
            }
        ]
    };

    $t->post_ok("//$userid:$password@/api/v1/contrib/kohasuomi/broadcast/biblios" 
        => json => $not_found_body)
        ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {
    plan tests => 7;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }
        }
    );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    # Create valid MARCXML
    my $record = MARC::Record->new();
    $record->leader('00000nam a22000007a 4500');
    $record->append_fields(
        MARC::Field->new('001', 'ADD001'),
        MARC::Field->new('003', 'TEST'),
        MARC::Field->new('245', '', '', a => 'New Book to Add'),
        MARC::Field->new('020', '', '', a => '978-2-345678-90-1'),
    );
    my $marcxml = $record->as_xml_record();

    # Test successful add
    $t->post_ok("//$userid:$password@/api/v1/contrib/kohasuomi/biblios" 
        => $marcxml)
        ->status_is(201)
        ->json_has('/biblio_id');

    my $created_id = $t->tx->res->json->{biblio_id};
    ok($created_id, 'Biblio ID returned');

    # Verify the biblio was actually created
    my $created_biblio = Koha::Biblios->find($created_id);
    ok($created_biblio, 'Biblio was created in database');

    # Test with empty body
    $t->post_ok("//$userid:$password@/api/v1/contrib/kohasuomi/biblios" 
        => '')
        ->status_is(400);

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {
    plan tests => 7;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }
        }
    );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    # Create initial biblio
    my $record = MARC::Record->new();
    $record->leader('00000nam a22000007a 4500');
    $record->append_fields(
        MARC::Field->new('001', 'UPDATE001'),
        MARC::Field->new('003', 'TEST'),
        MARC::Field->new('245', '', '', a => 'Original Title'),
        MARC::Field->new('020', '', '', a => '978-3-456789-01-2'),
    );
    my ($biblionumber) = AddBiblio($record, '');
    ok($biblionumber, 'Initial biblio created');

    # Create updated MARCXML with new title
    my $updated_record = MARC::Record->new();
    $updated_record->leader('00000nam a22000007a 4500');
    $updated_record->append_fields(
        MARC::Field->new('001', 'UPDATE001'),
        MARC::Field->new('003', 'TEST'),
        MARC::Field->new('245', '', '', a => 'Updated Title'),
        MARC::Field->new('020', '', '', a => '978-3-456789-01-2'),
    );
    my $updated_marcxml = $updated_record->as_xml_record();

    # Test successful update
    $t->put_ok("//$userid:$password@/api/v1/contrib/kohasuomi/broadcast/biblios/$biblionumber" 
        => $updated_marcxml)
        ->status_is(200)
        ->json_has('/biblio');

    # Verify the update was applied
    my $updated_biblio = Koha::Biblios->find($biblionumber);
    ok($updated_biblio, 'Biblio still exists after update');

    # Test update of non-existent biblio
    my $non_existent_id = $biblionumber + 999;
    $t->put_ok("//$userid:$password@/api/v1/contrib/kohasuomi/broadcast/biblios/$non_existent_id" 
        => $updated_marcxml)
        ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'getBroadcastBiblio() tests' => sub {
    plan tests => 10;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }
        }
    );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    # Create test biblio
    my $record = MARC::Record->new();
    $record->leader('00000nam a22000007a 4500');
    $record->append_fields(
        MARC::Field->new('001', 'BROADCAST001'),
        MARC::Field->new('245', '', '', a => 'Broadcast Test'),
        MARC::Field->new('020', '', '', a => '978-4-567890-12-3'),
    );
    my ($biblionumber) = AddBiblio($record, '');
    ok($biblionumber, 'Test biblio created');

    # Test with MARCXML format (default)
    $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/broadcast/biblios/$biblionumber")
        ->status_is(200)
        ->json_has('/biblionumber')
        ->json_has('/marcxml');

    # Test with MARC-in-JSON format
    $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/broadcast/biblios/$biblionumber"
        => { Accept => 'application/marc-in-json' })
        ->status_is(200)
        ->json_has('/marcjson');

    # Test non-existent biblio
    my $non_existent_id = $biblionumber + 999;
    $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/broadcast/biblios/$non_existent_id")
        ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'getcomponentparts() tests' => sub {
    plan tests => 11;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }
        }
    );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    # Create host record
    my $host_record = MARC::Record->new();
    $host_record->leader('00000nam a22000007a 4500');
    $host_record->append_fields(
        MARC::Field->new('001', 'HOST999'),
        MARC::Field->new('003', 'TEST'),
        MARC::Field->new('245', '', '', a => 'Journal of Testing'),
    );
    my ($host_biblionumber) = AddBiblio($host_record, '');
    ok($host_biblionumber, 'Host record created');

    # Create component part
    my $component_record = MARC::Record->new();
    $component_record->leader('00000naa a22000007a 4500');
    $component_record->append_fields(
        MARC::Field->new('001', 'COMP999'),
        MARC::Field->new('003', 'TEST'),
        MARC::Field->new('245', '', '', a => 'Test Article'),
        MARC::Field->new('773', '0', '', 
            w => 'HOST999',
            t => 'Journal of Testing'
        ),
    );
    my ($component_biblionumber) = AddBiblio($component_record, '');
    ok($component_biblionumber, 'Component part created');

    # Test getting component parts
    $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/biblios/$host_biblionumber/componentparts")
        ->status_is(200)
        ->json_has('/biblio')
        ->json_has('/componentparts')
        ->json_is('/biblio/biblionumber' => $host_biblionumber);

    # Test with biblio that has no component parts
    my $standalone_record = MARC::Record->new();
    $standalone_record->leader('00000nam a22000007a 4500');
    $standalone_record->append_fields(
        MARC::Field->new('245', '', '', a => 'Standalone Book'),
    );
    my ($standalone_biblionumber) = AddBiblio($standalone_record, '');
    
    $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/biblios/$standalone_biblionumber/componentparts")
        ->status_is(200);

    # Test non-existent biblio
    my $non_existent_id = $host_biblionumber + 999;
    $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/biblios/$non_existent_id/componentparts")
        ->status_is(404);

    $schema->storage->txn_rollback;
};

1;
