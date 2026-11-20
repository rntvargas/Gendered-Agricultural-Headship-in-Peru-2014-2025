param(
  [string]$DataRoot = '.',
  [string]$HistoricalSav = '',
  [string]$Round2025Sav = '',
  [string]$PythonExe = 'python',
  [string]$RscriptExe = 'Rscript'
)
$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $PSScriptRoot
if (-not $HistoricalSav) { $HistoricalSav = Join-Path $DataRoot 'ENA_2014_2024.sav' }
if (-not $Round2025Sav) { $Round2025Sav = Join-Path $DataRoot 'ENA_2025\1036-Modulo1911\19_CAP1100.sav' }
foreach ($path in @($HistoricalSav,$Round2025Sav)) {
  if (-not (Test-Path -LiteralPath $path)) { throw "No se encontró: $path" }
}
foreach ($exe in @($PythonExe,$RscriptExe)) {
  if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { throw "No se encontró el ejecutable: $exe" }
}
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$run = Join-Path $base "runs\$stamp"
New-Item -ItemType Directory -Force -Path $run | Out-Null
$csv = Join-Path $run 'holders_2014_2025_LOCAL_ONLY.csv'
$results = Join-Path $run 'results'
$env:PYTHONPATH = Join-Path $base '.deps\python'
$env:ENA_R_LIB = Join-Path $base '.deps\Rlib'
& $PythonExe (Join-Path $PSScriptRoot 'extract_design.py') --historical $HistoricalSav --round-2025 $Round2025Sav --output $csv
if ($LASTEXITCODE -ne 0) { throw 'Fallo la extracción de datos.' }
& $RscriptExe (Join-Path $PSScriptRoot 'run_analysis.R') $csv $results
if ($LASTEXITCODE -ne 0) { throw 'Fallo el análisis en R.' }
$files = @($HistoricalSav,$Round2025Sav,(Join-Path $PSScriptRoot 'extract_design.py'),(Join-Path $PSScriptRoot 'run_analysis.R'))
$files += Get-ChildItem -LiteralPath $results -File | ForEach-Object FullName
$manifest = foreach ($file in $files) {
  $item = Get-Item -LiteralPath $file
  $hash = Get-FileHash -LiteralPath $file -Algorithm SHA256
  [pscustomobject]@{ Path=$item.FullName; Bytes=$item.Length; SHA256=$hash.Hash }
}
$manifest | Export-Csv -LiteralPath (Join-Path $run 'manifest_sha256.csv') -NoTypeInformation -Encoding UTF8
Write-Host "Ejecución completa: $run"
Write-Host 'El CSV LOCAL_ONLY contiene microdatos y no se debe subir al depósito.'
