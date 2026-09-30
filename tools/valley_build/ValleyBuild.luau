-- Valley build (remaster checkpoint C): the part-built hub of the Starter Meadow. Studio build helper, not used by
-- the game. Each Build* function clears and rebuilds only its own folder, so it can be re-run after a tweak.
-- Usage: local B = require(ServerStorage.RemasterTools.ValleyBuild:Clone()); B.BuildEntrance() ...
-- Stand-ins for future custom models are named "Placeholder_<Name>".
-- The live copy is ServerStorage.RemasterTools.ValleyBuild in the place; this file is the reference copy.
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local B = {}
local SM = workspace:WaitForChild("StarterMeadow")
local KIT = ServerStorage.PropKits.Enchanted
local V = require(ServerStorage.RemasterTools.ValleyTerrain:Clone())
local M = Enum.Material
local rad, sin, cos, sqrt = math.rad, math.sin, math.cos, math.sqrt

local C = {
	Stone = Color3.fromRGB(178, 166, 146), -- warm weathered stone
	StoneDark = Color3.fromRGB(142, 132, 118),
	Cap = Color3.fromRGB(156, 148, 134),
	Gold = Color3.fromRGB(226, 184, 84),
	GoldGlow = Color3.fromRGB(228, 176, 86), -- night glow of gold stars/runes (brighter blooms out)
	Navy = Color3.fromRGB(30, 42, 96),
	Iron = Color3.fromRGB(58, 58, 66),
	Wood = Color3.fromRGB(96, 68, 46),
	Plank = Color3.fromRGB(122, 88, 58),
	Roof = Color3.fromRGB(84, 90, 104),
	StarBlue = Color3.fromRGB(120, 180, 255),
	Straw = Color3.fromRGB(196, 160, 92),
	StrawDark = Color3.fromRGB(128, 94, 54),
	Water = Color3.fromRGB(70, 150, 190),
}
B.Colors = C

local function folder(parent: Instance, name: string, clear: boolean?): Instance
	local f = parent:FindFirstChild(name)
	if f and clear then
		f:Destroy()
		f = nil
	end
	if f == nil then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f :: Instance
end
B.Folder = folder

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function P(parent: Instance, name: string, size: Vector3, cf: CFrame, mat: Enum.Material, color: Color3, extra: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Material = mat
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if extra then
		for k, v in extra do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end
B.P = P

-- WedgePart: full height at its +Z end, sloping down to its -Z end.
local function W(parent: Instance, name: string, size: Vector3, cf: CFrame, mat: Enum.Material, color: Color3): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Material = mat
	p.Color = color
	p.Parent = parent
	return p
end

local function glow(p: BasePart, color: Color3?)
	p:SetAttribute("GlowColor", color or C.GoldGlow)
	CollectionService:AddTag(p, "NightGlow")
end

-- Gold 8-point star (two squares at 45°), flat in the cf's XY plane; glows at night.
local function star(parent: Instance, cf: CFrame, s: number, glowColor: Color3?)
	for i = 0, 1 do
		local p = P(parent, "GoldStar", Vector3.new(s, s, 0.2), cf * CFrame.Angles(0, 0, rad(45 * i)), M.Foil, C.Gold, { CanCollide = false, CastShadow = false })
		glow(p, glowColor)
	end
end

-- Iron lantern post from the kit, standing on the ground at pos, tagged Lantern (lit at dusk by WorldLifeController).
local function lantern(parent: Instance, pos: Vector3, yaw: number?): Model
	local l = KIT.AI_Ench_IronLantern:Clone()
	l:PivotTo(CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0))
	l.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(l, "Lantern")
	l.Parent = parent
	return l
end

-- Upright disc (Cylinder part lying flat): center position and radius, thickness.
local function disc(parent: Instance, name: string, center: Vector3, radius: number, thick: number, mat: Enum.Material, color: Color3, extra: { [string]: any }?): Part
	local p = P(parent, name, Vector3.new(thick, radius * 2, radius * 2), CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), mat, color, extra)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ground(x: number, z: number): number
	return (V.Height(x, z))
end
B.Ground = ground
B.Star, B.Lantern, B.Disc, B.Glow, B.Wedge, B.Model = star, lantern, disc, glow, W, model

---------------------------------------------------------------------------------------------------------------
-- Entrance: two stone towers with star banners at the valley mouth

function B.BuildEntrance()
	local f = folder(SM, "Entrance", true)
	local m = model(f, "Placeholder_EntranceGate")
	local z, g = 150, 0.8
	for _, side in { -1, 1 } do
		local x = side * 15.5
		local y = g
		P(m, "Plinth", Vector3.new(10, 2.4, 10), CFrame.new(x, y + 0.6, z), M.Slate, C.Cap)
		y += 1.8
		P(m, "Tower", Vector3.new(7.5, 17, 7.5), CFrame.new(x, y + 8.5, z), M.Cobblestone, C.Stone)
		y += 17
		P(m, "Cornice", Vector3.new(8.8, 1.2, 8.8), CFrame.new(x, y + 0.6, z), M.Slate, C.Cap)
		y += 1.2
		P(m, "Top", Vector3.new(6, 2.4, 6), CFrame.new(x, y + 1.2, z), M.Cobblestone, C.Stone)
		y += 2.4
		P(m, "Finial", Vector3.new(3, 1.8, 3), CFrame.new(x, y + 0.9, z), M.Slate, C.Cap)
		-- banner on the south face (toward arriving players): gold rod, navy cloth, gold star
		local face = z + 3.75
		P(m, "BannerRod", Vector3.new(6.4, 0.4, 0.4), CFrame.new(x, g + 17.4, face + 0.35), M.Metal, C.Gold)
		P(m, "Banner", Vector3.new(5.4, 10.5, 0.2), CFrame.new(x, g + 12, face + 0.3), M.Fabric, C.Navy, { CanCollide = false })
		star(m, CFrame.new(x, g + 13.6, face + 0.45), 2.8)
		-- low wall toward the gorge cliffs, and a lantern by the road
		P(m, "Wall", Vector3.new(14, 4.5, 3), CFrame.new(side * 26.5, g + 1.25, z), M.Cobblestone, C.Stone)
		lantern(f, Vector3.new(side * 10, g, z + 5), 0)
	end
end

---------------------------------------------------------------------------------------------------------------
-- Market square: the star obelisk (signpost) and stone platforms under the three stations

local function modelYaw(m: Model): number
	local look = (m.PrimaryPart :: BasePart).CFrame.LookVector
	return math.atan2(-look.X, -look.Z)
end

-- Footprint of a model in its own yawed frame: center (world) and size (x = width, z = depth), plus bottom y.
local function footprint(m: Model, yaw: number): (Vector3, Vector3, number)
	local rot = CFrame.Angles(0, yaw, 0)
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local cf, s = d.CFrame, d.Size / 2
			for _, c in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1), Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) } do
				local w = rot:PointToObjectSpace(cf:PointToWorldSpace(s * c))
				mn = mn:Min(w)
				mx = mx:Max(w)
			end
		end
	end
	local centerWorld = rot:PointToWorldSpace((mn + mx) / 2)
	return centerWorld, mx - mn, mn.Y -- (the yaw rotation keeps Y, so mn.Y is the world bottom)
end

function B.BuildMarket()
	local f = folder(SM, "Market", true)
	local cx, cz, g = 0, 112, 0.8

	-- star obelisk
	local o = model(f, "Placeholder_StarObelisk")
	local y = g
	for i, r in { 9, 7, 5.2 } do
		disc(o, "Step" .. i, Vector3.new(cx, y + 0.5, cz), r, 1, if i == 2 then M.Slate else M.Cobblestone, if i == 2 then C.Cap else C.Stone)
		y += 1
	end
	-- (kept low, top ~14, so it never hides the altar from the spawn)
	P(o, "Plinth", Vector3.new(5, 2.4, 5), CFrame.new(cx, y + 1.2, cz) * CFrame.Angles(0, rad(45), 0), M.Slate, C.StoneDark)
	glow(P(o, "RuneBand", Vector3.new(5.2, 0.35, 5.2), CFrame.new(cx, y + 1.8, cz) * CFrame.Angles(0, rad(45), 0), M.Foil, C.Gold, { CanCollide = false }))
	y += 2.4
	-- the crystal: the kit's crystal mesh stretched tall (glass by day, glowing star-blue at night)
	local crystal = (KIT.AI_Ench_MagicCrystals :: Model).Crystals:Clone() :: MeshPart
	crystal.Name = "Crystal"
	crystal.Size = Vector3.new(5.5, 8, 5.5)
	crystal.CFrame = CFrame.new(cx, y + 3.8, cz)
	crystal.Material = M.Glass
	crystal.Color = C.StarBlue
	crystal.Transparency = 0.05
	crystal.Anchored = true
	crystal.Parent = o
	glow(crystal, C.StarBlue)
	-- signpost arms: Altar (north), Sanctuaries (west, east); wording at D
	for i, yawDeg in { 0, 90, -90 } do
		local dir = CFrame.Angles(0, rad(yawDeg), 0)
		P(o, "SignArm", Vector3.new(0.5, 1.1, 6), CFrame.new(cx, g + 3.5 + i * 0.65, cz) * dir * CFrame.new(0, 0, -5), M.WoodPlanks, C.Plank)
	end

	-- stone platforms under the stations (top 1.6 above the square), stations raised onto them
	for _, name in { "StarMerchant", "DragonstoneForge", "RuneShrine" } do
		local st = SM.Buildings:FindFirstChild(name) :: Model?
		if st then
			local yaw = modelYaw(st)
			local center, size, bottom = footprint(st, yaw)
			local top = g + 1.6
			st:PivotTo(st:GetPivot() + Vector3.new(0, top - bottom, 0))
			local rot = CFrame.Angles(0, yaw, 0)
			local pf = model(f, "Platform_" .. name)
			P(pf, "Platform", Vector3.new(size.X + 4, 2.4, size.Z + 4), CFrame.new(center.X, top - 1.2, center.Z) * rot, M.Cobblestone, C.Stone)
			P(pf, "Step", Vector3.new(math.min(size.X, 14), 1.6, 2.4), CFrame.new(center.X, g + 0.4, center.Z) * rot * CFrame.new(0, 0, -(size.Z / 2 + 3.2)), M.Slate, C.Cap)
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Bridges: stone arch bridges built from slices (the vault), deck segments and parapets following the arch

-- a, b: the two ends on the ground (Y = ground height). width: deck width. rise: deck rise at the middle.
-- spanFrom, spanTo: distances from a where the river is (the arch opening). archRise: opening height above the water.
local function bridge(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, rise: number, spanFrom: number, spanTo: number, archRise: number, stars: boolean): Model
	local m = model(parent, name)
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local L = flat.Magnitude
	local dir = flat.Unit
	local rot = CFrame.lookAt(Vector3.zero, dir)
	local th = 1.2
	local function deckY(s: number): number
		local t = s / L
		return a.Y + (b.Y - a.Y) * t + rise * sin(math.pi * t)
	end
	local function point(s: number, y: number): Vector3
		return Vector3.new(a.X, y, a.Z) + dir * s
	end
	-- vault slices (full width incl. parapets): from the arch (or below ground at the ends) up to the deck
	local n = math.ceil(L / 1.8)
	local mid, half = (spanFrom + spanTo) / 2, (spanTo - spanFrom) / 2
	for i = 1, n do
		local s = (i - 0.5) * L / n
		local bottom
		if s > spanFrom and s < spanTo then
			bottom = -1.5 + archRise * sqrt(math.max(0, 1 - ((s - mid) / half) ^ 2))
		else
			bottom = math.min(a.Y, b.Y) - 3
		end
		local top = deckY(s) - th + 0.2
		if top > bottom + 0.2 then
			local c = point(s, (top + bottom) / 2)
			P(m, "Vault", Vector3.new(width + 2.8, top - bottom, L / n + 0.15), CFrame.new(c) * rot, M.Cobblestone, C.Stone)
		end
	end
	-- deck and parapets, following the arch
	local segs = math.ceil(L / 4)
	for i = 1, segs do
		local s0, s1 = (i - 1) * L / segs, i * L / segs
		local p0, p1 = point(s0, deckY(s0)), point(s1, deckY(s1))
		local c = (p0 + p1) / 2
		local cf = CFrame.lookAt(c, p1)
		local len = (p1 - p0).Magnitude + 0.3
		P(m, "Deck", Vector3.new(width, th, len), cf * CFrame.new(0, -th / 2, 0), M.Cobblestone, C.StoneDark)
		for _, side in { -1, 1 } do
			P(m, "Parapet", Vector3.new(1.4, 2.8, len), cf * CFrame.new(side * (width / 2 + 0.7), 1.2, 0), M.Slate, C.Cap)
		end
	end
	-- end posts
	for _, s in { 0.9, L - 0.9 } do
		for _, side in { -1, 1 } do
			local c = point(s, deckY(s)) + Vector3.new(0, 1.9, 0) + rot:VectorToWorldSpace(Vector3.new(side * (width / 2 + 0.7), 0, 0))
			P(m, "Post", Vector3.new(2.2, 4.6, 2.2), CFrame.new(c) * rot, M.Slate, C.StoneDark)
		end
	end
	-- gold stars on the outer faces (over the arch)
	if stars then
		for _, side in { -1, 1 } do
			local c = point(mid, deckY(mid) - th - 0.9) + rot:VectorToWorldSpace(Vector3.new(side * (width / 2 + 1.5), 0, 0))
			star(m, CFrame.lookAt(c, c + rot:VectorToWorldSpace(Vector3.new(side, 0, 0))), 2.4)
		end
	end
	return m
end

function B.BuildBridges()
	local f = folder(SM, "Bridges", true)
	-- the grand bridge on the main road (the valley's second landmark): from the square (south) to the plaza step
	bridge(f, "Placeholder_GrandBridge", Vector3.new(0, 0.8, 80), Vector3.new(0, 1.9, 48), 16, 4.2, 9, 25, 4.2, true)
	for _, zEnd in { 80.5, 47.5 } do
		for _, side in { -1, 1 } do
			lantern(f, Vector3.new(side * 11.5, if zEnd > 60 then 0.8 else 2.0, zEnd), 0)
		end
	end
	-- side bridges on the W3 / E3 roads, square to the river
	bridge(f, "Placeholder_SideBridge_W", Vector3.new(-102.3, ground(-102.3, 46.2), 46.2), Vector3.new(-97.7, ground(-97.7, 73.8), 73.8), 9, 3.2, 8, 20, 3.4, true)
	bridge(f, "Placeholder_SideBridge_E", Vector3.new(97.4, ground(97.4, 46.3), 46.3), Vector3.new(102.6, ground(102.6, 73.7), 73.7), 9, 3.2, 8, 20, 3.4, true)
end

---------------------------------------------------------------------------------------------------------------
-- Plaza: an outer step around the altar's stepped floor, 8 lanterns, 4 star banners

function B.BuildPlaza()
	local f = folder(SM.Plaza, "Dressing", true)
	disc(f, "OuterStep", Vector3.new(0, 1.4, 0), 48, 1.2, M.Cobblestone, C.StoneDark)
	for _, b in { 29, 151, -29, -151 } do -- lanterns flanking the north and south approaches (tidy-up: was 8)
		local r = rad(b)
		lantern(f, Vector3.new(45 * sin(r), 2.0, -45 * cos(r)), -r)
	end
	for _, b in { 45, 135, -45, -135 } do
		local r = rad(b)
		local pos = Vector3.new(46.5 * sin(r), 2.0, -46.5 * cos(r))
		local out = Vector3.new(sin(r), 0, -cos(r))
		local m = model(f, "Placeholder_StarBanner")
		P(m, "Pole", Vector3.new(0.7, 18, 0.7), CFrame.new(pos + Vector3.new(0, 9, 0)), M.Metal, C.Iron)
		P(m, "Finial", Vector3.new(1.1, 1.1, 1.1), CFrame.new(pos + Vector3.new(0, 18.4, 0)), M.Foil, C.Gold)
		local face = CFrame.lookAt(pos + Vector3.new(0, 12, 0) + out * 0.6, pos + Vector3.new(0, 12, 0) + out * 2)
		P(m, "Bar", Vector3.new(5, 0.35, 0.35), face * CFrame.new(0, 5.2, 0), M.Metal, C.Gold)
		P(m, "Banner", Vector3.new(4.4, 10, 0.2), face, M.Fabric, C.Navy, { CanCollide = false })
		star(m, face * CFrame.new(0, 1.8, -0.15), 2.4)
	end
end

-- Crystal ring: 8 star-blue crystal clusters (kit AI_Ench_MagicCrystals) on gold sockets around the altar, on the
-- lower floor step between the roads and stairs (bearings 22.5 + 45n, so the south view from the spawn stays open).
-- Glass by day, glowing at night (NightGlow).
B.CrystalRing = { Radius = 40, Y = 2.8, Scale = 0.7, Color = Color3.fromRGB(120, 180, 255) }

function B.BuildCrystalRing()
	local f = folder(SM.Plaza, "CrystalRing", true)
	local ring = B.CrystalRing
	local rng = Random.new(1618)
	for i = 0, 7 do
		local r = rad(22.5 + i * 45)
		local pos = Vector3.new(ring.Radius * sin(r), ring.Y, -ring.Radius * cos(r))
		local m = KIT.AI_Ench_MagicCrystals:Clone()
		m.Name = "AltarCrystal"
		m:ScaleTo(ring.Scale)
		m:PivotTo(CFrame.new(pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)) -- on the socket
		m.Parent = f
		local crystals = m:FindFirstChild("Crystals") :: BasePart
		crystals.Material = M.Glass
		crystals.Color = ring.Color
		crystals.Transparency = 0.05
		glow(crystals, ring.Color)
		local rock = m:FindFirstChild("Rock") :: BasePart
		rock.Material = M.Slate
		rock.Color = C.StoneDark
		local width = rock.Size.X + 0.6
		P(m, "Socket", Vector3.new(0.7, width, width), CFrame.new(pos + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.pi / 2), M.Metal, C.GoldGlow, { Shape = Enum.PartType.Cylinder })
	end
end

---------------------------------------------------------------------------------------------------------------
-- Portal terrace: retaining wall, grand stairs, stairs up to the Spire, a themed ground disc under each gate

B.GateGrounds = {
	Portal_VolcanoPeak = { M.Slate, Color3.fromRGB(64, 46, 42) },
	Portal_FrozenCliffs = { M.Marble, Color3.fromRGB(222, 236, 244) },
	Portal_StormCanyon = { M.Slate, Color3.fromRGB(86, 82, 116) },
	Portal_EclipseIsles = { M.Slate, Color3.fromRGB(72, 54, 100) },
}

function B.BuildTerrace()
	local f = folder(SM, "PortalTerrace", true)
	local R = 131.5
	for b = -46, 46, 4 do
		local r = rad(b)
		local x, z = R * sin(r), -R * cos(r)
		if math.abs(x) > 17 then
			local w = 2 * R * sin(rad(2)) + 0.8
			P(f, "Wall", Vector3.new(w, 14.2, 3), CFrame.lookAt(Vector3.new(x, 6, z), Vector3.new(0, 6, 0)), M.Cobblestone, C.Stone)
			if b % 12 == 2 or b % 12 == -10 then
				P(f, "Buttress", Vector3.new(2.6, 14.8, 4.4), CFrame.lookAt(Vector3.new(x, 6.3, z), Vector3.new(0, 6.3, 0)) * CFrame.new(0, 0, -0.8), M.Slate, C.Cap)
			end
		end
	end
	-- grand stairs from the plaza road up to the terrace
	local stairs = model(f, "GrandStairs")
	for k = 1, 8 do
		local top = 0.8 + 1.4 * k
		local front = 112 + 2.625 * (k - 1)
		local back = 134
		P(stairs, "Step", Vector3.new(24, top + 1, back - front), CFrame.new(0, (top - 1) / 2, -(front + back) / 2), M.Slate, C.Cap)
	end
	for _, side in { -1, 1 } do
		W(stairs, "Cheek", Vector3.new(2, 12.4, 22), CFrame.new(side * 13, 0.8 + 6.2, -123) * CFrame.Angles(0, math.pi, 0), M.Cobblestone, C.Stone)
		P(stairs, "Pedestal", Vector3.new(3.6, 3, 3.6), CFrame.new(side * 14.5, 2.3, -110), M.Slate, C.StoneDark)
		lantern(stairs, Vector3.new(side * 14.5, 3.8, -110), 0)
	end
	-- stairs from the terrace up the Spire hill
	local up = model(f, "SpireStairs")
	for k = 1, 10 do
		local top = 12 + 1.6 * k
		local front = 176 + 3.4 * (k - 1)
		local back = 213
		P(up, "Step", Vector3.new(16, top - 8, back - front), CFrame.new(0, (top + 8) / 2, -(front + back) / 2), M.Slate, C.Cap)
	end
	-- a themed ground disc under each gate
	for name, look in B.GateGrounds do
		local portal = SM.Portals:FindFirstChild(name) :: Model?
		if portal then
			local s = (portal.PrimaryPart :: BasePart).Position
			disc(f, "Ground_" .. name, Vector3.new(s.X, 12.0, s.Z), 12, 0.5, look[1], look[2])
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Dragon Sanctuaries: the six RoostPlot models rebuilt on their terraces

B.SanctuaryOrder = { RoostPlot6 = "W1", RoostPlot5 = "W2", RoostPlot4 = "W3", RoostPlot1 = "E1", RoostPlot2 = "E2", RoostPlot3 = "E3" }
local Slots = V.Slots
B.RoamRadius = Slots.Roam
B.PlainArt = false -- true = BuildSanctuary also builds the plain "Placeholder_*" stand-ins (rim wall, gate, perch spires, nests, pond)

-- The base sanctuary (Valley rework 2026-10): a neutral terrace with the slots every sanctuary look shares (zones,
-- perches, upgrade stands, sign; layout in ValleyTerrain V.Slots, local x/y = right/toward the gate) plus plain
-- "Placeholder_*" stand-ins (rim wall, gate, perch spires, nests, pond) that the look kits replace.
function B.BuildSanctuary(plot: Model)
	local id = B.SanctuaryOrder[plot.Name]
	local s
	for _, cand in V.Sanct do
		if cand.Name == id then
			s = cand
		end
	end
	assert(s, "no sanctuary for " .. plot.Name)
	local T = s.T
	local center = Vector3.new(s.X, T, s.Z)
	local fwd = Vector3.new(s.AX, 0, s.AZ) -- toward the altar (the gate side)
	local function at(x: number, y: number, h: number?): Vector3 -- slot coordinates -> world (h above the floor)
		local wx, wz = V.ToWorld(s, x, y)
		return Vector3.new(wx, T + (h or 0), wz)
	end
	local function frame(x: number, y: number, h: number?): CFrame -- at a slot, -Z toward the gate / the altar
		local p = at(x, y, h)
		return CFrame.lookAt(p, p + fwd)
	end

	-- clear the old content (keep Base, Sign, stands), rebuild in "Sanctuary"
	local old = plot:FindFirstChild("Sanctuary")
	if old then
		old:Destroy()
	end
	for _, name in { "Zones", "Perches" } do
		local oldFolder = plot:FindFirstChild(name)
		if oldFolder then
			oldFolder:Destroy()
		end
	end
	local sf = Instance.new("Folder")
	sf.Name = "Sanctuary"
	sf.Parent = plot

	-- Base: the invisible floor disc (PrimaryPart); the ground itself is terrain grass
	local base = plot:FindFirstChild("Base") :: Part
	base.Size = Vector3.new(1, Slots.Rim * 2, Slots.Rim * 2)
	base.CFrame = CFrame.new(s.X, T - 0.5, s.Z) * CFrame.Angles(0, 0, math.pi / 2)
	base.Transparency = 1
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	plot.PrimaryPart = base
	plot:SetAttribute("RoamCenter", center)
	plot:SetAttribute("RoamRadius", Slots.Roam)
	plot:SetAttribute("CenterHeight", Slots.Center.MaxHeight) -- fliers keep clear of the centerpiece below this height

	-- rim wall with a gap for the gate (a segment every 12 degrees around from the gate)
	local wall = model(sf, "Placeholder_RimWall")
	for deg = 6, 354, 12 do
		local away = math.abs(if deg > 180 then deg - 360 else deg)
		if away > 13 then
			local a = rad(deg)
			local p = at(sin(a) * Slots.Rim, cos(a) * Slots.Rim, 3)
			P(wall, "Wall", Vector3.new(2 * Slots.Rim * sin(rad(6)) + 0.9, 6, 3), CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z)), M.Cobblestone, C.Stone)
		end
	end

	-- the gate (pillars, lintel, gold star), the owner sign under its lintel
	local gate = model(sf, "Placeholder_SanctuaryGate")
	local gh, gy = Slots.GateHeight, Slots.Gate
	for _, sd in { -Slots.GateHalf, Slots.GateHalf } do
		P(gate, "Plinth", Vector3.new(7, 2, 7), frame(sd, gy, 1), M.Slate, C.Cap)
		P(gate, "Pillar", Vector3.new(4.6, gh - 6, 4.6), frame(sd, gy, 2 + (gh - 6) / 2), M.Cobblestone, C.Stone)
		P(gate, "Capital", Vector3.new(6, 1.6, 6), frame(sd, gy, gh - 3.2), M.Slate, C.Cap)
		glow(P(gate, "Runes", Vector3.new(0.6, 14, 0.12), frame(sd, gy + 2.35, 13), M.Foil, C.Gold, { CanCollide = false }))
	end
	P(gate, "Lintel", Vector3.new(2 * Slots.GateHalf + 6, 3.4, 5), frame(0, gy, gh - 1.4), M.Slate, C.StoneDark)
	star(gate, frame(0, gy + 2.6, gh - 1.4), 4.5)
	local sign = plot:FindFirstChild("Sign") :: BasePart
	sign.CFrame = frame(0, gy, 16)
	for _, sd in { -5, 5 } do
		P(gate, "SignChain", Vector3.new(0.3, 7.3, 0.3), frame(sd, gy, 21.2), M.Metal, C.Iron, { CanCollide = false })
	end

	-- upgrade stands in front of the gate (the parts carry the prompts; the art comes from BuildUpgradeStands),
	-- lanterns at the forecourt's front corners
	for i, name in { "UpgradeSlots", "UpgradeIncome" } do
		local stand = plot:FindFirstChild(name) :: BasePart
		local cap = plot:FindFirstChild(name .. "Glow") :: BasePart
		local sx, sy = Slots.Stands[i][1], Slots.Stands[i][2]
		stand.CFrame = frame(sx, sy, stand.Size.Y / 2)
		cap.CFrame = frame(sx, sy, stand.Size.Y + cap.Size.Y / 2)
	end
	lantern(sf, at(-20, 95), 0)
	lantern(sf, at(20, 95), 0)

	-- steps from the forecourt down to the road: solid blocks from below the ground (y -1) up to each tread
	-- (h is relative to the forecourt at T, so convert the absolute heights)
	local n = math.max(2, math.ceil((T - 0.8) / 1.5)) -- rises of at most 1.5 studs (walkable without jumping)
	local rise, run = (T - 0.8) / n, 2.2
	local steps = model(sf, "Steps")
	for k = 1, n - 1 do
		local top = T - k * rise
		local front = V.ApronLen + (k - 1) * run
		P(steps, "Step", Vector3.new(16, top + 1, run + 0.1), frame(0, front + run / 2, (top - 1) / 2 - T), M.Slate, C.Cap)
	end

	-- zones (invisible discs): where dragons appear and walkers roam (Shared/RoostZones); CenterZone / WaterZone keep
	-- fliers and walkers off the centerpiece and the water
	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = plot
	for name, z in { NestZone = Slots.Nest, MeadowZone = Slots.Meadow, CenterZone = Slots.Center, WaterZone = Slots.Water } do
		disc(zones, name, at(z.X, z.Y, 0.1), z.R, 0.2, M.SmoothPlastic, Color3.new(1, 1, 1), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	end

	-- perches for flying dragons (RoostAnimationController): the pad tops (Size 2 = Elder pads, Size 1 = Dragon pads);
	-- each faces the sanctuary center
	local perches = Instance.new("Folder")
	perches.Name = "Perches"
	perches.Parent = plot
	local function perch(pos: Vector3, size: number)
		local p = P(perches, "Perch", Vector3.new(2, 0.4, 2), CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)), M.SmoothPlastic, Color3.new(1, 1, 1), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
		p:SetAttribute("Size", size)
	end
	for _, pl in Slots.ElderPerches do
		perch(at(pl[1], pl[2], pl[3]), 2)
	end
	for _, pl in Slots.DragonPerches do
		perch(at(pl[1], pl[2], pl[3]), 1)
	end

	-- plain stand-ins for the look kits: perch spires, basking rocks, a pond and three straw nests
	local art = model(sf, "Placeholder_Plain")
	local function spire(pl: { number }, r: number, name: string)
		local p = P(art, name, Vector3.new(pl[3], r * 2, r * 2), CFrame.new(at(pl[1], pl[2], pl[3] / 2)) * CFrame.Angles(0, 0, math.pi / 2), M.Slate, C.StoneDark)
		p.Shape = Enum.PartType.Cylinder
		disc(art, name .. "Cap", at(pl[1], pl[2], pl[3] + 0.2), r - 0.3, 0.4, M.Grass, Color3.fromRGB(96, 140, 78))
	end
	for _, pl in Slots.ElderPerches do
		spire(pl, V.PillarR, "Placeholder_PerchElder")
	end
	for _, pl in Slots.DragonPerches do
		spire(pl, 7, "Placeholder_PerchDragon")
	end
	for _, b in Slots.Bask do
		disc(art, "Placeholder_Bask", at(b[1], b[2], 0.8), 9, 1.6, M.Slate, C.Cap)
	end
	local w = Slots.Water
	disc(art, "Placeholder_Pond", at(w.X, w.Y, 0.25), w.R, 0.5, M.Glass, C.Water, { Transparency = 0.25, CanCollide = false })
	local nz = Slots.Nest
	for _, off in { { 0, 0 }, { 10, -9 }, { -10, -8 } } do
		local c = at(nz.X + off[1], nz.Y + off[2], 0)
		local nm = model(art, "Placeholder_Nest")
		disc(nm, "Straw", c + Vector3.new(0, 0.9, 0), 5.5, 1.8, M.Grass, C.Straw)
		disc(nm, "Hollow", c + Vector3.new(0, 1.1, 0), 3.8, 1.8, M.Grass, C.StrawDark)
	end
	-- the look kits (SanctuaryLooks module) bring their own walls, gates, perches and nests
	if not B.PlainArt then
		for _, n in { "Placeholder_RimWall", "Placeholder_SanctuaryGate", "Placeholder_Plain" } do
			sf[n]:Destroy()
		end
	end
end

function B.BuildSanctuaries()
	for _, plot in SM.Pens:GetChildren() do
		if plot:IsA("Model") and B.SanctuaryOrder[plot.Name] then
			B.BuildSanctuary(plot)
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Upgrade stands: two shrines in the altar's style (blue slate, gold, star glass) on each sanctuary forecourt, built
-- around the "UpgradeSlots" / "UpgradeIncome" parts (kept, invisible: they carry the owner's prompts and the server
-- measures the buy range from them). Art goes in the plot's "UpgradeStandArt" folder:
--   Slots:  a column with a floating star egg over a gold cup, circled by star crystals ("Orbit"); 8 gems on the
--           capital ("Pip1".."Pip8": one per roost slot owned)
--   Income: a column with a gold bowl heaped with coins and a floating star coin; 5 jade gems ("Pip1".."Pip5": 5
--           income levels each)
-- The "Floater" (egg / star coin) bobs and spins, the orbit turns and the gems light up on the client
-- (UpgradeStandController); nothing here is animated.

B.StandColors = {
	SlateLow = Color3.fromRGB(78, 84, 116),
	Slate = Color3.fromRGB(116, 122, 154),
	Egg = Color3.fromRGB(150, 205, 255),
	EggCore = Color3.fromRGB(205, 235, 255),
	Pip = Color3.fromRGB(58, 64, 92), -- unlit gem (lit colors: UpgradeStandController)
	Jade = Color3.fromRGB(96, 214, 150),
	Coin = Color3.fromRGB(196, 132, 50), -- deeper amber, so its gold stars stand out
}
B.StandScale = 2.4 -- the stand is modelled ~7.5 studs tall, then scaled (bigger for the 150-stud sanctuaries)

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

-- Height of the terrain surface under (x, z), or fallback.
local function surfaceY(x: number, z: number, fallback: number): number
	local hit = workspace:Raycast(Vector3.new(x, fallback + 60, z), Vector3.new(0, -140, 0), terrainOnly)
	return if hit then hit.Position.Y else fallback
end
B.SurfaceY = surfaceY

-- Part with a sphere mesh (an ellipsoid of its size).
local function ellipsoid(parent: Instance, name: string, size: Vector3, cf: CFrame, mat: Enum.Material, color: Color3, extra: { [string]: any }?): Part
	local p = P(parent, name, size, cf, mat, color, extra)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function buildStand(parent: Instance, anchor: BasePart, kind: string, out: Vector3): Model
	local S = B.StandColors
	local function softGlow(p: BasePart) -- gold glows at night softly (night glow toned down)
		glow(p, B.TierColors.TrimGlow)
	end
	local m = model(parent, kind .. "Stand")
	-- on the real forecourt ground (it is not at the terrace height everywhere), sunk a hair so it never floats
	local ground = surfaceY(anchor.Position.X, anchor.Position.Z, anchor.Position.Y - anchor.Size.Y / 2)
	local base = Vector3.new(anchor.Position.X, ground - 0.05, anchor.Position.Z)
	anchor.CFrame = anchor.CFrame.Rotation + Vector3.new(anchor.Position.X, ground + anchor.Size.Y / 2, anchor.Position.Z)
	local face = CFrame.lookAt(base, base + out) -- -Z faces the road
	local function y(h: number): Vector3
		return base + Vector3.new(0, h, 0)
	end
	local noCollide = { CanCollide = false }

	-- stepped plinth with gold trim, column with gold bands and a star, capital
	disc(m, "Plinth", y(0.3), 2.3, 0.6, M.Slate, S.SlateLow)
	softGlow(disc(m, "PlinthTrim", y(0.64), 2.36, 0.12, M.Foil, C.Gold, noCollide))
	disc(m, "Step", y(0.95), 1.8, 0.6, M.Slate, S.Slate)
	local shaft = P(m, "Column", Vector3.new(2.9, 1.7, 1.7), CFrame.new(y(2.7)) * CFrame.Angles(0, 0, math.pi / 2), M.Slate, S.Slate)
	shaft.Shape = Enum.PartType.Cylinder
	for _, h in { 1.55, 3.9 } do
		softGlow(disc(m, "GoldBand", y(h), 0.94, 0.2, M.Foil, C.Gold, noCollide))
	end
	disc(m, "Capital", y(4.35), 1.45, 0.45, M.Slate, S.SlateLow)
	softGlow(disc(m, "CapitalTrim", y(4.6), 1.5, 0.1, M.Foil, C.Gold, noCollide))
	star(m, face * CFrame.new(0, 2.75, -0.87), 1.1, B.TierColors.TrimGlow)

	local floater = model(m, "Floater")
	if kind == "Slots" then
		disc(m, "Cup", y(4.78), 1.15, 0.3, M.Foil, C.Gold, noCollide)
		ellipsoid(floater, "Egg", Vector3.new(1.55, 2.1, 1.55), CFrame.new(y(6.25)), M.Glass, S.Egg, { CanCollide = false, Transparency = 0.15, CastShadow = false })
		P(floater, "EggCore", Vector3.new(0.85, 0.85, 0.85), CFrame.new(y(6.2)), M.Neon, S.EggCore, { CanCollide = false, CastShadow = false, Shape = Enum.PartType.Ball })
		star(floater, CFrame.lookAt(y(6.3), y(6.3) + out) * CFrame.new(0, 0, -0.78), 0.55, B.TierColors.TrimGlow)
		local orbit = model(m, "Orbit")
		for i = 1, 6 do
			local a = rad(i * 60)
			local pos = y(6.25 + sin(a * 2) * 0.25) + Vector3.new(sin(a), 0, cos(a)) * 1.9
			P(orbit, "Crystal", Vector3.new(0.3, 0.75, 0.3), CFrame.new(pos) * CFrame.Angles(0, a, rad(20)), M.Glass, S.Egg, { CanCollide = false, CastShadow = false })
		end
		for i = 1, 8 do
			local a = rad((i - 1) * 45 + 22.5)
			local pos = y(4.62) + Vector3.new(sin(a), 0, cos(a)) * 1.32
			P(m, "Pip" .. i, Vector3.new(0.28, 0.28, 0.28), CFrame.new(pos) * CFrame.Angles(rad(45), a, rad(45)), M.Glass, S.Pip, noCollide)
		end
	else
		disc(m, "Bowl", y(4.85), 1.4, 0.5, M.Foil, C.Gold, noCollide)
		disc(m, "BowlRim", y(5.12), 1.48, 0.12, M.Foil, C.Gold, noCollide)
		ellipsoid(m, "Hoard", Vector3.new(2.5, 1.1, 2.5), CFrame.new(y(5.12)), M.Metal, C.GoldGlow, noCollide)
		local rng = Random.new(77)
		for _ = 1, 9 do
			local a, r = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(0.1, 1.0)
			local pos = y(5.2 + (1 - r) * 0.45) + Vector3.new(sin(a) * r, 0, cos(a) * r)
			local tilt = CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 6.3), math.pi / 2 + rng:NextNumber(-0.5, 0.5))
			local coin = P(m, "Coin", Vector3.new(0.08, 0.5, 0.5), CFrame.new(pos) * tilt, M.Foil, C.Gold, noCollide)
			coin.Shape = Enum.PartType.Cylinder
		end
		for i = 1, 2 do
			local a = rad(i * 150)
			P(m, "Gem", Vector3.new(0.35, 0.35, 0.35), CFrame.new(y(5.45) + Vector3.new(sin(a), 0, cos(a)) * 0.55) * CFrame.Angles(rad(45), a, rad(45)), M.Glass, S.Jade, noCollide)
		end
		local coinFace = CFrame.lookAt(y(6.9), y(6.9) + out)
		local big = P(floater, "StarCoin", Vector3.new(0.22, 1.9, 1.9), coinFace * CFrame.Angles(0, math.pi / 2, 0), M.Foil, S.Coin, { CanCollide = false, CastShadow = false })
		big.Shape = Enum.PartType.Cylinder -- no NightGlow: a whole neon coin blooms too much (the client adds a light)
		for _, side in { -1, 1 } do
			star(floater, coinFace * CFrame.new(0, 0, side * -0.13), 0.95, B.TierColors.TrimGlow)
		end
		for i = 1, 5 do
			local a = rad((i - 1) * 72 + 36)
			local pos = y(4.62) + Vector3.new(sin(a), 0, cos(a)) * 1.42
			P(m, "Pip" .. i, Vector3.new(0.32, 0.32, 0.32), CFrame.new(pos) * CFrame.Angles(rad(45), a, rad(45)), M.Glass, S.Pip, noCollide)
		end
	end
	m.PrimaryPart = m:FindFirstChild("Plinth") :: BasePart
	m.WorldPivot = CFrame.new(base)
	m:ScaleTo(B.StandScale)
	return m
end

function B.BuildUpgradeStands()
	for _, plot in SM.Pens:GetChildren() do
		local center = if plot:IsA("Model") then plot:GetAttribute("RoamCenter") else nil
		if typeof(center) == "Vector3" then
			local f = folder(plot, "UpgradeStandArt", true)
			for _, kind in { "Slots", "Income" } do
				local anchor = plot:FindFirstChild("Upgrade" .. kind) :: BasePart?
				local cap = plot:FindFirstChild("Upgrade" .. kind .. "Glow") :: BasePart?
				if anchor then
					local out = Vector3.new(anchor.Position.X - center.X, 0, anchor.Position.Z - center.Z).Unit
					buildStand(f, anchor, kind, out)
					anchor.Transparency, anchor.CanCollide = 1, false
				end
				if cap then
					cap.Transparency, cap.CanCollide = 1, false
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Sanctuary tiers: extra art a sanctuary gains as its owner upgrades the roost (SanctuaryTierController shows the
-- tiers reached; the tier comes from the owner's slots and income level, Config/WorldUI.SanctuaryTiers). Built per
-- sanctuary, in world position, into ReplicatedStorage.Assets.SanctuaryTiers.<PlotName>.Tier1..Tier5 (not in the
-- Workspace: each client clones only the tiers reached, so locked tiers cost nothing). Each tier adds to the ones below:
--   1 Gilded:    gold trim along the rim wall, star banners on the gate pillars
--   2 Runed:     a glowing rune circle on the meadow floor, fire braziers flanking the gate
--   3 Crystal:   star crystals at the foot of the rock pillars, light motes drifting over the pen
--   4 Ascendant: glowing rune strips up the rock pillars, an aurora over the pen (night only, set by the client)
--   5 Legendary: a beam of starlight into the sky from the sanctuary, golden dragon statues on the gate pillars
-- Lights ("TierLight"), the aurora ("Aurora" beams) and the motes ("Motes" emitter) are switched by the client.

B.TierColors = {
	Rune = Color3.fromRGB(86, 150, 210), -- softer than before (night glow toned down)
	TrimGlow = Color3.fromRGB(104, 80, 38), -- night glow of the gold trim, banner stars and braziers
	Crystal = Color3.fromRGB(130, 190, 255),
	Fire = Color3.fromRGB(255, 170, 70),
	Beam = Color3.fromRGB(255, 226, 150),
	AuroraA = Color3.fromRGB(90, 230, 200),
	AuroraB = Color3.fromRGB(170, 120, 255),
}
B.TierStatueSpecies = "Solflare" -- the golden guardian statues copy this Elder model

local function noCollide(extra: { [string]: any }?): { [string]: any }
	local t = { CanCollide = false, CanQuery = false, CanTouch = false }
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end

function B.BuildSanctuaryTiers()
	local assets = game:GetService("ReplicatedStorage"):WaitForChild("Assets")
	local root = folder(assets, "SanctuaryTiers", true)
	local TC = B.TierColors
	for plotName, id in B.SanctuaryOrder do
		local s
		for _, cand in V.Sanct do
			if cand.Name == id then
				s = cand
			end
		end
		local T = s.T
		local center = Vector3.new(s.X, T, s.Z)
		local fwd = Vector3.new(s.AX, 0, s.AZ)
		local right = Vector3.new(-fwd.Z, 0, fwd.X)
		local face = CFrame.lookAt(center, center + fwd)
		local function at(forward: number, side: number, y: number): Vector3
			return center + fwd * forward + right * side + Vector3.new(0, y, 0)
		end
		local function frame(forward: number, side: number, y: number): CFrame
			return face.Rotation + at(forward, side, y)
		end
		-- a spot on the forecourt, on the real ground
		local function grounded(forward: number, side: number): Vector3
			local p = at(forward, side, 0)
			return Vector3.new(p.X, surfaceY(p.X, p.Z, T), p.Z)
		end
		local plotFolder = folder(root, plotName)
		local tiers = {}
		for i = 1, 5 do
			tiers[i] = model(plotFolder, "Tier" .. i)
		end

		-- 1 Gilded: gold trim on the rim wall (same segments as BuildSanctuary), banners on the gate pillars
		for deg = 0, 348, 12 do
			local a = rad(deg + 6)
			if math.abs(math.deg(math.atan2(sin(a), cos(a)))) > 13 then
				local p = at(cos(a) * Slots.Rim, sin(a) * Slots.Rim, 6.1)
				local trim = P(tiers[1], "GoldTrim", Vector3.new(2 * Slots.Rim * sin(rad(6)) + 1, 0.3, 3.4), CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z)), M.Foil, C.Gold, noCollide())
				glow(trim, TC.TrimGlow)
			end
		end
		for _, sd in { -Slots.GateHalf, Slots.GateHalf } do
			local bf = frame(Slots.Gate + 2.6, sd, 19)
			P(tiers[1], "Banner", Vector3.new(4.4, 9, 0.2), bf, M.Fabric, C.Navy, noCollide())
			P(tiers[1], "BannerRod", Vector3.new(5.2, 0.4, 0.4), bf * CFrame.new(0, 4.6, -0.05), M.Foil, C.Gold, noCollide())
			star(tiers[1], bf * CFrame.new(0, 0.6, -0.15), 2.6, TC.TrimGlow) -- -Z = the banner's front (toward the road)
		end

		-- 2 Runed: a double rune circle on the meadow floor, braziers flanking the gate
		local mz = Slots.Meadow
		local mcx, mcz = V.ToWorld(s, mz.X, mz.Y)
		local mc = Vector3.new(mcx, T, mcz)
		local runeY = surfaceY(mc.X, mc.Z, T) + 0.25
		for _, ring in { { R = mz.R, N = 24, W = 1.6 }, { R = mz.R - 4.5, N = 18, W = 1 } } do
			for k = 0, ring.N - 1 do
				local a = (k + 0.5) / ring.N * 2 * math.pi
				local p = Vector3.new(mc.X + cos(a) * ring.R, runeY, mc.Z + sin(a) * ring.R)
				local len = 2 * ring.R * sin(math.pi / ring.N) * 0.92
				P(tiers[2], "RuneRing", Vector3.new(ring.W, 0.12, len), CFrame.lookAt(p, Vector3.new(mc.X, runeY, mc.Z)) * CFrame.Angles(0, math.pi / 2, 0), M.Neon, TC.Rune, noCollide({ Transparency = 0.62, CastShadow = false }))
			end
		end
		for k = 0, 5 do
			local a = k / 6 * 2 * math.pi
			local p = Vector3.new(mc.X + cos(a) * (mz.R - 1.75), runeY, mc.Z + sin(a) * (mz.R - 1.75))
			P(tiers[2], "RuneGlyph", Vector3.new(1.3, 0.14, 1.3), CFrame.new(p) * CFrame.Angles(0, a + math.pi / 4, 0), M.Neon, TC.Rune, noCollide({ Transparency = 0.5, CastShadow = false }))
		end
		for _, sd in { -20, 20 } do
			local g = grounded(79, sd)
			local post = P(tiers[2], "BrazierPost", Vector3.new(3, 1.3, 1.3), CFrame.new(g + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), M.Slate, C.Cap, noCollide({ CanCollide = true }))
			post.Shape = Enum.PartType.Cylinder
			disc(tiers[2], "BrazierBase", g + Vector3.new(0, 0.2, 0), 1.3, 0.4, M.Slate, C.StoneDark, noCollide({ CanCollide = true }))
			local bowl = disc(tiers[2], "BrazierBowl", g + Vector3.new(0, 3.2, 0), 1.5, 0.5, M.Foil, C.Gold, noCollide())
			glow(bowl, TC.TrimGlow)
			local fire = Instance.new("ParticleEmitter")
			fire.Name = "Fire"
			fire.Texture = "rbxasset://textures/particles/fire_main.dds"
			fire.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), TC.Fire)
			fire.LightEmission = 1
			fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0.2) })
			fire.Transparency = NumberSequence.new(0.1, 1)
			fire.Lifetime = NumberRange.new(0.6, 1)
			fire.Speed = NumberRange.new(2, 4)
			fire.SpreadAngle = Vector2.new(12, 12)
			fire.Rate = 22
			fire.EmissionDirection = Enum.NormalId.Right -- the bowl is a cylinder lying on its side: +X is up
			fire.Parent = bowl
			local light = Instance.new("PointLight")
			light.Name = "TierLight"
			light.Color = TC.Fire
			light.Range = 14
			light.Brightness = 1.4
			light.Shadows = false
			light.Parent = bowl
		end

		-- 3 Crystal: crystals at the foot of each rock pillar (on the side facing the pen), light motes over the pen
		for _, pl in s.PillarList do
			local toCenter = Vector3.new(center.X - pl.X, 0, center.Z - pl.Z).Unit
			-- clear of the pillar (its radius wobbles up to +30%); the ground ray starts low so it can't land on the top
			local x, z = pl.X + toCenter.X * (V.PillarR * 1.3 + 1.5), pl.Z + toCenter.Z * (V.PillarR * 1.3 + 1.5)
			local m = KIT.AI_Ench_MagicCrystals:Clone()
			m:ScaleTo(2.2)
			m:PivotTo(CFrame.new(x, surfaceY(x, z, T - 56) - 0.3, z) * CFrame.Angles(0, math.atan2(toCenter.X, toCenter.Z), 0))
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
					if d.Name == "Crystals" then
						d.Material = M.Glass
						d.Color = TC.Crystal
						d.Transparency = 0.05
						glow(d, TC.Crystal)
					end
				end
			end
			m.Name = "PillarCrystals"
			m.Parent = tiers[3]
		end
		local motes = P(tiers[3], "MoteVolume", Vector3.new(140, 30, 140), CFrame.new(center + Vector3.new(0, 20, 0)), M.SmoothPlastic, Color3.new(1, 1, 1), noCollide({ Transparency = 1, CastShadow = false }))
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Motes"
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(TC.Crystal, TC.Beam)
		emitter.LightEmission = 1
		emitter.LightInfluence = 0
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0) })
		emitter.Lifetime = NumberRange.new(4, 7)
		emitter.Speed = NumberRange.new(0.3, 1)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rate = 24
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		emitter.Parent = motes

		-- 4 Ascendant: a rune strip up each rock pillar (on its surface facing the pen), the aurora
		for _, pl in s.PillarList do
			local height = pl.Top - T
			local mid = T + height * 0.5
			local from = Vector3.new(center.X, mid, center.Z)
			local target = Vector3.new(pl.X, mid, pl.Z)
			local hit = workspace:Raycast(from, (target - from), terrainOnly)
			local toCenter = (from - target).Unit
			local surface = if hit then hit.Position else target + toCenter * V.PillarR
			local strip = CFrame.lookAt(surface + toCenter * 0.35, surface + toCenter * 2)
			P(tiers[4], "PillarRunes", Vector3.new(1.8, height * 0.7, 0.2), strip, M.Neon, TC.Rune, noCollide({ Transparency = 0.5, CastShadow = false }))
			for _, dy in { height * 0.42, -height * 0.42 } do
				P(tiers[4], "PillarGlyph", Vector3.new(2, 2, 0.2), strip * CFrame.new(0, dy, 0) * CFrame.Angles(0, 0, math.pi / 4), M.Neon, TC.Rune, noCollide({ Transparency = 0.5, CastShadow = false }))
			end
		end
		local sky = P(tiers[4], "AuroraAnchor", Vector3.new(1, 1, 1), CFrame.new(center + Vector3.new(0, 75, 0)), M.SmoothPlastic, Color3.new(1, 1, 1), noCollide({ Transparency = 1, CastShadow = false }))
		-- three thin, curving ribbons (a beam's side edges are hard, so wide ones read as a glass panel)
		for i, spec in { { Side = -24, Width = 14, Curve = 40 }, { Side = 0, Width = 10, Curve = -34 }, { Side = 24, Width = 11, Curve = 28 } } do
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Parent, a1.Parent = sky, sky -- parent first: WorldPosition is relative to the parent
			a0.WorldPosition = center + right * -110 + fwd * spec.Side + Vector3.new(0, 75 + i * 8, 0)
			a1.WorldPosition = center + right * 110 + fwd * spec.Side + Vector3.new(0, 75 + i * 8, 0)
			local beam = Instance.new("Beam")
			beam.Name = "Aurora"
			beam.Attachment0, beam.Attachment1 = a0, a1
			beam.Width0, beam.Width1 = spec.Width, spec.Width * 0.7
			beam.CurveSize0, beam.CurveSize1 = spec.Curve, -spec.Curve
			beam.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, TC.AuroraA), ColorSequenceKeypoint.new(0.5, TC.AuroraB), ColorSequenceKeypoint.new(1, TC.AuroraA) })
			beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.72), NumberSequenceKeypoint.new(0.7, 0.72), NumberSequenceKeypoint.new(1, 1) })
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Segments = 20
			beam.Parent = sky
		end

		-- 5 Legendary: a beam of starlight from the sanctuary into the sky, golden dragon statues on the gate
		local beamBase = P(tiers[5], "SkyBeamAnchor", Vector3.new(1, 1, 1), CFrame.new(center + Vector3.new(0, 1, 0)), M.SmoothPlastic, Color3.new(1, 1, 1), noCollide({ Transparency = 1, CastShadow = false }))
		local b0, b1 = Instance.new("Attachment"), Instance.new("Attachment")
		b0.Parent, b1.Parent = beamBase, beamBase
		b0.WorldPosition = center + Vector3.new(0, 1, 0)
		b1.WorldPosition = center + Vector3.new(0, 420, 0)
		for _, spec in { { Width = 5, T0 = 0.7 }, { Width = 1.8, T0 = 0.45 } } do
			local beam = Instance.new("Beam")
			beam.Name = "SkyBeam"
			beam.Attachment0, beam.Attachment1 = b0, b1
			beam.Width0, beam.Width1 = spec.Width, spec.Width * 2.2
			beam.FaceCamera = true
			beam.Color = ColorSequence.new(Color3.new(1, 1, 1), TC.Beam)
			beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.03, spec.T0), NumberSequenceKeypoint.new(0.6, 0.78), NumberSequenceKeypoint.new(1, 1) })
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Parent = beamBase
		end
		local template = assets.Dragons:FindFirstChild(B.TierStatueSpecies)
		template = template and template:FindFirstChild("Elder")
		-- golden guardians standing on the gate's lintel over each pillar, facing the road
		for _, sd in { -Slots.GateHalf, Slots.GateHalf } do
			if template then
				local statue = template:Clone()
				statue.Name = "GoldenGuardian"
				for _, d in statue:GetDescendants() do
					if d:IsA("SurfaceAppearance") or d:IsA("LuaSourceContainer") then
						d:Destroy()
					elseif d:IsA("BasePart") then
						if d:IsA("MeshPart") then
							d.TextureID = "" -- plain gold, no painted skin
						end
						d.Material = M.Foil
						d.Color = C.Gold
						d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
						d.Anchored = true
					end
				end
				local _, size = statue:GetBoundingBox()
				statue:ScaleTo(statue:GetScale() * 11 / math.max(size.X, size.Z))
				local top = at(Slots.Gate, sd, Slots.GateHeight + 0.4) -- the lintel's top (it covers the pillar capitals)
				statue:PivotTo(CFrame.lookAt(top, top + fwd))
				statue.Parent = tiers[5]
			end
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Bounds: invisible walls a little way up the foothills all around the valley

function B.BuildBounds()
	local f = folder(SM, "Bounds", true)
	local step = 6
	for b = -180, 180 - step, step do
		local th = b + step / 2
		local r = rad(th)
		local R = V.EdgeAt(th) + 30 -- 30 studs up the foothills from where the mountains start
		local w = 2 * R * sin(rad(step / 2)) + 4
		P(f, "Wall", Vector3.new(w, 320, 4), CFrame.lookAt(Vector3.new(R * sin(r), 140, -R * cos(r)), Vector3.new(0, 140, 0)), M.SmoothPlastic, Color3.new(1, 1, 1), { Transparency = 1, CanQuery = false, CanTouch = false, CastShadow = false })
	end
end

---------------------------------------------------------------------------------------------------------------
-- Tiles: real stone tiles (parts) laid flush on the flagstone terrain in two places: a two-row ring around the
-- plaza's outer step (gap where the grand bridge lands) and a two-row ring around the market obelisk. Granite
-- (no material override), alternating warm cream stone shades (matching the cream flagstone roads, Valley_RoadA),
-- outer row offset half a tile like laid paving; small gold inlays at the compass points (NightGlow).

function B.BuildTiles()
	local f = folder(SM, "Tiles", true)
	local rng = Random.new(2718)
	local shades = { Color3.fromRGB(222, 204, 170), Color3.fromRGB(202, 186, 154), Color3.fromRGB(214, 200, 176) }
	local groundParams = RaycastParams.new() -- tiles only where their outer edge is on solid ground (not the river bank)
	groundParams.FilterType = Enum.RaycastFilterType.Include
	groundParams.FilterDescendantsInstances = { workspace.Terrain }
	local function ring(parent: Instance, center: Vector3, r0: number, r1: number, count: number, offset: number, skip: ((Vector3) -> boolean)?)
		local mid = (r0 + r1) / 2
		local width = 2 * mid * sin(math.pi / count) * 0.94
		for i = 0, count - 1 do
			local angle = (i + offset) / count * 2 * math.pi
			local at = center + Vector3.new(sin(angle) * mid, 0, cos(angle) * mid)
			local edge = center + Vector3.new(sin(angle) * (r1 + 0.5), 0, cos(angle) * (r1 + 0.5))
			local hit = workspace:Raycast(edge + Vector3.new(0, 20, 0), Vector3.new(0, -40, 0), groundParams)
			local onGround = hit ~= nil and hit.Material ~= Enum.Material.Water and hit.Position.Y > center.Y - 0.3
			if onGround and (skip == nil or not skip(at)) then
				local shade = shades[(i % #shades) + 1]:Lerp(Color3.fromRGB(190, 178, 156), rng:NextNumber(0, 0.25))
				P(parent, "Tile", Vector3.new(width, 0.5, (r1 - r0) * 0.92), CFrame.lookAt(at, Vector3.new(center.X, at.Y, center.Z)), M.Granite, shade, { CastShadow = false })
			end
		end
	end
	local function inlays(parent: Instance, center: Vector3, r: number)
		for i = 0, 3 do
			local angle = i * math.pi / 2
			local at = center + Vector3.new(sin(angle) * r, 0.05, cos(angle) * r)
			local inlay = P(parent, "GoldInlay", Vector3.new(1.6, 0.5, 1.6), CFrame.new(at) * CFrame.Angles(0, math.pi / 4 + angle, 0), M.Metal, C.GoldGlow, { CastShadow = false })
			CollectionService:AddTag(inlay, "NightGlow")
		end
	end

	-- Plaza ring on the flagstone between the outer step (r48) and the river bank; the grand bridge lands on the south.
	local plaza = folder(f, "PlazaRing")
	local centre = Vector3.new(0, 0, 0)
	local function onBridge(at: Vector3): boolean
		return at.Z > 0 and math.abs(at.X) < 8
	end
	ring(plaza, centre, 48.4, 52.2, 40, 0, onBridge)
	ring(plaza, centre, 52.2, 56, 40, 0.5, onBridge)
	inlays(plaza, centre, 52.2)
	for i = 0, 3 do -- diagonal inlays too: 8 around the plaza
		local angle = math.pi / 4 + i * math.pi / 2
		local at = Vector3.new(sin(angle) * 52.2, 0.05, cos(angle) * 52.2)
		CollectionService:AddTag(P(plaza, "GoldInlay", Vector3.new(1.6, 0.5, 1.6), CFrame.new(at) * CFrame.Angles(0, angle, 0), M.Metal, C.GoldGlow, { CastShadow = false }), "NightGlow")
	end

	-- Market square: around the obelisk's stepped base (18 wide).
	local market = folder(f, "MarketSquare")
	local obelisk = Vector3.new(0, 0, 112)
	ring(market, obelisk, 10, 15, 20, 0, nil)
	ring(market, obelisk, 15, 20, 26, 0.5, nil)
	inlays(market, obelisk, 15)
end

---------------------------------------------------------------------------------------------------------------
-- Travel points: invisible markers where the travel buttons land a player (TravelService, Config/Travel), standing on
-- the ground and facing what they came for. One per sanctuary (named after its plot, on the forecourt facing the
-- gate; "Home"), plus Altar (plaza, facing the altar; Home before the player has a sanctuary), Portals (the front of
-- the portal terrace, facing the gates) and Market (the valley mouth where new players spawn, facing the market).

function B.BuildTravelPoints()
	local f = folder(SM, "TravelPoints", true)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { f, SM:FindFirstChild("Nature") :: Instance, SM:FindFirstChild("Bounds") :: Instance }
	local function point(name: string, x: number, z: number, lookX: number, lookZ: number)
		local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), params)
		local y = if hit then hit.Position.Y else ground(x, z)
		local at = Vector3.new(x, y + 0.5, z)
		P(f, name, Vector3.new(2, 1, 2), CFrame.lookAt(at, Vector3.new(lookX, at.Y, lookZ)), M.SmoothPlastic, Color3.new(1, 1, 1), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	end
	point("Altar", 0, 34, 0, 0)
	point("Portals", 0, -138, 0, -200)
	point("Market", 0, 164, 0, 100)
	for _, plot in SM.Pens:GetChildren() do
		local center = plot:GetAttribute("RoamCenter")
		if plot:IsA("Model") and typeof(center) == "Vector3" then
			local out = Vector3.new(-center.X, 0, -center.Z).Unit -- toward the altar
			local at = center + out * 95 -- forecourt, in front of the upgrade stands
			point(plot.Name, at.X, at.Z, center.X, center.Z)
		end
	end
end

return B
