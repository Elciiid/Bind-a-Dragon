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
local function star(parent: Instance, cf: CFrame, s: number)
	for i = 0, 1 do
		local p = P(parent, "GoldStar", Vector3.new(s, s, 0.2), cf * CFrame.Angles(0, 0, rad(45 * i)), M.Foil, C.Gold, { CanCollide = false, CastShadow = false })
		glow(p)
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
B.RoamRadius = 40
B.NestZone = { Forward = 16, Side = -22, Radius = 13 } -- front left (seen from the gate, facing in: right)
B.MeadowZone = { Forward = -4, Side = 8, Radius = 20 }

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
	local right = Vector3.new(-fwd.Z, 0, fwd.X)
	local face = CFrame.lookAt(center, center + fwd) -- local frame: -Z = forward
	local function at(forward: number, side: number, y: number): Vector3
		return center + fwd * forward + right * side + Vector3.new(0, y, 0)
	end
	local function frame(forward: number, side: number, y: number): CFrame
		return face.Rotation + at(forward, side, y)
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
	base.Size = Vector3.new(1, 96, 96)
	base.CFrame = CFrame.new(s.X, T - 0.5, s.Z) * CFrame.Angles(0, 0, math.pi / 2)
	base.Transparency = 1
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	plot.PrimaryPart = base
	plot:SetAttribute("RoamCenter", center)
	plot:SetAttribute("RoamRadius", B.RoamRadius)

	-- rim wall with a gap for the gate
	local wall = model(sf, "RimWall")
	for deg = 0, 348, 12 do
		local a = rad(deg + 6)
		if math.abs(math.deg(math.atan2(sin(a), cos(a)))) > 12 then
			local fw, sd = cos(a) * 49, sin(a) * 49
			local p = at(fw, sd, 1.1 - 0.6)
			P(wall, "Wall", Vector3.new(2 * 49 * sin(rad(6)) + 0.9, 2.6, 2), CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z)), M.Cobblestone, C.Stone)
		end
	end

	-- the grand binder gate, the owner sign under its lintel
	local gate = model(sf, "Placeholder_SanctuaryGate")
	for _, sd in { -9.5, 9.5 } do
		P(gate, "Plinth", Vector3.new(5, 2, 5), frame(48.5, sd, 1), M.Slate, C.Cap)
		P(gate, "Pillar", Vector3.new(3.6, 18, 3.6), frame(48.5, sd, 11), M.Cobblestone, C.Stone)
		P(gate, "Capital", Vector3.new(4.6, 1.2, 4.6), frame(48.5, sd, 20.6), M.Slate, C.Cap)
		local rune = P(gate, "Runes", Vector3.new(0.5, 11, 0.12), frame(48.5 + 1.86, sd, 10.5), M.Foil, C.Gold, { CanCollide = false })
		glow(rune)
	end
	P(gate, "Lintel", Vector3.new(24, 3, 3.8), frame(48.5, 0, 22.7), M.Slate, C.StoneDark)
	star(gate, frame(48.5 + 1.95, 0, 22.7), 3)
	local sign = plot:FindFirstChild("Sign") :: BasePart
	sign.CFrame = frame(48.5, 0, 14.2)
	P(gate, "SignChain", Vector3.new(0.25, 6.5, 0.25), frame(48.5, -4.5, 18.4), M.Metal, C.Iron, { CanCollide = false })
	P(gate, "SignChain", Vector3.new(0.25, 6.5, 0.25), frame(48.5, 4.5, 18.4), M.Metal, C.Iron, { CanCollide = false })

	-- upgrade stands flanking the forecourt path, lanterns at its front corners
	for _, pair in { { "UpgradeSlots", -7 }, { "UpgradeIncome", 7 } } do
		local stand = plot:FindFirstChild(pair[1]) :: BasePart
		local cap = plot:FindFirstChild(pair[1] .. "Glow") :: BasePart
		stand.CFrame = frame(56, pair[2], stand.Size.Y / 2)
		cap.CFrame = frame(56, pair[2], stand.Size.Y + cap.Size.Y / 2)
	end
	lantern(sf, at(63, -12, 0), 0)
	lantern(sf, at(63, 12, 0), 0)

	-- steps from the forecourt down to the road: solid blocks from below the ground (y -1) up to each tread
	-- (frame() heights are relative to the forecourt at T, so convert the absolute heights)
	local n = math.max(2, math.ceil((T - 0.8) / 1.5)) -- rises of at most 1.5 studs (walkable without jumping)
	local rise, run = (T - 0.8) / n, 2.2
	local steps = model(sf, "Steps")
	for k = 1, n - 1 do
		local top = T - k * rise
		local front = 66 + (k - 1) * run
		P(steps, "Step", Vector3.new(14, top + 1, run + 0.1), frame(front + run / 2, 0, (top - 1) / 2 - T), M.Slate, C.Cap)
	end

	-- zones (invisible discs): where dragons appear and walkers roam (Shared/RoostZones)
	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = plot
	for name, z in { NestZone = B.NestZone, MeadowZone = B.MeadowZone } do
		disc(zones, name, at(z.Forward, z.Side, 0.1), z.Radius, 0.2, M.SmoothPlastic, Color3.new(1, 1, 1), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	end

	-- perches for flying dragons (RoostAnimationController): the flat tops of the four rock pillars (Size 2, fit Elders)
	-- and two spots on the back cliff's ledge (Size 1); each faces the sanctuary center
	local perches = Instance.new("Folder")
	perches.Name = "Perches"
	perches.Parent = plot
	local function perch(pos: Vector3, size: number)
		local p = P(perches, "Perch", Vector3.new(2, 0.4, 2), CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)), M.SmoothPlastic, Color3.new(1, 1, 1), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
		p:SetAttribute("Size", size)
	end
	for _, pl in s.PillarList do
		perch(Vector3.new(pl.X, pl.Top, pl.Z), 2)
	end
	for _, deg in { -36, 36 } do
		local a = rad(deg)
		local bx, bz = -fwd.X, -fwd.Z
		local dx, dz = bx * cos(a) - bz * sin(a), bx * sin(a) + bz * cos(a)
		local x, z = s.X + dx * 55, s.Z + dz * 55
		perch(Vector3.new(x, ground(x, z), z), 1)
	end

	-- nesting ground: three straw nests, hay, a timber shelter against the wall
	local nz = B.NestZone
	local nest = model(sf, "NestingGround")
	for i, off in { { 0, 0 }, { 6, -6 }, { -6, -5 } } do
		local c = at(nz.Forward + off[1], nz.Side + off[2], 0)
		local nm = model(nest, "Placeholder_Nest")
		disc(nm, "Straw", c + Vector3.new(0, 0.6, 0), 3.4, 1.2, M.Grass, C.Straw)
		disc(nm, "Hollow", c + Vector3.new(0, 0.75, 0), 2.3, 1.2, M.Grass, C.StrawDark)
	end
	P(nest, "Hay", Vector3.new(3.4, 2, 2.2), frame(nz.Forward + 9, nz.Side + 6, 1) * CFrame.Angles(0, rad(20), 0), M.Grass, C.Straw)
	P(nest, "Hay", Vector3.new(3.4, 2, 2.2), frame(nz.Forward + 11.5, nz.Side + 4, 1) * CFrame.Angles(0, rad(-15), 0), M.Grass, C.Straw)
	local shelter = model(nest, "Placeholder_Shelter")
	local sc = frame(14, -40, 0) * CFrame.Angles(0, rad(-90), 0) -- open side faces the sanctuary center
	for _, px in { -6, 6 } do
		for _, pz in { -3.5, 3.5 } do
			P(shelter, "Post", Vector3.new(0.9, 8.6, 0.9), sc * CFrame.new(px, 4.3, pz), M.Wood, C.Wood)
		end
	end
	P(shelter, "BackWall", Vector3.new(12.8, 6, 0.5), sc * CFrame.new(0, 3, 3.9), M.WoodPlanks, C.Plank)
	P(shelter, "Ridge", Vector3.new(13.6, 0.8, 0.8), sc * CFrame.new(0, 10.3, 0), M.Wood, C.Wood)
	for _, sgn in { -1, 1 } do
		P(shelter, "Roof", Vector3.new(14.4, 0.5, 6.2), sc * CFrame.new(0, 9.2, sgn * 2.6) * CFrame.Angles(sgn * rad(32), 0, 0), M.RoofShingles, C.Roof)
	end

	-- open meadow: a stone water trough (no boulders: the meadow stays open for dragons lying down)
	local meadow = model(sf, "Meadow")
	local trough = model(meadow, "Placeholder_Trough")
	local tc = frame(24, 22, 0) * CFrame.Angles(0, rad(-30), 0)
	P(trough, "Stone", Vector3.new(9, 2.2, 3.8), tc * CFrame.new(0, 1.1, 0), M.Slate, C.Cap)
	P(trough, "Water", Vector3.new(8, 0.3, 2.8), tc * CFrame.new(0, 2, 0), M.Glass, C.Water, { Transparency = 0.25, CanCollide = false })
end

function B.BuildSanctuaries()
	for _, plot in SM.Pens:GetChildren() do
		if plot:IsA("Model") and B.SanctuaryOrder[plot.Name] then
			B.BuildSanctuary(plot)
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
-- Travel points: invisible markers where the Travel menu lands a player (TravelService, Config/Travel), standing on
-- the ground and facing what they came for. One per sanctuary (named after its plot, on the forecourt facing the
-- gate), plus Altar (plaza, facing the altar), Market (south of the obelisk, facing north) and Spire (court, facing
-- the door).

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
	point("Market", 0, 130, 0, 100)
	point("Spire", 0, -208, 0, -260)
	for _, plot in SM.Pens:GetChildren() do
		local center = plot:GetAttribute("RoamCenter")
		if plot:IsA("Model") and typeof(center) == "Vector3" then
			local out = Vector3.new(-center.X, 0, -center.Z).Unit -- toward the altar
			local at = center + out * 64 -- forecourt, in front of the upgrade stands
			point(plot.Name, at.X, at.Z, center.X, center.Z)
		end
	end
end

return B
