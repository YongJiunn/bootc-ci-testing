#!/bin/bash
set -xeuo pipefail

CONTEXT_PATH="$(realpath "$(dirname "$0")/..")" # should return /run/context
BUILD_SCRIPTS_PATH="$(realpath "$(dirname "$0")")"

# copy files from /files to / - merging the files
cp -avf "${CONTEXT_PATH}/files/." /

sed -i \
  "s/POSTGRESQL_MAJOR_VERSION/${POSTGRESQL_MAJOR_VERSION}/g" \
  /usr/lib/systemd/system/postgresql-init.service
  
#####
# Stock variant checks
#####

# check for env var that says to harden
if [ "$HARDENED" = "false" ]; then
    echo "Removing harden scripts"
    find  /opt -type f -name 'hardened-*' -exec rm -f {} \;

    echo "Removing FIPS configuration"
    rm /usr/lib/bootc/kargs.d/01-fips.toml
fi

## Run checks for DEFAULT_PASSWORD and BOOTLOADER_PASSWORD as they have no sane defaults by design
# check if bootloader password is provided
if [ "$HARDENED" = "true" ]; then
    if [ -z "$BOOTLOADER_PASSWORD" ]; then
        echo "No bootloader password provided. Provide one as build arg (BOOTLOADER_PASSWORD)"
        exit 1
    fi
fi

# populate the build args into the boot scripts
# populate the build args into the boot scripts
find /opt -name "*.sh" -type f -print0 | while IFS= read -r -d '' file; do
    sed -i "s/ADMIN_USERNAME/$ADMIN_USERNAME/g" "$file"

    # harden config
    if [ "$HARDENED" = "true" ]; then
        sed -i "s/BOOTLOADER_PASSWORD/$BOOTLOADER_PASSWORD/g" "$file"
    fi
done

#####
# Postgres variant specific checks
#####
if [ "$VARIANT" = "postgres" ]; then
    if [ "$HARDENED" = "true" ]; then
        if [ -z "$BOOTLOADER_PASSWORD" ]; then
            echo "No bootloader password provided. Provide one as build arg (BOOTLOADER_PASSWORD)"
            exit 1
        fi
        if [ -z "$POSTGRESQL_REPLICATION_PASSWORD" ]; then
            echo "No replication password provided. Provide one as build arg (POSTGRESQL_REPLICATION_PASSWORD)"
            exit 1
        fi
    fi

    # check if postgres exporter password is provided
    if [ -z "$POSTGRES_EXPORTER_PASSWORD" ]; then
        echo "No default postgres exporter password provided. Provide one as build arg (POSTGRES_EXPORTER_PASSWORD)"
        exit 1
    fi

    # check if default postgres password is provided
    if [ -z "$DEFAULT_PASSWORD" ]; then
        echo "No default postgres password provided. Provide one as build arg (DEFAULT_PASSWORD)"
        exit 1
    fi

    # populate the build args into the boot scripts
    # populate the build args into the boot scripts
    find /opt -name "*.sh" -type f -print0 | while IFS= read -r -d '' file; do
        ## configure the postgresql init script
        sed -i "s/POSTGRESQL_MAJOR_VERSION/$POSTGRESQL_MAJOR_VERSION/g" "$file"
        sed -i "s/POSTGRES_EXPORTER_USER/$POSTGRES_EXPORTER_USER/g" "$file"
        sed -i "s/POSTGRES_EXPORTER_PASWORD/$POSTGRES_EXPORTER_PASSWORD/g" "$file"
        sed -i "s/DEFAULT_PASSWORD/$DEFAULT_PASSWORD/g" "$file"
        sed -i "s/POSTGRESQL_USERNAME/$POSTGRESQL_USERNAME/g" "$file"

        # harden config
        if [ "$HARDENED" = "true" ]; then
            sed -i "s/POSTGRESQL_REPLICATION_PASSWORD/$POSTGRESQL_REPLICATION_PASSWORD/g" "$file"
        fi
    done
else
    # remove postgres deps
    # TODO - to evaluate whether adding app-specific configs is better?
    rm -r /opt/postgres
    rm /usr/lib/systemd/system/postgresql-init.service
fi


# run the build scripts in order
find "${BUILD_SCRIPTS_PATH}" -maxdepth 1 -iname "*-*.sh" -type f -print0 | sort --zero-terminated --sort=human-numeric | while IFS= read -r -d $'\0' script ; do
    printf "%s" "$(basename "$script")"
    "$(realpath "$script")"
    printf "::endgroup::\n"
done

"${BUILD_SCRIPTS_PATH}/cleanup.sh"