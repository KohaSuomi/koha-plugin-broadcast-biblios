#!/bin/bash

PM_FILE="Koha/Plugin/Fi/KohaSuomi/BroadcastBiblios.pm"
VERSION=`grep -oE "\-?[0-9]+\.[0-9]+" $PM_FILE | head -1`
RELEASE_FILE="koha-plugin-broadcast-biblios-v${VERSION}.kpz"

rm $RELEASE_FILE

echo "Building release package ${RELEASE_FILE}"

zip -r $RELEASE_FILE ./Koha