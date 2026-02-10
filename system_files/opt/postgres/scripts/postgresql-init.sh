#!/bin/bash
set -ouex pipefail

# pulled from /usr/pgsql-15/bin/postgresql-15-setup for the filesystem check

# PGVERSION is the full package version, e.g., 15.0
# Note: the specfile inserts the correct value during package build
PGVERSION=POSTGRESQL_MAJOR_VERSION
# PGMAJORVERSION is major version, e.g., 15 (this should match PG_VERSION)
# shellcheck disable=SC2001
PGMAJORVERSION=$(echo "$PGVERSION" | sed 's/^\([0-9]*\.[0-9]*\).*$/\1/')
# PGENGINE is the directory containing the postmaster executable
# Note: the specfile inserts the correct value during package build
# PGENGINE=/usr/pgsql-$PGVERSION/bin
# The second parameter is the new database version, i.e. $PGMAJORVERSION in this case.
# Use  "postgresql-$PGMAJORVERSION" service, if not specified.
SERVICE_NAME=postgresql-$PGMAJORVERSION

# create new user so that postgres system account does not get used
USERNAME=POSTGRESQL_USERNAME
if getent group postgres >/dev/null 2>&1; then
    if ! id "$USERNAME" >/dev/null 2>&1; then
        useradd -G postgres "$USERNAME"
        PASSWORD=DEFAULT_PASSWORD
        echo "$USERNAME:$PASSWORD" | chpasswd
        chage -d 0 -m 1 -M 365 "$USERNAME"
    fi
fi

PGDATA=/var/lib/pgsql/$PGMAJORVERSION/data

if [ -z "$PGDATA" ]; then
    echo "failed to find PGDATA setting in ${SERVICE_NAME}.service"
    exit 1
fi

# Check if the folder exists - if exists means already init'ed
if [ -f "$PGDATA/PG_VERSION" ]; then
  echo "$PGDATA found. Exiting script."
  exit 0
else
  echo "$PGDATA not found. Executing command."
  
  sudo -u postgres /usr/pgsql-$PGVERSION/bin/initdb -D "$PGDATA"

  # Hard guard: initdb must have completed successfully
  if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "ERROR: PG_VERSION missing after initdb. Aborting further configuration."
    exit 1
  fi

  # configure all can access and login using password
  echo "listen_addresses='*'" >> "$PGDATA"/postgresql.conf
  echo "host    all             all             0.0.0.0/0            scram-sha-256" >> "$PGDATA"/pg_hba.conf

  # configure max connections - https://stackoverflow.com/questions/30778015/how-to-increase-the-max-connections-in-postgres
  sed -i 's/max_connections = [0-9]\+/max_connections = 300/' "$PGDATA"/postgresql.conf
  
  systemctl restart "${SERVICE_NAME}".service

  # run the harden script if it is present inside the same directory
  # Get the directory where this script is located
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # Loop through all files in the same directory
  for file in "$DIR"/*; do
      # Skip if it's this script itself
      [[ "$file" == "$0" ]] && continue

      # Make sure it's executable and a regular file
      if [[ -f "$file" && -x "$file" ]]; then
          echo "Running $file..."
          "$file"
      fi
  done

  systemctl restart "${SERVICE_NAME}".service

  USERNAME=POSTGRESQL_USERNAME

  # List of SQL commands to execute
  commands=(
      "CREATE USER POSTGRES_EXPORTER_USER WITH PASSWORD 'POSTGRES_EXPORTER_PASWORD';"
      "GRANT pg_monitor TO POSTGRES_EXPORTER_USER;"
      "CREATE ROLE $USERNAME SUPERUSER LOGIN;"
      "CREATE DATABASE $USERNAME;"
    )

  for cmd in "${commands[@]}"; do
      echo "Running command: $cmd"
      sudo -u postgres psql -c "$cmd"
  done
fi

systemctl restart "${SERVICE_NAME}".service