# Runs Flutter on Android (emulator or physical device) from a drive letter +
# pub cache without spaces (fixes Windows native-assets / objective_c hook when
# the user profile path contains spaces).
#
# Usage examples:
#   .\run_android.ps1                                  # auto-picks first connected device
#   .\run_android.ps1 -DeviceId emulator-5554
#   .\run_android.ps1 -ApiBaseUrl http://192.168.1.128:8080
#   .\run_android.ps1 -DeviceId C5 -ApiBaseUrl http://10.0.2.2:8080
#   .\run_android.ps1 -- build apk                     # pass-through to flutter

param(
  [string] $DeviceId = '',
  [string] $ApiBaseUrl = '',
  [switch] $Clean,
  [switch] $Release,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $FlutterArgs
)

$ErrorActionPreference = 'Stop'

$scanSystemRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pubCache = 'C:\FlutterPubCache'

if (-not (Test-Path $pubCache)) {
  New-Item -ItemType Directory -Path $pubCache -Force | Out-Null
}
$env:PUB_CACHE = $pubCache

function Get-FreeDriveLetter {
  foreach ($c in 'Z', 'Y', 'X', 'W', 'V', 'U', 'T', 'S', 'R') {
    if (-not (Test-Path "${c}:\")) { return $c }
  }
  return $null
}

function Get-LanIPv4 {
  $addrs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
      $_.InterfaceAlias -notmatch 'Loopback|vEthernet|WSL|Hyper-V' -and
      $_.IPAddress -notmatch '^(169\.|127\.)' -and
      $_.PrefixOrigin -ne 'WellKnown'
    } | Sort-Object -Property @{Expression = {
      if ($_.IPAddress -like '192.168.*') { 0 }
      elseif ($_.IPAddress -like '10.*') { 1 }
      elseif ($_.IPAddress -like '172.*') { 2 }
      else { 3 }
    }}
  if ($addrs) { return $addrs[0].IPAddress }
  return $null
}

$dl = Get-FreeDriveLetter
if (-not $dl) {
  Write-Error 'No free drive letter for SUBST (try removing unused mappings: subst).'
  exit 1
}

$mapped = $false
try {
  $cmd = "subst ${dl}: `"$scanSystemRoot`""
  cmd /c $cmd
  if ($LASTEXITCODE -ne 0) {
    Write-Error "subst failed: $cmd"
    exit $LASTEXITCODE
  }
  $mapped = $true

  Set-Location "${dl}:\app"

  if ($Clean) {
    Write-Host "Running flutter clean (may take a minute)..." -ForegroundColor Yellow
    flutter clean
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }

  flutter pub get
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  # Resolve device id: explicit > first android device from `flutter devices --machine`
  if (-not $DeviceId) {
    $json = flutter devices --machine 2>$null | Out-String
    try {
      $devs = $json | ConvertFrom-Json
      $android = $devs | Where-Object { $_.targetPlatform -match '^android' -and $_.ephemeral -ne $false } | Select-Object -First 1
      if (-not $android) {
        $android = $devs | Where-Object { $_.targetPlatform -match '^android' } | Select-Object -First 1
      }
      if ($android) { $DeviceId = $android.id }
    } catch {}
  }

  if (-not $DeviceId) {
    Write-Warning 'No Android device found. Start an emulator or plug in a device, then rerun.'
    Write-Host 'Tip: flutter emulators --launch Medium_Phone_API_36.0' -ForegroundColor Yellow
    exit 2
  }

  # Resolve API base URL: explicit > emulator loopback if device looks like emulator > LAN IP
  if (-not $ApiBaseUrl) {
    if ($DeviceId -match 'emulator-' -or $DeviceId -match '^emulator') {
      $ApiBaseUrl = 'http://10.0.2.2:8080'
    } else {
      $lan = Get-LanIPv4
      if ($lan) {
        $ApiBaseUrl = "http://${lan}:8080"
      } else {
        Write-Warning 'Could not auto-detect LAN IPv4. Falling back to http://10.0.2.2:8080.'
        $ApiBaseUrl = 'http://10.0.2.2:8080'
      }
    }
  }

  Write-Host "Device:        $DeviceId" -ForegroundColor Cyan
  Write-Host "API_BASE_URL:  $ApiBaseUrl" -ForegroundColor Cyan

  if ($FlutterArgs.Count -gt 0 -and $FlutterArgs[0] -eq 'flutter') {
    $FlutterArgs = @($FlutterArgs | Select-Object -Skip 1)
  }
  if ($FlutterArgs.Count -gt 0) {
    # Pass-through: user is running a custom flutter subcommand (e.g. build apk).
    & flutter @FlutterArgs --dart-define=API_BASE_URL=$ApiBaseUrl
  } else {
    if ($Release) {
      Write-Host "Mode:          RELEASE (faster, no hot reload)" -ForegroundColor Green
      & flutter run -d $DeviceId --release --dart-define=API_BASE_URL=$ApiBaseUrl
    } else {
      Write-Host "Mode:          DEBUG (hot reload enabled, slower)" -ForegroundColor Yellow
      & flutter run -d $DeviceId --dart-define=API_BASE_URL=$ApiBaseUrl
    }
  }
  exit $LASTEXITCODE
}
finally {
  if ($mapped) {
    Set-Location $env:USERPROFILE
    cmd /c "subst ${dl}: /d" 2>$null
  }
}
