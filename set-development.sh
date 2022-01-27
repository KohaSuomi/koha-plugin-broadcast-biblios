#!/bin/bash

kohaplugindir="$(grep -Po '(?<=<pluginsdir>).*?(?=</pluginsdir>)' $KOHA_CONF)"

rm -r $kohaplugindir/Koha/Plugin/Fi/KohaSuomi/BroadcastBiblios
rm $kohaplugindir/Koha/Plugin/Fi/KohaSuomi/BroadcastBiblios.pm

ln -s "/home/jraisa//koha-plugin-broadcast-biblios/Koha/Plugin/Fi/KohaSuomi/BroadcastBiblios" $kohaplugindir/Koha/Plugin/Fi/KohaSuomi/BroadcastBiblios
ln -s "/home/jraisa//koha-plugin-broadcast-biblios/Koha/Plugin/Fi/KohaSuomi/BroadcastBiblios.pm" $kohaplugindir/Koha/Plugin/Fi/KohaSuomi/BroadcastBiblios.pm

DATABASE=`xmlstarlet sel -t -v 'yazgfs/config/database' $KOHA_CONF`
HOSTNAME=`xmlstarlet sel -t -v 'yazgfs/config/hostname' $KOHA_CONF`
PORT=`xmlstarlet sel -t -v 'yazgfs/config/port' $KOHA_CONF`
USER=`xmlstarlet sel -t -v 'yazgfs/config/user' $KOHA_CONF`
PASS=`xmlstarlet sel -t -v 'yazgfs/config/pass' $KOHA_CONF`

PM_FILE="Koha/Plugin/Fi/KohaSuomi/BroadcastBiblios.pm"
VERSION=`grep -oE "\-?[0-9]+\.[0-9]+\.[0-9]" $PM_FILE | head -1`

mysql --user=$USER --password="$PASS" --port=$PORT --host=$HOST $DATABASE << END
DELETE FROM plugin_data where plugin_class = 'Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios';
DELETE FROM plugin_methods where plugin_class = 'Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios';
INSERT INTO plugin_data (plugin_class,plugin_key,plugin_value) VALUES ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios','__INSTALLED__','1');
INSERT INTO plugin_data (plugin_class,plugin_key,plugin_value) VALUES ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios','__INSTALLED_VERSION__','${VERSION}');
INSERT INTO plugin_data (plugin_class,plugin_key,plugin_value) VALUES ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios','__ENABLED__','1');

INSERT INTO plugin_methods (plugin_class, plugin_method) values 
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'abs_path'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'api_namespace'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'api_routes'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'as_heavy'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'bundle_path'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'canonpath'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'catdir'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'catfile'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'curdir'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'configure'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'decode_json'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'disable'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'enable'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'except'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'export'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'export_fail'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'export_ok_tags'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'export_tags'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'export_to_level'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'file_name_is_absolute'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'get_metadata'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'get_plugin_dir'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'get_plugin_http_path'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'get_qualified_table_name'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'get_template'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'go_home'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'import'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'install'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'intranet_catalog_biblio_enhancements_toolbar_button'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'is_enabled'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'max'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'mbf_dir'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'mbf_exists'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'mbf_open'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'mbf_path'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'mbf_read'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'mbf_validate'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'new'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'no_upwards'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'only'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'output'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'output_html'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'output_html_with_http_headers'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'output_with_http_headers'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'path'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'plugins'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'require_version'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'retrieve_data'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'rootdir'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'search_path'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'store_data'),
     ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios', 'updir');

END

