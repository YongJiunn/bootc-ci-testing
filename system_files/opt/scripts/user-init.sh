#!/bin/bash
set -ouex pipefail

# create an admin user
ADMIN_USER=ADMIN_USERNAME
ISSUE_DIR="/etc/issue.d"
ISSUE_FILE="$ISSUE_DIR/password.issue"

if ! id "$ADMIN_USER" >/dev/null 2>&1; then
    useradd -G wheel "$ADMIN_USER"
    ADMIN_PASSWORD=$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9')
    echo "$ADMIN_USER:$ADMIN_PASSWORD" | chpasswd

    mkdir -p "$ISSUE_DIR"
    echo "The password for sudo user: $ADMIN_USER is $ADMIN_PASSWORD. This will only appear once." > "$ISSUE_FILE"
else
    rm -f "$ISSUE_FILE"
fi


# cis 7.2.9
chmod -R 740 /home/*