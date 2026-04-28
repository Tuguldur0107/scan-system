$ErrorActionPreference = 'Stop'

$scriptsDir = $PSScriptRoot

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Scan System - Dev Web Helper" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

function Test-ServerUp {
  try {
    $r = Invoke-WebRequest -Uri "http://localhost:8080" -Method Head -TimeoutSec 2 -ErrorAction Stop
    return $true
  } catch {
    return $false
  }
}

if (Test-ServerUp) {
  Write-Host "[OK] Server already running at http://localhost:8080" -ForegroundColor Green
} else {
  Write-Host "[1/2] Starting server in a new terminal..." -ForegroundColor Yellow
  Start-Process -FilePath "cmd.exe" -ArgumentList "/k `"$scriptsDir\start_server.cmd`"" | Out-Null
  Start-Sleep -Seconds 6
}

Write-Host "[2/2] Starting Flutter Web (Chrome)..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Dev loop shortcuts while app is running:" -ForegroundColor Gray
Write-Host "  r  = hot reload (most code/UI changes)" -ForegroundColor Gray
Write-Host "  R  = hot restart (state reset)" -ForegroundColor Gray
Write-Host "  q  = quit web runner" -ForegroundColor Gray
Write-Host ""
Write-Host "Tip: keep this terminal open; no need full restart each edit." -ForegroundColor Gray
Write-Host ""

& "$scriptsDir\run_web.ps1"
exit $LASTEXITCODE

