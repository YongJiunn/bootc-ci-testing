#!/bin/bash

set -xeuo pipefail

echo "workaround if needed"

# This thing slows down downloads A LOT for no reason
dnf remove -y subscription-manager

# dnf upgrade -y

# postgres user configuration workarounds
# to configure a script to run at startup to generate a password for the postgres user
sed -i "s/DEFAULT_PASSWORD/$DEFAULT_PASSWORD/g" /opt/scripts/user-init.sh
# configure user-init
ln -s /usr/lib/systemd/system/boot-scripts.service /etc/systemd/system/multi-user.target.wants/boot-scripts.service