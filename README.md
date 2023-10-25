# Koha-Suomi plugin BroadcastBiblios

This plugin is for broadcasting biblios via REST.

# Downloading

From the release page you can download the latest \*.kpz file

# Installing

Koha's Plugin System allows for you to add additional tools and reports to Koha that are specific to your library. Plugins are installed by uploading KPZ ( Koha Plugin Zip ) packages. A KPZ file is just a zip file containing the perl files, template files, and any other files necessary to make the plugin work.

The plugin system needs to be turned on by a system administrator.

To set up the Koha plugin system you must first make some changes to your install.

    Change <enable_plugins>0<enable_plugins> to <enable_plugins>1</enable_plugins> in your koha-conf.xml file
    Confirm that the path to <pluginsdir> exists, is correct, and is writable by the web server
    Remember to allow access to plugin directory from Apache

    <Directory <pluginsdir>>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    Restart your webserver

Once set up is complete you will need to alter your UseKohaPlugins system preference. On the Tools page you will see the Tools Plugins and on the Reports page you will see the Reports Plugins.

# Configuring

For interface broadcast define broadcast-config.yaml to KOHA_CONF path.

```yaml
MYEXPORTINTERFACE:
  interface_name: "TATI"
  type: "export"
  user_id: 1
  rest:
    baseUrl: http://127.0.0.1:8080/api/v1/contrib/kohasuomi
    inactivityTimeout: 60000
    findBiblios: 
      path: broadcast/biblios
      method: post
    findActiveBiblios:
      path: broadcast/biblios/active
      method: get
    setToQueue:
      path: broadcast/queue
      method: post
  sru:
    baseUrl: http://
MYIMPORTINTERFACE:
  interface_name: "OUTI"
  type: "import"
  user_id: 1
  rest:
    baseUrl: http://127.0.0.1:8080/api/v1/contrib/kohasuomi
    inactivityTimeout: 60000
    findBiblios: 
      path: broadcast/biblios
      method: post
    findActiveBiblios:
      path: broadcast/biblios/active
      method: get
    setToQueue:
      path: broadcast/queue
      method: post
  sru:
    baseUrl: http://
```



For UI export and import define interfaces to plugin configuration as YAML. When these are defined the export/import dropdown will appear to record detail page.

Example of export interfaces. Type can be export or import, if set import then you can only import records from the remote sources.

```yaml
---
-   host: https://foobaa.fi
    basePath: /service/api/biblio/export
    searchPath: /service/api/biblio/search
    reportPath: /service/api/biblio
    interface: MyExport
    interfaceName: Api of mine
    apiToken: foobaa
    type: export
-   host: https://foobaa.fi
    basePath: /service/api/biblio/export
    searchPath: /service/api/biblio/search
    reportPath: /service/api/biblio
    interface: OnlyImports
    interfaceName: Import this
    apiToken: foobaa
    type: import
```

Example of import interface. Import interface is defined so the background service nows where to import. Activation parameter can be enabled for record activation on detail screen.

```yaml
host: https://foobaa.fi
basePath: /service/api/biblio/export
searchPath: /service/api/biblio/search
reportPath: /service/api/biblio
interface: OUTI
apiToken: foobaa
activation: enabled
```

# Update records on your local Koha

The basic workflow for import type broadcasts.

## Build active records table

To activate records on your local Koha we need to build an active records table, koha_plugin_fi_kohasuomi_broadcastbiblios_activerecords.

```sh
perl set_active_records.pl --all
```

This will activate all records which have specific identifier, the identifiers are

1. 035a (only if it has FI-Melinda value)
2. 020a (ISBN)
3. 024a (EAN, ISMN)
4. 003|001 (only if 003 is FI-BTJ)

Activation process will skip two types of records.

1. If record is already added to the table.
2. If record is a component part.

## Activate incoming records and try to pull record from an interface

```sh
perl set_active_records.pl -i INTERFACENAME
```

This will activate the record and trying to fetch a updated record from an interface. If found the record is added to a queue table.
This is recommended to set in crontab and run regulary.

## Broadcast record from Koha to another interface.

```bash
perl fetch_broadcast_biblios.pl --block_component_parts
```
This script is recommended to set in crontab and run regulary.

Process:
1. Find recently updated records.
2. Check the activation from import interfaces (broadcast-config.yaml).
    1. If found then push record to interface's queue table.

## Process import queue

Records processed with **set_active_records.pl** or **fetch_broadcast_biblios.pl** are import type broadcasts.

```sh
perl process_queue.pl -t import
```

This script will process the broadcast queue and updates the records. Should be run regulary on crontab.