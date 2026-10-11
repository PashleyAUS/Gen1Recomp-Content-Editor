param(
  [string]$Runtime,
  [string]$CacheRoot = "$env:APPDATA/LOVE/pokemon-love2d"
)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if (-not $Runtime) { $Runtime = Join-Path $workspace 'runtime/gen1recomp' }
Push-Location $workspace
try {
  & (Join-Path $workspace 'tools/tooling/luajit/luajit.exe') 'tests/content-editor/test_all_game_forms.lua'
  if ($LASTEXITCODE -ne 0) { throw 'All-game form export and template checks failed' }
  foreach ($game in @('firered','leafgreen','ruby','sapphire','emerald')) {
    foreach ($runner in @('run-dynamic-form-checks.ps1','run-form-rule-checks.ps1','run-advanced-form-checks.ps1')) {
      & (Join-Path $PSScriptRoot $runner) -Runtime $Runtime -Game $game -Cache (Join-Path $CacheRoot $game)
    }
  }
} finally { Pop-Location }
