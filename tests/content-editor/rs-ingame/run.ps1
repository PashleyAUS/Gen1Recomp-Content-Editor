param([string]$Cache = "$env:APPDATA\LOVE\pokemon-love2d")
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$env:EDITOR_TEST_ROOT = $workspace
$env:POKEPORT_RS_CACHE = (Resolve-Path -LiteralPath $Cache).Path
foreach ($rsGame in @('ruby', 'sapphire')) {
  $env:RS_TEST_GAME = $rsGame
  $process = Start-Process -FilePath (Join-Path $workspace 'love/love.exe') -ArgumentList ('"' + $PSScriptRoot + '"') -WindowStyle Hidden -PassThru
  if (-not $process.WaitForExit(60000)) { $process.Kill(); throw "$rsGame test timed out" }
  $result = Get-Content -LiteralPath (Join-Path $PSScriptRoot "$rsGame-result.txt") -Raw
  Write-Output $result
  if (-not $result.StartsWith('PASS:')) { throw "$rsGame in-game test failed" }
}
