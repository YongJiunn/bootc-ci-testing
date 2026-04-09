#!/bin/bash
set -xeuo pipefail

echo "Executing custom tests for Postgres Variant!"
# Example: systemctl is-active postgresql-17
# Example: psql -c "SELECT 1;"
systemctl is-active postgresql-17.service

exit 0
