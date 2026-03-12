# Test Scripts

This folder contains test utilities for the broadcast-biblios plugin.

## populate_test_data.pl

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
