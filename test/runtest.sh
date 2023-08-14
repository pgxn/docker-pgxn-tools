#!/bin/sh

set -eu

pgversion=$1
export GITHUB_OUTPUT="/tmp/github_output"

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

if ! grep -F "bundle=widget-1.0.0.zip" "$GITHUB_OUTPUT"; then
    echo "ERROR:  Output 'bundle' not appended to $GITHUB_OUTPUT"
    echo File:
    ls -lah "$GITHUB_OUTPUT"
    echo Contents:
    cat "$GITHUB_OUTPUT"
    exit 2
fi
