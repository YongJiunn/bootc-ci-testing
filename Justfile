# figure out justfile for backup and restore

# Show available commands
default:
    @just --list

# Set the time manually if NTP is not available, this will be important for the cert generation for quay setup
retrieve-postgres-password:
    #!/usr/bin/env bash
    set -xeuo pipefail
    eval "$(dbus-launch --sh-syntax)"
    eval "$(printf '\n' | gnome-keyring-daemon --unlock)"
    eval "$(printf '\n' | /usr/bin/gnome-keyring-daemon --start)"

    if ( ! secret-tool lookup postgres password > /dev/null 2>&1 ); then
        echo "Password Generated.."
        DB_PASSWORD=$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9')

        echo "Altering Password.."
        psql -c "ALTER USER $USER WITH PASSWORD '$DB_PASSWORD';"

        printf "$DB_PASSWORD" | secret-tool store --label="postgres" postgres password
    fi
    PASSWORD=$(secret-tool lookup postgres password)
    echo "The password to the postgres user is $PASSWORD ."