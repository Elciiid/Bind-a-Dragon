-- Crystal Garden look kit (Valley rework checkpoint 3). Studio build helper, not used by the game.
-- Polished white-and-gold marble, star-blue crystals, star-blossom trees. Same slots as every look (ValleyTerrain V.Slots);
-- built into ReplicatedStorage.Assets.SanctuaryLooks.CrystalGarden.<PlotName> (see SanctuaryLooks for the piece rules).
-- Methods: code parts (gate, wall, path, plaza, pool, fountain, small crystals), AI meshes from
-- ServerStorage.PropKits.SanctuaryLooks (Studio generate_mesh: CG_Crystal centerpiece, CG_Pillar perch pillars,
-- CG_CrystalCluster), and the existing Fantasy (star-blossom trees) / Meadow (nests) prop kits. No Blender pieces.
-- Usage: local C = require(ServerStorage.RemasterTools.SanctuaryLooksCrystal:Clone()); C.Build(); L.Preview("RoostPlot6", "CrystalGarden")
-- The live copy is ServerStorage.RemasterTools.SanctuaryLooksCrystal in the place; this file is the reference copy.
local ServerStorage = game:GetService("ServerStorage")

local C = {}
local L = require(ServerStorage.RemasterTools.SanctuaryLooks:Clone())
local H = L.H
local B, V = H.B, H.V
local Slots = V.Slots
local M = Enum.Material
local rad, sin, cos = math.rad, math.sin, math.cos
local P, Disc, Star, Glow = B.P, B.Disc, B.Star, B.Glow
local Colors = B.Colors
local LOOKS = ServerStorage.PropKits.SanctuaryLooks
local MEADOW = ServerStorage.PropKits.Meadow
local ENCH = ServerStorage.PropKits.Enchanted
local FANTASY = ServerStorage.PropKits.Fantasy
local SM = workspace:WaitForChild("StarterMeadow")

local CG = {
	Marble = Color3.fromRGB(238, 236, 230),
	MarbleShade = Color3.fromRGB(212, 210, 206),
	Gold = Colors.Gold,
	GoldSoft = Color3.fromRGB(104, 80, 38), -- soft night glow of the gold (toned down)
	Crystal = Color3.fromRGB(140, 200, 255),
	CrystalGlow = Color3.fromRGB(56, 92, 150),
	Water = Color3.fromRGB(110, 196, 232),
}
C.Colors = CG

-- A code-built crystal: a glass column rotated 45 degrees with a pointed cap, growing from base (glows softly at night).
local function crystal(parent: Instance, base: CFrame, h: number, w: number)
	local body = P(parent, "Crystal", Vector3.new(w, h, w), base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, rad(45), 0), M.Glass, CG.Crystal, { CanCollide = false, Transparency = 0.12 })
	Glow(body, CG.CrystalGlow)
	local tip = P(parent, "CrystalTip", Vector3.new(w * 0.72, w * 0.72, w * 0.72), base * CFrame.new(0, h + w * 0.05, 0) * CFrame.Angles(rad(45), rad(45), 0), M.Glass, CG.Crystal, { CanCollide = false, Transparency = 0.12 })
	Glow(tip, CG.CrystalGlow)
end

-- Open ground in local slot coordinates (no zones, perches, path, pool, gate approach), inside the wall.
local function openGround(x: number, y: number, pad: number?): boolean
	local extra = pad or 0
	local function near(cx: number, cy: number, r: number): boolean
		return (x - cx) ^ 2 + (y - cy) ^ 2 < (r + extra) ^ 2
	end
	if x * x + y * y > 66 * 66 or y > 68 or (math.abs(x) < 16 and y > 58) then
		return false
	end
	local w, nz = Slots.Water, Slots.Nest
	if near(Slots.Center.X, Slots.Center.Y, 30) or near(w.X, w.Y, w.R + 5) or near(nz.X, nz.Y, nz.R + 2) then
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
	if math.abs(x - 6 * sin(y / 14)) < 6 and y > -10 then
		return false
	end
	return true
end

function C.BuildPlot(plot: Model, kitRoot: Folder)
	local ctx = H.context(plot)
	local T, at, frame = ctx.T, ctx.at, ctx.frame
	local piece, prop, stretched = H.piece, H.prop, H.stretched
	local kit = B.Folder(kitRoot, plot.Name, true)
	local rng = Random.new(2000 + tonumber(string.match(plot.Name, "%d+")) :: number)
	local gy, gh, gx = Slots.Gate, Slots.GateHeight, Slots.GateHalf

	-- gate: two round marble columns with gold bands, carved rune glyphs and crystals on top, a marble lintel
	-- with gold trim and a star; no statues
	piece(kit, "Gate", frame(0, gy, 0), function(m)
		for _, sd in { -gx, gx } do
			local col = P(m, "Column", Vector3.new(gh - 4, 4.4, 4.4), frame(sd, gy, 1.6 + (gh - 4) / 2) * CFrame.Angles(0, 0, math.pi / 2), M.Marble, CG.Marble)
			col.Shape = Enum.PartType.Cylinder
			Disc(m, "Base", at(sd, gy, 0.8), 4.6, 1.6, M.Marble, CG.MarbleShade)
			Disc(m, "BaseGold", at(sd, gy, 1.75), 3.3, 0.3, M.Foil, CG.Gold, { CanCollide = false })
			for _, h in { 7, gh - 7 } do
				Glow(Disc(m, "Band", at(sd, gy, h), 2.5, 0.6, M.Foil, CG.Gold, { CanCollide = false }), CG.GoldSoft)
			end
			Disc(m, "Capital", at(sd, gy, gh - 2.6), 3.6, 1.2, M.Marble, CG.MarbleShade)
			for k, h in { 10, 14, 18, 22 } do -- carved glyphs down the front of the column
				Glow(P(m, "Glyph", Vector3.new(1.3, 1.3, 0.15), frame(sd, gy + 2.25, h) * CFrame.Angles(0, 0, rad(45)), M.Foil, CG.Gold, { CanCollide = false }), CG.GoldSoft)
			end
			crystal(m, CFrame.new(at(sd * 1.22, gy, gh + 0.2)) * CFrame.Angles(0, 0, 0), 8, 2.4)
			crystal(m, CFrame.new(at(sd * 1.0, gy + 1.2, gh + 0.2)), 4.6, 1.4)
		end
		P(m, "Lintel", Vector3.new(2 * gx + 8, 3.2, 4.4), frame(0, gy, gh - 1.4), M.Marble, CG.Marble)
		P(m, "LintelTrimFront", Vector3.new(2 * gx + 8.2, 0.4, 0.4), frame(0, gy + 2.3, gh - 2.6), M.Foil, CG.Gold, { CanCollide = false })
		P(m, "LintelCap", Vector3.new(2 * gx + 8.4, 0.4, 4.8), frame(0, gy, gh + 0.4), M.Foil, CG.Gold, { CanCollide = false })
		Star(m, frame(0, gy + 2.6, gh - 1.4), 4.5, CG.GoldSoft)
		for _, sd in { -5, 5 } do
			P(m, "SignChain", Vector3.new(0.3, 7.3, 0.3), frame(sd, gy, 21.2), M.Metal, Colors.Iron, { CanCollide = false })
		end
		H.light(m, at(0, gy + 3, gh - 6), CG.Crystal, 1.2, 38)
	end)

	-- rim wall: polished white marble with a gold cap, a crystal post at the start of every arc (7 arcs of 4 segments)
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
			local function post(deg: number)
				local p = at(sin(rad(deg)) * Slots.Rim, cos(rad(deg)) * Slots.Rim, 0)
				local cf = ctx.faceCenter(p)
				P(m, "Post", Vector3.new(3, 8.6, 3), cf * CFrame.new(0, 4.3, 0), M.Marble, CG.Marble)
				P(m, "PostCap", Vector3.new(3.6, 0.5, 3.6), cf * CFrame.new(0, 8.8, 0), M.Foil, CG.Gold, { CanCollide = false })
				crystal(m, cf * CFrame.new(0, 9, 0), 5.6, 1.7)
			end
			post(group[1] - 6)
			if i == #arcs then
				post(group[#group] + 6)
			end
			for _, deg in group do
				local a = rad(deg)
				local p = at(sin(a) * Slots.Rim, cos(a) * Slots.Rim, 2.8)
				local cf = ctx.faceCenter(p)
				local len = 2 * Slots.Rim * sin(rad(6)) + 0.9
				P(m, "Wall", Vector3.new(len, 5.6, 3), cf, M.Marble, CG.Marble)
				P(m, "WallCap", Vector3.new(len + 0.2, 0.4, 3.5), cf * CFrame.new(0, 3, 0), M.Foil, CG.Gold, { CanCollide = false })
				P(m, "WallBand", Vector3.new(len - 2, 0.3, 0.2), cf * CFrame.new(0, 0.4, 1.55), M.Foil, CG.Gold, { CanCollide = false })
			end
		end)
	end

	-- the centerpiece: a giant star-blue crystal on a stone base (AI mesh), on a marble plaza with a gold ring inlay
	local cp = at(Slots.Center.X, Slots.Center.Y, 0)
	piece(kit, "Crystal", CFrame.lookAt(cp, cp + ctx.Fwd), function(m)
		Disc(m, "Plaza", cp + Vector3.new(0, 0.2, 0), 15.5, 0.6, M.Marble, CG.Marble)
		Glow(Disc(m, "PlazaRing", cp + Vector3.new(0, 0.52, 0), 14.3, 0.1, M.Foil, CG.Gold, { CanCollide = false }), CG.GoldSoft)
		Disc(m, "PlazaInner", cp + Vector3.new(0, 0.56, 0), 13.6, 0.12, M.Marble, CG.Marble, { CanCollide = false })
		prop(m, LOOKS.CG_Crystal, CFrame.lookAt(cp + Vector3.new(0, 0.4, 0), cp + Vector3.new(0, 0.4, 0) + ctx.Fwd), Slots.Center.MaxHeight / 44, false)
		P(m, "BaseCollider", Vector3.new(6, 20, 20), CFrame.new(cp + Vector3.new(0, 3.4, 0)) * CFrame.Angles(0, 0, math.pi / 2), M.SmoothPlastic, Color3.new(1, 1, 1), { Shape = Enum.PartType.Cylinder, Transparency = 1, CanCollide = true, CanQuery = false })
		for k = 0, 7 do
			local a = k * math.pi / 4 + math.pi / 8
			crystal(m, CFrame.new(cp + Vector3.new(cos(a) * 14.6, 0.6, sin(a) * 14.6)), 3.8, 1.2)
		end
		H.light(m, cp + Vector3.new(0, 18, 0), CG.Crystal, 2.6, 62)
	end)

	-- perches: white marble pillars with gold rims (AI mesh, stretched to the pad), crystal clusters on the rims
	for i, pl in Slots.ElderPerches do
		local base = at(pl[1], pl[2], -1)
		piece(kit, "Pillar" .. i, CFrame.new(at(pl[1], pl[2], 0)), function(m)
			stretched(m, LOOKS.CG_Pillar, ctx.faceCenter(base), Vector3.new(V.PillarR * 2, pl[3] + 1, V.PillarR * 2), true)
			local top = at(pl[1], pl[2], pl[3])
			local outward = Vector3.new(top.X - ctx.Center.X, 0, top.Z - ctx.Center.Z).Unit
			for _, turn in { -0.6, 0.6 } do
				local dir = CFrame.Angles(0, turn, 0):VectorToWorldSpace(outward)
				prop(m, LOOKS.CG_CrystalCluster, CFrame.lookAt(top + dir * 8.2, top + dir * 9), 1.15, false)
			end
		end)
	end
	for i, pl in Slots.DragonPerches do
		local base = at(pl[1], pl[2], -1)
		piece(kit, "Pedestal" .. i, CFrame.new(at(pl[1], pl[2], 0)), function(m)
			stretched(m, LOOKS.CG_Pillar, ctx.faceCenter(base), Vector3.new(14, pl[3] + 1, 14), true)
			local top = at(pl[1], pl[2], pl[3])
			local outward = Vector3.new(top.X - ctx.Center.X, 0, top.Z - ctx.Center.Z).Unit
			prop(m, LOOKS.CG_CrystalCluster, CFrame.lookAt(top + outward * 6, top + outward * 7), 0.9, false)
		end)
	end

	-- path: white marble slabs from the gate toward the plaza (5 a piece)
	local group, y = 0, gy - 6
	local batch: { CFrame } = {}
	local function flush()
		if #batch == 0 then
			return
		end
		group += 1
		piece(kit, "Path" .. group, CFrame.new(batch[1].Position), function(m)
			for _, cf in batch do
				P(m, "Slab", Vector3.new(4.8, 0.5, 4.8), cf * CFrame.new(0, 0.2, 0), M.Marble, CG.Marble)
			end
		end)
		batch = {}
	end
	while y > Slots.Center.Y + 28 do
		table.insert(batch, CFrame.new(at(6 * sin(y / 14) + rng:NextNumber(-0.6, 0.6), y, 0)) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0))
		if #batch >= 5 then
			flush()
		end
		y -= 5.6
	end
	flush()

	-- the crystal-lined pool with a small fountain
	local w = Slots.Water
	piece(kit, "Pool", CFrame.new(at(w.X, w.Y, 0)), function(m)
		local wc = at(w.X, w.Y, 0)
		Disc(m, "Bed", wc + Vector3.new(0, 0.15, 0), w.R + 1, 0.3, M.Marble, CG.MarbleShade, { CanCollide = false })
		Disc(m, "Water", wc + Vector3.new(0, 0.42, 0), w.R, 0.4, M.Glass, CG.Water, { Transparency = 0.3, CanCollide = false })
		for k = 0, 17 do -- marble rim with a gold trim
			local a = k * math.pi * 2 / 18
			local rp = at(w.X + cos(a) * (w.R + 1.4), w.Y + sin(a) * (w.R + 1.4), 0.9)
			local cf = CFrame.lookAt(rp, wc + Vector3.new(0, 0.9, 0))
			P(m, "Rim", Vector3.new(6.4, 1.8, 3.6), cf, M.Marble, CG.Marble)
			P(m, "RimGold", Vector3.new(6.2, 0.2, 0.3), cf * CFrame.new(0, 0.95, 1.5), M.Foil, CG.Gold, { CanCollide = false })
		end
		for k = 0, 11 do -- crystal lining inside the rim
			local a = k * math.pi * 2 / 12 + 0.2
			crystal(m, CFrame.new(at(w.X + cos(a) * (w.R - 1), w.Y + sin(a) * (w.R - 1), 0.5)) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25)), rng:NextNumber(2.4, 4.2), 1)
		end
		for _, a in { 0.5, 2.5, 4.4 } do
			prop(m, LOOKS.CG_CrystalCluster, CFrame.lookAt(at(w.X + cos(a) * (w.R + 4.6), w.Y + sin(a) * (w.R + 4.6), 0), wc), 1.0, false)
		end
		-- fountain: pedestal, bowl, column, sparkle jets
		Disc(m, "FountainBase", wc + Vector3.new(0, 0.9, 0), 4.2, 1.2, M.Marble, CG.Marble)
		local stem = P(m, "FountainStem", Vector3.new(4.2, 2.2, 2.2), CFrame.new(wc + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), M.Marble, CG.Marble)
		stem.Shape = Enum.PartType.Cylinder
		Disc(m, "FountainBowl", wc + Vector3.new(0, 5.4, 0), 4.4, 0.7, M.Marble, CG.Marble)
		Disc(m, "FountainBowlGold", wc + Vector3.new(0, 5.8, 0), 4.5, 0.2, M.Foil, CG.Gold, { CanCollide = false })
		Disc(m, "FountainWater", wc + Vector3.new(0, 5.85, 0), 3.8, 0.15, M.Glass, CG.Water, { Transparency = 0.3, CanCollide = false })
		local top = P(m, "FountainJet", Vector3.new(0.4, 0.4, 0.4), CFrame.new(wc + Vector3.new(0, 6, 0)), M.SmoothPlastic, Color3.new(1, 1, 1), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
		local jet = Instance.new("ParticleEmitter")
		jet.Name = "Fountain"
		jet.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		jet.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255), Color3.fromRGB(120, 200, 240))
		jet.LightEmission = 0.6
		jet.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.2) })
		jet.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.9) })
		jet.Lifetime = NumberRange.new(1, 1.5)
		jet.Speed = NumberRange.new(13, 17)
		jet.SpreadAngle = Vector2.new(10, 10)
		jet.Acceleration = Vector3.new(0, -32, 0)
		jet.Rate = 34
		jet.EmissionDirection = Enum.NormalId.Top
		jet.Parent = top
	end)

	-- basking slabs: marble with a gold inlay ring
	for i, b in Slots.Bask do
		piece(kit, "Bask" .. i, CFrame.new(at(b[1], b[2], 0)), function(m)
			Disc(m, "Slab", at(b[1], b[2], 0.8), 9, 1.6, M.Marble, CG.Marble)
			Glow(Disc(m, "SlabRing", at(b[1], b[2], 1.62), 8.3, 0.1, M.Foil, CG.Gold, { CanCollide = false }), CG.GoldSoft)
			Disc(m, "SlabInner", at(b[1], b[2], 1.66), 7.7, 0.12, M.Marble, CG.Marble, { CanCollide = false })
		end)
	end

	-- nests and a crystal beside them
	local nz = Slots.Nest
	piece(kit, "Nests", CFrame.new(at(nz.X, nz.Y, 0)), function(m)
		for _, off in { { 0, 0 }, { 10, -9 } } do
			prop(m, MEADOW.AI_Meadow_Nest, CFrame.new(at(nz.X + off[1], nz.Y + off[2], 0)) * CFrame.Angles(0, off[1] * 0.3, 0), 1.3, false)
		end
		prop(m, MEADOW.AI_Meadow_HayBales, CFrame.new(at(nz.X + 14, nz.Y + 5, 0)) * CFrame.Angles(0, 0.6, 0), 1.7, false)
		prop(m, LOOKS.CG_CrystalCluster, CFrame.new(at(nz.X - 12, nz.Y - 4, 0)), 1.2, false)
	end)

	-- six star-blossom trees on open ground, spread apart
	local placed: { { number } } = {}
	local tries = 0
	while #placed < 6 and tries < 600 do
		tries += 1
		local x, yy = rng:NextNumber(-64, 64), rng:NextNumber(-64, 64)
		local ok = openGround(x, yy, 6) and x * x + yy * yy > 38 * 38 and yy < 50
		for _, q in placed do
			if (x - q[1]) ^ 2 + (yy - q[2]) ^ 2 < 26 * 26 then
				ok = false
			end
		end
		if ok then
			table.insert(placed, { x, yy })
			piece(kit, "Tree" .. #placed, CFrame.new(at(x, yy, 0)), function(m)
				local pos = at(x, yy, 0)
				prop(m, FANTASY.Fantasy_StarBlossom, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.42, 0.52), false)
				P(m, "TrunkCollider", Vector3.new(9, 3.2, 3.2), CFrame.new(pos + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), M.SmoothPlastic, Color3.new(1, 1, 1), { Shape = Enum.PartType.Cylinder, Transparency = 1, CanCollide = true, CanQuery = false })
			end)
		end
	end

	-- a few white wildflower patches
	local patches = 0
	tries = 0
	while patches < 5 and tries < 400 do
		tries += 1
		local x, yy = rng:NextNumber(-66, 66), rng:NextNumber(-66, 66)
		if openGround(x, yy, 0) then
			patches += 1
			piece(kit, "Patch" .. patches, CFrame.new(at(x, yy, 0)), function(m)
				for k = 1, 3 do
					local px, py = x + rng:NextNumber(-4, 4), yy + rng:NextNumber(-4, 4)
					if openGround(px, py, 0) then
						prop(m, ENCH.Store_WildFlower, CFrame.new(at(px, py, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(1.6, 2.4), false)
					end
				end
			end)
		end
	end
	return kit
end

function C.Build()
	local kitRoot = H.kitFolder("CrystalGarden")
	for _, plot in SM.Pens:GetChildren() do
		if plot:IsA("Model") and B.SanctuaryOrder[plot.Name] then
			C.BuildPlot(plot, kitRoot)
		end
	end
end

C.H = { crystal = crystal, openGround = openGround } -- shared with the other look modules

return C
