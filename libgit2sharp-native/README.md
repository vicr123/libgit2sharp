# LibGit2Sharp Native Library Builds

This directory contains the build scripts for creating native libgit2 and libssh2 libraries for multiple platforms.

## Build System

**Simplified Multi-Platform Approach**: Instead of complex cross-compilation, we use Docker's multi-platform build support for native compilation on each target architecture.

### Supported Platforms

- **Windows**: `win-x64`, `win-x86`, `win-arm64` (native Visual Studio builds)
- **Linux (glibc)**: `linux-x64`, `linux-arm64`, `linux-arm` (Docker multi-platform)
- **Linux (musl)**: `linux-musl-x64`, `linux-musl-arm64` (Alpine containers)
- **macOS**: `osx-x64`, `osx-arm64` (native Xcode builds with OpenSSL 3)

### How It Works

1. **GitHub Actions** triggers builds for all platforms automatically
2. **Docker Buildx** handles architecture emulation for ARM builds
3. **Native compilation** in each target environment (no cross-compilation complexity)
4. **System dependencies** are used (Schannel, OpenSSL, SecureTransport)

### Files

- `build-native-windows.ps1` - Windows native builds using Visual Studio
- `build-native-linux.sh` + `Dockerfile.linux-simple` - Linux glibc builds
- `build-native-linux.sh` + `Dockerfile.alpine` - Linux musl builds  
- `build-native-macos.sh` - macOS native builds

### Building Locally

For production builds, just push to the `ssh-vicr123` branch - GitHub Actions handles everything.

For local development:
```bash
# Windows (requires Visual Studio)
./build-native-windows.ps1 win-x64

# Linux via Docker
docker buildx build --platform linux/amd64 -f Dockerfile.linux-simple -t build .
docker run --rm -v "$(pwd)/build-output:/src/libgit2sharp-native/build-output" build linux-x64

# macOS (requires Xcode + OpenSSL 3)
brew install openssl@3
export OPENSSL_ROOT_DIR=$(brew --prefix openssl@3)
./build-native-macos.sh osx-arm64
```

Much simpler than the old cross-compilation approach!
