#!/bin/bash

PM_FILE="Koha/Plugin/Fi/KohaSuomi/BroadcastBiblios.pm"
VERSION=`grep -oE "\-?[0-9]+\.[0-9]+\.[0-9]" $PM_FILE | head -1`
MINVERSION=`grep -oE "\-?[0-9]+\.[0-9][0-9]" $PM_FILE | head -1`
RELEASE_FILE="koha-plugin-broadcast-biblios-v${VERSION}.kpz"
CURRENT_BRANCH=`git rev-parse --abbrev-ref HEAD`
if [ "$CURRENT_BRANCH" == "master" ]; then
    VERSIONTAG=`git tag -l "v${VERSION}-koha-$MINVERSION"`
else
    VERSIONTAG=`git tag -l "v${VERSION}-koha-$MINVERSION-$CURRENT_BRANCH"`
fi

if [ $VERSIONTAG ]; then
    echo "Release version already exists!"
    exit 1
fi

rm $RELEASE_FILE

echo "Building release package ${RELEASE_FILE}"

zip -r $RELEASE_FILE ./Koha

echo "Creating tag v${VERSION}-koha-$MINVERSION"
if [ "$CURRENT_BRANCH" == "master" ]; then
    git tag -a "v${VERSION}-koha-$MINVERSION" -m "Release ${VERSION}"
else
    git tag -a "v${VERSION}-koha-$MINVERSION-$CURRENT_BRANCH" -m "Release ${VERSION}-$CURRENT_BRANCH"
fi