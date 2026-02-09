#!/bin/bash
set -ouex pipefail

# main .sh file that calls the other .sh files
bash /opt/scripts/user-init.sh

# Get the directory where this script is located
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Loop through all files in the same directory
for file in "$DIR"/hardened-*; do
    # Skip if it's this script itself
    if [[ "$file" != "$0" ]]; then
        bash "$file"
    fi
done
