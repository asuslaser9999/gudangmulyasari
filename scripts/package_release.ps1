# Salin hasil build ke dist/ seperti Mulyasari POS.
# Usage:
#   powershell -File scripts/package_release.ps1
#   powershell -File scripts/package_release.ps1 -SkipBuild

param(
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$pubspec = Get-Content (Join-Path $root 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
  throw 'Tidak menemukan version di pubspec.yaml'
}
$version = $Matches[1]

$apkSrc = Join-Path $root 'build\app\outputs\apk\release\app-release.apk'
$apkSrcAlt = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
$winSrc = Join-Path $root 'build\windows\x64\runner\Release'
$dist = Join-Path $root 'dist'
$apkDest = Join-Path $dist "InventoriGudang-v$version.apk"
$winDest = Join-Path $dist 'InventoriGudang-Windows-x64'

if (-not $SkipBuild) {
  flutter build apk --release
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  flutter build windows --release
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$apk = if (Test-Path $apkSrc) { $apkSrc } elseif (Test-Path $apkSrcAlt) { $apkSrcAlt } else { $null }
if (-not $apk) { throw "APK belum ada. Jalankan tanpa -SkipBuild." }
if (-not (Test-Path $winSrc)) { throw "Folder Windows Release belum ada. Jalankan tanpa -SkipBuild." }

New-Item -ItemType Directory -Force -Path $dist | Out-Null
Copy-Item -Force $apk $apkDest
if (Test-Path $winDest) {
  Remove-Item -Recurse -Force $winDest
}
Copy-Item -Recurse $winSrc $winDest

Write-Host "APK: $apkDest"
Write-Host "EXE: $(Join-Path $winDest 'gudangmulyasari.exe')"
