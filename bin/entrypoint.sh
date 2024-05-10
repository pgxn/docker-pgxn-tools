#!/bin/bash

set -e

# Just continue if unprivileged user not requested.
[ -z "$AS_USER" ] && exec "$@"

USER_ID=${LOCAL_UID:-1001}

echo "Starting with UID $USER_ID"
useradd --create-home --shell /bin/bash -g root -G sudo -u "$USER_ID" "$AS_USER"
export HOME="/home/$AS_USER"
exec /usr/sbin/gosu "$AS_USER" "$@"
