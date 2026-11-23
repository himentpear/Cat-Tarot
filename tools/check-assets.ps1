# Verify assets/ still matches assets.sha256 (Windows).
#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Split-Path -Parent $here
$py = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
if (-not $py) { $py = Get-Command py -ErrorAction SilentlyContinue }
if (-not $py) { Write-Error "Python 3.8+ is required"; exit 1 }
& $py.Source (Join-Path $here "assets.py") --root $repo check @args
exit $LASTEXITCODE
