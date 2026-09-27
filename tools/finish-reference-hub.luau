-- World authoring only; Hakai / Kyle TEST, never a runtime Script.
assert(game.PlaceId==85007700009982,"Wrong place")
assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
local root=assert(workspace.StarterMeadow:FindFirstChild("ReferenceRemodel"))
assert(not root:FindFirstChild("07_MarketAndPolish"),"Polish already applied")
local V,C,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local m=Instance.new("Model");m.Name="07_MarketAndPolish";m.Parent=root
local gold=RGB(205,157,67)
local function p(n,s,cf,col,mat,parent)
 local a=Instance.new("Part");a.Name=n;a.Size=s;a.CFrame=cf;a.Color=col;a.Material=mat or Enum.Material.SmoothPlastic;a.Anchored=true;a.TopSurface=Enum.SurfaceType.Smooth;a.BottomSurface=Enum.SurfaceType.Smooth;a.Parent=parent or m;return a
end
local function beam(n,a,b,r,col,mat,parent) return p(n,V(r,r,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),col,mat,parent) end
local function ball(n,pos,s,col,parent)
 local a=p(n,s,C(pos),col,Enum.Material.Grass,parent);a.Shape=Enum.PartType.Ball;a.CanCollide=false;return a
end
local market=Instance.new("Model");market.Name="StarlightMerchantPavilion";market.Parent=m
for _,x in {-72,-40} do for _,z in {105,130} do
 p("CarvedSupport",V(1.3,26,1.3),C(x,15,z),RGB(97,65,37),Enum.Material.Wood,market)
 p("BrassCapital",V(2.2,1,2.2),C(x,26,z),gold,Enum.Material.Metal,market)
end end
for _,sg in {-1,1} do
 local cf=C(-56+sg*8,28,117)*CFrame.Angles(0,0,-sg*0.5)
 p("RoyalCanvas",V(19,0.6,31),cf,RGB(34,48,135),Enum.Material.Fabric,market)
 for _,z in {-14,0,14} do p("GoldenSeam",V(19,0.1,0.25),cf*C(0,0.38,z),gold,Enum.Material.Metal,market) end
 for j=1,3 do
  local q=cf*C(0,0.42,(j-2)*9)
  p("CanvasStar",V(3.4,0.12,0.28),q,gold,Enum.Material.Metal,market)
  p("CanvasStar",V(0.28,0.12,3.4),q,gold,Enum.Material.Metal,market)
 end
end
beam("RidgePole",V(-56,32,100),V(-56,32,134),0.6,gold,Enum.Material.Metal,market)
for _,x in {-76,-35} do
 local crate=p("SupplyCrate",V(5,5,5),C(x,4.9,120),RGB(122,79,39),Enum.Material.WoodPlanks,market)
 for _,y in {3,6.5} do p("CrateBand",V(5.15,0.45,5.15),C(x,y,120),RGB(56,62,70),Enum.Material.Metal,market) end
end
local forge=Instance.new("Model");forge.Name="DragonstoneWorkshop";forge.Parent=m
for _,sg in {-1,1} do
 local cf=C(58+sg*9,31,121)*CFrame.Angles(0,0,-sg*0.4)
 p("WorkshopRoof",V(21,1.4,30),cf,RGB(52,63,71),Enum.Material.Slate,forge)
 for k=0,4 do p("RoofRib",V(21,0.4,0.6),cf*C(0,0.85,(k-2)*6),RGB(112,86,53),Enum.Material.Wood,forge) end
 for _,z in {108,134} do p("OakBeam",V(1.5,28,1.5),C(58+sg*17,16,z),RGB(91,59,34),Enum.Material.Wood,forge) end
end
p("StoneChimney",V(6,30,6),C(77,25,130),RGB(104,113,116),Enum.Material.Cobblestone,forge)
p("ChimneyRim",V(7.5,2,7.5),C(77,41,130),RGB(148,152,142),Enum.Material.Slate,forge)
local ember=p("ForgeEmbers",V(4,1,4),C(77,40,130),RGB(255,133,46),Enum.Material.Neon,forge)
local smoke=Instance.new("Smoke");smoke.Color=RGB(109,119,135);smoke.Opacity=0.12;smoke.RiseVelocity=5;smoke.Size=5;smoke.Parent=ember

local rand=Random.new(48)
local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={workspace.Terrain};params.IgnoreWater=true
local function y(x,z) local r=workspace:Raycast(V(x,500,z),V(0,-800,0),params);return r and r.Position.Y or 0 end
-- Fine leaf clusters soften the round blockout crowns without affecting movement.
local trees=root:FindFirstChild("03_ForestAndGardens")
for _,tree in trees:GetChildren() do
 if tree:IsA("Model") and tree.Name=="BroadleafTree" then
  local clusters={};for _,a in tree:GetChildren() do if a.Name=="LeafCanopy" then table.insert(clusters,a) end end
  for _,a in clusters do
   a.Size=a.Size*0.87
   for k=1,3 do
    local off=V(rand:NextNumber(-0.45,0.45)*a.Size.X,rand:NextNumber(-0.25,0.4)*a.Size.Y,rand:NextNumber(-0.45,0.45)*a.Size.Z)
    ball("LeafTuft",a.Position+off,a.Size*rand:NextNumber(0.38,0.58),a.Color:Lerp(RGB(140,163,63),rand:NextNumber(0,0.2)),tree)
   end
  end
 end
end
for i=1,85 do
 local a=rand:NextNumber(0,math.pi*2);local r=rand:NextNumber(250,300);local x,z=math.cos(a)*r,math.sin(a)*r-15
 if not(z>150 and math.abs(x)<55) then
  local h=y(x,z);ball("FernBed",V(x,h+1,z),V(7,2.5,5),RGB(63,110,52))
  for j=1,3 do
   local leaf=p("FernFrond",V(0.25,0.4,5),C(x,h+1.2,z)*CFrame.Angles(0,j*2.1,0)*C(0,0,2),RGB(90,143,65),Enum.Material.Grass);leaf.CanCollide=false
  end
 end
end
-- Edit-mode camera only, keeping the full valley and skyline legible.
workspace.CurrentCamera.FieldOfView=65
workspace.CurrentCamera.CFrame=CFrame.lookAt(V(0,310,660),V(0,88,-130))
workspace.CurrentCamera.Focus=C(0,50,-65)
game:GetService("ChangeHistoryService"):SetWaypoint("Reference market and foliage polish")
print("REFERENCE POLISH COMPLETE: merchant pavilion, forge workshop, fine foliage, overview")
