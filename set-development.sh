#!/bin/bash

kohaplugindir="$(grep -Po '(?<=<pluginsdir>).*?(?=</pluginsdir>)' $KOHA_CONF)"
kohadir="$(grep -Po '(?<=<intranetdir>).*?(?=</intranetdir>)' $KOHA_CONF)"

rm -r $kohaplugindir/Koha/Plugin/Fi/KohaSuomi/BroadcastBiblios
rm $kohaplugindir/Koha/Plugin/Fi/KohaSuomi/BroadcastBiblios.pm

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

ln -s "$SCRIPT_DIR/Koha/Plugin/Fi/KohaSuomi/BroadcastBiblios" $kohaplugindir/Koha/Plugin/Fi/KohaSuomi/BroadcastBiblios
ln -s "$SCRIPT_DIR/Koha/Plugin/Fi/KohaSuomi/BroadcastBiblios.pm" $kohaplugindir/Koha/Plugin/Fi/KohaSuomi/BroadcastBiblios.pm

perl $kohadir/misc/devel/install_plugins.pl

