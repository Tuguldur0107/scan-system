# Runs Flutter web from a drive letter + pub cache without spaces (fixes Windows
# native-assets / objective_c hook when the user profile path contains spaces).
param(
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

  flutter pub get
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  if ($FlutterArgs.Count -gt 0 -and $FlutterArgs[0] -eq 'flutter') {
    $FlutterArgs = @($FlutterArgs | Select-Object -Skip 1)
  }
  if ($FlutterArgs.Count -gt 0) {
    & flutter @FlutterArgs
  } else {
    & flutter run -d chrome
  }
  exit $LASTEXITCODE
}
finally {
  if ($mapped) {
    Set-Location $env:USERPROFILE
    cmd /c "subst ${dl}: /d" 2>$null
  }
}
