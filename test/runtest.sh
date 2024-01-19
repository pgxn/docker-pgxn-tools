#!/bin/sh

set -eu

pgversion=$1
expectutil=${2:-git}
testopts=${3:-}
export GITHUB_OUTPUT="/tmp/github_output"
prefix=widget-1.0.0
zipfile="${prefix}.zip"
extrafile=extra.txt

cd $(dirname "$0")

if [ -n "$testopts" ]; then
    # Use GIT_BUNDLE_OPTS to add an untracked file to the Git archive or
    # ZIP_BUNDLE_OPTS to exclude it.
    echo extra > "$extrafile"
    export GIT_BUNDLE_OPTS="--add-file $extrafile"
    export ZIP_BUNDLE_OPTS="--exclude */$extrafile"
fi

pg-start $pgversion
pg-build-test
pgxn-bundle
make clean

# Make sure pgxn-bundle built the zip file.
if [ ! -f "$zipfile" ]; then
    echo ERROR:  Missing $zipfile
    ls -lah
    exit 2
fi

# Unzip the zipfile.
unzip "$zipfile"

if [ "$expectutil" = "git" ]; then
    # Make sure runtest.sh was omitted thanks to .gitattributes.
    if [ -f "$prefix/runtests.sh" ]; then
        echo 'ERROR:  Zip file contains runtests.sh and should not'
        echo '        Did pgxn-bundle use `zip` instead of `git archive`?'
        exit 2
    fi
    # Make sure the untracked file was added via GIT_BUNDLE_OPTS.
    if [ -n "$testopts" ] && [ ! -f "$prefix/$extrafile" ]; then
        echo "ERROR  $prefix/$extrafile not included in archive"
        exit 2
    fi
else
    # Make sure runtest.sh is included in the zip file.
    if [ ! -f "$prefix/runtest.sh" ]; then
        echo 'ERROR:  Zip file contains runtests.sh and should not'
        echo '        Did pgxn-bundle use `git archive` instead of `zip`?'
        exit 2
    fi
    # Make sure the extra file was excluded via ZIP_BUNDLE_OPTS.
    if [ -n "$testopts" ] && [ -f "$prefix/$extrafile" ]; then
        echo "ERROR  $prefix/$extrafile included in archive but should not be"
        exit 2
    fi
fi

rm -rf "$prefix" "$zipfile"

if ! grep -F "bundle=$zipfile" "$GITHUB_OUTPUT"; then
    echo "ERROR:  Output 'bundle' not appended to $GITHUB_OUTPUT"
    echo File:
    ls -lah "$GITHUB_OUTPUT"
    echo Contents:
    cat "$GITHUB_OUTPUT"
    exit 2
fi
