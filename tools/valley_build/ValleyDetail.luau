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

D.MaxTrees = 260
D.MaxLifeTrees = 140 -- BuildLife: extra forest trees on the new valley edges

-- Valley tidy-up (2026-09-28): open grass around the landmarks, fewer and bigger clusters of dressing.
-- Clear zones: BuildNature leaves nothing (except the magical trees, which only stand where they mean something) in a
-- ring of grass around the plaza and in the field in front of the portal terrace.
D.ClearZones = {
	Plaza = 82, -- radius around the altar (the plaza base is 57)
	-- layout A-N: the old terrace area north of the plaza is the open meadow of the lantern avenue (x +-110, z -176 .. -57),
	-- and the forest keeps PortalTerrace studs away from the new portal terrace (a polygon behind the Spire)
	NorthField = { X = 110, Z0 = -176, Z1 = -57 },
	PortalTerrace = 24,
	Sanctuaries = 108, -- radius around each sanctuary center (terrace 80 + forecourt to 97): nothing grows here (Valley rework)
}
D.FlowerPatches = 14 -- wildflower patches of 9-13 flowers, toward the valley edges (the middle of each field stays open)
D.MaxBoulders = 18 -- boulders on the lower slopes only (none in the open meadows)
-- Trees removed by hand in the place (2026-09-28). BuildNature still generates them, so every other tree keeps its
-- spot (all trees share one random stream), then removes them: { name, x, z }.
D.RemovedByHand = {
	{ "Fantasy_EmeraldTree_A", -271.7, 131.5 },
	{ "Fantasy_TealFir_B", -255.2, 125.5 },
	{ "Fantasy_TealFir_B", -254.9, 143.7 },
	{ "Fantasy_TealFir", -195.0, 184.3 },
	{ "Fantasy_TealFir_B", -140.1, 184.7 },
	{ "Fantasy_TealFir_B", -105.8, 189.3 },
	{ "Fantasy_EmeraldTree_B", -91.2, 178.0 },
	{ "Fantasy_EmeraldTree_A", -76.7, 145.6 },
	{ "Fantasy_TealFir_B", -77.3, 186.7 },
	{ "Fantasy_EmeraldTree_B", 71.0, 146.7 },
	{ "Fantasy_EmeraldTree_A", 69.6, 164.6 },
	{ "Fantasy_TealFir_B", 204.4, 179.5 },
	{ "Fantasy_EmeraldTree_B", 219.0, 173.3 },
	{ "Fantasy_EmeraldTree_B", 234.7, -200.2 },
	{ "Fantasy_TealFir_B", 248.7, -159.2 },
	{ "Fantasy_EmeraldTree_A", 253.0, 112.8 },
	{ "Fantasy_TealFir_B", 254.9, 146.0 },
	{ "Fantasy_EmeraldTree_A", 270.2, -138.9 },
	{ "Fantasy_TealFir_B", 279.1, -46.6 },
	{ "Fantasy_TealFir_B", 295.6, -10.0 },
	{ "Fantasy_LanternWillow", -252.5, 89.1 },
	{ "Fantasy_LanternWillow", -159.5, 27.3 },
	{ "Fantasy_LanternWillow", 113.5, 42.6 },
	{ "Fantasy_LanternWillow", 242.8, 86.0 },
	{ "Fantasy_LanternWillow", -61.0, 109.0 },
	{ "Fantasy_LanternWillow", -89.3, 101.7 },
	{ "Fantasy_LanternWillow", 101.0, 84.0 },
	{ "Fantasy_LanternWillow", 61.0, 109.0 },
	{ "Fantasy_StarBlossom", 286.5, 26.7 },
	{ "Fantasy_CrystalTree", 273.5, 49.3 },
	{ "Fantasy_StarBlossom", -124.5, -144.5 },
	{ "Fantasy_StarBlossom", 124.5, -144.5 },
	{ "Fantasy_StarBlossom", -106.5, -18.7 },
	{ "Fantasy_StarBlossom", 92.0, 22.0 },
	{ "Fantasy_StarBlossom", 85.0, 150.0 },
	{ "Fantasy_CrystalTree", 59.0, 150.0 },
	{ "Fantasy_StarBlossom", -109.7, -88.6 },
	{ "Fantasy_StarBlossom", -138.2, -54.5 },
	{ "Fantasy_StarBlossom", -146.0, -22.0 },
	{ "Fantasy_StarBlossom", -146.0, 22.0 },
	{ "Fantasy_StarBlossom", -122.9, 45.0 },
	{ "Fantasy_StarBlossom", -114.8, 91.8 },
	{ "Fantasy_StarBlossom", 138.2, -54.5 },
	{ "Fantasy_StarBlossom", 109.7, -88.6 },
	{ "Fantasy_StarBlossom", 146.0, 22.0 },
	{ "Fantasy_StarBlossom", 146.0, -22.0 },
	{ "Fantasy_StarBlossom", 114.8, 91.8 },
	{ "Fantasy_EmeraldTree_B", 117.6, 142.6 },
	{ "Fantasy_EmeraldTree_B", -127.1, 149.5 },
}

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
		if sqrt((x - s.X) ^ 2 + (z - s.Z) ^ 2) < V.FlatR + 30 then
			return false -- sanctuary terraces and their forecourts
		end
	end
	if V.PolyOut(V.Terrace.Poly, x, z) < 16 then
		return false -- portal terrace (layout A-N)
	end
	local sd = sqrt(x * x + (z + 252) ^ 2)
	if sd < 48 or (abs(x) < 16 and z < -95 and z > -225) then
		return false -- Spire hilltop and the stairs up to it
	end
	if abs(x) < 42 and z > 125 and z < 230 then
		return false -- entrance and the road through the gorge
	end
	if sqrt((x + 335) ^ 2 + (z - 118) ^ 2) < 48 or sqrt((x - 332) ^ 2 + (z - 121) ^ 2) < 30 then
		return false -- keep the waterfall and the lower pool in view
	end
	return true
end
D.Open = open

-- Inside a clear zone (open grass around the plaza and in front of the portal terrace)?
local function clear(x: number, z: number): boolean
	local R = sqrt(x * x + z * z)
	local th = math.deg(math.atan2(x, -z))
	local nf = D.ClearZones.NorthField
	if R < D.ClearZones.Plaza or (abs(x) < nf.X and z > nf.Z0 and z < nf.Z1) or V.PolyOut(V.Terrace.Poly, x, z) < D.ClearZones.PortalTerrace then
		return true
	end
	for _, s in V.Sanct do
		if sqrt((x - s.X) ^ 2 + (z - s.Z) ^ 2) < D.ClearZones.Sanctuaries then
			return true
		end
	end
	return false
end
D.Clear = clear

local function saddleDistance(th: number): number
	local best = 180
	for _, s in { -35, -18, 18, 35 } do
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
	-- magical trees first (about 15%), placed where they matter; the forest then keeps its distance from them
	local magic = B.Folder(f, "MagicTrees")
	local function magicTree(name: string, x: number, z: number): boolean
		if not (farFrom(x, z, 10) and open(x, z, 5)) then
			return false
		end
		local _, h = slopeAt(x, z)
		D.PlaceFantasyTree(magic, name, Vector3.new(x, h - 0.4, z), rng, true)
		table.insert(placed, Vector3.new(x, h, z))
		return true
	end
	-- lantern willows on the river banks, every ~50 studs, alternating sides, clear of the bridges and the waterfall
	local river, side, lastX = V.River, 1, -math.huge
	for i = 1, #river - 1 do
		local p, q = river[i], river[i + 1]
		if p[1] - lastX >= 50 and abs(p[1]) > 26 and abs(abs(p[1]) - 100) > 18 then
			local dir = Vector2.new(q[1] - p[1], q[2] - p[2]).Unit
			local normal = Vector2.new(-dir.Y, dir.X)
			local done = false
			for _, extra in { 10, 14, 18 } do
				for _, sgn in { side, -side } do
					local off = p[3] / 2 + extra
					if not done and magicTree("Fantasy_LanternWillow", p[1] + normal.X * off * sgn, p[2] + normal.Y * off * sgn) then
						lastX, side, done = p[1], -sgn, true
					end
				end
			end
		end
	end
	-- lantern willows by the ponds and the lower pool, on opposite banks
	local pools = { V.Ponds[1], V.Ponds[2], { X = V.LowPool.X, Z = V.LowPool.Z, A = V.LowPool.R, B = V.LowPool.R } }
	for _, pool in pools do
		local n = 0
		for _, k in { 0, 4, 2, 6, 1, 5, 3, 7 } do
			local a = k * math.pi / 4
			if n < 2 and magicTree("Fantasy_LanternWillow", pool.X + cos(a) * (pool.A + 9), pool.Z + sin(a) * (pool.B + 9)) then
				n += 1
			end
		end
	end
	-- a star-blossom and a crystal tree at each ruin site, on different sides
	for i, site in D.RuinSites do
		for j, name in { "Fantasy_StarBlossom", "Fantasy_CrystalTree" } do
			for k = 0, 11 do
				local a, r = (k + (i + j * 3) * 2) * math.pi / 6, 13 + (k % 3) * 3
				if magicTree(name, site[2].X + cos(a) * r, site[2].Z + sin(a) * r) then
					break
				end
			end
		end
	end
	-- a pair of star-blossoms flanking the road in front of each sanctuary gate
	for _, sanct in V.Sanct do
		local out = Vector2.new(-sanct.X, -sanct.Z).Unit
		local across = Vector2.new(-out.Y, out.X)
		for _, sgn in { -1, 1 } do
			local done = false
			for _, d in { 74, 80, 86, 92 } do
				for _, w in { 17, 22, 27 } do
					if not done and magicTree("Fantasy_StarBlossom", sanct.X + out.X * d + across.X * w * sgn, sanct.Z + out.Y * d + across.Y * w * sgn) then
						done = true
					end
				end
			end
		end
	end
	-- crystal trees framing the approaches to the altar plaza (between the roads)
	for _, bearing in { 35, -35, 145, -145 } do
		local done = false
		for _, r in { 84, 92, 100, 110, 120 } do
			for _, db in { 0, 8, -8, 16, -16 } do
				local b = rad(bearing + db)
				if not done and magicTree("Fantasy_CrystalTree", r * sin(b), -r * cos(b)) then
					done = true
				end
			end
		end
	end

	-- forest: jittered grid, dense on the foothills, groves at the valley edge, sparse high up, thin in the saddles;
	-- teal firs on the ridges and high slopes, emerald broadleaves on the valley floor, both on the foothills
	local FIRS = { "Fantasy_TealFir", "Fantasy_TealFir_B", "Fantasy_TealFir_B" } -- the slender B (925 triangles) twice as often
	local BROADLEAVES = { "Fantasy_EmeraldTree_A", "Fantasy_EmeraldTree_B" }
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
				if h < 130 and slope < 1.2 and rng:NextNumber() < p and farFrom(x, z, 12) and open(x, z, 8) then
					-- ridges and high slopes: firs; foothills: half and half; valley floor: mostly broadleaves
					local list = if u > 60 or h > 50 then FIRS
						elseif u > 0 then (if rng:NextNumber() < 0.5 then FIRS else BROADLEAVES)
						else (if rng:NextNumber() < 0.8 then BROADLEAVES else FIRS)
					local name = list[rng:NextInteger(1, #list)]
					D.PlaceFantasyTree(trees, name, Vector3.new(x, h - 0.6 - slope * 2, z), rng, u < 32)
					table.insert(placed, Vector3.new(x, h, z))
					count += 1
				end
			end
		end
	end

	-- a few big old broadleaves as specimen trees on the valley floor, at the edges so they never hide the plaza
	local specimens = B.Folder(f, "Specimens")
	local specimenCount = 0
	for _ = 1, 400 do
		if specimenCount >= 5 then
			break
		end
		local x, z = rng:NextNumber(-260, 260), rng:NextNumber(-200, 150)
		local R = sqrt(x * x + z * z)
		local u = R - V.EdgeAt(math.deg(math.atan2(x, -z)))
		if u < -18 and u > -55 and abs(x) > 110 and farFrom(x, z, 22) and open(x, z, 14) then
			local _, h = slopeAt(x, z)
			D.PlaceFantasyTree(specimens, "Fantasy_EmeraldTree_B", Vector3.new(x, h - 0.4, z), rng, true, rng:NextNumber(46, 54))
			table.insert(placed, Vector3.new(x, h, z))
			specimenCount += 1
		end
	end

	-- the giant ancient tree beside the waterfall
	D.PlaceAncientTree(B.Folder(f, "Landmark"))

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

	-- wildflower meadows: a few big patches (D.FlowerPatches) toward the valley edges, at least 55 studs apart, so the
	-- middle of each field stays open grass (own random stream)
	local flowers = B.Folder(f, "Flowers")
	local kinds = { KIT.AI_Ench_Lupines, KIT.AI_Ench_Buttercups, KIT.AI_Ench_Daisies, KIT.Store_WildFlower }
	local frng = Random.new(4401)
	local patches, centers = 0, {}
	for _ = 1, 4000 do
		if patches >= D.FlowerPatches then
			break
		end
		local x, z = frng:NextNumber(-280, 280), frng:NextNumber(-230, 170)
		local R = sqrt(x * x + z * z)
		local u = R - V.EdgeAt(math.deg(math.atan2(x, -z)))
		local spaced = true
		for _, c in centers do
			if (c.X - x) ^ 2 + (c.Y - z) ^ 2 < 55 * 55 then
				spaced = false
				break
			end
		end
		if u < -10 and u > -90 and spaced and not clear(x, z) and open(x, z, 9) then
			table.insert(centers, Vector2.new(x, z))
			local mainKind = kinds[frng:NextInteger(1, #kinds)]
			for _ = 1, frng:NextInteger(9, 13) do
				local a, r = frng:NextNumber(0, 2 * math.pi), sqrt(frng:NextNumber()) * 8
				local px, pz = x + cos(a) * r, z + sin(a) * r
				if open(px, pz, 1) then
					local _, h = slopeAt(px, pz)
					local kind = if frng:NextNumber() < 0.75 then mainKind else kinds[frng:NextInteger(1, #kinds)]
					local m = placeModel(kind, flowers, Vector3.new(px, h - 0.1, pz), frng:NextNumber(0, 2 * math.pi), frng:NextNumber(1, 1.6))
					for _, d in m:GetDescendants() do
						if d:IsA("BasePart") then
							d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
						end
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

	-- boulders on the lower slopes (none in the open meadows)
	local rocks = B.Folder(f, "Boulders")
	local rockKinds = { { "Store_Boulder2", 0.35 }, { "Store_Boulder4", 0.5 }, { "Store_Boulder5", 0.7 }, { "Store_Boulder7", 0.4 }, { "Store_Boulder9", 0.45 }, { "Store_Boulder11", 0.35 }, { "Store_Boulder14", 0.5 }, { "Store_Boulder15", 0.4 } }
	local rockCount = 0
	for _ = 1, 2000 do
		if rockCount >= D.MaxBoulders then
			break
		end
		local x, z = rng:NextNumber(-340, 340), rng:NextNumber(-340, 240)
		local R = sqrt(x * x + z * z)
		local u = R - V.EdgeAt(math.deg(math.atan2(x, -z)))
		if u > 4 and u < 40 and open(x, z, 4) then
			local spec = rockKinds[rng:NextInteger(1, #rockKinds)]
			local slope, h = slopeAt(x, z)
			placeModel(KIT[spec[1]], rocks, Vector3.new(x, h - 0.8 - slope * 2, z), rng:NextNumber(0, 2 * math.pi), spec[2] * rng:NextNumber(0.8, 1.4))
			rockCount += 1
		end
	end
	-- prune: trees removed by hand, the magical trees of removed ruin sites, anything else in the clear zones
	local pruned = 0
	for _, e in D.RemovedByHand do
		for _, sub in { trees, magic, specimens } do
			for _, m in sub:GetChildren() do
				local p = m:GetPivot().Position
				if m.Name == e[1] and abs(p.X - e[2]) < 0.5 and abs(p.Z - e[3]) < 0.5 then
					m:Destroy()
					pruned += 1
				end
			end
		end
	end
	for _, s in D.RuinSites do
		if s[5] == false then
			for _, m in magic:GetChildren() do
				local p = m:GetPivot().Position
				if (p.X - s[2].X) ^ 2 + (p.Z - s[2].Z) ^ 2 < 30 * 30 then
					m:Destroy()
					pruned += 1
				end
			end
		end
	end
	for _, sub in { trees, specimens, ferns, flowers, night, rocks } do
		for _, m in sub:GetChildren() do
			local p = m:GetPivot().Position
			if clear(p.X, p.Z) then
				m:Destroy()
				pruned += 1
			end
		end
	end
	return string.format("trees %d, magic trees %d, specimens %d, ferns %d, flower patches %d, night flora %d, boulders %d (generated); %d pruned", count, #magic:GetChildren(), specimenCount, fernCount, patches, nightCount, rockCount, pruned)
end

---------------------------------------------------------------------------------------------------------------
-- Fantasy trees (PropKits.Fantasy, used by BuildNature): teal firs on the slopes, emerald broadleaves on the valley
-- floor (canopies tinted via SurfaceAppearance.Color), star-blossom, crystal and lantern-willow trees where they
-- matter (they glow at night: NightGlow, set in the kit), and one ancient tree on the cliff top beside the waterfall.

D.FantasyTint = { Color3.fromRGB(56, 112, 52), Color3.fromRGB(48, 104, 60), Color3.fromRGB(86, 120, 46) }
D.FantasyHeight = { -- target height range (studs) per kit tree
	Fantasy_EmeraldTree_A = { 30, 40 },
	Fantasy_EmeraldTree_B = { 32, 42 },
	Fantasy_TealFir = { 38, 52 },
	Fantasy_TealFir_B = { 36, 50 },
	Fantasy_StarBlossom = { 28, 36 },
	Fantasy_CrystalTree = { 22, 30 },
	Fantasy_LanternWillow = { 24, 30 },
}
D.AncientTree = { X = -355, Z = 185, Height = 115 } -- cliff top south of the waterfall lip (layout A-N: moved with the waterfall), canopy clear of the falls

function D.PlaceFantasyTree(parent: Instance, name: string, pos: Vector3, rng: Random, withCollider: boolean, height: number?): Model
	local template = ServerStorage.PropKits.Fantasy[name] :: Model
	local range = D.FantasyHeight[name]
	local scale = (height or rng:NextNumber(range[1], range[2])) / (template:GetAttribute("Height") :: number)
	local m = placeModel(template, parent, pos, rng:NextNumber(0, 2 * math.pi), scale)
	local canopyTint = if name:find("TealFir")
		then Color3.fromRGB(44, 104, 84):Lerp(Color3.fromRGB(60, 118, 76), rng:NextNumber())
		elseif name:find("Emerald") then D.FantasyTint[rng:NextInteger(1, #D.FantasyTint)]
		else nil
	if canopyTint then
		for _, d in m:GetDescendants() do
			if d:IsA("MeshPart") and d.Name:find("Canopy") then
				(d:FindFirstChildOfClass("SurfaceAppearance") :: any).Color = canopyTint
			end
		end
	end
	if withCollider then
		collider(m, pos - Vector3.new(0, 0.4, 0), 1.3, 14)
	end
	return m
end

function D.PlaceAncientTree(parent: Instance): Model
	local a = D.AncientTree
	local template = ServerStorage.PropKits.Fantasy.Fantasy_AncientTree :: Model
	local h = V.Height(a.X, a.Z)
	return placeModel(template, parent, Vector3.new(a.X, h - 1.5, a.Z), math.rad(200), a.Height / (template:GetAttribute("Height") :: number))
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

-- { name, position, yaw, pieces, keep }. Removed sites (keep = false, tidy-up 2026-09-28) stay listed: BuildNature
-- still runs its magical-tree placement over every site (so every other tree keeps its spot), then removes theirs.
D.RuinSites = {
	-- layout A-N (2026-10-02): the four kept ruins stand in the open meadow wedges: two beside the W1/E1 and W2/E2 roads
	-- (the old waterfall / low pool names stay), two flanking the lantern avenue
	{ "Ruin_Waterfall", Vector3.new(-125, 0, -48), 70, { "column", "arch", "rune" }, true },
	{ "Ruin_LowPool", Vector3.new(125, 0, -48), -70, { "stump", "fallen", "rune" }, true },
	{ "Ruin_TerraceWest", Vector3.new(-115, 0, -128), 48, { "rune", "step" }, false },
	{ "Ruin_TerraceEast", Vector3.new(115, 0, -128), -48, { "step", "rune" }, false },
	{ "Ruin_MeadowWest", Vector3.new(-100, 0, -30), 70, { "stump", "step", "fallen" }, false }, -- W2 forecourt (Valley rework)
	{ "Ruin_MeadowEast", Vector3.new(105, 0, 22), -70, { "fallen", "column" }, false },
	{ "Ruin_SpireWest", Vector3.new(-64, 0, -140), 90, { "column", "stump" }, true },
	{ "Ruin_SpireEast", Vector3.new(64, 0, -140), -90, { "stump", "column" }, true },
	{ "Ruin_Market", Vector3.new(72, 0, 150), 200, { "rune", "fallen" }, false },
}

function D.BuildRuins()
	local f = B.Folder(SM, "Ruins", true)
	for _, s in D.RuinSites do
		if s[5] ~= false then
			site(f, s[1], s[2], rad(s[3]), s[4])
		end
	end
	-- (the sanctuaries' own ruins come with their looks: ValleyBuild.BuildSanctuaryLooks)
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
				for _, old in arm:GetChildren() do
					if old:IsA("SurfaceGui") then
						old:Destroy() -- a rebuild replaces the words instead of stacking them
					end
				end
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

	-- road lanterns: only the pair on the north road where it leaves the plaza toward the portal terrace (lanterns
	-- elsewhere stand at junctions: the plaza, the bridge ends, the entrance gate, the grand stairs, the sanctuary gates)
	local lamps = B.Folder(f, "RoadLanterns")
	for _, xz in { { -9.5, -78 }, { 9.5, -78 } } do
		B.Lantern(lamps, Vector3.new(xz[1], V.Height(xz[1], xz[2]), xz[2]), 0)
	end

	-- the east cascade: the river drops into the lower pool (streaks + foam from the big waterfall's look)
	local wf = SM.Water:FindFirstChild("Waterfall")
	if wf then
		local cascade = B.Folder(f, "EastCascade")
		-- layout A-N: the river drops into the lower pool at (332, 121); attachments are placed in anchor space (setting
		-- WorldPosition before parenting left them far off, so the beam was never seen)
		local anchor = P(cascade, "BeamAnchor", Vector3.new(1, 1, 1), CFrame.new(313, 0, 113), M.SmoothPlastic, Color3.new(1, 1, 1), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = anchor, anchor
		a0.CFrame = CFrame.new(anchor.CFrame:PointToObjectSpace(Vector3.new(316, -0.9, 114)))
		a1.CFrame = CFrame.new(anchor.CFrame:PointToObjectSpace(Vector3.new(323.5, -6.9, 117)))
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
			fm.CFrame = CFrame.lookAt(Vector3.new(321, -6.6, 116.5), Vector3.new(332, -6.6, 121))
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

---------------------------------------------------------------------------------------------------------------
-- Life (layout A-N, 2026-10-02): everything planted after the sanctuaries moved. Own folder SM.Life (cleared and rebuilt
-- by BuildLife, deterministic): Forest (new trees on the valley edges, same kit and rules as BuildNature), Magic (star-
-- blossom / crystal trees at the gates and beside the ruins), Flowers (patches in the meadow wedges and along the lantern
-- avenue), Lanterns (the avenue on the north road). Run D.BuildRuins() first for the four ruins.

local function gatherTrees(): { Vector3 }
	local out = {}
	for _, fname in { "Trees", "MagicTrees", "Specimens" } do
		local sub = SM.Nature:FindFirstChild(fname)
		for _, m in (if sub then sub:GetChildren() else {}) do
			local p = m:GetPivot().Position
			table.insert(out, Vector3.new(p.X, 0, p.Z))
		end
	end
	return out
end

function D.BuildLife()
	local life = B.Folder(SM, "Life", true)
	local forest = B.Folder(life, "Forest")
	local magic = B.Folder(life, "Magic")
	local flowers = B.Folder(life, "Flowers")
	local lamps = B.Folder(life, "Lanterns")
	local rng = Random.new(5101)
	local placed = gatherTrees()
	local function farFrom(x: number, z: number, d: number): boolean
		for _, p in placed do
			if (p.X - x) ^ 2 + (p.Z - z) ^ 2 < d * d then
				return false
			end
		end
		return true
	end
	local function plant(parent: Instance, name: string, x: number, z: number, collider: boolean, height: number?)
		local slope, h = slopeAt(x, z)
		D.PlaceFantasyTree(parent, name, Vector3.new(x, h - 0.5 - slope * 2, z), rng, collider, height)
		table.insert(placed, Vector3.new(x, 0, z))
	end
	-- the nearest free spot to (cx, cz) (rings of 4 studs, up to maxR)
	local function findSpot(cx: number, cz: number, maxR: number, margin: number, sep: number, ignoreSanct: boolean?): (number?, number?)
		for r = 0, maxR, 4 do
			for k = 0, (if r == 0 then 0 else 11) do
				local a = k * math.pi / 6 + r * 0.7
				local x, z = cx + cos(a) * r, cz + sin(a) * r
				local ok = farFrom(x, z, sep)
				if ok then
					if ignoreSanct then
						local _, level, hint = V.Height(x, z)
						ok = level == nil and hint ~= "paved" and hint ~= "flat" and hint ~= "bed" and hint ~= "rockbed"
					else
						ok = open(x, z, margin)
					end
				end
				if ok then
					return x, z
				end
			end
		end
		return nil, nil
	end

	-- 1) forest replant: the BuildNature grid with its own stream, only where the valley edge is bare (spacing 12 from every tree)
	local FIRS = { "Fantasy_TealFir", "Fantasy_TealFir_B", "Fantasy_TealFir_B" }
	local BROADLEAVES = { "Fantasy_EmeraldTree_A", "Fantasy_EmeraldTree_B" }
	local count = 0
	for gx = -560, 560, 15 do
		for gz = -560, 560, 15 do
			local x, z = gx + rng:NextNumber(-6, 6), gz + rng:NextNumber(-6, 6)
			local R = sqrt(x * x + z * z)
			local th = math.deg(math.atan2(x, -z))
			local u = R - V.EdgeAt(th)
			if u > -45 and count < D.MaxLifeTrees then
				local slope, h = slopeAt(x, z)
				local base = if u < 0 then 0.16 elseif u < 130 then 0.42 else 0.12
				local cluster = math.clamp((0.5 + noise(x / 110, z / 110, 4.2)) * 1.6, 0.1, 1.3)
				local p = base * cluster
				if R > 290 and saddleDistance(th) < 9 then
					p *= 0.25
				end
				if h < 130 and slope < 1.2 and rng:NextNumber() < p and farFrom(x, z, 12) and open(x, z, 8) and not clear(x, z) then
					local list = if u > 60 or h > 50 then FIRS
						elseif u > 0 then (if rng:NextNumber() < 0.5 then FIRS else BROADLEAVES)
						else (if rng:NextNumber() < 0.8 then BROADLEAVES else FIRS)
					plant(forest, list[rng:NextInteger(1, #list)], x, z, u < 32)
					count += 1
				end
			end
		end
	end

	-- 2) lantern avenue: the north road from the plaza to the grand stairs, a pair every 22 studs (the first pair stands at z -78)
	for _, z in { -100, -122, -144 } do
		for _, sd in { -1, 1 } do
			B.Lantern(lamps, Vector3.new(sd * 9.5, V.Height(sd * 9.5, z), z), 0)
		end
	end
	-- star-blossom trees framing the avenue, crystal trees further up (clear of the road and the lanterns)
	for _, sd in { -1, 1 } do
		plant(magic, "Fantasy_StarBlossom", sd * 24, -92, true)
		plant(magic, "Fantasy_CrystalTree", sd * 26, -134, true)
	end

	-- 3) a pair of star-blossoms at each sanctuary gate, outside the forecourt (center + 100 toward the altar, +-34 across)
	for _, sanct in V.Sanct do
		local out = Vector2.new(-sanct.X, -sanct.Z).Unit
		local across = Vector2.new(-out.Y, out.X)
		for _, sgn in { -1, 1 } do
			local x, z = sanct.X + out.X * 100 + across.X * 34 * sgn, sanct.Z + out.Y * 100 + across.Y * 34 * sgn
			local sx, sz = findSpot(x, z, 16, 3, 10, true)
			if sx then
				plant(magic, "Fantasy_StarBlossom", sx, sz, true)
			end
		end
	end

	-- 4) trees beside each ruin (a star-blossom and a crystal tree on different sides)
	for i, s in D.RuinSites do
		if s[5] ~= false then
			for j, name in { "Fantasy_StarBlossom", "Fantasy_CrystalTree" } do
				local a = (i * 1.3 + j * 3.1)
				local sx, sz = findSpot(s[2].X + cos(a) * 15, s[2].Z + sin(a) * 15, 14, 4, 9)
				if sx then
					plant(magic, name, sx, sz, true)
				end
			end
		end
	end

	-- 5) flower patches in the meadow wedges and beside the avenue (own stream; 9-13 flowers per patch)
	local kinds = { KIT.AI_Ench_Lupines, KIT.AI_Ench_Buttercups, KIT.AI_Ench_Daisies, KIT.Store_WildFlower }
	local frng = Random.new(6203)
	local patchCenters = {
		{ -48, -72 }, { 48, -72 }, { -78, -118 }, { 78, -118 }, { -44, -152 }, { 44, -152 }, -- the avenue field
		{ -118, -22 }, { 118, -22 }, { -112, -70 }, { 112, -70 }, -- the W / E wedges
		{ -86, 118 }, { 86, 118 }, { -30, 214 }, { 30, 214 }, -- by the market and the entrance gorge
	}
	local patches = 0
	for _, c in patchCenters do
		local cx, cz = findSpot(c[1], c[2], 14, 6, 6)
		if cx then
			local mainKind = kinds[frng:NextInteger(1, #kinds)]
			for _ = 1, frng:NextInteger(9, 13) do
				local a, r = frng:NextNumber(0, 2 * math.pi), sqrt(frng:NextNumber()) * 8
				local px, pz = cx + cos(a) * r, cz + sin(a) * r
				if open(px, pz, 1) then
					local _, h = slopeAt(px, pz)
					local kind = if frng:NextNumber() < 0.75 then mainKind else kinds[frng:NextInteger(1, #kinds)]
					local m = placeModel(kind, flowers, Vector3.new(px, h - 0.1, pz), frng:NextNumber(0, 2 * math.pi), frng:NextNumber(1, 1.6))
					for _, d in m:GetDescendants() do
						if d:IsA("BasePart") then
							d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
						end
					end
				end
			end
			patches += 1
		end
	end
	return string.format("forest %d, magic %d, patches %d, lanterns %d", count, #magic:GetChildren(), patches, #lamps:GetChildren())
end

---------------------------------------------------------------------------------------------------------------
-- Simplify (2026-10-04): the kid-friendly Roblox look (KISS). Prunes what BuildNature / BuildLife / BuildRuins / BuildTiles /
-- BuildDressing placed, by rule (deterministic, safe to run twice): a line of big firs on the foothills, friendly trees only at
-- the landmarks, a few flower patches, no ruins/ferns/boulders/night flora/tiles/avenue or road lanterns, fewer lily pads, crates
-- and gate crystals; night glow only on the altar, portals, gates and Spire; small parts cast no shadow, decoration is not
-- touchable/queryable. If any Build* above is ever re-run, run D.Simplify() right after it.
D.Simplify = {
	FirBand = { 0, 110 }, -- foothill firs kept: this far past the valley edge (studs, V.EdgeAt)
	FirSpacing = 50, -- at least this far apart, tallest first
	MaxFirs = 42,
	-- Life.Flowers patches kept (BuildLife patch centers): the W/E wedges, the market, the entrance, the plaza's north field
	FlowerPatches = { { -118, -22 }, { 118, -22 }, { -112, -70 }, { 112, -70 }, { -86, 118 }, { 86, 118 }, { -30, 214 }, { 30, 214 }, { -48, -72 }, { 48, -72 } },
	FlowersPerPatch = 7,
	LilyPads = 6,
	MarketProps = { { 36, 124 }, { 38, 128 }, { -38, 102 }, { -38, 108 } }, -- the crates/barrels kept
	SmallShadow = 4, -- parts whose biggest side is under this cast no shadow
	-- star-blossom canopies (SurfaceAppearance.Color multiplies the near-white leaves): soft pink and lilac, alternating, instead of
	-- the washed-out cream; GlowStrength lowered (only used if a canopy is ever tagged NightGlow again)
	BlossomTints = { Color3.fromRGB(240, 160, 200), Color3.fromRGB(196, 168, 245) },
	BlossomGlow = 0.25,
}

function D.RunSimplify(): string
	local S = D.Simplify
	local removed = 0
	local function kill(inst: Instance)
		inst:Destroy()
		removed += 1
	end
	local function flat(p: Vector3): Vector2
		return Vector2.new(p.X, p.Z)
	end
	-- 1) forest: keep a spaced line of the tallest firs on the foothills; every other forest tree goes
	local candidates = {}
	for _, fold in { SM.Nature:FindFirstChild("Trees"), SM.Life:FindFirstChild("Forest") } do
		for _, m in (if fold then fold:GetChildren() else {}) do
			local p = m:GetPivot().Position
			local u = sqrt(p.X * p.X + p.Z * p.Z) - V.EdgeAt(math.deg(math.atan2(p.X, -p.Z)))
			local _, size = m:GetBoundingBox()
			if string.find(m.Name, "TealFir") and u >= S.FirBand[1] and u <= S.FirBand[2] then
				table.insert(candidates, { Model = m, At = flat(p), Height = size.Y })
			else
				kill(m)
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.Height > b.Height
	end)
	local kept = {}
	for _, c in candidates do
		local ok = #kept < S.MaxFirs
		for _, k in kept do
			if ok and (k.At - c.At).Magnitude < S.FirSpacing then
				ok = false
			end
		end
		if ok then
			table.insert(kept, c)
		else
			kill(c.Model)
		end
	end
	-- 2) magical trees: the star-blossom pair at each sanctuary gate + the pair at the avenue start (Life.Magic) and the two
	-- crystal trees framing the altar's north approach (Nature.MagicTrees) stay; the ruin and avenue-top trees go
	local spots = { Vector2.new(-24, -92), Vector2.new(24, -92) }
	for _, sanct in V.Sanct do
		local out = Vector2.new(-sanct.X, -sanct.Z).Unit
		local across = Vector2.new(-out.Y, out.X)
		for _, sgn in { -1, 1 } do
			table.insert(spots, Vector2.new(sanct.X, sanct.Z) + out * 100 + across * 34 * sgn)
		end
	end
	for _, m in SM.Life.Magic:GetChildren() do
		local near = false
		for _, s in spots do
			near = near or (flat(m:GetPivot().Position) - s).Magnitude < 20
		end
		if not (near and m.Name == "Fantasy_StarBlossom") then
			kill(m)
		end
	end
	-- 3) whole folders that go
	for _, path in { { "Ruins" }, { "Tiles" }, { "Nature", "Ferns" }, { "Nature", "Boulders" }, { "Nature", "NightFlora" }, { "Nature", "Flowers" }, { "Life", "Lanterns" }, { "Dressing", "RoadLanterns" } } do
		local node: Instance? = SM
		for _, name in path do
			node = node and node:FindFirstChild(name)
		end
		for _, c in (if node then node:GetChildren() else {}) do
			kill(c)
		end
	end
	-- 4) flowers: the kept patches, the nearest FlowersPerPatch to each center
	local keepFlowers = {}
	for _, c in S.FlowerPatches do
		local center = Vector2.new(c[1], c[2])
		local list = {}
		for _, m in SM.Life.Flowers:GetChildren() do
			local d = (flat(m:GetPivot().Position) - center).Magnitude
			if d < 26 then
				table.insert(list, { Model = m, D = d })
			end
		end
		table.sort(list, function(a, b)
			return a.D < b.D
		end)
		for i = 1, math.min(S.FlowersPerPatch, #list) do
			keepFlowers[list[i].Model] = true
		end
	end
	for _, m in SM.Life.Flowers:GetChildren() do
		if not keepFlowers[m] then
			kill(m)
		end
	end
	-- 5) dressing: fewer lily pads, crates/barrels and portal crystals (the biggest cluster per portal)
	local pads = SM.Dressing.LilyPads:GetChildren()
	table.sort(pads, function(a, b)
		local pa, pb = (a :: any).Position, (b :: any).Position
		return if pa.X ~= pb.X then pa.X < pb.X else pa.Z < pb.Z
	end)
	local padKept = {}
	for _, pad in pads do
		local p = flat((pad :: any).Position)
		local ok = #padKept < S.LilyPads
		for _, k in padKept do
			ok = ok and (k - p).Magnitude > 20
		end
		if ok then
			table.insert(padKept, p)
		else
			kill(pad)
		end
	end
	for _, m in SM.Dressing.MarketProps:GetChildren() do
		local p = flat(if m:IsA("Model") then m:GetPivot().Position else (m :: any).Position)
		local keep = false
		for _, k in S.MarketProps do
			keep = keep or (p - Vector2.new(k[1], k[2])).Magnitude < 1.5
		end
		if not keep then
			kill(m)
		end
	end
	local best: { [string]: Model } = {}
	for _, m in SM.Dressing.GateCrystals:GetChildren() do
		local _, size = (m :: Model):GetBoundingBox()
		local b = best[m.Name]
		if b == nil or select(2, b:GetBoundingBox()).Magnitude < size.Magnitude then
			best[m.Name] = m :: Model
		end
	end
	for _, m in SM.Dressing.GateCrystals:GetChildren() do
		if best[m.Name] ~= m then
			kill(m)
		end
	end
	-- 6) night glow only on the altar, portals, gates and Spire
	for _, inst in CollectionService:GetTagged("NightGlow") do
		if inst:IsDescendantOf(SM.Bridges) or inst:IsDescendantOf(SM.Life) or inst:IsDescendantOf(SM.Nature.MagicTrees)
			or inst:IsDescendantOf(SM.Market) then
			CollectionService:RemoveTag(inst, "NightGlow")
		end
	end
	-- 7) cheap flags: small parts cast no shadow; decoration can't be touched or hit by queries
	local shadowsOff = 0
	for _, d in SM:GetDescendants() do
		if d:IsA("BasePart") and d.CastShadow and math.max(d.Size.X, d.Size.Y, d.Size.Z) < S.SmallShadow then
			d.CastShadow = false
			shadowsOff += 1
		end
	end
	for _, fold in { SM.Life.Flowers, SM.Dressing.LilyPads, SM.Dressing.GateCrystals, SM.Plaza.CrystalRing } do
		for _, d in fold:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanTouch, d.CanQuery = false, false
			end
		end
	end
	for _, fold in { SM.Nature.Trees, SM.Life.Forest, SM.Life.Magic, SM.Nature.MagicTrees, SM.Nature.Landmark } do
		for _, d in fold:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "TrunkCollider" then
				d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
			end
		end
	end
	-- 8) star-blossom tint (sorted by position so the pink/lilac pattern is the same on every run)
	local blossoms = {}
	for _, m in SM.Life.Magic:GetChildren() do
		if m.Name == "Fantasy_StarBlossom" then
			table.insert(blossoms, m)
		end
	end
	table.sort(blossoms, function(a, b)
		local pa, pb = a:GetPivot().Position, b:GetPivot().Position
		return if pa.X ~= pb.X then pa.X < pb.X else pa.Z < pb.Z
	end)
	for i, m in blossoms do
		for _, d in m:GetDescendants() do
			if d:IsA("SurfaceAppearance") and d.Parent and string.find(d.Parent.Name, "Canopy") then
				d.Color = S.BlossomTints[(i - 1) % #S.BlossomTints + 1]
				d.Parent:SetAttribute("GlowStrength", S.BlossomGlow)
			end
		end
	end
	return string.format("removed %d, firs %d, magic %d, flowers %d, small shadows off %d", removed, #kept, #SM.Life.Magic:GetChildren(), #SM.Life.Flowers:GetChildren(), shadowsOff)
end

-- Foothill life (Simplify 2026-10-04): the big grass slopes read as one flat green wall, so they get two close shades of bright
-- green in big soft patches (terrain Grass + Mud recolored a little darker; Mud's Valley_ForestA variant is the same texture,
-- without grass blades) and a few big friendly broadleaf trees spread over the lower foothills (one per bearing sector at a
-- random distance, so never in a line), below the fir line. Deterministic and safe to run twice (it repaints the patches from
-- scratch and rebuilds its own folder SM.Life.Foothills). Terrain materials only, no shape change.
D.Foothills = {
	PatchAbove = 18, -- only ground above this height (the slopes; the valley floor and terraces stay plain)
	PatchScale = 210, -- studs per noise cycle: big patches
	PatchDetail = 0.3, -- share of a second, finer (x2.3) noise in the patch edges
	PatchThreshold = 0.06, -- noise above this = the darker shade
	Light = Color3.fromRGB(122, 152, 58), -- terrain Grass (unchanged)
	Dark = Color3.fromRGB(84, 126, 44), -- terrain Mud: a close darker bright green (no teal)
	Trees = 12, -- one per 30-degree bearing sector (sectors with no free spot get none)
	TreeBand = { 8, 70 }, -- studs past the valley edge (V.EdgeAt): the lower foothills, below the fir line
	TreeHeight = { 44, 54 },
	TreeSpacing = 60, -- from each other
	TreeClear = 22, -- from any other tree
	Kinds = { "Fantasy_EmeraldTree_A", "Fantasy_EmeraldTree_B" },
	Seed = 7201,
}

function D.RunFoothills(): string
	local F = D.Foothills
	local T = workspace.Terrain
	local Mt = Enum.Material
	-- 1) patches
	T:SetMaterialColor(Mt.Grass, F.Light)
	T:SetMaterialColor(Mt.Mud, F.Dark)
	local RES = 4
	local painted = 0
	for cx = -1024, 768, 256 do
		for cz = -1024, 768, 256 do
			local region = Region3.new(Vector3.new(cx, -48, cz), Vector3.new(cx + 256, 304, cz + 256)):ExpandToGrid(RES)
			local ch = T:ReadVoxelChannels(region, RES, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" })
			local mat = ch.SolidMaterial
			local sx, sy, sz = region.Size.X / RES, region.Size.Y / RES, region.Size.Z / RES
			local minX = region.CFrame.Position.X - region.Size.X / 2
			local minY = region.CFrame.Position.Y - region.Size.Y / 2
			local minZ = region.CFrame.Position.Z - region.Size.Z / 2
			local any = false
			for x = 1, sx do
				local wx = minX + (x - 0.5) * RES
				for z = 1, sz do
					local wz = minZ + (z - 0.5) * RES
					local n = noise(wx / F.PatchScale, wz / F.PatchScale, 3.7) + F.PatchDetail * noise(wx / F.PatchScale * 2.3, wz / F.PatchScale * 2.3, 9.1)
					local dark = n > F.PatchThreshold
					for y = 1, sy do
						local wy = minY + (y - 0.5) * RES
						local m = mat[x][y][z]
						if m == Mt.Mud then
							mat[x][y][z] = Mt.Grass -- start clean (safe to run twice)
							m = Mt.Grass
							any = true
						end
						if m == Mt.Grass and wy > F.PatchAbove and dark then
							mat[x][y][z] = Mt.Mud
							painted += 1
							any = true
						end
					end
				end
			end
			if any then
				T:WriteVoxelChannels(region, RES, { SolidMaterial = mat, SolidOccupancy = ch.SolidOccupancy, LiquidOccupancy = ch.LiquidOccupancy })
			end
		end
	end
	-- 2) a few big friendly trees on the lower foothills
	local life = SM:FindFirstChild("Life") or B.Folder(SM, "Life")
	local folder = B.Folder(life, "Foothills", true)
	local others = {}
	for _, fold in { SM.Nature:FindFirstChild("Trees"), SM.Nature:FindFirstChild("MagicTrees"), SM.Nature:FindFirstChild("Landmark"), life:FindFirstChild("Forest"), life:FindFirstChild("Magic") } do
		for _, m in (if fold then fold:GetChildren() else {}) do
			local p = m:GetPivot().Position
			table.insert(others, Vector2.new(p.X, p.Z))
		end
	end
	local rng = Random.new(F.Seed)
	local placed = {}
	local step = 360 / F.Trees
	for sector = 0, F.Trees - 1 do
		for _ = 1, 60 do
			local th = (sector + rng:NextNumber(0.1, 0.9)) * step - 180
			local u = rng:NextNumber(F.TreeBand[1], F.TreeBand[2])
			local R = V.EdgeAt(th) + u
			local x, z = math.sin(math.rad(th)) * R, -math.cos(math.rad(th)) * R
			local at = Vector2.new(x, z)
			local slope, h = slopeAt(x, z)
			local ok = slope < 1.1 and h > 4 and h < 110 and open(x, z, 8) and not clear(x, z)
			for _, p in placed do
				ok = ok and (p - at).Magnitude >= F.TreeSpacing
			end
			for _, p in others do
				ok = ok and (p - at).Magnitude >= F.TreeClear
			end
			if ok then
				local kind = F.Kinds[rng:NextInteger(1, #F.Kinds)]
				D.PlaceFantasyTree(folder, kind, Vector3.new(x, h - 0.5 - slope * 2, z), rng, u < 32, rng:NextNumber(F.TreeHeight[1], F.TreeHeight[2]))
				table.insert(placed, at)
				break
			end
		end
	end
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "TrunkCollider" then
			d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
		end
	end
	return string.format("dark patch voxels %d, foothill trees %d", painted, #folder:GetChildren())
end

return D
