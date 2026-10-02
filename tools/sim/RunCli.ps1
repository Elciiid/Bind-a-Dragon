param([string]$Luau = 'C:/Users/Kyle/AppData/Local/Temp/luau-cli/luau.exe', [int]$Runs = 20, [int]$MaxDays = 120, [string]$Profile = 'Dedicated', [double]$LateGrowth = 0, [switch]$Baseline, [switch]$Check)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path "$PSScriptRoot/../..").Path
$chunks = [System.Collections.Generic.List[string]]::new()
$chunks.Add(@'
local sources, cache = {}, {}
local function node(path) return setmetatable({Path=path}, {__index=function(t,k) return node(t.Path.."/"..k) end}) end
local game = {GetService=function(_, name) return node(name) end}
local Color3 = {fromRGB=function(...) return {...} end, new=function(...) return {...} end}
local Vector3 = {new=function(...) return {...} end}
local Vector2 = {new=function(...) return {...} end}
local Random = {new=function(seed)
 local state = math.max(1, seed % 2147483647)
 local function next() state = (state * 16807) % 2147483647; return state / 2147483647 end
 return {NextNumber=function(_,a,b) local x=next(); return if a then a+x*((b or 1)-a) else x end, NextInteger=function(_,a,b) return a+math.floor(next()*(b-a+1)) end}
end}
local env = setmetatable({game=game,Color3=Color3,Vector3=Vector3,Vector2=Vector2,NumberRange={new=function(...) return {...} end},Random=Random,task={wait=function() end},warn=print}, {__index=getfenv()})
local function loadModule(n)
 local path=n.Path
 if cache[path] then return cache[path] end
 assert(sources[path], "Missing "..path)
 local fn, err=loadstring(sources[path],path); assert(fn,err); setfenv(fn,env)
 cache[path]=fn(); return cache[path]
end
env.require=loadModule
'@)
Get-ChildItem "$repo/src/ReplicatedStorage/Shared" -Filter '*.luau' -Recurse | ForEach-Object {
    $key = 'ReplicatedStorage/Shared/' + [System.IO.Path]::GetRelativePath("$repo/src/ReplicatedStorage/Shared", $_.FullName).Replace('\','/').Replace('.luau','')
    $source = Get-Content -LiteralPath $_.FullName -Raw
    $chunks.Add('sources["'+$key+'"]=[====['+$source+']====]')
}
$chunks.Add('sources["Sim"]=[====['+(Get-Content "$PSScriptRoot/CohortSim.luau" -Raw)+']====]')
$chunks.Add('local Sim=loadModule(node("Sim"))')
if ($Check) {
    $chunks.Add('sources["CostChecks"]=[====['+(Get-Content "$PSScriptRoot/CostChecks.luau" -Raw)+']====]')
    $chunks.Add('local checks=loadModule(node("CostChecks"))(); for k,v in checks do print(k,v) end')
}
if ($Baseline) { $chunks.Add('Sim.SetVariant("FlatLevelCost",true); Sim.Set("Rebirth","LateGrowth",2.55)') }
if ($LateGrowth -gt 0) { $chunks.Add('Sim.Set("Rebirth","LateGrowth",'+$LateGrowth.ToString([cultureinfo]::InvariantCulture)+')') }
if ($Runs -gt 0) {
    $chunks.Add('local r=Sim.Cohort("'+$Profile+'",'+$Runs+','+$MaxDays+')')
    $chunks.Add('for k,v in r do if type(v)~="table" then print(k,v) end end')
}
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('bind-dragon-cohort-'+$Profile+'-'+$LateGrowth+'-'+$Runs+'-'+[bool]$Baseline+'.luau')
[System.IO.File]::WriteAllText($temp, [string]::Join("`n", $chunks))
& $Luau $temp
if ($LASTEXITCODE -ne 0) { throw "Luau simulation failed" }
