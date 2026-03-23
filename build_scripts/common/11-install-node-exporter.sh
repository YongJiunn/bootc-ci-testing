#!/bin/bash
set -xeuo pipefail

# install node-exporter for monitoring
# wget https://github.com/prometheus/node_exporter/releases/download/<VERSION>/node_exporter-<VERSION>.<OS>-<ARCH>.tar.gz
# tar xvfz node_exporter-*.*-amd64.tar.gz
#cd node_exporter-*.*-amd64
# ./node_exporter

url=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases | \
  jq -r 'sort_by(.published_at) | last | .assets[] | select(.name | test(".*linux-amd64.*")) | .browser_download_url')

dnf install -y wget
wget -O node_exporter.tar.gz "$url"
tar xvfz node_exporter.tar.gz

mv node_exporter-*.*-amd64/node_exporter /usr/bin/node_exporter && chmod +x /usr/bin/node_exporter 

## add symlink to make it run at startup
ln -s /usr/lib/systemd/system/node-exporter.service /etc/systemd/system/multi-user.target.wants/node-exporter.service 

# install postgres exporter here?