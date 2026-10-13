$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskRun=Join-Path $PSScriptRoot 'mega-ingame'
New-Item -ItemType Directory -Force -Path "$taskRun/save/mods", "$taskRun/shots" | Out-Null
if (Test-Path -LiteralPath "$taskRoot/mods/Mega/Megas") {
  Copy-Item -LiteralPath "$taskRoot/mods/Mega/Megas" -Destination "$taskRun/save/mods" -Recurse -Force
}
Set-Content -LiteralPath "$taskRun/save/options.lua" -Value 'return {mods={Megas=true},modsByVersion={sapphire={Megas=true}}}'
Set-Content -LiteralPath "$taskRun/result.log" -Value 'RUNNING'
$env:EDITOR_TEST_ROOT=$taskRoot
$env:POKEPORT_GEN3_CACHE=Join-Path $env:APPDATA 'LOVE/pokemon-love2d/sapphire'
$env:POKEPORT_GAME='sapphire'
$env:POKEPORT_VERSION='sapphire'
$env:POKEPORT_DRIVER="$taskRun/driver.lua"
$env:POKEPORT_SPEED='10'
Push-Location $taskRoot
try {
  $taskProcess=Start-Process -FilePath "$taskRoot/love/lovec.exe" -ArgumentList 'tests/content-editor/mega-ingame' -WindowStyle Hidden -PassThru -RedirectStandardOutput "$taskRun/stdout.log" -RedirectStandardError "$taskRun/stderr.log"
  if (-not $taskProcess.WaitForExit(50000)) { $taskProcess.Kill();throw 'Mega in-game test timed out' }
  Get-Content -LiteralPath "$taskRun/result.log" -Tail 32
  if ($taskProcess.ExitCode -ne 0 -or -not (Select-String -LiteralPath "$taskRun/result.log" -Pattern '^RESULT: 0 failure\(s\)$' -Quiet)) { throw 'Mega in-game test failed' }
} finally { Pop-Location }
