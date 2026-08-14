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

use Test::More tests => 5;
use Test::MockModule;
use MARC::Record;
use MARC::Field;
use C4::Biblio;
use C4::Context;
use Koha::Database;
use Koha::ActionLogs;

BEGIN {
    use_ok( 'Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios' );
}

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

# Build the record exactly as Koha would have logged it before a MODIFY
my $original = MARC::Record->new();
$original->leader('00880nam a2200241 i 4500');
my $war = MARC::Field->new('650', ' ', '0', a => 'War', x => 'Napoleonic');
$war->add_subfields( x => 'Peninsular' ); # repeated subfield code within one field

# Finnish cataloguing case: repeated $e in 100/700, repeated $t in 505 and 880 fields
my $main_entry = MARC::Field->new('100', '1', ' ', a => 'Virtanen, Matti', e => 'toimittaja');
$main_entry->add_subfields( e => 'kuvittaja' );
my $secondary_entry = MARC::Field->new('700', '1', ' ', a => 'Korhonen, Liisa', e => 'suomentaja');
$secondary_entry->add_subfields( e => 'jälkikirjoittaja' );
my $contents = MARC::Field->new('505', '0', ' ', a => 'Sisältö', t => 'Ensimmäinen luku');
$contents->add_subfields( t => 'Toinen luku', t => 'Kolmas luku' );

$original->append_fields(
    MARC::Field->new('001', '12345'),
    MARC::Field->new('003', 'OCoLC'),
    MARC::Field->new('008', '960523s1996    nyu           000 0 eng  '),
    $main_entry,
    MARC::Field->new('245', '1', '0', a => 'The book', b => 'volume one'),
    $contents,
    MARC::Field->new('650', ' ', '0', a => 'History', x => '19th century', y => 'England'),
    MARC::Field->new('650', ' ', '0', a => 'Romance', x => 'Fiction'),
    $war,
    # 880 fields link to the preceding field; each must keep its own subfields
    MARC::Field->new('880', ' ', '0', '6' => '650-01', a => 'Historia', x => '1800-luku'),
    MARC::Field->new('700', '1', ' ', a => 'Doe, John', d => '1900-1980'),
    MARC::Field->new('700', '1', ' ', a => 'Roe, Jane', d => '1910-1990'),
    $secondary_entry,
    # repeated 700 with $t/$l must stay on their own field, not spread to all 700s
    MARC::Field->new('700', '1', ' ', a => 'Analyzer, Ada', d => '1900-1980', t => 'The book', l => 'English'),
    MARC::Field->new('700', '1', ' ', a => 'Evaluator, Eve', d => '1910-1990', t => 'The book', l => 'Finnish'),
    MARC::Field->new('880', ' ', '0', '6' => '700-01', a => 'Korhonen, Liisa', e => 'kääntäjä'),
    MARC::Field->new('880', ' ', '0', '6' => '700-02', a => 'Korhonen, Liisa', e => 'toimittaja'),
    MARC::Field->new('020', ' ', ' ', a => '123456789X'),
    MARC::Field->new('020', ' ', ' ', a => '0987654321', q => 'paperback'),
    MARC::Field->new('520', ' ', ' ', a => 'Read the manual => see page 5'),
);

my $info = 'biblio  BEFORE=>' . $original->as_formatted();

{
    package ActionLogStub;
    sub new    { my ($class, $info, $object) = @_; return bless { info => $info, object => $object }, $class; }
    sub info   { return shift->{info}; }
    sub object { return shift->{object}; }
}

my $captured_record;
my $actionlog_mock = Test::MockModule->new('Koha::ActionLogs');
$actionlog_mock->mock( 'find', sub { return ActionLogStub->new($info, 42); } );

my $biblio_mock = Test::MockModule->new('C4::Biblio');
$biblio_mock->mock( 'TransformMarcToKoha',         sub { return {}; } );
$biblio_mock->mock( 'GetFrameworkCode',            sub { return ''; } );
$biblio_mock->mock( '_koha_modify_biblio',         sub { } );
$biblio_mock->mock( '_koha_modify_biblioitem_nonmarc', sub { } );

# ModBiblioMarc is imported into the module, so the bareword call inside
# restoreRecordFromActionLog must be mocked in the module's namespace
my $module_mock = Test::MockModule->new('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios');
$module_mock->mock( 'ModBiblioMarc', sub {
    my ($record, $biblionumber) = @_;
    $captured_record = $record;
    return 42;
} );

my $biblios = Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::Biblios->new();
my $biblio_id = $biblios->restoreRecordFromActionLog(1);

is( $biblio_id, 42, 'restoreRecordFromActionLog returns the biblio id from ModBiblioMarc' );

isa_ok( $captured_record, 'MARC::Record', 'Parsed record captured from ModBiblioMarc' );
is( $captured_record->as_formatted, $original->as_formatted, 'Parsed record matches the original record, including repeated fields' );

is( $captured_record->leader, $original->leader, 'Leader is restored correctly' );

$schema->storage->txn_rollback;

done_testing();
