-- One-time WORLD AUTHORING command, stored on Hakai. Paste into Studio Command Bar.
-- Never install this as a Script. All gameplay scripts remain untouched.
assert(game.PlaceId == 85007700009982, "STOP: this is not Kyle's private TEST place")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before authoring")
local W,CS,L = workspace,game:GetService("CollectionService"),game:GetService("Lighting")
local meadow = assert(W:FindFirstChild("StarterMeadow"), "Missing existing meadow")
assert(not meadow:FindFirstChild("ReferenceRemodel"), "Remodel already exists; do not run twice")
local V,C,RGB = Vector3.new,CFrame.new,Color3.fromRGB
local rng=Random.new(927)
local gold,stone,wood,roof=RGB(196,148,62),RGB(167,161,138),RGB(88,53,30),RGB(39,58,76)
local green=RGB(63,112,49)
local protected={}
for _,tag in {"StarAltar","AreaPortal","RoostPlot","StarMerchant","RuneShrine","DragonstoneForge","DragonSpire","AreaSpawn"} do
 for _,o in CS:GetTagged(tag) do
  if o:IsDescendantOf(W) then
   table.insert(protected,{o=o,tag=tag,attrs=o:GetAttributes(),primary=o:IsA("Model") and o.PrimaryPart or nil})
  end
 end
end
game:GetService("ChangeHistoryService"):SetWaypoint("Before Kyle Reference Remodel")
local root=Instance.new("Folder");root.Name="ReferenceRemodel";root.Parent=meadow
root:SetAttribute("TargetPlaceId",85007700009982);root:SetAttribute("SourceBranch","Hakai")
root:SetAttribute("ArtDirection","Crystal sanctuary / reference September 27")
local function model(n,p) local m=Instance.new("Model");m.Name=n;m.Parent=p or root;return m end
local function part(n,size,cf,color,mat,p)
 local a=Instance.new("Part");a.Name=n;a.Size=size;a.CFrame=cf;a.Color=color;a.Material=mat or Enum.Material.Slate
 a.Anchored=true;a.TopSurface=Enum.SurfaceType.Smooth;a.BottomSurface=Enum.SurfaceType.Smooth
 a.Parent=p or root;return a
end
local function ball(n,pos,size,color,p,mat)
 local a=part(n,size,C(pos),color,mat,p);a.Shape=Enum.PartType.Ball;a.CanCollide=false;return a
end
local function cyl(n,pos,r,h,color,p,mat)
 local a=part(n,V(h,r*2,r*2),C(pos)*CFrame.Angles(0,0,math.pi/2),color,mat,p);a.Shape=Enum.PartType.Cylinder;return a
end
local function beam(n,a,b,w,color,p,mat)
 return part(n,V(w,w,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),color,mat,p)
end
local function wedge(n,size,cf,color,p,mat)
 local a=Instance.new("WedgePart");a.Name=n;a.Size=size;a.CFrame=cf;a.Color=color;a.Material=mat or Enum.Material.Slate;a.Anchored=true;a.Parent=p;return a
end
local terrainParams=RaycastParams.new();terrainParams.FilterType=Enum.RaycastFilterType.Include;terrainParams.FilterDescendantsInstances={W.Terrain};terrainParams.IgnoreWater=true
local function ground(x,z)
 local hit=W:Raycast(V(x,500,z),V(0,-750,0),terrainParams)
 return hit and hit.Position.Y or 0
end
local function placeBottom(m,pos)
 local cf,s=m:GetBoundingBox();local d=pos-V(cf.Position.X,cf.Position.Y-s.Y/2,cf.Position.Z)
 m:PivotTo(m:GetPivot()+d)
end
local function clearCloneTags(m)
 for _,o in {m,table.unpack(m:GetDescendants())} do
  for _,tag in CS:GetTags(o) do CS:RemoveTag(o,tag) end
  if o:IsA("BasePart") then o.Anchored=true end
 end
end
local land=model("01_HorizonLandmarks")
local sourceIsland
for _,o in W:GetChildren() do
 if o:IsA("Model") then
  if o.Name:find("Tall steep volcano",1,true) then placeBottom(o,V(-430,70,-560));o.Parent=land
  elseif o.Name:find("Floating rock island",1,true) then placeBottom(o,V(390,195,-520));o.Parent=land;sourceIsland=o
  elseif o.Name:find("Wide mountain range",1,true) then placeBottom(o,V(-530,12,-230));o.Parent=land
  elseif o.Name:find("Long row of rugged",1,true) then placeBottom(o,V(500,8,-200));o.Parent=land end
 end
end
local assets=game.ReplicatedStorage.Assets.Horizon
local function horizon(name,pos,scale)
 local s=assets:FindFirstChild(name);if not s then return end
 local m=s:Clone();m.Name=name.."_Vista";clearCloneTags(m);m:ScaleTo(m:GetScale()*scale);placeBottom(m,pos);m.Parent=land
 for _,p in m:GetDescendants() do if p:IsA("BasePart") then p.CanCollide=false end end
 return m
end
horizon("IceSpire",V(-230,110,-605),0.7)
horizon("IceCrystals",V(-210,105,-545),0.72)
horizon("StormTowerLocal",V(240,92,-600),0.85)
local eclipse=model("EclipseCorona",land)
local ec=V(390,385,-535)
local disk=cyl("EclipsedSun",ec,37,2,RGB(27,34,62),eclipse,Enum.Material.SmoothPlastic)
disk.CFrame=C(ec)*CFrame.Angles(0,math.pi/2,0)
for i=1,96 do local a=(i-1)*math.pi*2/96;local b=i*math.pi*2/96
 beam("CoronaArc",ec+V(math.cos(a)*40,math.sin(a)*40,0),ec+V(math.cos(b)*40,math.sin(b)*40,0),1.3,RGB(255,224,143),eclipse,Enum.Material.Neon)
end
for i=1,16 do local a=i*math.pi/8;beam("SunRay",ec+V(math.cos(a)*40,math.sin(a)*40,0),ec+V(math.cos(a)*rng:NextNumber(44,49),math.sin(a)*rng:NextNumber(44,49),0),0.45,gold,eclipse,Enum.Material.Neon) end
local lightning=model("StormLightning",land)
local p0=V(240,350,-600)
for i=1,8 do local p1=p0+V(rng:NextNumber(-12,12),-13,rng:NextNumber(-5,5));beam("Lightning",p0,p1,1.1,RGB(184,194,255),lightning,Enum.Material.Neon);p0=p1 end
print("REMODEL: horizon arranged")

local paths=model("02_CobblestoneWalks")
local function path(points,width)
 for i=1,#points-1 do
  local a,b=points[i],points[i+1];local flat=V(b.X-a.X,0,b.Z-a.Z);local d=flat.Magnitude;local side=V(-flat.Z,0,flat.X).Unit
  for j=0,math.floor(d/5) do
   local t=j/math.max(1,math.floor(d/5));local pos=a:Lerp(b,t)
   for k=-math.floor(width/8),math.floor(width/8) do
    local q=pos+side*(k*4);local y=ground(q.X,q.Z)+0.22
    local a1=part("LimestonePaver",V(3.8,0.45,4.6),C(q.X,y,q.Z)*CFrame.Angles(0,math.atan2(flat.X,flat.Z)+rng:NextNumber(-0.08,0.08),0),RGB(rng:NextInteger(158,185),rng:NextInteger(151,175),rng:NextInteger(125,145)),Enum.Material.Cobblestone,paths)
    a1.CanCollide=false
   end
  end
 end
end
path({V(0,0,205),V(0,0,147),V(0,0,86)},15)
path({V(0,0,42),V(0,0,76)},15)
path({V(0,0,-43),V(0,0,-102)},16)
for _,sign in {-1,1} do
 path({V(sign*35,0,0),V(sign*95,0,-10),V(sign*148,0,0)},12)
 path({V(sign*36,0,-22),V(sign*95,0,-59),V(sign*139,0,-98)},12)
 path({V(sign*18,0,126),V(sign*87,0,138),V(sign*138,0,120)},12)
 path({V(sign*110,0,36),V(sign*108,0,-42),V(sign*135,0,-100)},10)
end

local forest=model("03_ForestAndGardens")
local function oak(pos,s)
 local m=model("BroadleafTree",forest)
 beam("Trunk",pos,pos+V(s*0.2,s*1.5,0),s*0.22,wood,m,Enum.Material.Wood)
 for j=1,5 do
  local a=j*2.399;local q=pos+V(math.cos(a)*s*0.56,s*(1.25+rng:NextNumber(0.1,0.55)),math.sin(a)*s*0.56)
  beam("Branch",pos+V(0,s*0.9,0),q,s*0.1,wood,m,Enum.Material.Wood)
  local leaf=ball("LeafCanopy",q,V(s*1.35,s*1.05,s*1.3),RGB(rng:NextInteger(42,83),rng:NextInteger(99,137),rng:NextInteger(38,62)),m,Enum.Material.Grass)
 end
 return m
end
local function pine(pos,s)
 local m=model("Cypress",forest)
 beam("Trunk",pos,pos+V(0,s*2,0),s*0.15,wood,m,Enum.Material.Wood)
 for j=1,4 do
  local r=s*(0.8-j*0.12)
  for k=0,3 do
   local cf=C(pos+V(0,s*(0.45+j*0.37),0))*CFrame.Angles(0,k*math.pi/2,0)*C(0,0,-r/2)
   local a=wedge("EvergreenTier",V(r*1.45,s*0.8,r),cf,RGB(34+j*4,83+j*6,52+j*2),m,Enum.Material.Grass);a.CanCollide=false
  end
 end
end
local function rock(pos,s,p)
 local r=part("MossyBoulder",V(s,s*rng:NextNumber(0.55,0.85),s*rng:NextNumber(0.65,1.1)),C(pos)*CFrame.Angles(rng:NextNumber(-0.3,0.3),rng:NextNumber(0,6.28),rng:NextNumber(-0.3,0.3)),RGB(99,112,101),Enum.Material.Rock,p or forest)
 r.Shape=Enum.PartType.Ball
 return r
end
local function flowers(pos,count,p)
 local colors={RGB(239,217,105),RGB(208,138,230),RGB(244,195,220),RGB(230,237,218),RGB(135,160,238)}
 for k=1,count do
  local x,z=pos.X+rng:NextNumber(-5,5),pos.Z+rng:NextNumber(-5,5);local y=ground(x,z)
  local stem=part("WildflowerStem",V(0.15,1.2,0.15),C(x,y+0.6,z),green,Enum.Material.Grass,p or forest);stem.CanCollide=false
  ball("Blossom",V(x,y+1.3,z),V(0.9,0.42,0.9),colors[rng:NextInteger(1,#colors)],p or forest,Enum.Material.SmoothPlastic)
 end
end
for i=1,185 do
 local a=rng:NextNumber(0,math.pi*2);local radius=rng:NextNumber(255,360);local x,z=math.cos(a)*radius,math.sin(a)*radius-30
 if not (z>170 and math.abs(x)<58) and not (math.abs(x)<65 and z< -170) then
  local y=ground(x,z);if y<120 then
   if i%3==0 then pine(V(x,y,z),rng:NextNumber(13,23)) else oak(V(x,y,z),rng:NextNumber(10,19)) end
   if i%3==0 then rock(V(x+9,y+1,z+5),rng:NextNumber(5,11)) end
  end
 end
end
for _,sg in {-1,1} do
 for j=1,28 do
  local x=sg*rng:NextNumber(65,145);local z=rng:NextNumber(-95,155)
  if math.abs(z-62)>20 and math.abs(z)<150 and not(math.abs(z)<15 and math.abs(x)<130) then
   local y=ground(x,z);ball("GardenShrub",V(x,y+1.6,z),V(6,3.8,5),RGB(69,122,53),forest,Enum.Material.Grass);flowers(V(x,y,z),6)
   if j%5==0 then oak(V(x,y,z),7) end
  end
 end
end
for i=1,60 do local a=i*math.pi*2/60;local q=V(math.cos(a)*48,0,math.sin(a)*48);if math.abs(q.X)>14 and math.abs(q.Z)>14 then flowers(q,5) end end
print("REMODEL: woodland and paths built")

local homes=model("04_DragonSanctuaries")
local accents={RGB(123,93,218),RGB(241,184,53),RGB(69,87,162),RGB(94,181,70),RGB(122,212,242),RGB(233,91,39)}
local plots=meadow.Pens:GetChildren();table.sort(plots,function(a,b)return a.Name<b.Name end)
for idx,plot in plots do
 if not plot:IsA("Model") then continue end
 local center=plot:GetAttribute("RoamCenter");if typeof(center)~="Vector3" then continue end
 local sign=center.X>0 and 1 or -1
 local base=V(center.X+sign*24,center.Y,center.Z-7)
 local m=model(plot.Name.."_DragonLodge",homes)
 local angle=sign>0 and math.pi/2 or -math.pi/2
 local transform=C(base)*CFrame.Angles(0,angle,0)
 local function lp(n,size,offset,color,mat) return part(n,size,transform*C(offset),color,mat,m) end
 lp("StoneFoundation",V(29,2,26),V(0,0,0),stone,Enum.Material.Cobblestone)
 for _,x in {-12,12} do for _,z in {-10,10} do
  lp("TimberPost",V(1.8,16,1.8),V(x,8,z),wood,Enum.Material.Wood)
  lp("PostFoot",V(3,2.4,3),V(x,1.2,z),stone)
 end end
 lp("RearWall",V(25,10,1.4),V(0,5,-10),RGB(124,85,49),Enum.Material.WoodPlanks)
 for _,x in {-12,12} do lp("SideWall",V(1.2,9,20),V(x,4.5,0),RGB(122,87,51),Enum.Material.WoodPlanks) end
 for _,sg in {-1,1} do
  local cf=transform*C(sg*7,17,0)*CFrame.Angles(0,0,sg*-0.47)
  part("SlateRoof",V(17,1.2,29),cf,roof,Enum.Material.Slate,m)
  for row=0,3 do for tile=0,7 do
   local tilecf=cf*C((row-1.5)*4,0.75,(tile-3.5)*3.5)
   part("RoofShingle",V(3.9,0.35,3.35),tilecf,RGB(43+row*4,61+row*4,77+row*5),Enum.Material.Slate,m)
  end end
  beam("GableTrim",(transform*V(0,21.4,15)),(transform*V(sg*15,14.5,15)),0.75,gold,m,Enum.Material.Wood)
 end
 lp("RoofRidge",V(1.2,1.3,31),V(0,21.2,0),gold,Enum.Material.Wood)
 lp("FrontLintel",V(27,1.6,1.7),V(0,14,10),wood,Enum.Material.Wood)
 local med=ball("ElementCrest",transform*V(0,16,11),V(3,3,1),accents[idx] or gold,m,Enum.Material.Neon)
 local nest=cyl("StrawNest",base+V(-sign*11,0.9,12),7,0.8,RGB(171,139,66),m,Enum.Material.Grass);nest.CanCollide=false
 local dragon=game.ReplicatedStorage.Assets.Dragons.Placeholder:Clone();dragon.Name="ResidentDragon_"..idx;clearCloneTags(dragon)
 dragon:ScaleTo(dragon:GetScale()*2.1);dragon.Parent=m
 for _,p in dragon:GetDescendants() do if p:IsA("BasePart") then
  p.CanCollide=false
  if p.Name=="Body" or p.Name=="Head" or p.Name=="Neck" or p.Name=="Hips" or p.Name:find("Leg") or p.Name:find("Tail") then p.Color=accents[idx] or gold
  elseif p.Name=="Wing" then p.Color=(accents[idx] or gold):Lerp(RGB(35,30,65),0.3)
  elseif p.Name=="Eye" then p.Color=RGB(255,233,141);p.Material=Enum.Material.Neon end
 end end
 dragon:PivotTo(C(base+V(-sign*15,5,14))*CFrame.Angles(0,sign*-0.8,0))
 for j=1,8 do local a=j*math.pi/4;local q=center+V(math.cos(a)*44,0,math.sin(a)*44);flowers(q,6,forest) end
end

local decor=model("05_SanctuaryDetails")
local function lantern(pos)
 local m=model("Lantern",decor)
 cyl("Pedestal",pos+V(0,0.5,0),1.25,1,stone,m)
 part("Post",V(0.55,7,0.55),C(pos+V(0,4,0)),RGB(61,64,65),Enum.Material.Metal,m)
 part("Crown",V(2.2,0.45,2.2),C(pos+V(0,8.6,0)),gold,Enum.Material.Metal,m)
 local lamp=part("Lamp",V(1.4,1.8,1.4),C(pos+V(0,7.5,0)),RGB(255,210,110),Enum.Material.Neon,m);lamp.CanCollide=false
 local light=Instance.new("PointLight");light.Color=lamp.Color;light.Brightness=0.6;light.Range=13;light.Shadows=false;light.Parent=lamp
 m.PrimaryPart=lamp;m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic;CS:AddTag(m,"Lantern")
end
for _,sg in {-1,1} do
 for _,z in {192,163,132,100,36,-35,-73,-102} do local x=sg*(math.abs(z)<80 and 48 or 17);lantern(V(x,ground(x,z),z)) end
 for _,z in {-82,15,112} do lantern(V(sg*145,ground(sg*145,z),z)) end
end
local function crystal(pos,s,col,p)
 local m=model("RunicCrystal",p or decor)
 part("CrystalCore",V(s*0.48,s*1.4,s*0.48),C(pos+V(0,s*0.85,0))*CFrame.Angles(0,math.pi/4,0),col,Enum.Material.Glass,m)
 for j=0,3 do wedge("CrystalTip",V(s*0.48,s*0.65,s*0.24),C(pos+V(0,s*1.83,0))*CFrame.Angles(0,j*math.pi/2,0),col,m,Enum.Material.Neon).CanCollide=false end
 cyl("GoldSocket",pos+V(0,0.15,0),s*0.46,0.5,gold,m,Enum.Material.Metal)
 return m
end
for i=1,8 do local a=i*math.pi/4;local q=V(math.cos(a)*37,4.6,math.sin(a)*37);if math.abs(q.X)>5 then crystal(q,2,RGB(98,210,255)) end end
for _,sg in {-1,1} do
 for _,z in {174,-88} do
  local x=sg*(z>0 and 31 or 62);local y=ground(x,z);local m=model("StarBanner",decor)
  part("Pole",V(0.65,17,0.65),C(x,y+8.5,z),gold,Enum.Material.Metal,m)
  local flag=part("RoyalBlueBanner",V(6,10,0.25),C(x+sg*3,y+11,z),RGB(33,53,130),Enum.Material.Fabric,m);flag.CanCollide=false
  beam("Crossbar",V(x-0.7,y+16,z),V(x+sg*6.5,y+16,z),0.5,gold,m,Enum.Material.Metal)
  for j=0,3 do local a=j*math.pi/2;beam("StarEmblem",V(x+sg*3,y+11,z+0.2),V(x+sg*3+math.sin(a)*1.8,y+11+math.cos(a)*2.5,z+0.2),0.33,gold,m,Enum.Material.Metal) end
 end
end
-- Color the existing portal surfaces for edit-mode visibility. Their controllers retain authority in Play.
local palette={VolcanoPeak=RGB(255,108,30),FrozenCliffs=RGB(49,190,255),StormCanyon=RGB(216,158,255),EclipseIsles=RGB(156,59,255)}
for _,p in meadow.Portals:GetDescendants() do
 if p:IsA("BasePart") and p.Name=="Surface" then
  local col=palette[p:GetAttribute("AreaId") or p.Parent:GetAttribute("AreaId")]
  if col then p.Color=col;p.Material=Enum.Material.Neon;p.Transparency=0.32 end
 end
end
print("REMODEL: dragon lodges, dragons, lighting and portals built")

local water=model("06_WaterAndRiverbanks")
-- Retain the terrain river and existing traversable bridges; detail their banks.
for _,sg in {-1,1} do
 for i=1,24 do
  local x=sg*(30+i*10);local z=63+math.sin(i*0.6)*10
  for _,side in {-1,1} do
   local zz=z+side*17;local yy=ground(x,zz)
   rock(V(x,yy+1,zz),rng:NextNumber(3,7),water)
   if i%2==0 then flowers(V(x,yy,zz+side*3),4,forest) end
  end
 end
end
local falls=model("CascadeRibbons",water)
local fbase=V(-299,0,58)
for i=1,5 do
 local x=-304+i*2.4
 local stream=part("FallingWater",V(2.7,58,1.2),C(x,31,60+math.sin(i)*2),RGB(115,214,237),Enum.Material.Glass,falls);stream.Transparency=0.3;stream.CanCollide=false
 local white=part("FoamRibbon",V(0.45,56,0.6),C(x+0.3,31,61+math.sin(i)*2),RGB(222,249,255),Enum.Material.Neon,falls);white.Transparency=0.5;white.CanCollide=false
end
for i=1,15 do ball("CascadeFoam",fbase+V(rng:NextNumber(-10,10),1,rng:NextNumber(-4,14)),V(5,0.4,3),RGB(221,247,248),falls,Enum.Material.SmoothPlastic) end
for i=1,45 do
 local x=rng:NextNumber(-265,265);local z=63+rng:NextNumber(-9,9)
 if math.abs(x)>20 and math.abs(math.abs(x)-100)>16 then
  local l=cyl("LilyPad",V(x,-0.2,z),rng:NextNumber(0.8,1.8),0.15,RGB(76,139,80),water,Enum.Material.Grass);l.CanCollide=false
 end
end

-- Warm daylight and atmospheric depth for the saved editor view.
L.ClockTime=14.2;L.Brightness=2.4;L.Ambient=RGB(109,121,142);L.OutdoorAmbient=RGB(142,156,176)
L.GlobalShadows=true;L.EnvironmentDiffuseScale=0.6;L.EnvironmentSpecularScale=0.65
local atm=L:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere",L)
atm.Density=0.25;atm.Offset=0.15;atm.Color=RGB(191,220,244);atm.Decay=RGB(117,153,190);atm.Glare=0.14;atm.Haze=1.3
local bloom=L:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect",L);bloom.Intensity=0.18;bloom.Size=26;bloom.Threshold=1.3
local cc=L:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect",L);cc.Saturation=0.14;cc.Contrast=0.07;cc.Brightness=0.02;cc.TintColor=RGB(255,249,237)
W.Terrain.WaterColor=RGB(33,152,179);W.Terrain.WaterTransparency=0.35;W.Terrain.WaterReflectance=0.3;W.Terrain.WaterWaveSize=0.12;W.Terrain.WaterWaveSpeed=7
W.Terrain:SetMaterialColor(Enum.Material.Grass,RGB(83,133,62))
W.Terrain:SetMaterialColor(Enum.Material.Rock,RGB(116,127,132))

for _,entry in protected do
 assert(entry.o:IsDescendantOf(W) and CS:HasTag(entry.o,entry.tag),"Protected object lost: "..entry.tag)
 if entry.primary then assert(entry.o.PrimaryPart==entry.primary,"PrimaryPart changed") end
 for k,v in entry.attrs do assert(entry.o:GetAttribute(k)==v,"Protected attribute changed: "..k) end
end
local count=0;for _,o in root:GetDescendants() do if o:IsA("BasePart") then count+=1 end;assert(not o:IsA("LuaSourceContainer"),"No runtime scripts allowed in remodel") end
root:SetAttribute("AuthoredParts",count);root:SetAttribute("ProtectedObjectsVerified",#protected)
game:GetService("ChangeHistoryService"):SetWaypoint("Kyle Reference Remodel Complete")
print("REMODEL COMPLETE",count,"parts;",#protected,"gameplay objects and attributes preserved; TEST",game.PlaceId)
