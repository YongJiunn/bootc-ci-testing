# #!/bin/bash
# set -xeuo pipefail

# #curl --proto '=https' --tlsv1.2 -sSfL https://sh.vector.dev | bash -s -- -y

# url=$(curl -s https://api.github.com/repos/vectordotdev/vector/releases | \
#   jq -r 'sort_by(.published_at) | last | .assets[] | select(.name | test(".*x86_64-unknown-linux-musl.*")) | .browser_download_url')

# mkdir -p vector && \
#   curl -sSfL --proto '=https' --tlsv1.2 "$url"  | \
#   tar xzf - -C vector --strip-components=2

# #ls vector

# # move to /usr/bin
# mv vector/bin/vector /usr/bin/vector && chmod +x /usr/bin/vector

# #echo "export PATH=\"$(pwd)/vector/bin:\$PATH\"" >> $HOME/.profile
# #source $HOME/.profile

# ## add symlink to make it run at startup
# ln -s /usr/lib/systemd/system/vector.service /etc/systemd/system/multi-user.target.wants/vector.service 

# # replace the version
# sed -i "s/POSTGRESQL_MAJOR_VERSION/$POSTGRESQL_MAJOR_VERSION/g" /etc/vector/vector.yaml

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
