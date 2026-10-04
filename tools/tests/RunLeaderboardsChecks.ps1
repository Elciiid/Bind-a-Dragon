param([string]$Luau = 'C:/Users/Kyle/AppData/Local/Temp/luau-cli/luau.exe')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path "$PSScriptRoot/../..").Path
# Reuse the existing economic harness loader, but do not execute or alter its simulator.
$loader = Get-Content "$repo/tools/sim/RunCli.ps1" -Raw
$loader = $loader.Substring($loader.IndexOf("`$chunks ="), $loader.IndexOf("`$chunks.Add('sources[`"Sim`"]") - $loader.IndexOf("`$chunks ="))
Invoke-Expression $loader
$chunks.Add('sources["LeaderboardChecks"]=[====[' + (Get-Content "$PSScriptRoot/LeaderboardsChecks.luau" -Raw) + ']====]')
$chunks.Add('loadModule(node("LeaderboardChecks"))()')
$temp = Join-Path ([System.IO.Path]::GetTempPath()) 'bind-dragon-leaderboards-checks.luau'
[System.IO.File]::WriteAllText($temp, [string]::Join("`n", $chunks))
& $Luau $temp
if ($LASTEXITCODE -ne 0) { throw 'Leaderboard checks failed' }
