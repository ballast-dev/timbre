FROM ubuntu:22.04

# OCI Annotations
LABEL org.opencontainers.image.source="https://github.com/krakjn/timbre"

RUN <<EOF
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
    binfmt-support \
    build-essential \
    ca-certificates \
    clang-format \
    clang-tidy \
    cmake \
    cppcheck \
    crossbuild-essential-arm64 \
    curl \
    debhelper \
    devscripts \
    dh-make \
    dpkg-dev \
    fakeroot \
    g++ \
    git \
    jq \
    libc6-arm64-cross \
    libc6-dev-arm64-cross \
    libstdc++6-arm64-cross \
    dpkg-cross \
    make \
    ninja-build \
    pkg-config \
    qemu-user-static \
    tzdata \
    wget

# Set up QEMU for ARM64 emulation
update-binfmts --enable qemu-aarch64

# Create symlink for ARM64 dynamic linker
mkdir -p /lib
ln -sf /usr/aarch64-linux-gnu/lib/ld-linux-aarch64.so.1 /lib/ld-linux-aarch64.so.1

# Clean up apt cache
rm -rf /var/lib/apt/lists/*
EOF

# Install Node.js and npm
RUN <<EOF
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
npm install -g @commitlint/cli @commitlint/config-conventional auto-changelog

# Install Catch2 for amd64
cd /opt
git clone https://github.com/catchorg/Catch2.git
cd Catch2
git checkout v3.8.0
cmake -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build build --target install -j$(nproc)

# Install Catch2 for arm64
mkdir -p build-arm64
cd build-arm64
cmake .. -G Ninja \
    -DCMAKE_C_COMPILER=/usr/bin/aarch64-linux-gnu-gcc \
    -DCMAKE_CXX_COMPILER=/usr/bin/aarch64-linux-gnu-g++ \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_FIND_ROOT_PATH=/usr/aarch64-linux-gnu \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
    -DCMAKE_INSTALL_PREFIX=/usr/aarch64-linux-gnu \
    -DBUILD_TESTING=OFF \
    -DCMAKE_BUILD_TYPE=Release
cmake --build . --target install -j$(nproc)
cd /opt
rm -rf Catch2
EOF
