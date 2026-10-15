$ErrorActionPreference='Stop'
$workspace=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $workspace
try {
  $env:EDITOR_TEST_ROOT=$workspace
  $env:ADVENTURE_TEST_OUTPUT=Join-Path $PSScriptRoot 'adventure-smoke/output'
  & (Join-Path $workspace 'tools/tooling/luajit/luajit.exe') 'tests/content-editor/test_adventure_workflow.lua'
  if ($LASTEXITCODE -ne 0) { throw 'Adventure workflow checks failed' }
  $result=Join-Path $PSScriptRoot 'adventure-smoke/result.txt'
  Set-Content -LiteralPath $result -Value 'RUNNING'
  $process=Start-Process -FilePath (Join-Path $workspace 'love/love.exe') -ArgumentList 'tests/content-editor/adventure-smoke' -WindowStyle Hidden -PassThru
  if (-not $process.WaitForExit(50000)) { $process.Kill();throw 'Adventure smoke test timed out' }
  $output=Get-Content -LiteralPath $result -Raw
  Write-Output $output
  if (-not $output.StartsWith('PASS:')) { throw 'Adventure smoke test failed' }
} finally { Pop-Location }
