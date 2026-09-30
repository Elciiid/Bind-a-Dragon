-- Sanctuary look kits (Valley rework, docs/Valley_Rework_Proposal.md). Studio build helper, not used by the game.
-- Builds the art of each sanctuary look into ReplicatedStorage.Assets.SanctuaryLooks.<LookId>.<PlotName> (world
-- position, anchored): a Folder whose children are "pieces" (Models whose WorldPivot is their base, no PrimaryPart).
-- The client (SanctuaryLookController) clones a kit in near the camera and grows/shrinks the pieces on look changes.
-- Layout comes from ValleyTerrain V.Slots (local x/y = right/toward the gate); the base sanctuary (ValleyBuild
-- BuildSanctuary) keeps the invisible slots (zones, perches, stand anchors, sign).
-- Usage: local L = require(ServerStorage.RemasterTools.SanctuaryLooks:Clone()); L.BuildWildHollow(); L.Preview("RoostPlot6")
-- Art methods: code parts (gate, wall, stones, stumps, pond), AI meshes from ServerStorage.PropKits.SanctuaryLooks
-- (Studio generate_mesh: nest tree, perch spires), and the existing Meadow / Enchanted prop kits.
-- The live copy is ServerStorage.RemasterTools.SanctuaryLooks in the place; this file is the reference copy.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local L = {}
local SM = workspace:WaitForChild("StarterMeadow")
local B = require(ServerStorage.RemasterTools.ValleyBuild:Clone())
local V = require(ServerStorage.RemasterTools.ValleyTerrain:Clone())
local Slots = V.Slots
local M = Enum.Material
local rad, sin, cos, sqrt = math.rad, math.sin, math.cos, math.sqrt
local P, Disc, Star, Glow = B.P, B.Disc, B.Star, B.Glow
local Colors = B.Colors
local LOOKS = ServerStorage.PropKits.SanctuaryLooks
local MEADOW = ServerStorage.PropKits.Meadow
local ENCH = ServerStorage.PropKits.Enchanted

local WH = {
	Moss = Color3.fromRGB(96, 134, 72),
	MossDark = Color3.fromRGB(64, 98, 60),
	Bark = Color3.fromRGB(108, 76, 52),
	BarkDark = Color3.fromRGB(78, 56, 42),
	StoneMoss = Color3.fromRGB(148, 150, 128),
	Teal = Color3.fromRGB(120, 232, 200),
	Petal = Color3.fromRGB(255, 226, 150),
}
L.Colors = WH

---------------------------------------------------------------------------------------------------------------
-- helpers

local function kitFolder(look: string): Folder
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	assert(assets, "ReplicatedStorage.Assets missing")
	local root = B.Folder(assets, "SanctuaryLooks") :: Folder
	return B.Folder(root, look) :: Folder
end

-- The placement context of one sanctuary: slot coordinates -> world.
local function context(plot: Model)
	local id = B.SanctuaryOrder[plot.Name]
	local s
	for _, cand in V.Sanct do
		if cand.Name == id then
			s = cand
		end
	end
	assert(s, "no sanctuary for " .. plot.Name)
	local fwd = Vector3.new(s.AX, 0, s.AZ)
	local ctx = { S = s, T = s.T, Fwd = fwd, Center = Vector3.new(s.X, s.T, s.Z) }
	function ctx.at(x: number, y: number, h: number?): Vector3
		local wx, wz = V.ToWorld(s, x, y)
		return Vector3.new(wx, s.T + (h or 0), wz)
	end
	function ctx.frame(x: number, y: number, h: number?): CFrame -- -Z toward the gate / the altar
		local p = ctx.at(x, y, h)
		return CFrame.lookAt(p, p + fwd)
	end
	function ctx.faceCenter(p: Vector3): CFrame -- -Z toward the sanctuary center
		return CFrame.lookAt(p, Vector3.new(s.X, p.Y, s.Z))
	end
	return ctx
end

-- A piece of the kit: a Model whose pivot is its base (set after the parts are in).
local function piece(kit: Instance, name: string, pivot: CFrame, build: (Model) -> ()): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = kit
	build(m)
	m.WorldPivot = pivot
	return m
end

local function anchor(root: Instance, collide: boolean)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = collide
			d.CanTouch = false
		end
	end
end

-- A copy of a prop model standing on the ground at cf (-Z = its front), scaled by `scale`.
local function prop(parent: Instance, template: Model, cf: CFrame, scale: number?, collide: boolean?): Model
	local m = template:Clone()
	m.PrimaryPart = nil
	local bb, size = m:GetBoundingBox()
	m.WorldPivot = bb * CFrame.new(0, -size.Y / 2, 0) -- pivot at the bottom center
	if scale and scale ~= 1 then
		m:ScaleTo(scale)
	end
	m:PivotTo(cf)
	anchor(m, collide == true)
	m.Parent = parent
	return m
end

-- The mesh of an AI model stretched to an exact size (x/y/z), standing on the ground at cf.
local function stretched(parent: Instance, template: Model, cf: CFrame, size: Vector3, collide: boolean): MeshPart
	local src = template:FindFirstChildWhichIsA("MeshPart", true) :: MeshPart
	local mp = src:Clone()
	mp.Size = size
	mp.CFrame = cf * CFrame.new(0, size.Y / 2, 0)
	mp.Anchored = true
	mp.CanCollide = collide
	mp.CanTouch = false
	mp.Parent = parent
	return mp
end

local function light(parent: Instance, pos: Vector3, color: Color3, brightness: number, range: number)
	local p = P(parent, "Light", Vector3.new(0.4, 0.4, 0.4), CFrame.new(pos), M.SmoothPlastic, color, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	local l = Instance.new("PointLight")
	l.Color, l.Brightness, l.Range, l.Shadows = color, brightness, range, false
	l.Parent = p
end

---------------------------------------------------------------------------------------------------------------
-- Wild Hollow: cozy, mossy, natural. A giant nest tree with a glowing hollow at the center, mossy spires and log
-- stumps to perch on, a mossy rim wall, a wooden gate, a stepping-stone path, a spring pond, nests and wildflowers.

function L.BuildWildHollowPlot(plot: Model, kitRoot: Folder)
	local ctx = context(plot)
	local T, at, frame = ctx.T, ctx.at, ctx.frame
	local kit = B.Folder(kitRoot, plot.Name, true)
	local rng = Random.new(1000 + tonumber(string.match(plot.Name, "%d+")) :: number)

	-- gate: two log posts, a beam with a moss top, the gold star, sign chains, a teal lantern light
	local gy, gh, gx = Slots.Gate, Slots.GateHeight, Slots.GateHalf
	piece(kit, "Gate", frame(0, gy, 0), function(m)
		for _, sd in { -gx, gx } do
			local post = P(m, "Post", Vector3.new(gh - 3, 4.6, 4.6), frame(sd, gy, (gh - 3) / 2 - 1) * CFrame.Angles(0, 0, math.pi / 2), M.Wood, WH.Bark)
			post.Shape = Enum.PartType.Cylinder
			P(m, "Foot", Vector3.new(7.4, 1.6, 7.4), frame(sd, gy, 0.6), M.Cobblestone, WH.StoneMoss)
			P(m, "FootMoss", Vector3.new(7.6, 0.5, 7.6), frame(sd, gy, 1.6), M.Grass, WH.Moss, { CanCollide = false })
			P(m, "Cap", Vector3.new(6.2, 1.2, 6.2), frame(sd, gy, gh - 2.6), M.Wood, WH.BarkDark)
			Glow(P(m, "Runes", Vector3.new(0.6, 12, 0.12), frame(sd, gy + 2.35, 12), M.Foil, Colors.Gold, { CanCollide = false }))
		end
		P(m, "Beam", Vector3.new(2 * gx + 8, 3.2, 4.4), frame(0, gy, gh - 1.4), M.Wood, WH.Bark)
		P(m, "BeamMoss", Vector3.new(2 * gx + 8.4, 1, 5), frame(0, gy, gh + 0.6), M.Grass, WH.Moss)
		for i = -2, 2 do -- moss tufts hanging over the beam's front
			P(m, "Tuft", Vector3.new(2.2, 2.6, 1), frame(i * 6.4, gy + 2.4, gh - 2.4), M.Grass, WH.MossDark, { CanCollide = false })
		end
		Star(m, frame(0, gy + 2.6, gh - 1.4), 4.5)
		for _, sd in { -5, 5 } do
			P(m, "SignChain", Vector3.new(0.3, 7.3, 0.3), frame(sd, gy, 21.2), M.Metal, Colors.Iron, { CanCollide = false })
		end
		light(m, at(0, gy + 3, gh - 6), WH.Teal, 1.2, 38)
	end)

	-- rim wall: mossy stone blocks with a grass cap, a gap for the gate; grouped into 7 arcs of 4 segments
	local arcs: { { number } } = {}
	for deg = 6, 354, 12 do
		local away = math.abs(if deg > 180 then deg - 360 else deg)
		if away > 13 then
			local last = arcs[#arcs]
			if last == nil or #last >= 4 then
				last = {}
				table.insert(arcs, last)
			end
			table.insert(last, deg)
		end
	end
	for i, group in arcs do
		local mid = group[math.ceil(#group / 2)]
		local mp = at(sin(rad(mid)) * Slots.Rim, cos(rad(mid)) * Slots.Rim, 0)
		piece(kit, "Wall" .. i, ctx.faceCenter(mp), function(m)
			for _, deg in group do
				local a = rad(deg)
				local p = at(sin(a) * Slots.Rim, cos(a) * Slots.Rim, 2.8)
				local cf = ctx.faceCenter(p)
				local len = 2 * Slots.Rim * sin(rad(6)) + 0.9
				P(m, "Wall", Vector3.new(len, 5.6, 3), cf, M.Cobblestone, WH.StoneMoss)
				P(m, "Moss", Vector3.new(len + 0.2, 0.9, 3.6), cf * CFrame.new(0, 3.1, 0), M.Grass, WH.Moss)
				local r = rng:NextNumber()
				if r < 0.5 then -- a rounded rock leaning on the wall
					local rock = P(m, "Rock", Vector3.new(rng:NextNumber(2.6, 4), rng:NextNumber(2, 3.4), rng:NextNumber(2.6, 4)), cf * CFrame.new(rng:NextNumber(-5, 5), 1.4, 2.4) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), M.Slate, WH.StoneMoss)
					rock.Shape = Enum.PartType.Ball
				end
			end
		end)
	end

	-- the nest tree: the hero, 48 tall, its glowing hollow faces the gate; an invisible trunk collider stops players
	local cp = at(Slots.Center.X, Slots.Center.Y, 0)
	local treeScale = Slots.Center.MaxHeight / 37.32
	piece(kit, "NestTree", CFrame.lookAt(cp, cp - ctx.Fwd), function(m)
		prop(m, LOOKS.WH_NestTree, CFrame.lookAt(cp - Vector3.new(0, 0.6, 0), cp - Vector3.new(0, 0.6, 0) - ctx.Fwd), treeScale, false)
		P(m, "TrunkCollider", Vector3.new(16, 10.5, 10.5), CFrame.new(cp + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.pi / 2), M.SmoothPlastic, Color3.new(1, 1, 1), { Shape = Enum.PartType.Cylinder, Transparency = 1, CanCollide = true, CanQuery = false })
		light(m, at(Slots.Center.X, Slots.Center.Y + 11, 6), WH.Teal, 2, 46)
		for i = 1, 3 do -- mushrooms around the roots
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(11, 17)
			prop(m, ENCH.AI_Ench_GlowMushrooms, CFrame.new(at(Slots.Center.X + cos(a) * r, Slots.Center.Y + sin(a) * r, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), rng:NextNumber(1.3, 2), false)
		end
	end)

	-- perches: mossy spires (AI meshes) under the five Elder pads, giant log stumps under the three Dragon pads
	for i, pl in Slots.ElderPerches do
		local base = at(pl[1], pl[2], -1)
		piece(kit, "Spire" .. i, CFrame.new(at(pl[1], pl[2], 0)), function(m)
			local src = if i % 2 == 1 then LOOKS.WH_Spire_B else LOOKS.WH_Spire_A
			local cf = ctx.faceCenter(base) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
			stretched(m, src, cf, Vector3.new(V.PillarR * 2, pl[3] + 1, V.PillarR * 2), true)
		end)
	end
	for i, pl in Slots.DragonPerches do
		local top = pl[3]
		piece(kit, "Stump" .. i, CFrame.new(at(pl[1], pl[2], 0)), function(m)
			local c = at(pl[1], pl[2], 0)
			local trunk = P(m, "Trunk", Vector3.new(top + 1, 12.4, 12.4), CFrame.new(c + Vector3.new(0, (top - 1) / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), M.Wood, WH.Bark)
			trunk.Shape = Enum.PartType.Cylinder
			local crown = P(m, "Crown", Vector3.new(0.6, 14.2, 14.2), CFrame.new(c + Vector3.new(0, top - 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), M.Wood, Color3.fromRGB(150, 112, 76))
			crown.Shape = Enum.PartType.Cylinder
			local mossTop = P(m, "CrownMoss", Vector3.new(0.3, 7, 7), CFrame.new(c + Vector3.new(2.6, top + 0.05, -1.4)) * CFrame.Angles(0, 0, math.pi / 2), M.Grass, WH.Moss, { CanCollide = false })
			mossTop.Shape = Enum.PartType.Cylinder
			for k = 0, 4 do -- roots flaring out at the base
				local a = k * math.pi * 2 / 5 + i
				P(m, "Root", Vector3.new(2.6, 3.6, 7), CFrame.new(c) * CFrame.Angles(0, a, 0) * CFrame.new(0, 1.2, 7.4) * CFrame.Angles(-0.45, 0, 0), M.Wood, WH.BarkDark)
			end
		end)
	end

	-- path: stepping stones from the gate toward the tree, curving gently (5 stones a piece)
	local group = 0
	local y = gy - 6
	local pieceStones: { CFrame } = {}
	local function flush()
		if #pieceStones == 0 then
			return
		end
		group += 1
		local first = pieceStones[1]
		piece(kit, "Path" .. group, CFrame.new(first.Position), function(m)
			for _, cf in pieceStones do
				local r = rng:NextNumber(2.2, 3.2)
				local st = Disc(m, "Stone", cf.Position + Vector3.new(0, 0.15, 0), r, 0.5, M.Cobblestone, WH.StoneMoss)
				st.CFrame = cf * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2)
			end
		end)
		pieceStones = {}
	end
	while y > Slots.Center.Y + 24 do
		local x = 6 * sin(y / 14) + rng:NextNumber(-0.8, 0.8)
		table.insert(pieceStones, CFrame.new(at(x, y, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0))
		if #pieceStones >= 5 then
			flush()
		end
		y -= rng:NextNumber(3.8, 4.8)
	end
	flush()

	-- the spring pond: water, a ring of rocks, reeds, lily pads
	local w = Slots.Water
	piece(kit, "Pond", CFrame.new(at(w.X, w.Y, 0)), function(m)
		local wp = at(w.X, w.Y, 0.25)
		Disc(m, "Bed", wp - Vector3.new(0, 0.1, 0), w.R + 1, 0.3, M.Mud, Color3.fromRGB(58, 70, 60), { CanCollide = false })
		Disc(m, "Water", wp + Vector3.new(0, 0.1, 0), w.R, 0.5, M.Glass, Colors.Water, { Transparency = 0.25, CanCollide = false })
		for k = 0, 17 do
			local a = k * math.pi * 2 / 18 + rng:NextNumber(-0.08, 0.08)
			local rp = at(w.X + cos(a) * (w.R + 0.6), w.Y + sin(a) * (w.R + 0.6), 0.8)
			local rock = P(m, "Rock", Vector3.new(rng:NextNumber(4, 6.4), rng:NextNumber(2, 3.2), rng:NextNumber(3.6, 5.4)), CFrame.new(rp) * CFrame.Angles(0, -a, 0), M.Slate, WH.StoneMoss)
			rock.Shape = Enum.PartType.Ball
			if k % 3 == 0 then
				P(m, "RockMoss", Vector3.new(rock.Size.X * 0.7, 0.5, rock.Size.Z * 0.7), CFrame.new(rp + Vector3.new(0, rock.Size.Y * 0.36, 0)) * CFrame.Angles(0, -a, 0), M.Grass, WH.Moss, { CanCollide = false })
			end
		end
		for k = 0, 3 do
			local a = k * 1.6 + 0.6
			prop(m, MEADOW.AI_Meadow_Reeds, CFrame.new(at(w.X + cos(a) * (w.R - 2.5), w.Y + sin(a) * (w.R - 2.5), 0)) * CFrame.Angles(0, a, 0), 1.6, false)
		end
		for k = 1, 6 do
			local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(3, w.R - 4)
			Disc(m, "LilyPad", at(w.X + cos(a) * r, w.Y + sin(a) * r, 0.55), rng:NextNumber(1, 1.5), 0.15, M.Grass, Color3.fromRGB(84, 140, 80), { CanCollide = false })
		end
	end)

	-- basking slabs
	for i, b in Slots.Bask do
		piece(kit, "Bask" .. i, CFrame.new(at(b[1], b[2], 0)), function(m)
			Disc(m, "Slab", at(b[1], b[2], 0.8), 9, 1.6, M.Cobblestone, WH.StoneMoss)
			Disc(m, "SlabMoss", at(b[1] + 1.4, b[2] - 1, 1.65), 6, 0.3, M.Grass, WH.Moss, { CanCollide = false })
			for k = 1, 3 do
				local a = k * 2.1 + i
				local rock = P(m, "Rock", Vector3.new(3.4, 2.6, 3), CFrame.new(at(b[1] + cos(a) * 9.6, b[2] + sin(a) * 9.6, 1)), M.Slate, WH.StoneMoss)
				rock.Shape = Enum.PartType.Ball
			end
		end)
	end

	-- nests (three straw nests, two hay bales)
	local nz = Slots.Nest
	piece(kit, "Nests", CFrame.new(at(nz.X, nz.Y, 0)), function(m)
		for _, off in { { 0, 0 }, { 10, -9 }, { -10, -8 } } do
			prop(m, MEADOW.AI_Meadow_Nest, CFrame.new(at(nz.X + off[1], nz.Y + off[2], 0)) * CFrame.Angles(0, off[1] * 0.3, 0), 1.3, false)
		end
		prop(m, MEADOW.AI_Meadow_HayBales, CFrame.new(at(nz.X + 14, nz.Y + 5, 0)) * CFrame.Angles(0, 0.6, 0), 1.7, false)
		prop(m, MEADOW.AI_Meadow_HayBales, CFrame.new(at(nz.X - 13, nz.Y + 8, 0)) * CFrame.Angles(0, -0.5, 0), 1.5, false)
	end)

	-- wildflower patches and bushes on open ground (rejection-sampled away from zones, perches, path, pond)
	local function free(x: number, yy: number): boolean
		local function near(cx: number, cy: number, r: number): boolean
			return (x - cx) ^ 2 + (yy - cy) ^ 2 < r * r
		end
		if x * x + yy * yy > 66 * 66 or yy > 68 or (math.abs(x) < 16 and yy > 58) then
			return false
		end
		if near(Slots.Center.X, Slots.Center.Y, 27) or near(w.X, w.Y, w.R + 4) or near(nz.X, nz.Y, nz.R + 2) then
			return false
		end
		for _, pl in Slots.ElderPerches do
			if near(pl[1], pl[2], 12) then return false end
		end
		for _, pl in Slots.DragonPerches do
			if near(pl[1], pl[2], 10) then return false end
		end
		for _, b in Slots.Bask do
			if near(b[1], b[2], 12) then return false end
		end
		if math.abs(x - 6 * sin(yy / 14)) < 6 and yy > -10 then
			return false
		end
		return true
	end
	local flowerKinds = { ENCH.Store_WildFlower, ENCH.Store_WildFlower, ENCH.Store_WildFlower, ENCH.AI_Ench_Daisies }
	local patches, tries = 0, 0
	while patches < 9 and tries < 400 do
		tries += 1
		local x, yy = rng:NextNumber(-66, 66), rng:NextNumber(-66, 66)
		if free(x, yy) then
			patches += 1
			piece(kit, "Patch" .. patches, CFrame.new(at(x, yy, 0)), function(m)
				for k = 1, 4 do
					local px, py = x + rng:NextNumber(-4, 4), yy + rng:NextNumber(-4, 4)
					if free(px, py) then
						local kind = flowerKinds[rng:NextInteger(1, #flowerKinds)]
						prop(m, kind, CFrame.new(at(px, py, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(1.6, 2.4), false)
					end
				end
				if patches % 3 == 0 then
					prop(m, MEADOW.AI_Meadow_Bush, CFrame.new(at(x, yy, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), 2, false)
				elseif patches % 3 == 1 then
					prop(m, MEADOW.AI_Meadow_Mushrooms, CFrame.new(at(x + 2, yy - 2, 0)), 1.8, false)
				end
			end)
		end
	end

	-- two iron lanterns just inside the gate (tag Lantern: lit at dusk)
	piece(kit, "Lanterns", frame(0, gy - 10, 0), function(m)
		for _, sd in { -12, 12 } do
			B.Lantern(m, at(sd, gy - 9, 0), 0)
		end
	end)
	return kit
end

---------------------------------------------------------------------------------------------------------------

function L.BuildWildHollow()
	local kitRoot = kitFolder("WildHollow")
	for _, plot in SM.Pens:GetChildren() do
		if plot:IsA("Model") and B.SanctuaryOrder[plot.Name] then
			L.BuildWildHollowPlot(plot, kitRoot)
		end
	end
end

-- Edit-mode preview: clones a built kit into Workspace._LookPreview so it can be screenshotted (L.ClearPreview() removes it).
function L.Preview(plotName: string, look: string?)
	local kit = kitFolder(look or "WildHollow"):FindFirstChild(plotName)
	assert(kit, "no kit for " .. plotName)
	local f = B.Folder(workspace, "_LookPreview") :: Folder
	local old = f:FindFirstChild(plotName)
	if old then
		old:Destroy()
	end
	local c = kit:Clone()
	c.Parent = f
end

function L.ClearPreview()
	local f = workspace:FindFirstChild("_LookPreview")
	if f then
		f:Destroy()
	end
end

-- Part and triangle counts of one kit (AI mesh faces via EditableMesh; needs to run in Studio).
function L.Stats(look: string, plotName: string): (number, number)
	local AssetService = game:GetService("AssetService")
	local kit = kitFolder(look):FindFirstChild(plotName)
	assert(kit, "no kit for " .. plotName)
	local cache: { [string]: number } = {}
	local parts, tris = 0, 0
	for _, d in kit:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if d:IsA("MeshPart") and d.MeshId ~= "" then
				if cache[d.MeshId] == nil then
					local ok, n = pcall(function()
						local em = AssetService:CreateEditableMeshAsync(Content.fromUri(d.MeshId))
						local c = #em:GetFaces()
						em:Destroy()
						return c
					end)
					cache[d.MeshId] = if ok then n else 0
				end
				tris += cache[d.MeshId]
			elseif d:IsA("Part") and d.Shape == Enum.PartType.Block then
				tris += 12
			elseif d:IsA("Part") then
				tris += 100
			end
		end
	end
	return parts, tris
end

return L
