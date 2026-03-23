#!/bin/bash
set -xeuo pipefail

# Image-layer cleanup
shopt -s extglob

dnf clean all && rm -r /var/cache/dnf

# rm -rf /.gitkeep /var /boot
# mkdir -p /boot /var

# shellcheck disable=SC2114
rm -rf /.gitkeep /boot
mkdir -p /boot


# FIXME: use --fix option once https://github.com/containers/bootc/pull/1152 is merged
bootc container lint --fatal-warnings || true