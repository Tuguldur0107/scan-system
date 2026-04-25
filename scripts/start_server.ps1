# ============================================================
# Server & Database starter (one-click)
#
# What it does:
#   1. Starts PostgreSQL via Docker
#   2. Detects the LAN IPv4 address (for phone access)
#   3. Starts the dart_frog dev server
#   4. Prints the URL the phone should use
#
# Usage:
#   .\start_server.ps1
#
# Stop:
#   Ctrl+C  (the Postgres container keeps running in the background)
# ============================================================

$ErrorActionPreference = 'Stop'

$scanSystemRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$serverDir = Join-Path $scanSystemRoot 'server'

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

# Step 1: Check docker
Write-Host ""
Write-Host "==> [1/4] Checking Docker..." -ForegroundColor Cyan
try {
  docker version --format '{{.Server.Version}}' | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "docker not running" }
  Write-Host "    OK: Docker is running" -ForegroundColor Green
} catch {
  Write-Host "    ERROR: Docker Desktop is not running." -ForegroundColor Red
  Write-Host "    Please start Docker Desktop, then run this script again." -ForegroundColor Yellow
  exit 1
}

# Step 2: Start postgres
Write-Host ""
Write-Host "==> [2/4] Starting PostgreSQL container..." -ForegroundColor Cyan
Push-Location $serverDir
try {
  docker-compose up -d postgres
  if ($LASTEXITCODE -ne 0) {
    Write-Host "    ERROR: docker-compose failed" -ForegroundColor Red
    exit 1
  }
  Write-Host "    OK: PostgreSQL is up" -ForegroundColor Green
} finally {
  Pop-Location
}

# Step 3: Wait for postgres to accept connections
Write-Host ""
Write-Host "==> [3/4] Waiting for database to be ready..." -ForegroundColor Cyan
$retries = 20
$ready = $false
for ($i = 0; $i -lt $retries; $i++) {
  docker exec server-postgres-1 pg_isready -U scan_user -d scan_system 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) {
    $ready = $true
    break
  }
  Start-Sleep -Seconds 1
  Write-Host "." -NoNewline
}
Write-Host ""
if ($ready) {
  Write-Host "    OK: Database is accepting connections" -ForegroundColor Green
} else {
  Write-Host "    WARNING: Database is slow to respond. Continuing anyway." -ForegroundColor Yellow
}

# Step 4: Print connection info
$lanIp = Get-LanIPv4
if (-not $lanIp) { $lanIp = 'localhost' }

Write-Host ""
Write-Host "==> [4/4] Starting dart_frog dev server..." -ForegroundColor Magenta
Write-Host ""
Write-Host "    From this computer:     http://localhost:8080" -ForegroundColor White
Write-Host "    From phone on same WiFi http://$($lanIp):8080" -ForegroundColor Yellow
Write-Host ""
Write-Host "    To start the phone app with this address, in another terminal run:" -ForegroundColor Gray
Write-Host "      .\run_android.ps1 -ApiBaseUrl http://$($lanIp):8080" -ForegroundColor Gray
Write-Host ""
Write-Host "    Press Ctrl+C to stop the server (the database keeps running)." -ForegroundColor DarkGray
Write-Host ""

# Step 5: Ensure dart_frog_cli is installed
$dartFrogInstalled = $false
$listOutput = dart pub global list 2>$null
if ($listOutput -match 'dart_frog_cli') { $dartFrogInstalled = $true }

if (-not $dartFrogInstalled) {
  Write-Host "    dart_frog_cli is not installed. Installing now..." -ForegroundColor Yellow
  dart pub global activate dart_frog_cli
  if ($LASTEXITCODE -ne 0) {
    Write-Host "    ERROR: failed to install dart_frog_cli" -ForegroundColor Red
    exit 1
  }
}

# Step 6: Run the server
Set-Location $serverDir
dart pub get
if ($LASTEXITCODE -ne 0) {
  Write-Host "    ERROR: 'dart pub get' failed" -ForegroundColor Red
  exit $LASTEXITCODE
}

# Call dart_frog through "dart pub global run" so we don't need it on PATH.
# This works on fresh machines where pub-cache/bin is not in the user PATH.
dart pub global run dart_frog_cli:dart_frog dev
