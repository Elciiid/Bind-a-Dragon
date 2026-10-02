param([string]$Luau = 'C:/Users/Kyle/AppData/Local/Temp/luau-cli/luau.exe')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path "$PSScriptRoot/../..").Path
$chunks = [System.Collections.Generic.List[string]]::new()
$chunks.Add(@'
local sources, cache = {}, {}
local function node(path) return setmetatable({Path=path}, {__index=function(t,k) return node(t.Path.."/"..k) end}) end
local env = setmetatable({
 game={GetService=function(_,n) return node(n) end}, script={Parent=node("ServerScriptService/Services")},
 Color3={fromRGB=function(...) return {...} end,new=function(...) return {...} end},
 Vector2={new=function(x,y) return {X=x,Y=y} end}, Vector3={new=function(...) return {...} end},
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
local cycleState={NightIndex=123,IsNight=false}
cache["ReplicatedStorage/Shared/Cycle"]={GetState=function() return cycleState end}
cache["ReplicatedStorage/Shared/DragonStats"]={}
'@)
Get-ChildItem "$repo/src/ReplicatedStorage/Shared" -Filter '*.luau' -Recurse | ForEach-Object {
    $key = 'ReplicatedStorage/Shared/' + [System.IO.Path]::GetRelativePath("$repo/src/ReplicatedStorage/Shared", $_.FullName).Replace('\','/').Replace('.luau','')
    $chunks.Add('sources["'+$key+'"]=[====['+(Get-Content -LiteralPath $_.FullName -Raw)+']====]')
}
$chunks.Add('sources["ServerScriptService/Services/OnboardingService"]=[====['+(Get-Content "$repo/src/ServerScriptService/Services/OnboardingService.luau" -Raw)+']====]')
$chunks.Add(@'
local service=loadModule(node("ServerScriptService/Services/OnboardingService"))
local config=loadModule(node("ReplicatedStorage/Shared/Config/Onboarding"))
local view=loadModule(node("ReplicatedStorage/Shared/Config/UITheme")).Onboarding
assert(config.TrailGroundOffset>=2 and config.TrailMaxDistance>config.TrailCount*config.TrailSpacing)
assert(config.NightHintSeconds>=30 and view.TrailPixels.X>=30 and view.TrailPixels.Y>=30)
assert(view.HintTop+view.HintLineHeight<view.ProgressTop)
assert(view.ProgressTop+view.ProgressHeight<view.PanelSize.Y-view.Padding-view.ActionHeight)
assert(view.ActionHeight>=44)
for _,safeWidth in {240,288,320,375,430,800} do
 local width=math.min(view.PanelSize.X,safeWidth*view.HintWidth)
 local actionWidth=math.min(view.ActionWidth,width/2-view.Padding*2)
 local segmentWidth=(width-view.Padding*2-view.ProgressGap*(config.Steps.Complete-1))/config.Steps.Complete
 assert(actionWidth>0 and segmentWidth>0)
 assert(width/4-actionWidth/2>=view.Padding)
 assert(width*3/4+actionWidth/2<=width-view.Padding)
end
print("PASS: raised-star config and hint layout geometry at six usable widths; rendering requires Studio")
local dragons=loadModule(node("ReplicatedStorage/Shared/Config/Dragons"))
local function fresh()
 return {OnboardingStep=0,OnboardingFirstBindUsed=false,OnboardingFreeLevelUsed=false,OnboardingHints={},Rebirths=0,LastBindNight=-1,Dragons={starter={SpeciesId="Cinderwing",Level=1}}}
end
local d=fresh(); assert(service:CanFirstBind(d,"StarterMeadow")); assert(not service:CanFirstBind(d,"VolcanoPeak"))
assert(not service:UseFreeLevel(d)); local dayThreshold=service:DidFirstBind({},d)
assert(dayThreshold==122 and 123>dayThreshold) -- Same-index upcoming night is eligible after a daylight bind.
cycleState.IsNight=true
local nightThreshold=service:DidFirstBind({},fresh())
assert(nightThreshold==123 and not(123>nightThreshold) and 124>nightThreshold)
assert(d.OnboardingStep==config.Steps.Home and d.OnboardingFirstBindUsed)
assert(not service:CanFirstBind(d,"StarterMeadow")); assert(not service:UseFreeLevel(d))
d.OnboardingStep=config.Steps.Upgrade
assert(service:UseFreeLevel(d)); assert(not service:UseFreeLevel(d)); assert(d.OnboardingFreeLevelUsed)
assert(d.OnboardingStep==config.Steps.Night)
for _,kind in {"Rebirth","Multiple","PreviouslyBound"} do
 local old=fresh()
 if kind=="Rebirth" then old.Rebirths=1 elseif kind=="Multiple" then old.Dragons.other={SpeciesId="Emberclaw",Level=1} else old.LastBindNight=10 end
 service:Ensure(old); assert(old.OnboardingStep==config.Steps.Skipped)
 assert(old.OnboardingFirstBindUsed and old.OnboardingFreeLevelUsed)
 assert(not service:CanFirstBind(old,"StarterMeadow")); assert(not service:UseFreeLevel(old))
end
local skipped=fresh(); skipped.OnboardingStep=config.Steps.Skipped
assert(not service:CanFirstBind(skipped,"StarterMeadow")); assert(not service:UseFreeLevel(skipped))
local totals=0
for _,element in {"Fire","Ice","Storm","Shadow",false} do
 local pool=service:GetFirstBindPool(if element then element else nil)
 local sum=0
 for _,outcome in pool do
  assert(dragons[outcome.SpeciesId].Rarity=="Rare")
  assert(not element or dragons[outcome.SpeciesId].Element==element)
  assert(outcome.BaseProbability>0 and outcome.BaseProbability==outcome.EffectiveProbability)
  assert(math.abs(outcome.BaseProbability*outcome.BaseOneIn-1)<1e-12)
  sum+=outcome.BaseProbability
 end
 assert(#pool==(if element then 5 else 20)); assert(math.abs(sum-1)<1e-12)
 local state=7919; local rng={NextNumber=function() state=(state*16807)%2147483647; return state/2147483647 end}
 local normal=0
 for i=1,100000 do
  local outcome,speciesOneIn,mutationOneIn=service:RollFirstBind(rng,if element then element else nil)
  assert(outcome and dragons[outcome.SpeciesId].Rarity=="Rare")
  assert(math.abs(speciesOneIn*mutationOneIn-outcome.BaseOneIn)<1e-9)
  if outcome.MutationId=="Normal" then normal+=1 end
 end
 assert(math.abs(normal-90000)<5*math.sqrt(100000*0.9*0.1))
 totals+=100000
end
assert(#service:GetFirstBindPool("UnknownElement")==0)
print("PASS: tutorial eligibility/once-only free-level and skipped saves; 5 conditional pools; "..totals.." seeded rolls, Normal share inside five sigma")
'@)
$temp = Join-Path ([System.IO.Path]::GetTempPath()) 'bind-dragon-onboarding-checks.luau'
[System.IO.File]::WriteAllText($temp, [string]::Join("`n", $chunks))
& $Luau $temp
if ($LASTEXITCODE -ne 0) { throw 'Onboarding checks failed' }
