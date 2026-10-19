param(
  [ValidateSet('emerald','firered','leafgreen')][string[]]$Games = @('emerald','firered','leafgreen')
)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$savedEnv = @{}
foreach ($key in @('POKEPORT_CUSTOM_MODEL_REVIEW','POKEPORT_INTERIOR_REVIEW','POKEPORT_INTERIOR_MAP')) {
  $savedEnv[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
}
Push-Location $workspace
try {
  & (Join-Path $workspace 'tools/tooling/luajit/luajit.exe') 'tests/content-editor/test_custom_models_3d.lua'
  if ($LASTEXITCODE -ne 0) { throw 'Custom model parser/serialization tests failed' }
  $env:POKEPORT_CUSTOM_MODEL_REVIEW = '1'
  $env:POKEPORT_INTERIOR_REVIEW = '0'
  $env:POKEPORT_INTERIOR_MAP = $null
  & (Join-Path $PSScriptRoot 'run-terrain3d-native-checks.ps1') -Games $Games
  foreach ($game in $Games) {
    $env:POKEPORT_INTERIOR_REVIEW = '1'
    $env:POKEPORT_INTERIOR_MAP = if ($game -eq 'emerald') {
      'EM_OLDALE_TOWN_POKEMON_CENTER_1F'
    } else { 'FR_VIRIDIAN_CITY_POKEMON_CENTER_1F' }
    & (Join-Path $PSScriptRoot 'run-terrain3d-native-checks.ps1') -Games @($game)
    & (Join-Path $PSScriptRoot 'run-terrain3d-town-checks.ps1') -Games @($game)
  }
} finally {
  Pop-Location
  foreach ($key in $savedEnv.Keys) {
    [Environment]::SetEnvironmentVariable($key, $savedEnv[$key], 'Process')
  }
}
