param([string]$Luau = 'C:/Users/Kyle/AppData/Local/Temp/luau-cli/luau.exe')
$ErrorActionPreference = 'Stop'

# Executes the real RevealGate module with inert service dependencies. These assertions
# cover callback lifecycle logic, not Roblox rendering, input, or ScreenGui masking.
# Run from any directory: pwsh -File tools/tests/RevealGateChecks.ps1 -Luau <luau.exe>
$repo = (Resolve-Path "$PSScriptRoot/../..").Path
$sourcePath = Join-Path $repo 'src/StarterPlayer/StarterPlayerScripts/Controllers/UI/RevealGate.luau'
if (-not (Test-Path -LiteralPath $Luau -PathType Leaf)) {
    throw "Luau interpreter not found at '$Luau'. Supply -Luau with a local interpreter path."
}
$prefix = @'
local attributes = {}
local player = { SetAttribute = function(_, key, value) attributes[key] = value end }
local services = {
    Players = { LocalPlayer = player },
    ReplicatedStorage = { Shared = { Config = {
        Ceremony = "ceremony", Text = "text", UITheme = "theme",
    } } },
    TweenService = {},
}
local game = { GetService = function(_, key) return services[key] end }
local script = { Parent = { Style = "style", Parent = { EffectsQuality = "effects" } } }
local require = function(_) return {} end
local warningCount = 0
local warn = function(_) warningCount += 1 end
local Gate = (function()
'@
$suffix = @'
end)()

local count = 0
Gate.Defer(function() count += 1 end)
assert(count == 1, "Inactive defer must run immediately")
Gate.AfterDragon("confirmed", function() count += 1 end)
assert(count == 1, "Unknown dragon announcement must wait")
Gate.ReleaseDragon("confirmed")
assert(count == 2, "Confirmed result releases one announcement")
Gate.ReleaseDragon("confirmed")
assert(count == 2, "Duplicate release must not repeat")
Gate.AfterDragon("confirmed", function() count += 1 end)
assert(count == 3, "Already released announcement must not be lost")
Gate.AfterDragon("cancelled", function() count += 1 end)
Gate.Cancel()
assert(count == 4, "Cancellation must release held metadata")
assert(attributes.BindRevealActive == false, "Cancellation releases the HUD mask attribute")
Gate.Cancel()
assert(count == 4, "Repeated cancellation must be idempotent")
Gate.Defer(function() error("expected callback failure") end)
assert(warningCount == 1, "Callback failure is isolated and warned")
Gate.Defer(function() count += 1 end)
assert(count == 5, "Queue remains usable after a callback failure")
print("PASS: 10 RevealGate lifecycle assertions; actual source, no Studio rendering simulated.")
'@

# A unique temporary harness avoids clobbering another concurrent test run.
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("bind-dragon-reveal-gate-" + [guid]::NewGuid().ToString('N') + '.luau')
try {
    $contents = [string]::Join("`n", @($prefix, (Get-Content -LiteralPath $sourcePath -Raw), $suffix))
    [System.IO.File]::WriteAllText($temp, $contents, [System.Text.UTF8Encoding]::new($false))
    & $Luau $temp
    if ($LASTEXITCODE -ne 0) { throw "RevealGate checks failed with exit code $LASTEXITCODE." }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp }
}
