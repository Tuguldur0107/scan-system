# Release APK build helper for Windows when BOTH of these paths contain spaces:
#   - Flutter SDK (e.g. C:\Users\ACER PREDATOR\Downloads\flutter_...)
#   - Project / pub workspace (e.g. C:\Users\ACER PREDATOR\OneDrive\...)
#
# Dart's native-assets hook (package:objective_c) can spawn subprocesses with
# unquoted paths → cmd splits at the first space → 'C:\Users\ACER' is not
# recognized. PUB_CACHE alone is NOT enough because package_config.json
# still lives under the spaced project path.
#
# Fix: SUBST two drive letters:
#   - Repo drive → scan-system/ (so app is R:\app with no spaces in path)
#   - Flutter drive → Flutter SDK root (so F:\bin\flutter.bat has no spaces)
#
# Usage (PowerShell):
#   cd "...\scan-system\scripts"
#   .\build_apk_release.ps1

$ErrorActionPreference = 'Stop'

function Find-FlutterRoot {
  if ($env:FLUTTER_ROOT -and (Test-Path (Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat'))) {
    return (Resolve-Path $env:FLUTTER_ROOT).Path
  }
  $cmd = Get-Command flutter -ErrorAction SilentlyContinue
  if (-not $cmd) { throw 'flutter not found in PATH. Add Flutter bin to PATH or set FLUTTER_ROOT.' }
  $bat = $cmd.Source
  $binDir = Split-Path -Parent $bat
  $root = Split-Path -Parent $binDir
  if (-not (Test-Path (Join-Path $root 'bin\flutter.bat'))) {
    throw "Could not resolve Flutter SDK root from: $bat"
  }
  return (Resolve-Path $root).Path
}

function Get-TwoFreeDriveLetters {
  $free = @()
  foreach ($ch in 'R', 'F', 'Q', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') {
    $p = "${ch}:"
    if (-not (Test-Path $p)) {
      $free += $ch
      if ($free.Count -ge 2) { return @($free[0], $free[1]) }
    }
  }
  throw 'Need 2 free drive letters (R–Z) for SUBST. Unmap unused drives or reboot.'
}

$PubCache = 'C:\PubCache'
if (-not (Test-Path $PubCache)) {
  New-Item -ItemType Directory -Force -Path $PubCache | Out-Null
}
$env:PUB_CACHE = $PubCache
Write-Host "PUB_CACHE=$($env:PUB_CACHE)"

$RepoReal = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Write-Host "Repo (real)=$RepoReal"

$FlutterReal = Find-FlutterRoot
Write-Host "Flutter (real)=$FlutterReal"

$pair = Get-TwoFreeDriveLetters
$repoDrive = $pair[0]
$flutterDrive = $pair[1]

Write-Host "SUBST ${repoDrive}: -> $RepoReal"
Write-Host "SUBST ${flutterDrive}: -> $FlutterReal"

# Quoted paths: repo + SDK live under "...\ACER PREDATOR\..." with spaces.
cmd /c "subst ${repoDrive}: `"$RepoReal`""
cmd /c "subst ${flutterDrive}: `"$FlutterReal`""

try {
  # Use "R:\..." not "R:..." — "R:path" is drive-relative and breaks Join-Path.
  $flutterBat = "${flutterDrive}:\bin\flutter.bat"
  if (-not (Test-Path $flutterBat)) {
    throw "SUBST Flutter drive invalid: $flutterBat missing"
  }

  $appRoot = "${repoDrive}:\app"
  Set-Location $appRoot
  Write-Host "AppRoot (SUBST)=$(Get-Location)"
  Write-Host "Using: $flutterBat"

  & $flutterBat clean
  & $flutterBat pub get
  & $flutterBat build apk --release

  $apk = Join-Path $appRoot 'build\app\outputs\flutter-apk\app-release.apk'
  if (Test-Path $apk) {
    Write-Host "OK: $apk"
    Get-Item $apk | Format-List FullName, Length, LastWriteTime
  } else {
    Write-Host "APK not found at expected path: $apk"
    exit 1
  }
} finally {
  # Must leave SUBST drives *before* `subst /d`, otherwise cwd can sit on `R:\`
  # and `cmd.exe` fails with "The directory name is invalid".
  Set-Location $PSScriptRoot
  Write-Host "Removing SUBST ${repoDrive}: and ${flutterDrive}: ..."
  cmd /c "subst ${repoDrive}: /d" 2>$null | Out-Null
  cmd /c "subst ${flutterDrive}: /d" 2>$null | Out-Null
}
