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

mysql --user=$USER --password="$PASS" --port=$PORT --host=$HOST $DATABASE << END
DELETE FROM plugin_data where plugin_class = 'Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios';
INSERT INTO plugin_data (plugin_class,plugin_key,plugin_value) VALUES ('Koha::Plugin::Fi::KohaSuomi::BroadcastBiblios','__INSTALLED__','1');
END

