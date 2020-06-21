#!/bin/sh

set -eu

pgversion=$1

cd $(dirname "$0")
pg-start $pgversion
pg-build-test
pgxn-bundle
