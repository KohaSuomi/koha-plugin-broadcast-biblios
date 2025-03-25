#!/bin/sh

die() { echo "$@"; exit 1; }

# Switch to root
if test "$(whoami)" != "root"; then
  sudo -uroot $0
  exit $!
fi

# Get config if we don't have it
test -z "$KOHA_CONF" -o -z "$KOHA_PATH" && . /etc/environment
test -z "$KOHA_CONF" -o -z "$KOHA_PATH" && die "No KOHA_CONF or KOHA_PATH."

# Find dirs (plugin home and koha plugins directory)
kohaplugindir="$(grep -Po '(?<=<pluginsdir>).*?(?=</pluginsdir>)' $KOHA_CONF)"
mypath="$(dirname $(readlink -f $0))"

# Make links
ln -svfn $mypath/Koha/Plugin/Fi/KohaSuomi/* $kohaplugindir/Koha/Plugin/Fi/KohaSuomi/

echo "Setting permissions for www-data"
sudo chown -R www-data:www-data $kohaplugindir/Koha/Plugin/Fi/KohaSuomi/

# Install plugins as koha
sudo -ukoha $KOHA_PATH/misc/devel/install_plugins.pl

# Get package name
# package_name=$(grep -Po '(?<=package\s).*?(?=\s*;)' $mypath/Koha/Plugin/Fi/KohaSuomi/*.pm)

# Disable plugin
# echo "Disabling plugin $package_name"
# sudo -ukoha perl $KOHA_PATH/../koha-suomi-utility/misc/manage_plugins.pl --disable "$package_name"