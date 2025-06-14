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

echo "Building $RID for architecture $ARCH (native compilation)"

# Get macOS SDK path
MACOS_SDK_PATH=$(xcrun --show-sdk-path)
echo "Using macOS SDK: $MACOS_SDK_PATH"

# Install and use Homebrew OpenSSL
echo "Installing OpenSSL@3 via Homebrew..."
brew install openssl@3
OPENSSL_ROOT_DIR=$(brew --prefix openssl@3)
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
    -DBUILD_TESTS=OFF \
    -DBUILD_CLI=OFF \
    -DUSE_SSH=libssh2 \
    -DUSE_HTTPS=SecureTransport \
    -DLibSSH2_DIR="$INSTALL_DIR" \
    -DOpenSSL_ROOT="$OPENSSL_ROOT_DIR" \
    -DCMAKE_EXE_LINKER_FLAGS="-L$OPENSSL_ROOT_DIR/lib -lssl -lcrypto" \
    -DCMAKE_SHARED_LINKER_FLAGS="-L$OPENSSL_ROOT_DIR/lib -lssl -lcrypto" \
    -DLIBGIT2_FILENAME="$LIBGIT2_FILENAME" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"

cmake --build . --config Release --target install

# Copy dylibs to output
if [[ -d "$INSTALL_DIR/lib" ]]; then
    find "$INSTALL_DIR/lib" -type f \( -name "*.dylib" \) -exec cp {} "$OUTPUT_DIR" \;
fi

echo "Build completed for $RID"
ls -la "$OUTPUT_DIR"

