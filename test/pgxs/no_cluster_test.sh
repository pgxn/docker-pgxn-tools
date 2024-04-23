#!/bin/sh

pgversion=$1
if ! pg-start "$pgversion"; then
    echo "ERROR: error returned from script"
    exit 1
fi

if [ -d "/var/lib/postgresql/$pgversion/test" ]; then
  echo "ERROR: /var/lib/postgresql/$pgversion/test should not exist!"
  exit 1;
fi
