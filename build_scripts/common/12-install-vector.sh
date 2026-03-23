#!/bin/bash
set -xeuo pipefail

VECTOR_VERSION="${VECTOR_VERSION:-0.38.0}"
ARCH="x86_64-unknown-linux-musl"

FILENAME="vector-${VECTOR_VERSION}-${ARCH}.tar.gz"
URL="https://github.com/vectordotdev/vector/releases/download/v${VECTOR_VERSION}/${FILENAME}"

mkdir -p vector

curl -sSfL --proto '=https' --tlsv1.2 "$URL" -o "$FILENAME"

tar xzf "$FILENAME" -C vector --strip-components=2

mv vector/bin/vector /usr/bin/vector
chmod +x /usr/bin/vector

ln -sf /usr/lib/systemd/system/vector.service \
  /etc/systemd/system/multi-user.target.wants/vector.service

sed -i "s/POSTGRESQL_MAJOR_VERSION/${POSTGRESQL_MAJOR_VERSION}/g" \
  /etc/vector/vector.yaml
