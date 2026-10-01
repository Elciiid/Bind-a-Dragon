# Importing the Elder LOD meshes (`BodyLOD`)

The 4k-triangle versions are in `assets/Dragons/fbx/lod/` (`Solflare|Aurorynth|Borealis|Duskling|Infernus_Elder_LOD.fbx`; made
with `tools/glb_to_fbx.py --tris 4000 --flip`, same bones as the full mesh). The game swaps an Elder to `BodyLOD` beyond
`DragonRigs.LodDistance` (120 studs). Until they are in, Elders keep the full mesh. Studio's MCP cannot import FBX, so:

## Click by click (once per dragon, or select all five at once)

1. Open the place in Studio (Rojo not needed). Make sure nothing is in Play mode.
2. **Avatar** tab -> **Import 3D** (or File -> Import 3D). In the file picker go to
   `E:\Roblox\Bind a Dragon\assets\Dragons\fbx\lod\`, select the five `*_Elder_LOD.fbx` files, Open.
3. In the 3D Importer window use the **same settings you used for the Elder bodies** (it remembers them): the
   mesh stays skinned with its bones, textures are imported, "Insert in Workspace". Press **Import**.
   (Sign in / upload permission is the normal asset upload to your account.)
4. Five Models appear in Workspace, named after the files. **Tell Claude "LODs imported"** and it attaches them
   (steps 5-6 below, through the Studio MCP). Or do it by hand:
5. Paste this in the **command bar** (View -> Command Bar) and press Enter. It scales each LOD mesh like its Elder
   (`Model:GetScale()`), puts it on the Body, names it `BodyLOD`, and deletes the imported model:

```lua
local RS = game:GetService("ReplicatedStorage")
for _, id in { "Solflare", "Aurorynth", "Borealis", "Duskling", "Infernus" } do
	local elder = RS.Assets.Dragons[id].Elder
	local body = elder.Body
	local imported = workspace:FindFirstChild(id .. "_Elder_LOD")
	local mesh = imported and (if imported:IsA("MeshPart") then imported else imported:FindFirstChildWhichIsA("MeshPart", true))
	if mesh == nil then
		warn("no imported LOD for " .. id)
		continue
	end
	local old = elder:FindFirstChild("BodyLOD")
	if old then old:Destroy() end
	local lod = mesh:Clone()
	lod.Name = "BodyLOD"
	lod.Anchored, lod.CanCollide, lod.CanTouch, lod.CanQuery = body.Anchored, false, false, false
	lod.Size = lod.Size * elder:GetScale()
	lod.CFrame = body.CFrame
	lod.Parent = elder
	imported:Destroy()
end
```

6. Check one: select `ReplicatedStorage > Assets > Dragons > Solflare > Elder` in the Explorer. It should now hold
   `Body` and `BodyLOD` (BodyLOD has `Bone` children with the same names as Body's). In the viewport the two meshes
   overlap exactly; the game hides `BodyLOD` close up and `Body` beyond 120 studs.
7. **Save the place** (the models live in the place, not in Git).

Test in Play: stand 150+ studs from a sanctuary with an Elder (it should look the same, slightly lower detail);
beyond 260 studs dragons disappear; with Low effects only the nearest 4 dragons of a sanctuary are drawn.
