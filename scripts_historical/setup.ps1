param(
  [string]$PythonExe = 'python',
  [string]$RscriptExe = 'Rscript'
)
$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $PSScriptRoot
$deps = Join-Path $base '.deps'
$pyLib = Join-Path $deps 'python'
$rLib = Join-Path $deps 'Rlib'
$tmp = Join-Path $deps 'tmp'
New-Item -ItemType Directory -Force -Path $pyLib,$rLib,$tmp | Out-Null
$env:TEMP = $tmp
$env:TMP = $tmp
if (-not (Get-Command $PythonExe -ErrorAction SilentlyContinue)) { throw "Python no encontrado: $PythonExe. Indique -PythonExe." }
if (-not (Get-Command $RscriptExe -ErrorAction SilentlyContinue)) { throw "Rscript no encontrado: $RscriptExe. Indique -RscriptExe." }
& $PythonExe -m pip install --target $pyLib -r (Join-Path $PSScriptRoot 'requirements.txt')
if ($LASTEXITCODE -ne 0) { throw 'Fallo la instalación de Python.' }
$r = 'options(timeout=600); lib <- commandArgs(TRUE)[1]; dir.create(lib, recursive=TRUE, showWarnings=FALSE); install.packages("survey", repos="https://cloud.r-project.org", lib=lib, type="win.binary")'
& $RscriptExe -e $r $rLib
if ($LASTEXITCODE -ne 0) { throw 'Fallo la instalación de survey en R.' }
Write-Host 'Dependencias preparadas.'
