-- Final world polish and structural checks. TEST place only; run once.
assert(game.PlaceId==85007700009982,"Wrong place")
assert(not game:GetService("RunService"):IsRunning(),"Stop Play")
local root=assert(workspace.StarterMeadow:FindFirstChild("ReferenceRemodel"))
if not root:GetAttribute("PaversRaised") then
 for _,p in root["02_CobblestoneWalks"]:GetChildren() do
  if p:IsA("BasePart") then p.Position+=Vector3.new(0,0.75,0);p.Material=Enum.Material.Limestone end
 end
 root:SetAttribute("PaversRaised",true)
end
if not root:GetAttribute("WalksWeeded") then
 for _,p in root["02_CobblestoneWalks"]:GetChildren() do
  if p:IsA("BasePart") then
   local region=Region3.new(p.Position-Vector3.new(3,8,3),p.Position+Vector3.new(3,4,3)):ExpandToGrid(4)
   workspace.Terrain:ReplaceMaterial(region,4,Enum.Material.Grass,Enum.Material.Ground)
  end
 end
 root:SetAttribute("WalksWeeded",true)
end
workspace.CurrentCamera.FieldOfView=60
workspace.CurrentCamera.CFrame=CFrame.lookAt(Vector3.new(0,255,420),Vector3.new(0,45,-90))
workspace.CurrentCamera.Focus=CFrame.new(0,30,-40)
local parts,scripts=0,0
for _,o in root:GetDescendants() do
 if o:IsA("BasePart") then o.Anchored=true;parts+=1 end
 if o:IsA("LuaSourceContainer") then scripts+=1 end
end
assert(scripts==0,"Unexpected runtime script")
assert(root:GetAttribute("ProtectedObjectsVerified")==28,"Missing original structure validation")
root:SetAttribute("AuthoredParts",parts)
print("REVIEW OK",parts,"anchored decorative parts, zero runtime scripts; 28 original tagged objects preserved; test place",game.PlaceId)
