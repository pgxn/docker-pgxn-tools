#!/bin/sh

set -eu

pgversion=$1
cd "$(dirname "$0")"
pg-start "$pgversion"
pgrx-build-test
