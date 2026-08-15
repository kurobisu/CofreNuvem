#Requires -Version 5.1
<#
.SYNOPSIS
  Build the CofreNuvem Windows installer with Inno Setup.
.DESCRIPTION
  Compiles the Flutter Windows release bundle and packages it into a single
  setup executable using the Inno Setup script at .\cofrenuvem.iss.
#>
[CmdletBinding()]
param(
    [string]$FlutterPath = "",
    [string]$IssPath = "$PSScriptRoot\cofrenuvem.iss",
    [string]$IsccPath = ""
)

$ErrorActionPreference = "Stop"

# Resolve Flutter executable: prefer PATH, then common locations.
if (-not $FlutterPath) {
    $flutterFromPath = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterFromPath) {
        $FlutterPath = $flutterFromPath.Source
    } else {
        $candidates = @(
            "D:\flutter\bin\flutter.bat"
            "C:\flutter\bin\flutter.bat"
            "${env:LOCALAPPDATA}\flutter\bin\flutter.bat"
        )
        $FlutterPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
}
if (-not $FlutterPath -or -not (Test-Path $FlutterPath)) {
    throw "Flutter executable not found. Provide -FlutterPath or add flutter to PATH."
}

# Resolve project root (parent of installer directory).
$projectRoot = Resolve-Path "$PSScriptRoot\.." | Select-Object -ExpandProperty Path

# Ensure Visual C++ Redistributable is available for the installer.
$redistDir = Join-Path $PSScriptRoot "redist"
$redistFile = Join-Path $redistDir "vc_redist.x64.exe"
if (-not (Test-Path $redistFile)) {
    New-Item -ItemType Directory -Path $redistDir -Force | Out-Null
    Write-Host "Downloading Visual C++ Redistributable..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vc_redist.x64.exe" -OutFile $redistFile -UseBasicParsing
}

# Read version from the Dart source of truth.
$versionFile = Join-Path $projectRoot "lib\utils\app_version.dart"
$versionMatch = Select-String -Path $versionFile -Pattern "appVersion\s*=\s*'v?\.?([^']+)'"
if (-not $versionMatch) {
    throw "Could not extract appVersion from $versionFile"
}
$version = $versionMatch.Matches[0].Groups[1].Value
Write-Host "Building CofreNuvem v$version" -ForegroundColor Cyan

# Build Flutter Windows release bundle.
Write-Host "Building Flutter Windows release..." -ForegroundColor Cyan
& $FlutterPath build windows --release
if ($LASTEXITCODE -ne 0) {
    throw "Flutter build failed with exit code $LASTEXITCODE"
}

# Locate Inno Setup compiler.
$isccCandidates = @(
    $IsccPath,
    "${env:ProgramFiles}\Inno Setup 7\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 7\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)
$IsccPath = $isccCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $IsccPath) {
    throw "Inno Setup compiler (ISCC.exe) not found. Install Inno Setup 6 or 7."
}

# Package with Inno Setup, injecting the extracted version into the script.
Write-Host "Packaging installer with Inno Setup..." -ForegroundColor Cyan
$issContent = Get-Content -Path $IssPath -Raw
$issContent = $issContent -replace '#define MyAppVersion "[^"]*"', "#define MyAppVersion `"$version`""
$issDir = Split-Path -Path $IssPath -Parent
$tempIssPath = Join-Path $issDir "cofrenuvem-$version.iss"
$issContent | Out-File -FilePath $tempIssPath -Encoding utf8

try {
    & $IsccPath "$tempIssPath"
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup build failed with exit code $LASTEXITCODE"
    }
} finally {
    Remove-Item -Path $tempIssPath -ErrorAction SilentlyContinue
}

$installer = Join-Path $projectRoot "build\windows\x64\installer\CofreNuvem-Setup-$version.exe"
Write-Host "Installer created: $installer" -ForegroundColor Green
