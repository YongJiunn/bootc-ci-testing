#!/bin/bash
set -xeuo pipefail

if [ -n "$VARIANT" ] && [ "$VARIANT" != "postgres" ]; then
    exit 0;
fi

# check for env var that says to harden
if [ -z "$HARDENED" ] || [ "$HARDENED" = "false" ]; then
    echo "Not going to harden"
    exit 0
fi

echo "hardening"

# installing packages that are required to be hardened
dnf -y install pgaudit_$POSTGRESQL_MAJOR_VERSION set_user_$POSTGRESQL_MAJOR_VERSION pgbackrest

# fips mode - https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/using_image_mode_for_rhel_to_build_deploy_and_manage_operating_systems/enabling-the-fips-mode-while-building-a-bootc-image#enabling-the-fips-mode-by-using-bootc-image-builder-tool_enabling-the-fips-mode-while-building-a-bootc-image
# When booting the RHEL Anaconda installer, on the installation screen, press the TAB key and add the fips=1 kernel argument.
# press e at choosing stage -> append `fips=1` to the end of the `linux` line
dnf install -y crypto-policies-scripts && update-crypto-policies --no-reload --set FIPS

# install pgdstat - for testing
dnf install -y perl-devel perl-bignum perl-Math-BigRat git

git clone https://github.com/HexaCluster/pgdsat

cd pgdsat
perl Makefile.PL
make
make install
chmod +x pgdsat
mv pgdsat /usr/bin/
rm -r /pgdsat
