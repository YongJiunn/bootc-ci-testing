#!/bin/bash
set -xeuo pipefail

if [ -n "$VARIANT" ] && [ "$VARIANT" != "postgres" ]; then
    exit 0;
fi

# configure repo rpm
dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-"$EL_VERSION"-"$ARCH"/pgdg-redhat-repo-latest.noarch.rpm

# install postgresql (e.g. postgresql15-server-15.5-1PGDG.rhel9.x86_64)
dnf install -y postgresql"$POSTGRESQL_MAJOR_VERSION"-server-"$POSTGRESQL_MAJOR_VERSION"."$POSTGRESQL_MINOR_VERSION"-1PGDG.rhel"$EL_VERSION"."$ARCH"

# install postgis
dnf -y install epel-release
dnf config-manager --enable crb
dnf -y install postgis34_"$POSTGRESQL_MAJOR_VERSION"

# hardening
dnf -y install pgaudit_"$POSTGRESQL_MAJOR_VERSION" set_user_"$POSTGRESQL_MAJOR_VERSION" pgbackrest


# delete repo once installed - otherwise will get a weird gpg key error
rm /etc/yum.repos.d/pgdg-redhat-all.repo

# configure both init script and postgres to start at startup
ln -s /usr/lib/systemd/system/postgresql-init.service /etc/systemd/system/multi-user.target.wants/postgresql-init.service
ln -s /usr/lib/systemd/system/postgresql-"$POSTGRESQL_MAJOR_VERSION".service \
      /etc/systemd/system/multi-user.target.wants/postgresql-"$POSTGRESQL_MAJOR_VERSION".service

# move extensions
PGLIB=/usr/pgsql-$POSTGRESQL_MAJOR_VERSION/lib
mv /opt/postgres/extensions/* "$PGLIB"
chmod 755 "$PGLIB"
