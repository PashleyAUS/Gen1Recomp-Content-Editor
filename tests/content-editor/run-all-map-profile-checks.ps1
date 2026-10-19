param([ValidateSet('emerald','firered','leafgreen')][string[]]$Games=@('emerald','firered','leafgreen'))
$ErrorActionPreference='Stop'
$workspace=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$keys=@('EDITOR_TEST_ROOT','POKEPORT_RECOMP','POKEPORT_GEN3_CACHE','POKEPORT_VERSION','POKEPORT_ALL_MAP_PROFILES')
$saved=@{};foreach($key in $keys){$saved[$key]=[Environment]::GetEnvironmentVariable($key,'Process')}
Push-Location $workspace
try {
  $env:EDITOR_TEST_ROOT=$workspace
  $env:POKEPORT_RECOMP=Join-Path $workspace 'runtime/gen1recomp'
  $env:POKEPORT_ALL_MAP_PROFILES='1'
  foreach($game in $Games){
    $env:POKEPORT_VERSION=$game
    $env:POKEPORT_GEN3_CACHE=Join-Path $env:APPDATA "LOVE/pokemon-love2d/$game"
    $result=Join-Path $PSScriptRoot 'terrain3d-native/result.txt'
    Set-Content -LiteralPath $result -Value 'RUNNING'
    $process=Start-Process -FilePath (Join-Path $workspace 'love/lovec.exe') -ArgumentList 'tests/content-editor/terrain3d-native' -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PSScriptRoot "terrain3d-native/$game-profiles-log.txt")
    $deadline=[DateTime]::UtcNow.AddMinutes(6)
    while(-not $process.WaitForExit(1000)){if([DateTime]::UtcNow -gt $deadline){$process.Kill();throw "$game all-map profile audit timed out"}}
    $process.Refresh()
    $output=Get-Content -LiteralPath $result -Raw
    Write-Output "$game`: $output"
    if($process.ExitCode -ne 0 -or -not $output.StartsWith('PASS:')){throw "$game all-map profile audit failed"}
  }
} finally {
  Pop-Location
  foreach($key in $keys){[Environment]::SetEnvironmentVariable($key,$saved[$key],'Process')}
}
