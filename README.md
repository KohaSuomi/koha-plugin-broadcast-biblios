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

Define export and import interfaces to plugin configuration as YAML.

Example of export interfaces. Type can be export or import, if set import then you can only import records from the remote sources.

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

Example of import interface. Import interface is defined so the service nows where to import. Activation parameter can be enabled for record activation on detail screen.

    host: https://foobaa.fi
    basePath: /service/api/biblio/export
    searchPath: /service/api/biblio/search
    reportPath: /service/api/biblio
    interface: OUTI
    apiToken: foobaa
    activation: enabled
