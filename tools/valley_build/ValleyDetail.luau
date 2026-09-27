-- Valley detail (remaster checkpoint D): nature, binder ruins and dressing of the Starter Meadow. Studio build helper,
-- not used by the game. Each Build* function clears and rebuilds only its own folder; placement is deterministic
-- (fixed seeds), so a re-run gives the same result.
-- Usage: local D = require(ServerStorage.RemasterTools.ValleyDetail:Clone()); D.BuildNature() ...
-- The live copy is ServerStorage.RemasterTools.ValleyDetail in the place; this file is the reference copy.
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local D = {}
local SM = workspace:WaitForChild("StarterMeadow")
local KIT = ServerStorage.PropKits.Enchanted
local V = require(ServerStorage.RemasterTools.ValleyTerrain:Clone())
local B = require(ServerStorage.RemasterTools.ValleyBuild:Clone())
local C, P = B.Colors, B.P
local M = Enum.Material
local noise, sqrt, abs, max, min, rad, sin, cos = math.noise, math.sqrt, math.abs, math.max, math.min, math.rad, math.sin, math.cos

D.TreeTint = Color3.new(0.88, 1, 0.82) -- brighter, greener conifers (they read black untinted)
D.MaxTrees = 210

---------------------------------------------------------------------------------------------------------------
-- Where nature may go

local function slopeAt(x: number, z: number): (number, number)
	local h = V.Height(x, z)
	local hx, hz = V.Height(x + 4, z), V.Height(x, z + 4)
	return max(abs(hx - h), abs(hz - h)) / 4, h
end

-- Free for nature: not on a road, square, water, rock or sanctuary floor, and outside every play space.
local function open(x: number, z: number, margin: number): boolean
	for _, o in { { 0, 0 }, { margin, 0 }, { -margin, 0 }, { 0, margin }, { 0, -margin } } do
		local _, level, hint = V.Height(x + o[1], z + o[2])
		if level or hint == "paved" or hint == "bed" or hint == "rockbed" or hint == "flat" or hint == "rock" then
			return false
		end
	end
	local R = sqrt(x * x + z * z)
	local th = math.deg(math.atan2(x, -z))
	if R < 72 then
		return false -- plaza
	end
	if sqrt(x * x + (z - 112) ^ 2) < 52 then
		return false -- market
	end
	for _, s in V.Sanct do
		if sqrt((x - s.X) ^ 2 + (z - s.Z) ^ 2) < 64 then
			return false -- sanctuaries and their back cliffs
		end
	end
	if R > 120 and R < 190 and abs(th) < 50 then
		return false -- portal terrace
	end
	local sd = sqrt(x * x + (z + 252) ^ 2)
	if sd < 48 or (abs(x) < 16 and z < -95 and z > -225) then
		return false -- Spire hilltop and the stairs up to it
	end
	if abs(x) < 42 and z > 125 and z < 230 then
		return false -- entrance and the road through the gorge
	end
	if sqrt((x + 292) ^ 2 + (z - 60) ^ 2) < 48 then
		return false -- keep the waterfall in view
	end
	return true
end
D.Open = open

local function saddleDistance(th: number): number
	local best = 180
	for _, s in { -40, -15, 15, 40 } do
		best = min(best, abs(th - s))
	end
	return best
end

local function placeModel(template: Model, parent: Instance, pos: Vector3, yaw: number, scale: number): Model
	local m = template:Clone()
	if scale ~= 1 then
		m:ScaleTo(scale)
	end
	m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, yaw, 0))
	m.Parent = parent
	return m
end

local function tint(m: Model, color: Color3)
	for _, d in m:GetDescendants() do
		if d:IsA("SurfaceAppearance") then
			(d :: any).Color = color
		elseif d:IsA("MeshPart") then
			d.CanCollide = false
			d.CanTouch = false
			d.RenderFidelity = Enum.RenderFidelity.Automatic
		end
	end
end

local function collider(parent: Instance, base: Vector3, radius: number, height: number)
	local p = P(parent, "TrunkCollider", Vector3.new(height, radius * 2, radius * 2), CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), M.SmoothPlastic, Color3.new(1, 1, 1), { Transparency = 1, CanQuery = false, CanTouch = false, CastShadow = false })
	p.Shape = Enum.PartType.Cylinder
end

---------------------------------------------------------------------------------------------------------------
-- Nature: forest on the slopes and edges, a few big oaks, ferns, wildflower meadows, night flora, boulders

function D.BuildNature()
	local f = B.Folder(SM, "Nature", true)
	local trees = B.Folder(f, "Trees")
	local rng = Random.new(927)
	local placed = {}
	local function farFrom(x: number, z: number, d: number): boolean
		for _, p in placed do
			if (p.X - x) ^ 2 + (p.Z - z) ^ 2 < d * d then
				return false
			end
		end
		return true
	end
	local firs, pines = {}, {}
	for i = 1, 8 do
		table.insert(firs, KIT:FindFirstChild("Store_Fir" .. i))
	end
	for i = 1, 12 do
		table.insert(pines, KIT:FindFirstChild("Store_Pine" .. i))
	end

	-- forest: jittered grid, dense on the foothills, groves at the valley edge, sparse high up, thin in the saddles
	local count = 0
	for gx = -560, 560, 15 do
		for gz = -560, 560, 15 do
			local x, z = gx + rng:NextNumber(-6, 6), gz + rng:NextNumber(-6, 6)
			local R = sqrt(x * x + z * z)
			local th = math.deg(math.atan2(x, -z))
			local u = R - V.EdgeAt(th)
			if u > -45 and count < D.MaxTrees then
				local slope, h = slopeAt(x, z)
				local base = if u < 0 then 0.16 elseif u < 130 then 0.42 else 0.12
				local cluster = math.clamp((0.5 + noise(x / 110, z / 110, 4.2)) * 1.6, 0.1, 1.3)
				local p = base * cluster
				if R > 290 and saddleDistance(th) < 9 then
					p *= 0.25
				end
				if h < 115 and slope < 0.95 and rng:NextNumber() < p and farFrom(x, z, 12) and open(x, z, 8) then
					local isFir = rng:NextNumber() < 0.55
					local list = if isFir then firs else pines
					local template = list[rng:NextInteger(1, #list)]
					local scale = if isFir then rng:NextNumber(1.7, 2.4) else rng:NextNumber(1.4, 2.0)
					local m = placeModel(template, trees, Vector3.new(x, h - 0.6 - slope * 2, z), rng:NextNumber(0, 2 * math.pi), scale)
					tint(m, D.TreeTint:Lerp(Color3.new(0.95, 1, 0.9), rng:NextNumber(0, 0.5)))
					if u < 32 then
						collider(m, Vector3.new(x, h - 1, z), 0.9 * scale, 14)
					end
					table.insert(placed, Vector3.new(x, h, z))
					count += 1
				end
			end
		end
	end

	-- a few big old oaks as specimen trees on the valley floor
	local oaks = B.Folder(f, "Oaks")
	local oakCount = 0
	for _ = 1, 400 do
		if oakCount >= 5 then
			break
		end
		local x, z = rng:NextNumber(-260, 260), rng:NextNumber(-200, 150)
		local R = sqrt(x * x + z * z)
		local u = R - V.EdgeAt(math.deg(math.atan2(x, -z)))
		-- near the valley edge and well off the main axis, so they frame the valley and never hide the plaza
		if u < -18 and u > -55 and abs(x) > 110 and farFrom(x, z, 22) and open(x, z, 14) then
			local _, h = slopeAt(x, z)
			local m = placeModel(KIT.Store_Oak, oaks, Vector3.new(x, h - 0.4, z), rng:NextNumber(0, 2 * math.pi), rng:NextNumber(1.3, 1.6))
			tint(m, Color3.new(1, 1, 1))
			collider(m, Vector3.new(x, h - 1, z), 1.6, 14)
			table.insert(placed, Vector3.new(x, h, z))
			oakCount += 1
		end
	end

	-- ferns along the forest edge and the river banks
	local ferns = B.Folder(f, "Ferns")
	local fernCount = 0
	for _ = 1, 1500 do
		if fernCount >= 55 then
			break
		end
		local x, z = rng:NextNumber(-330, 330), rng:NextNumber(-330, 230)
		local R = sqrt(x * x + z * z)
		local u = R - V.EdgeAt(math.deg(math.atan2(x, -z)))
		local slope, h = slopeAt(x, z)
		local nearRiver = false
		for _, dz in { -12, 12 } do
			local _, level = V.Height(x, z + dz)
			if level then
				nearRiver = true
			end
		end
		if (u > -18 and u < 25 or nearRiver) and slope < 0.8 and open(x, z, 3) then
			local m = placeModel(KIT.Store_Fern, ferns, Vector3.new(x, h - 0.3, z), rng:NextNumber(0, 2 * math.pi), rng:NextNumber(0.13, 0.2))
			tint(m, Color3.new(0.9, 1, 0.85))
			fernCount += 1
		end
	end

	-- wildflower meadows on the valley floor (patches of 4-6)
	local flowers = B.Folder(f, "Flowers")
	local kinds = { KIT.AI_Ench_Lupines, KIT.AI_Ench_Buttercups, KIT.AI_Ench_Daisies, KIT.Store_WildFlower }
	local patches = 0
	for _ = 1, 3000 do
		if patches >= 44 then
			break
		end
		local x, z = rng:NextNumber(-280, 280), rng:NextNumber(-230, 170)
		local R = sqrt(x * x + z * z)
		local u = R - V.EdgeAt(math.deg(math.atan2(x, -z)))
		if u < -8 and noise(x / 60, z / 60, 8.1) > -0.1 and open(x, z, 5) then
			local mainKind = kinds[rng:NextInteger(1, #kinds)]
			for i = 1, rng:NextInteger(4, 6) do
				local a, r = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(0, 5)
				local px, pz = x + cos(a) * r, z + sin(a) * r
				local _, h = slopeAt(px, pz)
				local kind = if rng:NextNumber() < 0.7 then mainKind else kinds[rng:NextInteger(1, #kinds)]
				local m = placeModel(kind, flowers, Vector3.new(px, h - 0.1, pz), rng:NextNumber(0, 2 * math.pi), rng:NextNumber(1, 1.6))
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
					end
				end
			end
			patches += 1
		end
	end

	-- night flora: moonflowers and glow mushrooms by the river and at the forest edge (glow at night: NightGlow)
	local night = B.Folder(f, "NightFlora")
	local nightCount = 0
	for _ = 1, 3000 do
		if nightCount >= 30 then
			break
		end
		local x, z = rng:NextNumber(-300, 300), rng:NextNumber(-250, 170)
		local R = sqrt(x * x + z * z)
		local u = R - V.EdgeAt(math.deg(math.atan2(x, -z)))
		local nearRiver = false
		for _, dz in { -10, 10 } do
			local _, level = V.Height(x, z + dz)
			if level then
				nearRiver = true
			end
		end
		if (nearRiver or (u > -15 and u < 10)) and open(x, z, 3) then
			local template = if rng:NextNumber() < 0.55 then KIT.AI_Ench_Moonflowers else KIT.AI_Ench_GlowMushrooms
			local _, h = slopeAt(x, z)
			local m = placeModel(template, night, Vector3.new(x, h - 0.1, z), rng:NextNumber(0, 2 * math.pi), rng:NextNumber(1.1, 1.6))
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
					if d.Name == "Petals" or d.Name == "Caps" then
						if d:GetAttribute("GlowColor") == nil then
							d:SetAttribute("GlowColor", if d.Name == "Petals" then Color3.fromRGB(170, 130, 255) else Color3.fromRGB(110, 190, 255))
						end
						CollectionService:AddTag(d, "NightGlow")
					end
				end
			end
			nightCount += 1
		end
	end

	-- boulders at the foot of the slopes and along the banks
	local rocks = B.Folder(f, "Boulders")
	local rockKinds = { { "Store_Boulder2", 0.35 }, { "Store_Boulder4", 0.5 }, { "Store_Boulder5", 0.7 }, { "Store_Boulder7", 0.4 }, { "Store_Boulder9", 0.45 }, { "Store_Boulder11", 0.35 }, { "Store_Boulder14", 0.5 }, { "Store_Boulder15", 0.4 } }
	local rockCount = 0
	for _ = 1, 2000 do
		if rockCount >= 30 then
			break
		end
		local x, z = rng:NextNumber(-340, 340), rng:NextNumber(-340, 240)
		local R = sqrt(x * x + z * z)
		local u = R - V.EdgeAt(math.deg(math.atan2(x, -z)))
		if u > -12 and u < 40 and open(x, z, 4) then
			local spec = rockKinds[rng:NextInteger(1, #rockKinds)]
			local slope, h = slopeAt(x, z)
			placeModel(KIT[spec[1]], rocks, Vector3.new(x, h - 0.8 - slope * 2, z), rng:NextNumber(0, 2 * math.pi), spec[2] * rng:NextNumber(0.8, 1.4))
			rockCount += 1
		end
	end
	return string.format("trees %d, oaks %d, ferns %d, flower patches %d, night flora %d, boulders %d", count, oakCount, fernCount, patches, nightCount, rockCount)
end

---------------------------------------------------------------------------------------------------------------
-- Binder ruins: columns with gold bands, a broken arch, fallen columns, rune stones, star-inlaid steps

local function column(parent: Instance, base: Vector3, h: number, r: number, broken: boolean)
	local m = B.Model(parent, "Column")
	P(m, "Base", Vector3.new(r * 2 + 1.4, 1.2, r * 2 + 1.4), CFrame.new(base + Vector3.new(0, 0.2, 0)), M.Slate, C.Cap)
	local shaft = P(m, "Shaft", Vector3.new(h, r * 2, r * 2), CFrame.new(base + Vector3.new(0, 0.8 + h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), M.Cobblestone, C.Stone)
	shaft.Shape = Enum.PartType.Cylinder
	local band = P(m, "GoldBand", Vector3.new(0.4, r * 2 + 0.2, r * 2 + 0.2), CFrame.new(base + Vector3.new(0, 0.8 + h * 0.72, 0)) * CFrame.Angles(0, 0, math.pi / 2), M.Foil, C.Gold, { CanCollide = false })
	band.Shape = Enum.PartType.Cylinder
	B.Glow(band)
	if broken then
		P(m, "Chunk", Vector3.new(r * 2, 1.4, r * 2), CFrame.new(base + Vector3.new(0.4, 0.8 + h + 0.3, 0)) * CFrame.Angles(rad(14), rad(30), rad(-10)), M.Cobblestone, C.Stone)
	else
		P(m, "Capital", Vector3.new(r * 2 + 1, 1, r * 2 + 1), CFrame.new(base + Vector3.new(0, 0.8 + h + 0.5, 0)), M.Slate, C.Cap)
	end
	return m
end

local function fallenColumn(parent: Instance, base: Vector3, yaw: number, r: number)
	local m = B.Model(parent, "FallenColumn")
	local dir = CFrame.Angles(0, yaw, 0)
	for i, len in { 5, 3.5, 4 } do
		local off = dir:VectorToWorldSpace(Vector3.new(0, 0, (i - 2) * 4.6))
		local p = P(m, "Drum", Vector3.new(len, r * 2, r * 2), CFrame.new(base + off + Vector3.new(0, r - 0.3, 0)) * dir * CFrame.Angles(0, rad(90 + (i - 2) * 8), 0), M.Cobblestone, C.Stone)
		p.Shape = Enum.PartType.Cylinder
	end
	return m
end

local function starStep(parent: Instance, base: Vector3, r: number)
	local m = B.Model(parent, "StarStep")
	B.Disc(m, "Step", base + Vector3.new(0, 0.15, 0), r, 0.7, M.Slate, C.Cap)
	B.Star(m, CFrame.new(base + Vector3.new(0, 0.52, 0)) * CFrame.Angles(math.pi / 2, 0, 0), r * 1.1)
	return m
end

local function runeStone(parent: Instance, base: Vector3, yaw: number, scale: number)
	local m = placeModel(KIT.AI_Ench_RuneStone, parent, base - Vector3.new(0, 0.3, 0), yaw, scale)
	return m
end

local function brokenArch(parent: Instance, base: Vector3, yaw: number)
	local m = B.Model(parent, "Placeholder_BrokenArch")
	local rot = CFrame.Angles(0, yaw, 0)
	column(m, base + rot:VectorToWorldSpace(Vector3.new(-3.6, 0, 0)), 7, 1.1, false)
	column(m, base + rot:VectorToWorldSpace(Vector3.new(3.6, 0, 0)), 4, 1.1, true)
	-- the fallen lintel with its gold star
	local lc = CFrame.new(base + rot:VectorToWorldSpace(Vector3.new(1.5, 0.9, -3.2))) * rot * CFrame.Angles(0, rad(18), rad(8))
	P(m, "Lintel", Vector3.new(8.5, 1.6, 2), lc, M.Slate, C.StoneDark)
	B.Star(m, lc * CFrame.new(0, 0, -1.05), 1.4)
	return m
end

-- One ruin site: kinds listed in order, spread around pos.
local function site(parent: Instance, name: string, pos: Vector3, yaw: number, kinds: { string })
	local m = B.Model(parent, name)
	local rot = CFrame.Angles(0, yaw, 0)
	for i, kind in kinds do
		local off = rot:VectorToWorldSpace(Vector3.new((i - (#kinds + 1) / 2) * 7, 0, if i % 2 == 0 then 3 else -2))
		local x, z = pos.X + off.X, pos.Z + off.Z
		local g = V.Height(x, z)
		local base = Vector3.new(x, g, z)
		if kind == "arch" then
			brokenArch(m, base, yaw)
		elseif kind == "column" then
			column(m, base, 6.5, 1.2, false)
		elseif kind == "stump" then
			column(m, base, 2.5, 1.3, true)
		elseif kind == "fallen" then
			fallenColumn(m, base, yaw + rad(35), 1.1)
		elseif kind == "rune" then
			runeStone(m, base, yaw + math.pi, 1.7)
		elseif kind == "step" then
			starStep(m, base, 3)
		end
	end
	return m
end

D.RuinSites = {
	{ "Ruin_Waterfall", Vector3.new(-262, 0, 38), 100, { "column", "arch", "rune" } },
	{ "Ruin_LowPool", Vector3.new(280, 0, 38), -100, { "stump", "fallen", "rune" } },
	{ "Ruin_TerraceWest", Vector3.new(-115, 0, -128), 48, { "rune", "step" } },
	{ "Ruin_TerraceEast", Vector3.new(115, 0, -128), -48, { "step", "rune" } },
	{ "Ruin_MeadowWest", Vector3.new(-100, 0, -30), 70, { "stump", "step", "fallen" } },
	{ "Ruin_MeadowEast", Vector3.new(105, 0, 22), -70, { "fallen", "column" } },
	{ "Ruin_SpireWest", Vector3.new(-52, 0, -262), 90, { "column", "stump" } },
	{ "Ruin_SpireEast", Vector3.new(52, 0, -262), -90, { "stump", "column" } },
	{ "Ruin_Market", Vector3.new(72, 0, 150), 200, { "rune", "fallen" } },
}

function D.BuildRuins()
	local f = B.Folder(SM, "Ruins", true)
	for _, s in D.RuinSites do
		site(f, s[1], s[2], rad(s[3]), s[4])
	end
	-- each sanctuary: a broken binder arch between the back pillars and a rune stone
	for plotName, id in B.SanctuaryOrder do
		for _, s in V.Sanct do
			if s.Name == id then
				local center = Vector3.new(s.X, s.T, s.Z)
				local fwd = Vector3.new(s.AX, 0, s.AZ)
				local right = Vector3.new(-fwd.Z, 0, fwd.X)
				local yaw = math.atan2(-fwd.X, -fwd.Z)
				local m = B.Model(f, "Sanctuary_" .. id)
				brokenArch(m, center - fwd * 45.5, yaw)
				runeStone(m, center - fwd * 36 - right * 26, yaw, 1.6)
			end
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Dressing: gate crystals, signpost words, market props, lily pads, more lanterns, the east cascade

D.GateColors = {
	Portal_VolcanoPeak = Color3.fromRGB(255, 120, 45),
	Portal_FrozenCliffs = Color3.fromRGB(120, 225, 255),
	Portal_StormCanyon = Color3.fromRGB(110, 160, 255),
	Portal_EclipseIsles = Color3.fromRGB(150, 100, 255),
}

function D.BuildDressing()
	local f = B.Folder(SM, "Dressing", true)

	-- crystals at each portal gate, in its area's color (glass by day, glowing at night)
	local crystals = B.Folder(f, "GateCrystals")
	for name, color in D.GateColors do
		local portal = SM.Portals:FindFirstChild(name) :: Model?
		if portal then
			local s = portal.PrimaryPart :: BasePart
			local right = s.CFrame.RightVector
			local look = s.CFrame.LookVector
			for i, spec in { { -12.5, 1.8, 0.4 }, { 12.5, 1.5, -0.6 }, { -9.5, 1.1, 5 } } do
				local pos = Vector3.new(s.Position.X, 12, s.Position.Z) + right * spec[1] + look * spec[3]
				local m = placeModel(KIT.AI_Ench_MagicCrystals, crystals, pos, i * 1.7, spec[2])
				m.Name = "Crystals_" .. name
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") and d.Name == "Crystals" then
						d.Material = M.Glass
						d.Color = color
						d.Transparency = 0.05
						B.Glow(d, color)
					end
				end
			end
		end
	end

	-- words on the obelisk's signpost arms
	local obelisk = SM.Market:FindFirstChild("Placeholder_StarObelisk")
	if obelisk then
		local words = { "Star Altar  -  Portals  -  Spire", "West Sanctuaries", "East Sanctuaries" }
		local i = 0
		for _, arm in obelisk:GetChildren() do
			if arm.Name == "SignArm" then
				i += 1
				for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
					local gui = Instance.new("SurfaceGui")
					gui.Face = face
					gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
					gui.PixelsPerStud = 40
					gui.MaxDistance = 60
					gui.LightInfluence = 0.5
					local label = Instance.new("TextLabel")
					label.Size = UDim2.fromScale(1, 1)
					label.BackgroundTransparency = 1
					label.Text = words[i] or ""
					label.TextScaled = true
					label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
					label.TextColor3 = Color3.fromRGB(255, 222, 140)
					label.Parent = gui
					gui.Parent = arm
				end
			end
		end
	end

	-- market props: crates and barrels by the tent and the forge
	local props = B.Folder(f, "MarketProps")
	for _, spec in { { -38, 106, 0 }, { -37.5, 109.8, 0.3 }, { -38, 108, 3.2 }, { 38.5, 128, 0.2 }, { 41, 129.5, -0.2 } } do
		local g = V.Height(spec[1], spec[2])
		P(props, "Placeholder_Crate", Vector3.new(3, 3, 3), CFrame.new(spec[1], g + 1.5 + (if spec[3] > 3 then 3 else 0), spec[2]) * CFrame.Angles(0, spec[3], 0), M.WoodPlanks, C.Plank)
	end
	for _, spec in { { -38.5, 101.5 }, { 36, 124.5 }, { 34.5, 127.5 } } do
		local g = V.Height(spec[1], spec[2])
		local p = P(props, "Placeholder_Barrel", Vector3.new(3.4, 2.6, 2.6), CFrame.new(spec[1], g + 1.7, spec[2]) * CFrame.Angles(0, 0, math.pi / 2), M.Wood, C.Wood)
		p.Shape = Enum.PartType.Cylinder
	end

	-- lily pads (and a few water lilies) on the ponds
	local lilies = B.Folder(f, "LilyPads")
	local rng = Random.new(84)
	for _, pond in V.Ponds do
		for i = 1, 11 do
			local a, q = rng:NextNumber(0, 2 * math.pi), sqrt(rng:NextNumber()) * 0.75
			local x, z = pond.X + cos(a) * q * pond.A, pond.Z + sin(a) * q * pond.B
			local r = rng:NextNumber(1.1, 2)
			B.Disc(lilies, "LilyPad", Vector3.new(x, -0.92, z), r, 0.15, M.Grass, Color3.fromRGB(70, 138, 60), { CanCollide = false, CanQuery = false, CanTouch = false })
			if i % 3 == 0 then
				local bloom = P(lilies, "WaterLily", Vector3.new(0.7, 0.7, 0.7), CFrame.new(x + 0.3, -0.55, z), M.SmoothPlastic, if i % 2 == 0 then Color3.fromRGB(255, 205, 225) else Color3.fromRGB(250, 248, 240), { CanCollide = false, CanQuery = false, CanTouch = false, Shape = Enum.PartType.Ball })
				bloom.Size = Vector3.new(0.9, 0.9, 0.9)
			end
		end
	end

	-- more lanterns: halfway along each sanctuary road and on the north road
	local lamps = B.Folder(f, "RoadLanterns")
	for _, bearing in { -58, -90, 58, 90 } do
		local r = rad(bearing)
		local dir = Vector3.new(sin(r), 0, -cos(r))
		local side = Vector3.new(-dir.Z, 0, dir.X) * 7.5
		local p = dir * 100 + side
		B.Lantern(lamps, Vector3.new(p.X, V.Height(p.X, p.Z), p.Z), 0)
	end
	for _, xz in { { -76, 32 }, { 76, 32 }, { -9.5, -78 }, { 9.5, -78 } } do
		B.Lantern(lamps, Vector3.new(xz[1], V.Height(xz[1], xz[2]), xz[2]), 0)
	end

	-- the east cascade: the river drops into the lower pool (streaks + foam from the big waterfall's look)
	local wf = SM.Water:FindFirstChild("Waterfall")
	if wf then
		local cascade = B.Folder(f, "EastCascade")
		local anchor = P(cascade, "BeamAnchor", Vector3.new(1, 1, 1), CFrame.new(273, 0, 61), M.SmoothPlastic, Color3.new(1, 1, 1), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.WorldPosition = Vector3.new(273, -0.9, 61)
		a1.WorldPosition = Vector3.new(281.5, -6.9, 61.6)
		a0.Parent, a1.Parent = anchor, anchor
		local sheet = wf.BeamAnchor:FindFirstChild("Sheet1")
		if sheet then
			local beam = sheet:Clone()
			beam.Attachment0, beam.Attachment1 = a0, a1
			beam.Width0, beam.Width1 = 9, 10
			beam.Parent = anchor
		end
		local foam = wf:FindFirstChild("Foam")
		if foam then
			local fm = foam:Clone()
			fm.CFrame = CFrame.lookAt(Vector3.new(282, -6.6, 61.6), Vector3.new(300, -6.6, 62))
			fm.Size = Vector3.new(8, 1, 4)
			for _, e in fm:GetDescendants() do
				if e:IsA("ParticleEmitter") then
					e.Rate = e.Rate * 0.5
					CollectionService:AddTag(e, "AmbientFX")
				end
			end
			fm.Parent = cascade
		end
	end
end

return D
