# Koha-Suomi plugin BroadcastBiblios

This plugin is for broadcasting biblios via REST.

# Downloading

From the release page you can download the latest \*.kpz file

# Installing

Koha's Plugin System allows for you to add additional tools and reports to Koha that are specific to your library. Plugins are installed by uploading KPZ ( Koha Plugin Zip ) packages. A KPZ file is just a zip file containing the perl files, template files, and any other files necessary to make the plugin work.

The plugin system needs to be turned on by a system administrator.

To set up the Koha plugin system you must first make some changes to your install.

:yellow_circle: Change ```<enable_plugins>0<enable_plugins>``` to ```<enable_plugins>1<enable_plugins>``` in your **koha-conf.xml** file

:yellow_circle: Confirm that the path to ```<pluginsdir>``` exists, is correct, and is writable by the web server

:yellow_circle: Remember to allow access to plugin directory from Apache

```
<Directory <pluginsdir>>
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
```

Restart your webserver

Once set up is complete you will need to alter your UseKohaPlugins system preference. On the Tools page you will see the Tools Plugins and on the Reports page you will see the Reports Plugins.

# Configuring

Settings can be found from plugin's configuration page.

# Import records

The basic workflow for import type broadcasts.

## Build active records table

To activate records on your local Koha we need to build an active records table, koha_plugin_fi_kohasuomi_broadcastbiblios_activerecords.

```sh
perl set_active_records.pl --all
```

Checked identifiers on record:
1. 035a (FI-Melinda and FI-BTJ values)
2. 020a (ISBN)
3. 024a (EAN, ISMN)
4. 003|001 (only if 003 is FI-BTJ)

Activation process will skip two types of records:
1. If record is already added to the table.
2. If record is a component part.

## Activate incoming records and try to pull record from an interface

```sh
perl set_active_records.pl -i IMPORTINTERFACE
```

:yellow_circle: This is recommended to set in crontab and run regulary.

Needed configurations:
1. Create config for the interface.
2. Create user for interface, plugin's koha_plugin_fi_kohasuomi_broadcastbiblios_users table.
    1. Create user on another Koha interface.
    1. User needs edit_catalogue permissions.
    1. Add authorization values to user. Recommended to use oauth method.

Process:
1. Will activate the record
2. Tries to fetch updated record from specified interface.
    1. If found the record is added to a plugin's queue table.

## Broadcast record from Koha to another interface.

```bash
perl fetch_broadcast_biblios.pl --block_component_parts --blocked_encoding_level "5|8|u|z"
```
:yellow_circle: This script is recommended to set in crontab and run regulary.

Needed configurations:
1. Create config for interface.
2. Create user for interface, plugin's koha_plugin_fi_kohasuomi_broadcastbiblios_users table.
    1. Create user on another Koha interface.
    1. Add authorization values to user.

Process:
1. Find recently updated records.
2. Check the activation from import interfaces.
    1. If found then push record to interface's queue table.

# Export records

The basic workflow for export type broadcasts.

## Handle exports and imports from record detail page.

First define export interface on configurations. The interface should show up to record page under "Vie/Tuo" dropdown.
Search records from remote interface and export/import them.

# Process queues

To process queues add process_broadcast_queue.pl to crontab.

## Process only import queue

Records processed with **set_active_records.pl** or **fetch_broadcast_biblios.pl** are import type broadcasts.

```sh
perl process_broadcast_queue.pl -t import
```

:yellow_circle: This script will process the broadcast queue and updates the records. Should be run regulary on crontab.

## Process only export queue

```sh
perl process_broadcast_queue.pl -t export
```

:yellow_circle: This script will process the broadcast queue and exports to remote interface. Should be run regulary on crontab.

If you want to update records in local Koha after export then the script needs a --update flag

```sh
perl process_broadcast_queue.pl -t export --update
```

## Process both import and export queues

If your Koha exports and imports then you need to process both queues at once.

```sh
perl process_broadcast_queue.pl --update
```

:yellow_circle: This script will process the broadcast queue. Should be run regulary on crontab.