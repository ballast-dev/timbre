FROM debian:bookworm-slim

SHELL ["/bin/bash", "-c", "set -euxo pipefail"]

# OCI Annotations
LABEL org.opencontainers.image.source="https://github.com/ballast-dev/timbre"

RUN <<EOF
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
    apt-utils \
    ca-certificates \
    curl \
    git \
    jq \
    tzdata \
    wget
# Clean up apt cache
rm -rf /var/lib/apt/lists/*
EOF

# Install Zig 0.15.1
RUN <<EOF
ZIG_VERSION="0.15.1"
cd /tmp
wget -q "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz"
tar -xf "zig-linux-x86_64-${ZIG_VERSION}.tar.xz"
mv "zig-linux-x86_64-${ZIG_VERSION}" /usr/local/zig
ln -s /usr/local/zig/zig /usr/local/bin/zig
rm "zig-linux-x86_64-${ZIG_VERSION}.tar.xz"
zig version
EOF

RUN <<EOF 
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt-get update
apt-get install gh -y
EOF

# RUN <<EOF
# # Install Node.js and npm
# curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
# apt-get install -y nodejs
# npm install -g @commitlint/cli @commitlint/config-conventional auto-changelog
# EOF

WORKDIR /app
ENTRYPOINT ["/bin/bash"]
