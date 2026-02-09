#!/bin/bash
set -ouex pipefail

## The implications of this is that there can be no recovery, as the root password is randomly generated and is not stored anywhere

## create a random root user password for 5.4.2.4
# ROOT_PASSWORD=$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9')
# echo "root:$ROOT_PASSWORD" | chpasswd
# chage -m 1 -M 365 root
