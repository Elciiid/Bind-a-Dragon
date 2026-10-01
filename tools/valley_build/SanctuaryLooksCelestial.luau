-- Celestial Sanctum look kit (Valley rework checkpoint 4; concept assets/concepts/sanctuary_celestial.png). Studio build helper.
-- Lavender-white marble with gold filigree, constellation floor inlay, floating-rock perches held by gold rings, a grand
-- gold gate with two golden dragon statues, and a star-crystal nest dome inside spinning gold armillary rings with a thin
-- beam of starlight. Same slots as every look (ValleyTerrain V.Slots); built into
-- ReplicatedStorage.Assets.SanctuaryLooks.CelestialSanctum.<PlotName>.
-- Methods: code parts (wall with gold niches, gate arch, plinths, floor inlay, pool rocks, column stems, the armillary rings
-- and ring-held perches, spun by SanctuaryLookController via the SpinAxis / SpinSpeed model attributes); AI meshes from
-- ServerStorage.PropKits.SanctuaryLooks (Studio generate_mesh: CE_NestDome centerpiece, CE_FloatRock perch rocks,
-- CE_DragonStatue gate statues) and CG_CrystalCluster; reused Fantasy trees / Meadow nests. No Blender pieces.
-- Usage: local E = require(ServerStorage.RemasterTools.SanctuaryLooksCelestial:Clone()); E.Build()
-- The live copy is ServerStorage.RemasterTools.SanctuaryLooksCelestial in the place; this file is the reference copy.
local ServerStorage = game:GetService("ServerStorage")

local E = {}
local L = require(ServerStorage.RemasterTools.SanctuaryLooks:Clone())
local Cg = require(ServerStorage.RemasterTools.SanctuaryLooksCrystal:Clone())
local H = L.H
local crystal, openGround = Cg.H.crystal, Cg.H.openGround
local B, V = H.B, H.V
local Slots = V.Slots
local M = Enum.Material
local rad, sin, cos, pi = math.rad, math.sin, math.cos, math.pi
local P, Disc, Star, Glow = B.P, B.Disc, B.Star, B.Glow
local Colors = B.Colors
local LOOKS = ServerStorage.PropKits.SanctuaryLooks
local MEADOW = ServerStorage.PropKits.Meadow
local ENCH = ServerStorage.PropKits.Enchanted
local FANTASY = ServerStorage.PropKits.Fantasy
local SM = workspace:WaitForChild("StarterMeadow")

local CE = {
	Marble = Color3.fromRGB(232, 232, 244),
	MarbleShade = Color3.fromRGB(204, 206, 226),
	Gold = Colors.Gold,
	GoldSoft = Color3.fromRGB(104, 80, 38), -- soft night glow of the gold
	Teal = Color3.fromRGB(120, 226, 226),
	TealGlow = Color3.fromRGB(34, 96, 104),
	Stone = Color3.fromRGB(176, 176, 190),
	Beam = Color3.fromRGB(190, 225, 255),
}
E.Colors = CE

-- A gold armillary ring (a Model of thin blocks) around `center`, in the plane given by `tilt`; SpinAxis (world) and
-- SpinSpeed (radians per second) tell the client how to turn it.
local function ring(parent: Instance, name: string, center: Vector3, radius: number, tilt: CFrame, n: number, thick: number, axis: Vector3, speed: number): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	local base = CFrame.new(center) * tilt
	local len = 2 * radius * sin(pi / n) * 1.05
	for k = 0, n - 1 do
		local a = k / n * 2 * pi
		local seg = P(m, "Seg", Vector3.new(thick, thick, len), base * CFrame.new(cos(a) * radius, 0, sin(a) * radius) * CFrame.Angles(0, -a, 0), M.Foil, CE.Gold, { CanCollide = false, CastShadow = false })
		if k % 4 == 0 then
			Glow(seg, CE.GoldSoft)
		end
		if k % 8 == 0 then -- a little gold star bead
			local bead = P(m, "Bead", Vector3.new(thick * 2.6, thick * 2.6, thick * 2.6), base * CFrame.new(cos(a) * radius, 0, sin(a) * radius), M.Foil, CE.Gold, { CanCollide = false, CastShadow = false, Shape = Enum.PartType.Ball })
			Glow(bead, CE.GoldSoft)
		end
	end
	m.WorldPivot = CFrame.new(center)
	m:SetAttribute("SpinAxis", axis)
	m:SetAttribute("SpinSpeed", speed)
	return m
end

function E.BuildPlot(plot: Model, kitRoot: Folder)
	local ctx = H.context(plot)
	local T, at, frame = ctx.T, ctx.at, ctx.frame
	local piece, prop, stretched = H.piece, H.prop, H.stretched
	local kit = B.Folder(kitRoot, plot.Name, true)
	local rng = Random.new(3000 + tonumber(string.match(plot.Name, "%d+")) :: number)
	local gy, gh, gx = Slots.Gate, Slots.GateHeight, Slots.GateHalf
	local right = Vector3.new(-ctx.Fwd.Z, 0, ctx.Fwd.X)

	-- grand gate: marble columns with gold bases and crystals, a gold elliptical arch with a star, sign chains
	piece(kit, "Gate", frame(0, gy, 0), function(m)
		local archBase = 20.5
		for _, sd in { -gx, gx } do
			P(m, "Column", Vector3.new(5, archBase, 5), frame(sd, gy, archBase / 2), M.Marble, CE.Marble)
			P(m, "Foot", Vector3.new(7.4, 1.6, 7.4), frame(sd, gy, 0.8), M.Marble, CE.MarbleShade)
			P(m, "FootGold", Vector3.new(7.8, 0.4, 7.8), frame(sd, gy, 1.7), M.Foil, CE.Gold, { CanCollide = false })
			P(m, "Capital", Vector3.new(6.6, 1.2, 6.6), frame(sd, gy, archBase + 0.6), M.Marble, CE.MarbleShade)
			P(m, "CapitalGold", Vector3.new(7, 0.4, 7), frame(sd, gy, archBase + 1.4), M.Foil, CE.Gold, { CanCollide = false })
			for _, off in { -1.3, 1.3 } do -- gold pilaster strips down the front
				Glow(P(m, "Strip", Vector3.new(0.4, archBase - 5, 0.3), frame(sd + off, gy + 2.55, archBase / 2 + 1.2), M.Foil, CE.Gold, { CanCollide = false }), CE.GoldSoft)
			end
			crystal(m, CFrame.new(at(sd * 1.05, gy, archBase + 1.6)), 7.5, 2.2)
		end
		local ry, n = gh - archBase - 0.5, 18
		for _, spec in { { Rx = gx, Ry = ry, T = 1.3, Glow = true }, { Rx = gx - 1.8, Ry = ry - 1.8, T = 0.5, Glow = false } } do
			for k = 0, n - 1 do
				local a0, a1 = k / n * pi, (k + 1) / n * pi
				local x0, h0 = spec.Rx * cos(a0), archBase + 1.4 + spec.Ry * sin(a0)
				local x1, h1 = spec.Rx * cos(a1), archBase + 1.4 + spec.Ry * sin(a1)
				local len = math.sqrt((x1 - x0) ^ 2 + (h1 - h0) ^ 2) + 0.2
				local seg = P(m, "Arch", Vector3.new(len, spec.T, spec.T + 0.5), frame((x0 + x1) / 2, gy, (h0 + h1) / 2) * CFrame.Angles(0, 0, math.atan2(h1 - h0, x1 - x0)), M.Foil, CE.Gold, { CanCollide = false })
				if spec.Glow and k % 2 == 0 then
					Glow(seg, CE.GoldSoft)
				end
			end
		end
		Star(m, frame(0, gy + 0.6, gh - 1.6), 4.8, CE.GoldSoft)
		for _, sd in { -5, 5 } do
			P(m, "SignChain", Vector3.new(0.3, 11, 0.3), frame(sd, gy, 22), M.Metal, Colors.Iron, { CanCollide = false })
		end
		H.light(m, at(0, gy + 3, gh - 6), CE.Beam, 1.2, 38)
	end)

	-- the two golden dragon statues on plinths flanking the gate (AI mesh, stripped to plain gold)
	for i, sd in { -(gx + 11), gx + 11 } do
		local pos = at(sd, gy + 4, 0)
		piece(kit, "Statue" .. i, CFrame.new(pos), function(m)
			Disc(m, "Plinth", pos + Vector3.new(0, 2.6, 0), 4.8, 5.2, M.Marble, CE.Marble)
			Disc(m, "PlinthBase", pos + Vector3.new(0, 0.5, 0), 5.6, 1, M.Marble, CE.MarbleShade)
			Disc(m, "PlinthGold", pos + Vector3.new(0, 5.3, 0), 5, 0.4, M.Foil, CE.Gold, { CanCollide = false })
			Star(m, CFrame.lookAt(pos + Vector3.new(0, 2.8, 0), pos + Vector3.new(0, 2.8, 0) + ctx.Fwd) * CFrame.new(0, 0, -4.85), 2.6, CE.GoldSoft)
			local look = ctx.Fwd + right * (if sd < 0 then -0.35 else 0.35) -- a little turned in toward the gate's center line
			local statue = prop(m, LOOKS.CE_DragonStatue, CFrame.lookAt(pos + Vector3.new(0, 5.5, 0), pos + Vector3.new(0, 5.5, 0) + look), 1.6, false)
			for _, d in statue:GetDescendants() do
				if d:IsA("MeshPart") then
					d.TextureID = ""
					d.Material = M.Metal
					d.Color = CE.Gold
				end
			end
		end)
	end

	-- rim wall: lavender-white marble, gold cap and gold-framed glass niches, crystal posts at the start of every arc
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
				P(m, "Post", Vector3.new(3.2, 8.2, 3.2), cf * CFrame.new(0, 4.1, 0), M.Marble, CE.Marble)
				P(m, "PostBand", Vector3.new(3.7, 0.5, 3.7), cf * CFrame.new(0, 6.4, 0), M.Foil, CE.Gold, { CanCollide = false })
				P(m, "PostCap", Vector3.new(3.8, 0.6, 3.8), cf * CFrame.new(0, 8.5, 0), M.Foil, CE.Gold, { CanCollide = false })
				crystal(m, cf * CFrame.new(0, 8.8, 0), 5.4, 1.8)
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
				P(m, "Wall", Vector3.new(len, 5.6, 3), cf, M.Marble, CE.Marble)
				P(m, "WallCap", Vector3.new(len + 0.2, 0.5, 3.5), cf * CFrame.new(0, 3.05, 0), M.Foil, CE.Gold, { CanCollide = false })
				for _, sx in { -2.6, 2.6 } do
					P(m, "NicheFrame", Vector3.new(0.4, 3.6, 0.3), cf * CFrame.new(sx, 0.1, -1.6), M.Foil, CE.Gold, { CanCollide = false })
				end
				P(m, "NicheTop", Vector3.new(5.6, 0.4, 0.3), cf * CFrame.new(0, 1.95, -1.6), M.Foil, CE.Gold, { CanCollide = false })
				Glow(P(m, "NicheGlass", Vector3.new(4.8, 3.2, 0.12), cf * CFrame.new(0, 0.1, -1.55), M.Glass, CE.Teal, { CanCollide = false, Transparency = 0.35 }), CE.TealGlow)
			end
		end)
	end

	-- the centerpiece: the star-crystal nest dome (AI mesh) inside three spinning gold armillary rings, a thin beam of starlight
	local cp = at(Slots.Center.X, Slots.Center.Y, 0)
	piece(kit, "Dome", CFrame.new(cp), function(m)
		Disc(m, "Dais", cp + Vector3.new(0, 0.25, 0), 17, 0.6, M.Marble, CE.Marble)
		Glow(Disc(m, "DaisRing", cp + Vector3.new(0, 0.56, 0), 16.4, 0.1, M.Foil, CE.Gold, { CanCollide = false }), CE.GoldSoft)
		Disc(m, "DaisInner", cp + Vector3.new(0, 0.6, 0), 15.8, 0.12, M.Marble, CE.Marble, { CanCollide = false })
		prop(m, LOOKS.CE_NestDome, CFrame.lookAt(cp + Vector3.new(0, 0.5, 0), cp + Vector3.new(0, 0.5, 0) + ctx.Fwd), 1.75, false)
		P(m, "BaseCollider", Vector3.new(14, 22, 22), CFrame.new(cp + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.pi / 2), M.SmoothPlastic, Color3.new(1, 1, 1), { Shape = Enum.PartType.Cylinder, Transparency = 1, CanCollide = true, CanQuery = false })
		local hub = cp + Vector3.new(0, 27, 0)
		ring(m, "RingA", hub, 18, CFrame.Angles(rad(28), 0, 0), 36, 0.6, Vector3.yAxis, 0.32)
		ring(m, "RingB", hub, 15, CFrame.Angles(rad(68), rad(40), 0), 32, 0.55, Vector3.yAxis, -0.46)
		ring(m, "RingC", hub, 12, CFrame.Angles(rad(-20), rad(110), rad(40)), 28, 0.5, ctx.Fwd, 0.6)
		local beamBase = P(m, "BeamAnchor", Vector3.new(1, 1, 1), CFrame.new(cp + Vector3.new(0, 35, 0)), M.SmoothPlastic, Color3.new(1, 1, 1), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
		local b0, b1 = Instance.new("Attachment"), Instance.new("Attachment")
		b0.Parent, b1.Parent = beamBase, beamBase
		b0.WorldPosition = cp + Vector3.new(0, 35, 0)
		b1.WorldPosition = cp + Vector3.new(0, 420, 0)
		local beam = Instance.new("Beam")
		beam.Name = "StarBeam"
		beam.Attachment0, beam.Attachment1 = b0, b1
		beam.Width0, beam.Width1 = 1.6, 4
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(Color3.new(1, 1, 1), CE.Beam)
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.03, 0.45), NumberSequenceKeypoint.new(0.6, 0.78), NumberSequenceKeypoint.new(1, 1) })
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Parent = beamBase
		H.light(m, cp + Vector3.new(0, 28, 0), CE.Beam, 2.4, 60)
	end)

	-- perches: floating rocks (AI mesh) held by gold rings over slender marble columns, crystals hanging below
	local function floatingPerch(name: string, pl: { number }, width: number, rockH: number, ringN: number)
		local top = pl[3]
		piece(kit, name, CFrame.new(at(pl[1], pl[2], 0)), function(m)
			local c = at(pl[1], pl[2], 0)
			stretched(m, LOOKS.CE_FloatRock, ctx.faceCenter(at(pl[1], pl[2], top - rockH)), Vector3.new(width, rockH, width), true)
			local stemTop = top - rockH - 1.5
			local stem = P(m, "Stem", Vector3.new(stemTop + 1, width * 0.2, width * 0.2), CFrame.new(c + Vector3.new(0, (stemTop - 1) / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), M.Marble, CE.Marble)
			stem.Shape = Enum.PartType.Cylinder
			Disc(m, "StemBase", c + Vector3.new(0, 0.9, 0), width * 0.34, 1.8, M.Marble, CE.MarbleShade)
			Glow(Disc(m, "StemCollar", c + Vector3.new(0, stemTop - 0.4, 0), width * 0.14, 0.6, M.Foil, CE.Gold, { CanCollide = false }), CE.GoldSoft)
			ring(m, "HoldRing", c + Vector3.new(0, top - rockH * 0.42, 0), width * 0.56, CFrame.Angles(rad(rng:NextNumber(-8, 8)), 0, rad(rng:NextNumber(-8, 8))), ringN, 0.5, Vector3.yAxis, 0)
			for k = 0, 1 do
				local a = k * pi + 0.7
				crystal(m, CFrame.new(c + Vector3.new(cos(a) * width * 0.3, top - rockH * 0.55, sin(a) * width * 0.3)) * CFrame.Angles(pi, 0, 0), width * 0.2, 0.7)
			end
		end)
	end
	for i, pl in Slots.ElderPerches do
		floatingPerch("Float" .. i, pl, V.PillarR * 2, 11, 18)
	end
	for i, pl in Slots.DragonPerches do
		floatingPerch("Float" .. (i + 5), pl, 14, 9, 14)
	end

	-- constellation floor inlay: flat gold rings, a compass star and a constellation on glowing glass (NightGlow gold lines)
	local ic = Vector2.new(8, 16)
	piece(kit, "Inlay", CFrame.new(at(ic.X, ic.Y, 0)), function(m)
		local function d(name: string, r: number, h: number, mat: Enum.Material, color: Color3, gl: Color3?, tr: number?)
			local p = Disc(m, name, at(ic.X, ic.Y, h), r, 0.1, mat, color, { CanCollide = false, CastShadow = false, Transparency = tr or 0 })
			if gl then
				Glow(p, gl)
			end
		end
		d("RingOuter", 20.6, 0.3, M.Foil, CE.Gold, CE.GoldSoft)
		d("GlassOuter", 19.9, 0.34, M.Glass, CE.Teal, CE.TealGlow, 0.35)
		d("RingMid", 14.6, 0.38, M.Foil, CE.Gold, CE.GoldSoft)
		d("GlassMid", 13.9, 0.42, M.Glass, CE.Teal, CE.TealGlow, 0.35)
		d("RingInner", 8.6, 0.46, M.Foil, CE.Gold, CE.GoldSoft)
		d("GlassInner", 7.9, 0.5, M.Glass, CE.Teal, CE.TealGlow, 0.35)
		for k = 0, 3 do -- the compass star: four long thin lines through the center
			Glow(P(m, "Compass", Vector3.new(41, 0.1, k % 2 == 0 and 0.9 or 0.5), frame(ic.X, ic.Y, 0.58) * CFrame.Angles(0, k * pi / 4, 0), M.Foil, CE.Gold, { CanCollide = false, CastShadow = false }), CE.GoldSoft)
		end
		Star(m, CFrame.new(at(ic.X, ic.Y, 0.62)) * CFrame.Angles(-pi / 2, 0, 0), 6, CE.GoldSoft)
		local nodes = { { -9, -11 }, { -3, -4 }, { 5, -9 }, { 11, -2 }, { 4, 6 }, { -6, 8 }, { -12, 2 } } -- a little constellation
		for k, n in nodes do
			local nx, ny = ic.X + n[1], ic.Y + n[2]
			Glow(Disc(m, "Node", at(nx, ny, 0.62), 0.9, 0.12, M.Foil, CE.Gold, { CanCollide = false, CastShadow = false }), CE.GoldSoft)
			local nxt = nodes[k % #nodes + 1]
			local p0, p1 = at(nx, ny, 0.6), at(ic.X + nxt[1], ic.Y + nxt[2], 0.6)
			Glow(P(m, "Line", Vector3.new(0.35, 0.1, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), M.Foil, CE.Gold, { CanCollide = false, CastShadow = false }), CE.GoldSoft)
		end
	end)

	-- stepping path: lavender-white slabs from the gate down toward the inlay and from the inlay to the dais
	local group, y = 0, gy - 6
	local batch: { CFrame } = {}
	local function flush()
		if #batch == 0 then
			return
		end
		group += 1
		piece(kit, "Path" .. group, CFrame.new(batch[1].Position), function(m)
			for _, cf in batch do
				P(m, "Slab", Vector3.new(4.6, 0.5, 4.6), cf * CFrame.new(0, 0.2, 0), M.Marble, CE.MarbleShade)
			end
		end)
		batch = {}
	end
	while y > Slots.Center.Y + 20 do
		local x = 6 * sin(y / 14)
		if (x - ic.X) ^ 2 + (y - ic.Y) ^ 2 > 24 ^ 2 then
			table.insert(batch, CFrame.new(at(x + rng:NextNumber(-0.5, 0.5), y, 0)) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0))
			if #batch >= 5 then
				flush()
			end
		end
		y -= 5.6
	end
	flush()

	-- the glowing pool: a ring of rocks, water that lights up at night, crystals and a soft sparkle
	local w = Slots.Water
	piece(kit, "Pool", CFrame.new(at(w.X, w.Y, 0)), function(m)
		local wc = at(w.X, w.Y, 0)
		Disc(m, "Bed", wc + Vector3.new(0, 0.15, 0), w.R + 1, 0.3, M.Slate, CE.Stone, { CanCollide = false })
		Glow(Disc(m, "Water", wc + Vector3.new(0, 0.42, 0), w.R, 0.4, M.Glass, Color3.fromRGB(96, 214, 232), { Transparency = 0.3, CanCollide = false }), CE.TealGlow)
		for k = 0, 15 do
			local a = k * pi * 2 / 16 + rng:NextNumber(-0.08, 0.08)
			local rp = at(w.X + cos(a) * (w.R + 0.8), w.Y + sin(a) * (w.R + 0.8), 0.9)
			local rock = P(m, "Rock", Vector3.new(rng:NextNumber(4.4, 6.6), rng:NextNumber(2.2, 3.4), rng:NextNumber(3.8, 5.6)), CFrame.new(rp) * CFrame.Angles(0, -a, 0), M.Slate, CE.Stone, { Shape = Enum.PartType.Ball })
			if k % 4 == 0 then
				P(m, "RockMoss", Vector3.new(rock.Size.X * 0.7, 0.5, rock.Size.Z * 0.7), CFrame.new(rp + Vector3.new(0, rock.Size.Y * 0.36, 0)) * CFrame.Angles(0, -a, 0), M.Grass, Color3.fromRGB(96, 134, 72), { CanCollide = false })
			end
		end
		for _, a in { 0.6, 3.4 } do
			prop(m, LOOKS.CG_CrystalCluster, CFrame.lookAt(at(w.X + cos(a) * (w.R + 4.6), w.Y + sin(a) * (w.R + 4.6), 0), wc), 1.1, false)
		end
		local top = P(m, "Sparkle", Vector3.new(0.4, 0.4, 0.4), CFrame.new(wc + Vector3.new(0, 1, 0)), M.SmoothPlastic, Color3.new(1, 1, 1), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
		local e = Instance.new("ParticleEmitter")
		e.Name = "Sparkle"
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(190, 240, 255), Color3.fromRGB(120, 210, 240))
		e.LightEmission = 0.8
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.7), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(2, 3.5)
		e.Speed = NumberRange.new(1, 3)
		e.SpreadAngle = Vector2.new(30, 30)
		e.Rate = 8
		e.Shape = Enum.ParticleEmitterShape.Disc
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		e.Parent = top
	end)

	-- basking slabs: lavender marble with a gold inlay ring
	for i, b in Slots.Bask do
		piece(kit, "Bask" .. i, CFrame.new(at(b[1], b[2], 0)), function(m)
			Disc(m, "Slab", at(b[1], b[2], 0.8), 9, 1.6, M.Marble, CE.Marble)
			Glow(Disc(m, "SlabRing", at(b[1], b[2], 1.62), 8.3, 0.1, M.Foil, CE.Gold, { CanCollide = false }), CE.GoldSoft)
			Disc(m, "SlabInner", at(b[1], b[2], 1.66), 7.7, 0.12, M.Marble, CE.Marble, { CanCollide = false })
		end)
	end

	-- nests with crystal clusters
	local nz = Slots.Nest
	piece(kit, "Nests", CFrame.new(at(nz.X, nz.Y, 0)), function(m)
		for _, off in { { 0, 0 }, { 10, -9 } } do
			prop(m, MEADOW.AI_Meadow_Nest, CFrame.new(at(nz.X + off[1], nz.Y + off[2], 0)) * CFrame.Angles(0, off[1] * 0.3, 0), 1.3, false)
		end
		prop(m, LOOKS.CG_CrystalCluster, CFrame.new(at(nz.X + 12, nz.Y + 5, 0)), 1.2, false)
		prop(m, LOOKS.CG_CrystalCluster, CFrame.new(at(nz.X - 12, nz.Y - 4, 0)), 1.0, false)
	end)

	-- four white star-blossom trees and four tall cypress-like firs on open ground
	local placed: { { number } } = {}
	local function scatter(count: number, minGap: number, minR: number, pad: number, build: (Model, Vector3) -> ())
		local tries, made = 0, 0
		while made < count and tries < 800 do
			tries += 1
			local x, yy = rng:NextNumber(-64, 64), rng:NextNumber(-64, 64)
			local ok = openGround(x, yy, pad) and x * x + yy * yy > minR * minR and (x - ic.X) ^ 2 + (yy - ic.Y) ^ 2 > 24 ^ 2
			for _, q in placed do
				if (x - q[1]) ^ 2 + (yy - q[2]) ^ 2 < minGap * minGap then
					ok = false
				end
			end
			if ok then
				made += 1
				table.insert(placed, { x, yy })
				piece(kit, "Tree" .. #placed, CFrame.new(at(x, yy, 0)), function(m)
					build(m, at(x, yy, 0))
				end)
			end
		end
	end
	scatter(4, 26, 40, 6, function(m, pos)
		prop(m, FANTASY.Fantasy_StarBlossom, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.42, 0.5), false)
		P(m, "TrunkCollider", Vector3.new(8, 3, 3), CFrame.new(pos + Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.pi / 2), M.SmoothPlastic, Color3.new(1, 1, 1), { Shape = Enum.PartType.Cylinder, Transparency = 1, CanCollide = true, CanQuery = false })
	end)
	scatter(4, 12, 44, 2, function(m, pos)
		prop(m, FANTASY.Fantasy_TealFir_B, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.34, 0.42), false)
	end)

	-- a few wildflower patches
	local patches, tries = 0, 0
	while patches < 5 and tries < 400 do
		tries += 1
		local x, yy = rng:NextNumber(-66, 66), rng:NextNumber(-66, 66)
		if openGround(x, yy, 0) and (x - ic.X) ^ 2 + (yy - ic.Y) ^ 2 > 24 ^ 2 then
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

function E.Build()
	local kitRoot = H.kitFolder("CelestialSanctum")
	for _, plot in SM.Pens:GetChildren() do
		if plot:IsA("Model") and B.SanctuaryOrder[plot.Name] then
			E.BuildPlot(plot, kitRoot)
		end
	end
end

return E
