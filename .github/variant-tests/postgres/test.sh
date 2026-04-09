#!/bin/bash
set -xeuo pipefail

echo "Executing custom tests for Postgres Variant!"

echo "Waiting for PostgreSQL service to fully initialize..."
timeout 60 bash -c 'until systemctl is-active postgresql-17.service; do sleep 2; echo "Still waiting for initdb..."; done'

echo "PostgreSQL is active! Proving database connection..."
sudo -u postgres psql -c "SELECT 1;"

exit 0
