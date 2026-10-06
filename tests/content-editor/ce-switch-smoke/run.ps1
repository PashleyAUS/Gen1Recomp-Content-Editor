param([string]$LinkedRuntime = 'C:\Users\amand\Downloads\gen1recomp-dev\gen1recomp-dev')
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$env:EDITOR_TEST_ROOT = $workspace
$env:CE_LINKED_ROOT = (Resolve-Path -LiteralPath $LinkedRuntime).Path
foreach ($fallback in @($false, $true)) {
  if ($fallback) { $env:CE_TEST_FALLBACK = '1'; $env:POKEPORT_RECOMP = $env:CE_LINKED_ROOT }
  else { Remove-Item Env:CE_TEST_FALLBACK -ErrorAction SilentlyContinue; Remove-Item Env:POKEPORT_RECOMP -ErrorAction SilentlyContinue }
  $process = Start-Process -FilePath (Join-Path $workspace 'love/love.exe') -ArgumentList ('"' + $PSScriptRoot + '"') -WindowStyle Hidden -PassThru
  if (-not $process.WaitForExit(60000)) { $process.Kill(); throw "CE switch test timed out" }
  $result = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'result.txt') -Raw
  Write-Output $result
  if (-not $result.StartsWith('PASS:')) { throw 'CE switch test failed' }
}
