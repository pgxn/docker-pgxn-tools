#!/bin/sh

set -eu

pgversion=$1

cd $(dirname "$0")
pg-start $pgversion
pg-build-test
pgxn-bundle
make clean

if [ ! -e widget-1.0.0.zip ]; then
    echo 'ERROR:  No widget-1.0.0.zip file'
    ls -lah
    exit 2
fi

rm widget-1.0.0.zip
