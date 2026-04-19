#!/bin/bash
set -xeuo pipefail

echo "Inspecting PostgreSQL service state..."
systemctl list-units '*postgresql*' --no-pager
systemctl status postgresql-init.service postgresql-17.service --no-pager || true
journalctl -u postgresql-init.service -u postgresql-17.service -n 100 --no-pager || true
ls -l /opt/postgres/scripts/postgresql-init.sh

echo "Executing custom tests for Postgres Variant!"

echo "Waiting for PostgreSQL service to fully initialize..."
timeout 60 bash -c 'until systemctl is-active postgresql-17.service; do sleep 2; echo "Still waiting for initdb..."; done'

echo "PostgreSQL is active! Proving database connection..."
# sudo -u postgres psql -c "SELECT 1;"
runuser -u postgres -- psql -c "SELECT 1;"

exit 0
