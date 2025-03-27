#!/bin/sh

set -eu

pgversion=$1
package="${2-}"
cd "$(dirname "$0")"
pg-start "$pgversion"
echo "#################### pgrx-build-test $package ####################"
if [ -z "$package" ]; then pgrx-build-test; else pgrx-build-test "$package"; fi
