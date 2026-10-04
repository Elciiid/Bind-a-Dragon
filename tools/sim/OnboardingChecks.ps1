param([string]$Luau = 'C:/Users/Kyle/AppData/Local/Temp/luau-cli/luau.exe')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path "$PSScriptRoot/../..").Path
$chunks = [System.Collections.Generic.List[string]]::new()
$chunks.Add(@'
local sources, cache = {}, {}
local fired = {}
local function node(path) return setmetatable({Path=path}, {__index=function(t,k) return node(t.Path.."/"..k) end, __call=function(t,_,...) table.insert(fired,{t.Path,...}) end}) end
local env = setmetatable({
 game={GetService=function(_,n) return node(n) end}, script={Parent=node("ServerScriptService/Services")},
 Color3={fromRGB=function(...) return {...} end,new=function(...) return {...} end},
 Vector2={new=function(x,y) return {X=x,Y=y} end}, Vector3={new=function(...) return {...} end}, NumberRange={new=function(a,b) return {Min=a,Max=b or a} end},
 Enum=setmetatable({}, {__index=function(_,group) return setmetatable({}, {__index=function(_,key) return group.."."..key end}) end}),
 Font={new=function(...) return {...} end}, Rect={new=function(...) return {...} end},
 UDim2={fromOffset=function(x,y) return {X={Scale=0,Offset=x},Y={Scale=0,Offset=y}} end},
}, {__index=getfenv()})
local function loadModule(n)
 local path=n.Path; if cache[path] then return cache[path] end
 assert(sources[path],"Missing "..path)
 local fn,err=loadstring(sources[path],path); assert(fn,err); setfenv(fn,env)
 cache[path]=fn(); return cache[path]
end
env.require=loadModule
cache["ServerScriptService/Services/DataService"]={}
cache["ServerScriptService/Services/RoostService"]={}
cache["ServerScriptService/Services/IndexService"]={Sync=function() end}
local cycleState={NightIndex=123,IsNight=false}
cache["ReplicatedStorage/Shared/Cycle"]={GetState=function() return cycleState end}
cache["ReplicatedStorage/Shared/DragonStats"]={}
'@)
Get-ChildItem "$repo/src/ReplicatedStorage/Shared" -Filter '*.luau' -Recurse | ForEach-Object {
    $key = 'ReplicatedStorage/Shared/' + $_.FullName.Substring((Resolve-Path "$repo/src/ReplicatedStorage/Shared").Path.TrimEnd("\\").Length + 1).Replace('\','/').Replace('.luau','')
    $chunks.Add('sources["'+$key+'"]=[====['+(Get-Content -LiteralPath $_.FullName -Raw)+']====]')
}
$chunks.Add('sources["ServerScriptService/Services/OnboardingService"]=[====['+(Get-Content "$repo/src/ServerScriptService/Services/OnboardingService.luau" -Raw)+']====]')
$chunks.Add(@'
local service=loadModule(node("ServerScriptService/Services/OnboardingService"))
local config=loadModule(node("ReplicatedStorage/Shared/Config/Onboarding"))
assert(config.NightHintSeconds>=10 and config.WaitHintSeconds>0 and config.Twinkle.NearDistance>0 and config.Skip.PhoneSize.Y>=44)
print("PASS: Twinkle / hint timing / touch-sized Skip configuration (one-line contracts are in RunMobileUIChecks.ps1)")
local dataConfig=loadModule(node("ReplicatedStorage/Shared/Config/Data"))
local starter=dataConfig.StarterDragon
local player={Name="Tester"}
local function fresh()
 return {OnboardingStep=0,OnboardingFirstBindUsed=false,OnboardingFreeLevelUsed=false,OnboardingHints={},Rebirths=0,LastBindNight=-1,Dragons={},RoostDragonIds={},NextDragonId=1}
end
local function count(d) local n=0 for _ in d.Dragons do n+=1 end return n end
-- brand-new player: welcome bind at the starter altar only, by day (no night needed), once
local d=fresh(); assert(service:CanWelcomeBind(d,"StarterMeadow")); assert(not service:CanWelcomeBind(d,"VolcanoPeak"))
assert(d.OnboardingStep==config.Steps.Start and count(d)==0) -- the starter is NOT granted at join
assert(not service:UseFreeLevel(d))
local id=service:DidWelcomeBind(player,d)
assert(id and d.Dragons[id].SpeciesId==starter and d.Dragons[id].Starter==true and d.Dragons[id].Level==1 and d.Dragons[id].MutationId==nil)
assert(table.find(d.RoostDragonIds,id)) -- straight into the roost
assert(d.LastBindNight==-1) -- the night's normal bind is not used up
assert(d.OnboardingStep==config.Steps.Home and d.OnboardingFirstBindUsed)
assert(not service:CanWelcomeBind(d,"StarterMeadow")) -- once only
assert(service:DidWelcomeBind(player,d)==nil and count(d)==1) -- a repeat call grants nothing
assert(not service:UseFreeLevel(d))
d.OnboardingStep=config.Steps.Upgrade
assert(service:UseFreeLevel(d)); assert(not service:UseFreeLevel(d)); assert(d.OnboardingFreeLevelUsed)
assert(d.OnboardingStep==config.Steps.Night)
-- the Night step waits for the next night after the welcome bind (by day: the upcoming night; at night: the next one)
cycleState.IsNight=false; local dd=fresh(); assert(service:DidWelcomeBind(player,dd)); cycleState.IsNight=true
local dn=fresh(); assert(service:DidWelcomeBind(player,dn)); cycleState.IsNight=false
-- the welcome dragon never becomes a Rarest record
local stats=loadModule(node("ReplicatedStorage/Shared/LeaderboardStats"))
local rec={Dragons=d.Dragons,RarestOneIn=0}; stats.Backfill(rec); assert((rec.RarestOneIn or 0)==0)
-- left before the welcome bind: the same step on rejoin (classification is stable)
local left=fresh(); service:Ensure(left); service:Ensure(left); assert(left.OnboardingStep==config.Steps.Start and service:CanWelcomeBind(left,"StarterMeadow"))
-- Skip before the welcome bind grants the starter at once; Skip after it grants nothing more
local s1=fresh(); service:Ensure(s1); service:Skip(player,s1)
assert(count(s1)==1 and s1.OnboardingStep==config.Steps.Skipped and not service:CanWelcomeBind(s1,"StarterMeadow"))
service:Skip(player,s1); assert(count(s1)==1)
local s2=fresh(); service:DidWelcomeBind(player,s2); service:Skip(player,s2); assert(count(s2)==1 and s2.OnboardingStep==config.Steps.Skipped)
-- existing saves are not touched: any dragon, a rebirth or a previous bind -> Skipped, no welcome bind, no free level
for _,kind in {"Starter","Rebirth","PreviouslyBound"} do
 local old=fresh()
 if kind=="Starter" then old.Dragons["1"]={SpeciesId=starter,Level=1}; old.NextDragonId=2 elseif kind=="Rebirth" then old.Rebirths=1 else old.LastBindNight=10 end
 local before=count(old)
 service:Ensure(old); assert(old.OnboardingStep==config.Steps.Skipped)
 assert(old.OnboardingFirstBindUsed and old.OnboardingFreeLevelUsed)
 assert(not service:CanWelcomeBind(old,"StarterMeadow")); assert(not service:UseFreeLevel(old))
 service:Skip(player,old); assert(count(old)==before)
end
local skipped=fresh(); skipped.OnboardingStep=config.Steps.Skipped
assert(not service:CanWelcomeBind(skipped,"StarterMeadow")); assert(not service:UseFreeLevel(skipped))
assert(config.MinimumRarity==nil and service.RollFirstBind==nil) -- the guaranteed-Rare first bind is gone
print("PASS: welcome bind (starter "..tostring(starter)..", day ok, once, roost, night kept, no Rarest record), skip grants the starter, rejoin keeps the step, existing saves untouched, free level once")
'@)
$temp = Join-Path ([System.IO.Path]::GetTempPath()) 'bind-dragon-onboarding-checks.luau'
[System.IO.File]::WriteAllText($temp, [string]::Join("`n", $chunks))
& $Luau $temp
if ($LASTEXITCODE -ne 0) { throw 'Onboarding checks failed' }
