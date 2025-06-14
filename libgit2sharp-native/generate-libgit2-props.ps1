#!/usr/bin/env pwsh

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"


# Path to libgit2 submodule
$libgit2Src = Join-Path $PSScriptRoot "libgit2"

# Get libgit2 version info
Write-Host "Extracting libgit2 version information..."
Push-Location $libgit2Src
try {
    $libgit2Sha = git rev-parse HEAD
    $libgit2ShaShort = $libgit2Sha.Substring(0, 7)
    $libgit2Filename = "git2-$libgit2ShaShort"
} finally {
    Pop-Location
}

Write-Host "libgit2 SHA: $libgit2Sha"
Write-Host "libgit2 filename: $libgit2Filename"

# Generate props file
$propsFile = Join-Path $PSScriptRoot "libgit2.generated.props"
$propsContent = @"
<Project>
  <PropertyGroup>
    <libgit2_propsfile>`$(MSBuildThisFileFullPath)</libgit2_propsfile>
    <libgit2_hash>$libgit2Sha</libgit2_hash>
    <libgit2_filename>$libgit2Filename</libgit2_filename>
  </PropertyGroup>
</Project>
"@

Write-Host "Generating props file: $propsFile"
Set-Content -Path $propsFile -Value $propsContent -Encoding UTF8

Write-Host "Props file generated successfully"
