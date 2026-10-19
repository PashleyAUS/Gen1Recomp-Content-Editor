param([string[]]$Games = @('red', 'blue', 'yellow', 'gold', 'silver', 'crystal', 'firered', 'leafgreen', 'ruby', 'sapphire', 'emerald'), [switch]$BattleOnly, [switch]$Gameplay)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $workspace
try {
  $env:EDITOR_TEST_ROOT = $workspace
  $env:RULE_TEST_GAMEPLAY = if ($Gameplay) { '1' } else { '0' }
  $env:RULE_TEST_ALL = if ($BattleOnly) { '0' } else { '1' }
  foreach ($gameId in $Games) {
    $env:RULE_TEST_GAME = $gameId
    $suffix = if ($Gameplay) { "gameplay-result" } else { "result" }
    $result = Join-Path $PSScriptRoot "rules-ingame/$gameId-$suffix.txt"
    Set-Content -LiteralPath $result -Value 'RUNNING'
    $process = Start-Process -FilePath (Join-Path $workspace 'love/love.exe') -ArgumentList 'tests/content-editor/rules-ingame' -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddMinutes(15)
    while (-not $process.WaitForExit(10000)) {
      if ([DateTime]::UtcNow -gt $deadline) { $process.Kill(); throw "$gameId rule tests timed out" }
    }
    $output = Get-Content -LiteralPath $result -Raw
    Write-Output $output
    if (-not $output.StartsWith('PASS:')) { throw "$gameId rule tests failed" }
  }
} finally { Pop-Location }

