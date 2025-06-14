#!/usr/bin/env pwsh
param(
    [Parameter(Mandatory)]
    [string]$RID
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"

# Detect platform and validate RID
$validRIDs = @()
if ($IsWindows) {
    $validRIDs = @("win-x64", "win-x86", "win-arm64")
    $platform = "Windows"
} elseif ($IsLinux) {
    $validRIDs = @("linux-x64", "linux-arm64", "linux-arm", "linux-musl-x64", "linux-musl-arm64")
    $platform = "Linux"
} elseif ($IsMacOS) {
    $validRIDs = @("osx-x64", "osx-arm64")
    $platform = "macOS"
} else {
    Write-Error "Unsupported platform"
}

if ($RID -notin $validRIDs) {
    Write-Error "Unknown RID: $RID. Valid values for $platform are: $($validRIDs -join ', ')"
}

Write-Host "Building $RID on $platform"

# Common paths
$libssh2Src = Join-Path $PSScriptRoot "libssh2"
$libgit2Src = Join-Path $PSScriptRoot "libgit2"
$outputDir = Join-Path $PSScriptRoot "build-output" $RID

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# Get libgit2 version info
Push-Location $libgit2Src
$libgit2Sha = git rev-parse HEAD
$libgit2ShaShort = $libgit2Sha.Substring(0,7)
$libgit2Filename = "git2-$libgit2ShaShort"
Pop-Location

Write-Host "libgit2 version: $libgit2Filename"

# Platform-specific configuration
if ($IsWindows) {
    Write-Host "Setting up Visual Studio environment..."
    
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $vsPath = & $vsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    
    $targetArch = switch ($RID) {
        "win-x64"   { "amd64" }
        "win-x86"   { "x86" }
        "win-arm64" { "arm64" }
    }
    
    $launchVsDevShellPath = "$vsPath\Common7\Tools\Launch-VsDevShell.ps1"
    & $launchVsDevShellPath -Arch $targetArch -HostArch amd64
    
    $buildRoot = Join-Path $PSScriptRoot "build-$RID"
    $installDir = Join-Path $buildRoot "install"
    $filePattern = "*.dll"
    
} elseif ($IsLinux) {
    $isMusl = $RID -like "*musl*"
    $arch = switch ($RID) {
        "linux-x64"        { "x86_64" }
        "linux-arm64"      { "aarch64" }  
        "linux-arm"        { "armv7l" }
        "linux-musl-x64"   { "x86_64" }
        "linux-musl-arm64" { "aarch64" }
    }
    
    Write-Host "Building for $arch architecture (musl: $isMusl)"
    
    $buildRoot = "/tmp/build-$RID"
    $installDir = "/tmp/install-$RID"
    $filePattern = "*.so*"
    
} elseif ($IsMacOS) {
    $arch = switch ($RID) {
        "osx-x64"   { "x86_64" }
        "osx-arm64" { "arm64" }
    }
    
    $minVersion = switch ($RID) {
        "osx-x64"   { "10.15" }
        "osx-arm64" { "11.0" }
    }
    
    Write-Host "Building for $arch architecture (native compilation)"
    
    Write-Host "Installing OpenSSL@3 via Homebrew..."
    brew install openssl@3
    $opensslRoot = brew --prefix openssl@3
    Write-Host "Using OpenSSL at: $opensslRoot"
    
    $buildRoot = "/tmp/build-$RID"
    $installDir = "/tmp/install-$RID"
    $filePattern = "*.dylib"
}

# Create build directories
New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

# Build libssh2
Write-Host "Building libssh2..."
$libssh2Build = Join-Path $buildRoot "libssh2"
New-Item -ItemType Directory -Force -Path $libssh2Build | Out-Null
Push-Location $libssh2Build

# Common libssh2 arguments
$libssh2Args = @(
    $libssh2Src
    "-GNinja"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DBUILD_SHARED_LIBS=OFF"
    "-DBUILD_EXAMPLES=OFF" 
    "-DBUILD_TESTING=OFF"
    "-DCMAKE_INSTALL_PREFIX=$installDir"
)

# Platform-specific libssh2 arguments
if ($IsWindows) {
    $libssh2Args += @(
        "-DCRYPTO_BACKEND=WinCNG"
    )
} elseif ($IsLinux) {
    $libssh2Args += @(
        "-DCRYPTO_BACKEND=OpenSSL"
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
    )
} elseif ($IsMacOS) {
    $libssh2Args += @(
        "-DCMAKE_OSX_ARCHITECTURES=$arch"
        "-DCMAKE_OSX_DEPLOYMENT_TARGET=$minVersion"
        "-DCRYPTO_BACKEND=OpenSSL"
        "-DOPENSSL_ROOT_DIR=$opensslRoot"
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
    )
}

cmake @libssh2Args
cmake --build . --target install
Pop-Location

# Build libgit2
Write-Host "Building libgit2..."
$libgit2Build = Join-Path $buildRoot "libgit2"
New-Item -ItemType Directory -Force -Path $libgit2Build | Out-Null
Push-Location $libgit2Build

# Common libgit2 arguments
$libgit2Args = @(
    $libgit2Src
    "-GNinja"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DBUILD_TESTS=OFF"
    "-DBUILD_CLI=OFF"
    "-DUSE_SSH=libssh2"
    "-DLIBGIT2_FILENAME=$libgit2Filename"
    "-DCMAKE_INSTALL_PREFIX=$installDir"
)

# Platform-specific libgit2 arguments
if ($IsWindows) {
    $libgit2Args += @(
        "-DSTATIC_CRT=OFF"
        "-DUSE_HTTPS=Schannel"
    )
} elseif ($IsLinux) {
    $libgit2Args += @(
        "-DUSE_HTTPS=OpenSSL"
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
    )
} elseif ($IsMacOS) {
    $libgit2Args += @(
        "-DCMAKE_OSX_ARCHITECTURES=$arch"
        "-DCMAKE_OSX_DEPLOYMENT_TARGET=$minVersion"
        "-DUSE_HTTPS=SecureTransport"
        "-DOpenSSL_ROOT=$opensslRoot"
        "-DCMAKE_EXE_LINKER_FLAGS=-L$opensslRoot/lib -lssl -lcrypto"
        "-DCMAKE_SHARED_LINKER_FLAGS=-L$opensslRoot/lib -lssl -lcrypto"
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
    )
}

cmake @libgit2Args
cmake --build . --target install
Pop-Location

# Copy build artifacts
Write-Host "Copying libraries to output directory..."
$searchDirs = @("$installDir/lib", "$installDir/bin")
if ($IsWindows) {
    $searchDirs = @("$installDir\lib", "$installDir\bin")
}

foreach ($dir in $searchDirs) {
    if (Test-Path $dir) {
        Get-ChildItem -Path $dir -Filter $filePattern | Copy-Item -Destination $outputDir -Force
    }
}

Write-Host "Build completed for $RID"
if (Test-Path $outputDir) {
    Get-ChildItem $outputDir
} else {
    Write-Warning "Output directory not found: $outputDir"
}
