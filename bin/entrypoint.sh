#!/bin/bash

set -e

# Just continue if unprivileged user not requested.
[ -z "$AS_USER" ] && exec "$@"

USER_ID=${LOCAL_UID:-0}
USERNAME=worker

if [ $USER_ID == 0 ]; then
    if [ -n "${GITHUB_EVENT_PATH}" ]; then
        USER_ID=$(stat -f %u "${GITHUB_EVENT_PATH}")
    else
        USER_ID=1001
    fi
fi

echo "Starting with UID $USER_ID"
useradd --system --create-home --shell /bin/bash -g root -G sudo -u $USER_ID "$AS_USER"
export HOME="/home/$AS_USER"
exec /usr/sbin/gosu "$AS_USER" "$@"
