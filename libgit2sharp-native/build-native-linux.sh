#!/bin/bash
set -e

RID="$1"

if [ -z "$RID" ]; then
    echo "Usage: $0 <RID>" >&2
    exit 1
fi

echo "Building $RID natively (no cross-compilation needed!)"
echo "Architecture: $(uname -m)"
echo "System: $(uname -a)"

LIBSSH2_SRC="/src/libgit2sharp-native/libssh2"
LIBGIT2_SRC="/src/libgit2sharp-native/libgit2"
OUTPUT_DIR="/src/libgit2sharp-native/build-output/$RID"

mkdir -p "$OUTPUT_DIR"

# Create git info for libgit2
cd /src/libgit2sharp-native/libgit2
LIBGIT2_SHA=$(git rev-parse HEAD)
LIBGIT2_SHA_SHORT=$(echo $LIBGIT2_SHA | cut -c1-7)
LIBGIT2_FILENAME="git2-$LIBGIT2_SHA_SHORT"

# Note: Both glibc and musl builds use dynamic linking
echo "Building for $([[ "$RID" == *"musl"* ]] && echo "musl" || echo "glibc") libc"

# Build libssh2
LIBSSH2_BUILD="/tmp/build-libssh2-$RID"
INSTALL_DIR="/tmp/install-libssh2-$RID"
mkdir -p "$LIBSSH2_BUILD" "$INSTALL_DIR"
cd "$LIBSSH2_BUILD"

cmake "$LIBSSH2_SRC" \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_TESTING=OFF \
    -DCRYPTO_BACKEND=OpenSSL \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"

cmake --build . --target install

# Build libgit2
LIBGIT2_BUILD="/tmp/build-libgit2-$RID"
mkdir -p "$LIBGIT2_BUILD"
cd "$LIBGIT2_BUILD"

cmake "$LIBGIT2_SRC" \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTS=OFF \
    -DBUILD_CLI=OFF \
    -DUSE_SSH=libssh2 \
    -DUSE_HTTPS=OpenSSL \
    -DLibSSH2_DIR="$INSTALL_DIR" \
    -DLIBGIT2_FILENAME="$LIBGIT2_FILENAME" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"

cmake --build . --target install

# Copy shared libraries to output
if [[ -d "$INSTALL_DIR/lib" ]]; then
    find "$INSTALL_DIR/lib" -type f \( -name "*.so*" \) -exec cp {} "$OUTPUT_DIR" \;
fi

# Also check bin directory
if [[ -d "$INSTALL_DIR/bin" ]]; then
    find "$INSTALL_DIR/bin" -type f \( -name "*.so*" \) -exec cp {} "$OUTPUT_DIR" \;
fi

echo "Build completed for $RID"
ls -la "$OUTPUT_DIR"