ARG EL_VERSION=9
FROM scratch as context

COPY --chmod=0775 system_files /files
COPY --chmod=0775 build_scripts /build_scripts

#FROM quay.io/centos-bootc/centos-bootc:stream${EL_VERSION}
FROM quay.io/centos-bootc/centos-bootc:sha256-7c4853aa5212a4eb77796d835701f84dffbf430ef904575df97b4b3f4988e4a4

COPY Justfile /Justfile

ARG EL_VERSION=9
ARG ARCH=x86_64
ARG ADMIN_USERNAME=starforge
ARG HARDENED=false
ARG VARIANT=stock

ENV ARCH=${ARCH}
ENV EL_VERSION=${EL_VERSION}
ENV ADMIN_USERNAME=${ADMIN_USERNAME}
ENV HARDENED=${HARDENED}
ENV VARIANT=${VARIANT}

# VARIANT postgres specific
ARG POSTGRESQL_USERNAME=postgres_user
ARG POSTGRESQL_MAJOR_VERSION=17
ARG POSTGRESQL_MINOR_VERSION=4
ARG POSTGRES_EXPORTER_USER=postgres_exporter

ENV POSTGRESQL_USER=${POSTGRESQL_USERNAME}
ENV POSTGRESQL_MAJOR_VERSION=${POSTGRESQL_MAJOR_VERSION}
ENV POSTGRESQL_MINOR_VERSION=${POSTGRESQL_MINOR_VERSION}
ENV POSTGRES_EXPORTER_USER=${POSTGRES_EXPORTER_USER}

RUN \
 --mount=type=secret,id=bootloader_pwd \
 --mount=type=secret,id=default_pwd \
 --mount=type=secret,id=exporter_pwd \
 --mount=type=secret,id=replication_pwd \
 --mount=type=tmpfs,dst=/tmp \
 --mount=type=bind,from=context,source=/,target=/run/context \
 # Pull secrets from the default podman secret mount path (/run/secrets/id) and expose to build.sh \
 BOOTLOADER_PASSWORD="$(cat /run/secrets/bootloader_pwd)" \
 DEFAULT_PASSWORD="$(cat /run/secrets/default_pwd)" \
 POSTGRES_EXPORTER_PASSWORD="$(cat /run/secrets/exporter_pwd)" \
 POSTGRESQL_REPLICATION_PASSWORD="$(cat /run/secrets/replication_pwd)" \
 bash /run/context/build_scripts/common/build.sh
 
# for some reason centos-bootc doesn't have this as its entry point
ENTRYPOINT /sbin/init
