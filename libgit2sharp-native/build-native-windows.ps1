param(
    [string]$RID
)

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"

# Validate RID
if ($RID -notin @("win-x64", "win-x86", "win-arm64")) {
    Write-Error "Unknown RID: $RID. Valid values: win-x64, win-x86, win-arm64"
}

Write-Host "Building $RID using Visual Studio generators (simpler than Ninja on Windows)"

$libssh2Src = "$PSScriptRoot\libssh2"
$libgit2Src = "$PSScriptRoot\libgit2"
$outputDir = "$PSScriptRoot\build-output\$RID"

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# Get libgit2 version info
Push-Location $libgit2Src
$libgit2Sha = git rev-parse HEAD
$libgit2ShaShort = $libgit2Sha.Substring(0,7)
$libgit2Filename = "git2-$libgit2ShaShort"
Pop-Location

# Map RID to Visual Studio architecture
$arch = switch ($RID) {
    "win-x64"   { "x64" }
    "win-x86"   { "Win32" }
    "win-arm64" { "ARM64" }
}

$buildRoot = "$PSScriptRoot\build-$RID"
$installDir = "$buildRoot\install"

# Windows-specific build settings
$env:RC = "rc.exe"
$libgit2Args = @(
    '-DUSE_HTTPS=Schannel'
    '-DUSE_SSH=libssh2'
    '-DLIBGIT2_FILENAME=' + $libgit2Filename
)

# Build libssh2
Write-Host "Building libssh2 for $RID..."
$libssh2Build = "$buildRoot\libssh2"
New-Item -ItemType Directory -Force -Path $libssh2Build | Out-Null
Push-Location $libssh2Build

cmake $libssh2Src `
    -A $arch `
    -DBUILD_SHARED_LIBS=OFF `
    -DBUILD_EXAMPLES=OFF `
    -DBUILD_TESTING=OFF `
    -DCRYPTO_BACKEND=WinCNG `
    -DCMAKE_INSTALL_PREFIX="$installDir"

cmake --build . --config Release --target install
Pop-Location

# Build libgit2
Write-Host "Building libgit2 for $RID..."
$libgit2Build = "$buildRoot\libgit2"
New-Item -ItemType Directory -Force -Path $libgit2Build | Out-Null
Push-Location $libgit2Build

cmake $libgit2Src `
    -A $arch `
    -DBUILD_TESTS=OFF `
    -DBUILD_CLI=OFF `
    -DCMAKE_INSTALL_PREFIX="$installDir" `
    -DLibSSH2_DIR="$installDir" `
    @libgit2Args

cmake --build . --config Release --target install
Pop-Location

# Copy DLLs to output directory
Write-Host "Copying libraries to output directory..."
if (Test-Path "$installDir\bin") {
    Get-ChildItem -Path "$installDir\bin" -Filter "*.dll" | Copy-Item -Destination $outputDir -Force
}
if (Test-Path "$installDir\lib") {
    Get-ChildItem -Path "$installDir\lib" -Filter "*.dll" | Copy-Item -Destination $outputDir -Force  
}

Write-Host "Build completed for $RID"
if (Test-Path $outputDir) {
    Get-ChildItem $outputDir
} else {
    Write-Warning "Output directory not found: $outputDir"
}
