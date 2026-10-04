param([string]$Luau = 'C:/Users/Kyle/AppData/Local/Temp/luau-cli/luau.exe')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path "$PSScriptRoot/../..").Path
$chunks = [System.Collections.Generic.List[string]]::new()
$chunks.Add(@'
local sources, cache = {}, {}
local function node(path) return setmetatable({Path=path}, {__index=function(t,k) return node(t.Path.."/"..k) end}) end
local function vector(x,y,z)
 return setmetatable({X=x,Y=y,Z=z}, {__index=function(t,k)
  if k=="Unit" then local length=math.sqrt(x*x+y*y+(z or 0)^2); return {X=x/length,Y=y/length,Z=(z or 0)/length} end
 end})
end
local env=setmetatable({
 game={GetService=function(_,n) return node(n) end},
 Color3={fromRGB=function(...) return {...} end,new=function(...) return {...} end},
 Vector2={new=vector},Vector3={new=vector},NumberRange={new=function(...) return {...} end},
 Enum=setmetatable({}, {__index=function(_,group) return setmetatable({}, {__index=function(_,key) return group.."."..key end}) end}),
 Font={new=function(...) return {...} end}, Rect={new=function(...) return {...} end},
 UDim2={fromOffset=function(x,y) return {X={Scale=0,Offset=x},Y={Scale=0,Offset=y}} end},
},{__index=getfenv()})
local function loadModule(n)
 local path=n.Path; if cache[path] then return cache[path] end
 assert(sources[path],"Missing "..path)
 local fn,err=loadstring(sources[path],path); assert(fn,err); setfenv(fn,env)
 cache[path]=fn(); return cache[path]
end
env.require=loadModule
'@)
Get-ChildItem "$repo/src/ReplicatedStorage/Shared" -Filter '*.luau' -Recurse | ForEach-Object {
    $key = 'ReplicatedStorage/Shared/' + [System.IO.Path]::GetRelativePath("$repo/src/ReplicatedStorage/Shared", $_.FullName).Replace('\','/').Replace('.luau','')
    $chunks.Add('sources["'+$key+'"]=[====['+(Get-Content -LiteralPath $_.FullName -Raw)+']====]')
}
$chunks.Add('sources["MobileUIChecks"]=[====['+(Get-Content "$PSScriptRoot/MobileUIChecks.luau" -Raw)+']====]')
$chunks.Add('local clientSources = {}')
Get-ChildItem "$repo/src/StarterPlayer/StarterPlayerScripts/Controllers" -Filter '*.luau' -Recurse | ForEach-Object {
    $key = [System.IO.Path]::GetRelativePath($repo, $_.FullName).Replace('\','/')
    $chunks.Add('clientSources["'+$key+'"]=[====['+(Get-Content -LiteralPath $_.FullName -Raw)+']====]')
}
$chunks.Add('loadModule(node("MobileUIChecks"))(clientSources)')
$taskTempFile = Join-Path ([System.IO.Path]::GetTempPath()) 'bind-dragon-mobile-ui-checks.luau'
[System.IO.File]::WriteAllText($taskTempFile, [string]::Join("`n", $chunks))
& $Luau $taskTempFile
if ($LASTEXITCODE -ne 0) { throw 'Mobile UI checks failed' }
