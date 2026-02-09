#!/bin/bash
set -ouex pipefail

set_or_append_config_kv() {
    declare -n kv_pairs=$1
    local file="$2"

    # Backup the original file
    cp "$file" "${file}.bak"

    for key in "${!kv_pairs[@]}"; do
        local value="${kv_pairs[$key]}"

        if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
            # Key exists: replace quoted value
            sed -i -E "s/^([[:space:]]*${key}[[:space:]]*=[[:space:]]*')[^']*(')/\1${value}\2/" "$file"
        else
            # Key doesn't exist: append new entry
            echo "${key} = '${value}'" >> "$file"
        fi
    done
}

# pulled from /usr/pgsql-15/bin/postgresql-15-setup for the filesystem check

# PGVERSION is the full package version, e.g., 15.0
# Note: the specfile inserts the correct value during package build
PGVERSION=POSTGRESQL_MAJOR_VERSION
# PGMAJORVERSION is major version, e.g., 15 (this should match PG_VERSION)
PGMAJORVERSION=$(echo "$PGVERSION" | sed 's/^\([0-9]*\.[0-9]*\).*$/\1/')
# PGENGINE is the directory containing the postmaster executable
# Note: the specfile inserts the correct value during package build
PGENGINE=/usr/pgsql-$PGVERSION/bin
# The second parameter is the new database version, i.e. $PGMAJORVERSION in this case.
# Use  "postgresql-$PGMAJORVERSION" service, if not specified.
SERVICE_NAME=postgresql-$PGMAJORVERSION

PGDATA=/var/lib/pgsql/$PGMAJORVERSION/data
# folder for WAL archiving - cis 7.4
PGBACKUP_FOLDER="/var/postgres/backup"
mkdir -p $PGBACKUP_FOLDER
chown postgres:postgres $PGBACKUP_FOLDER

# configure the umask for postgres user
echo "umask 077" >> ~postgres/.bash_profile

# TODO: catalog down the CIS benchmark that this fixes
declare -A configuration_changes=(
    ["log_filename"]="postgresql-%Y%m%d.log" # cis 3.1.5
    ["log_rotation_age"]="1d" # cis 3.1.8
    ["log_rotation_size"]="1GB" # cis 3.1.9
    ["syslog_facility"]="LOCAL1" # cis 3.1.10
    ["syslog_ident"]="postgres" # cis 3.1.13
    ["log_connections"]="on" # cis 3.1.20
    ["log_disconnections"]="on" # cis 3.1.21
    ["log_error_verbosity"]="verbose" # cis 3.1.22
    ["log_line_prefix"]="%m [%p]: [%l-1] db=%d,user=%u,app=%a,client=%h" # cis 3.1.24
    ["log_statement"]="mod" # cis 3.1.25
    ["shared_preload_libraries"]="pgaudit,set_user,\$libdir/passwordcheck" # cis 3.2, 4.6, 5.3
    ["log_replication_commands"]="on" # cis 7.2
    ["archive_mode"]="on" # cis 7.4
    ["archive_command"]="cp %p $PGBACKUP_FOLDER/%f" # cis 7.4
    ["ssl"]="on" # cis 6.8 
    ["ssl_ca_file"]='root-ca.crt' # cis 6.8
    ["ssl_cert_file"]='server.crt'  # cis 6.8
    ["ssl_key_file"]='server.key'  # cis 6.8
)
config_file="$PGDATA/postgresql.conf"
set_or_append_config_kv configuration_changes $config_file

PG_ISREADY="/usr/pgsql-$PGMAJORVERSION/bin/pg_isready"

until sudo -u postgres "$PG_ISREADY" -q; do
  sleep 1
done

# List of SQL commands to execute
commands=(
    "CREATE USER replication_user REPLICATION PASSWORD 'POSTGRESQL_REPLICATION_PASSWORD';"
)

for cmd in "${commands[@]}"; do
  echo "Running command: $cmd"
  sudo -u postgres psql -v ON_ERROR_STOP=1 \
    -d postgres \
    -h /var/run/postgresql \
    -c "$cmd"
done    


# configure firewall - add 5432/tcp to trusted zone
firewall-cmd --permanent --zone=public --add-port=5432/tcp
firewall-cmd --reload

# generate default certificate configurations
openssl genrsa -out $PGDATA/rootCA.key 4096
openssl req -x509 -new -nodes -key $PGDATA/rootCA.key -sha256 -days 3650 -out $PGDATA/root-ca.crt \
    -subj "/C=US/ST=Placeholder/L=City/O=ExampleOrg/OU=RootCA/CN=ExampleRootCA"
openssl genrsa -out $PGDATA/server.key 2048
openssl req -new -key $PGDATA/server.key -out $PGDATA/server.csr \
    -subj "/C=US/ST=Placeholder/L=City/O=ExampleOrg/OU=Server/CN=example.com"
openssl x509 -req -in $PGDATA/server.csr -CA $PGDATA/root-ca.crt -CAkey $PGDATA/rootCA.key -CAcreateserial \
    -out $PGDATA/server.crt -days 825 -sha256
rm $PGDATA/server.csr $PGDATA/rootCA.key
# ensure permissions
chown postgres:postgres $PGDATA/root-ca.crt $PGDATA/server.key $PGDATA/server.crt
chmod 600 $PGDATA/root-ca.crt $PGDATA/server.key $PGDATA/server.crt

# override to enforce ssl connections only - tls config is buggy
sed -i '/0\.0\.0\.0/ s/^host\b/hostssl/' $PGDATA/pg_hba.conf
sed -i 's/^host\b/hostssl/' $PGDATA/pg_hba.conf


systemctl restart ${SERVICE_NAME}.service