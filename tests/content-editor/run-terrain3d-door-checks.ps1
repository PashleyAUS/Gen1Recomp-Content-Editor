param(
  [ValidateSet('emerald','firered','leafgreen')][string[]]$Games = @('emerald','firered','leafgreen'),
  [string]$Runtime,
  [string]$CacheRoot
)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if (-not $Runtime) { $Runtime = Join-Path $workspace 'runtime/gen1recomp' }
if (-not $CacheRoot) { $CacheRoot = Join-Path $env:APPDATA 'LOVE/pokemon-love2d' }
$savedEnv = @{}
foreach ($key in @('EDITOR_TEST_ROOT','POKEPORT_RECOMP','POKEPORT_GEN3_CACHE','POKEPORT_VERSION')) {
  $savedEnv[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
}
Push-Location $workspace
try {
  $env:EDITOR_TEST_ROOT = $workspace
  $env:POKEPORT_RECOMP = (Resolve-Path -LiteralPath $Runtime).Path
  foreach ($game in $Games) {
    $env:POKEPORT_VERSION = $game
    $env:POKEPORT_GEN3_CACHE = (Resolve-Path -LiteralPath (Join-Path $CacheRoot $game)).Path
    $result = Join-Path $PSScriptRoot 'terrain3d-doors/result.txt'
    Set-Content -LiteralPath $result -Value 'RUNNING'
    $process = Start-Process -FilePath (Join-Path $workspace 'love/lovec.exe') `
      -ArgumentList 'tests/content-editor/terrain3d-doors' -WindowStyle Hidden -PassThru `
      -RedirectStandardOutput (Join-Path $PSScriptRoot "terrain3d-doors/$game-log.txt")
    if (-not $process.WaitForExit(55000)) { $process.Kill(); throw "$game rotated building game tests timed out" }
    $output = Get-Content -LiteralPath $result -Raw
    Write-Output "$game`: $output"
    if ($process.ExitCode -ne 0 -or -not $output.StartsWith('PASS:')) {
      throw "$game rotated building game tests failed"
    }
  }
} finally {
  Pop-Location
  foreach ($key in $savedEnv.Keys) {
    [Environment]::SetEnvironmentVariable($key, $savedEnv[$key], 'Process')
  }
}
