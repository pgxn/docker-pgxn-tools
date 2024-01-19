#!/bin/sh

set -eu

pgversion=$1
expectgit=${2:-yes}
export GITHUB_OUTPUT="/tmp/github_output"
zipfile=widget-1.0.0.zip

cd $(dirname "$0")
pg-start $pgversion
pg-build-test
pgxn-bundle
make clean

if [ ! -e $zipfile ]; then
    echo 'ERROR:  No $zipfile file'
    ls -lah
    exit 2
fi

if [ "$expectgit" = "yes" ]; then
    # Make sure runtest.sh was omitted thanks to .gitattributes.
    if unzip -l $zipfile | grep -F runtest.sh; then
        echo 'ERROR:  Zip file contains runtests.sh and should not'
        echo '        Did pgxn-bundle use `zip` instead of `git archive`?'
        exit 2
    fi
else
    # Make sure runtest.sh include in the zip file.
    if ! unzip -l $zipfile | grep -F runtest.sh; then
        echo 'ERROR:  Zip file contains runtests.sh and should not'
        echo '        Did pgxn-bundle use `git archive` instead of `zip`?'
        exit 2
    fi
fi

rm $zipfile

if ! grep -F "bundle=$zipfile" "$GITHUB_OUTPUT"; then
    echo "ERROR:  Output 'bundle' not appended to $GITHUB_OUTPUT"
    echo File:
    ls -lah "$GITHUB_OUTPUT"
    echo Contents:
    cat "$GITHUB_OUTPUT"
    exit 2
fi
