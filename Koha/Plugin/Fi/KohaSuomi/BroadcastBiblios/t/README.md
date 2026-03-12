# Test Scripts

This folder contains test utilities and unit tests for the broadcast-biblios plugin.

## Unit Tests

### oai-sets.t
Comprehensive test for OAI set building functionality:
- OAI module instantiation and parameter handling
- OAI set creation with spec and name
- Retrieving existing OAI sets by spec
- Adding biblios to OAI sets
- Preventing duplicate biblios from being added to the same set
- Verifying biblio-to-set associations

**Run the test:**
```bash
perl oai-sets.t
```

### biblios-imported-records.t
Tests the `importedRecords()` method with component part filtering:
- Fetching all imported biblios (no filters)
- Filtering records with `no_components=1` flag (excludes hosts with components and component parts)
- Filtering records with `hosts_with_components=1` flag (returns only hosts and their components)
- Verifying that component parts with 773$w fields are correctly detected
- Ensuring orphan component parts (pointing to non-existent hosts) are also excluded

**Key features:**
- Uses `Test::MockModule` to mock `ComponentParts->fetch()` for deterministic testing
- No external search index required—component relationships are mocked
- Tests both positive cases (inclusions) and negative cases (exclusions)

**Run the test:**
```bash
perl biblios-imported-records.t
```

**Run all unit tests:**
```bash
prove -v *.t
```

**Test Dependencies:**
```bash
cpanm Test::MockModule Test::MockObject Test::Exception
```

---

## Test Data Scripts

### populate_test_data.pl

Creates test data for the OAI set cleaning script.

### Usage

**Create test data:**
```bash
perl populate_test_data.pl --verbose
```

**Remove test data:**
```bash
perl populate_test_data.pl --clean --verbose
```

### What it creates

- **OAI Set:** TEST-Kaunokirjallisuus (spec: TEST:fiction)
- **10 Biblios:**
  - 5 regular biblios (books without component part markers)
  - 5 component parts (articles/chapters with 773$w field)

All test biblios are linked to the test OAI set.

### Testing workflow

1. Create test data:
   ```bash
   perl populate_test_data.pl --verbose
   ```

2. Clean up:
   ```bash
   cd t/
   perl populate_test_data.pl --clean --verbose
   ```

## Test Data Details

### Regular Biblios (5)
- Taru sormusten herrasta
- Hobitti
- Kalevala
- Tuntematon sotilas
- Seitsemän veljestä

### Component Parts (5)
These have 773$w field indicating they are parts of a larger work:
- Artikkeli 1: Fantasiakirjallisuuden merkitys
- Artikkeli 2: Tolkienin vaikutus moderniin fantasiaan
- Luku 3: Hobittien historia
- Essee: Kalevalan kieli
- Artikkeli 3: Sota-ajan kuvaus suomalaisessa kirjallisuudessa

## Notes

- Test data uses "TEST-" prefix in set names to clearly identify it
- The populate script uses C4::Biblio::AddBiblio() to create proper MARC records
- Component parts include realistic 773 fields with host titles
- All biblios get random ISBNs and basic MARC fields

## Testing Approach: Mocking ComponentParts

The `biblios-imported-records.t` test uses `Test::MockModule` to mock the `ComponentParts->fetch()` method. This approach has several advantages:

### Why Mocking?

By default, `ComponentParts->fetch()` uses Koha's search engine (Elasticsearch or Zebra) to find component parts linked via MARC 773 fields. In a test environment:
- A running search index may not be available
- Search index updates are asynchronous and slow
- Tests should be isolated and deterministic

### How It Works

The mock intercepts calls to `ComponentParts->fetch()` and returns predefined component relationships:

```perl
my $componentparts_mock = Test::MockModule->new('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios::Modules::ComponentParts');
$componentparts_mock->mock('fetch', sub {
    my ($self, $biblionumber) = @_;
    # Return component relationships based on test fixtures
    if ($biblionumber == $host_biblionumber) {
        return [ { biblionumber => $component_biblionumber, marcxml => ... } ];
    }
    return undef;
});
```

### For Future Tests

If you need to test with a **live search index**, you can:
1. Skip the mock setup
2. Ensure Elasticsearch/Zebra is running and indexed
3. Allow time for indexing to complete

Otherwise, extend the mock's conditional logic to cover your specific test scenarios.
