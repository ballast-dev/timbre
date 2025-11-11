FROM debian:bookworm-slim

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
    wget \
    xz-utils
# Clean up apt cache
rm -rf /var/lib/apt/lists/*
EOF

RUN <<EOF
export ARCH=$(uname -m)
export ZIG_VERSION="0.15.2"
cd /tmp
wget -q "https://ziglang.org/download/${ZIG_VERSION}/zig-${ARCH}-linux-${ZIG_VERSION}.tar.xz"
tar -xJf "zig-${ARCH}-linux-${ZIG_VERSION}.tar.xz"
mv "zig-${ARCH}-linux-${ZIG_VERSION}" /usr/local/zig
ln -s /usr/local/zig/zig /usr/local/bin/zig
rm "zig-${ARCH}-linux-${ZIG_VERSION}.tar.xz"
zig version
EOF

RUN <<EOF 
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt-get update
apt-get install gh -y
EOF

CMD ["/bin/bash"]
