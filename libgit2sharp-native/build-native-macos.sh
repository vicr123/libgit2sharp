#!/bin/bash
set -e

RID="$1"

case "$RID" in
  osx-x64)
    ARCH="x86_64"
    MIN_VERSION="10.15"
    ;;
  osx-arm64)
    ARCH="arm64"
    MIN_VERSION="11.0"
    ;;
  *)
    echo "Unknown RID: $RID" >&2; exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIBSSH2_SRC="$SCRIPT_DIR/libssh2"
LIBGIT2_SRC="$SCRIPT_DIR/libgit2"
OUTPUT_DIR="$SCRIPT_DIR/build-output/$RID"

mkdir -p "$OUTPUT_DIR"

# Create git info for libgit2
cd "$LIBGIT2_SRC"
LIBGIT2_SHA=$(git rev-parse HEAD)
LIBGIT2_SHA_SHORT=$(echo $LIBGIT2_SHA | cut -c1-7)
LIBGIT2_FILENAME="git2-$LIBGIT2_SHA_SHORT"

echo "Building $RID for architecture $ARCH"

# Get macOS SDK path
MACOS_SDK_PATH=$(xcrun --show-sdk-path)
echo "Using macOS SDK: $MACOS_SDK_PATH"

# Install OpenSSL for both architectures to ensure cross-compilation works
echo "Setting up OpenSSL for cross-compilation..."

# Install x86_64 OpenSSL via Rosetta (needed for x86_64 builds on Apple Silicon)
arch -x86_64 brew install openssl@3 2>/dev/null || true

# Also ensure native OpenSSL is available
brew install openssl@3 2>/dev/null || true

# Use the appropriate OpenSSL path based on target architecture
if [[ "$ARCH" == "x86_64" ]]; then
    OPENSSL_ROOT_DIR="/usr/local/opt/openssl@3"
else
    OPENSSL_ROOT_DIR=$(brew --prefix openssl@3)
fi

echo "Using OpenSSL at: $OPENSSL_ROOT_DIR"

# Build libssh2
LIBSSH2_BUILD="/tmp/build-libssh2-$RID"
INSTALL_DIR="/tmp/install-libssh2-$RID"
mkdir -p "$LIBSSH2_BUILD" "$INSTALL_DIR"
cd "$LIBSSH2_BUILD"

cmake "$LIBSSH2_SRC" \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_VERSION" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_TESTING=OFF \
    -DCRYPTO_BACKEND=OpenSSL \
    -DOPENSSL_ROOT_DIR="$OPENSSL_ROOT_DIR" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"

cmake --build . --config Release --target install

# Build libgit2
LIBGIT2_BUILD="/tmp/build-libgit2-$RID"
mkdir -p "$LIBGIT2_BUILD"
cd "$LIBGIT2_BUILD"

cmake "$LIBGIT2_SRC" \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_VERSION" \
    -DCMAKE_OSX_SYSROOT="$MACOS_SDK_PATH" \
    -DBUILD_TESTS=OFF \
    -DBUILD_CLI=OFF \
    -DUSE_SSH=libssh2 \
    -DUSE_HTTPS=SecureTransport \
    -DLibSSH2_DIR="$INSTALL_DIR" \
    -DLIBSSH2_INCLUDE_DIR="$INSTALL_DIR/include" \
    -DLIBSSH2_LIBRARY="$INSTALL_DIR/lib/libssh2.a" \
    -DOPENSSL_ROOT_DIR="$OPENSSL_ROOT_DIR" \
    -DCMAKE_FIND_ROOT_PATH="$INSTALL_DIR" \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=BOTH \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH \
    -DCMAKE_FRAMEWORK_PATH="$MACOS_SDK_PATH/System/Library/Frameworks" \
    -DLIBGIT2_FILENAME="$LIBGIT2_FILENAME" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"

cmake --build . --config Release --target install

# Copy dylibs to output
if [[ -d "$INSTALL_DIR/lib" ]]; then
    find "$INSTALL_DIR/lib" -type f \( -name "*.dylib" \) -exec cp {} "$OUTPUT_DIR" \;
fi

echo "Build completed for $RID"
ls -la "$OUTPUT_DIR"

