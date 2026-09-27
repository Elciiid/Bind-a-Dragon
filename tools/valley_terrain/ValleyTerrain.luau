-- Valley terrain (remaster checkpoint B). Studio build helper, not used by the game.
-- Writes the whole Starter Meadow terrain (x/z -640..640, y -48..272) from a height function, water included.
-- Usage (Studio command bar / MCP): local V = require(ServerStorage.RemasterTools.ValleyTerrain:Clone())
--   for row = 1, 5 do V.WriteRow(row) end
-- Water cells never share a voxel with ground (beds sit below the water's voxel layer), otherwise the water
-- doesn't render in this place.
-- The live copy is ServerStorage.RemasterTools.ValleyTerrain in the place; this file is the reference copy.
local V = {}
local Terrain = workspace.Terrain
local RES = 4
local noise = math.noise
local sqrt, abs, max, min, clamp = math.sqrt, math.abs, math.max, math.min, math.clamp
local deg, atan2 = math.deg, math.atan2

local function smooth(t)
	t = clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function lerp(a, b, t)
	return a + (b - a) * t
end
V.Smooth, V.Lerp = smooth, lerp

V.Sanct = {
	{ Name = "W1", X = -186.6, Z = -116.6, T = 10 },
	{ Name = "W2", X = -220, Z = 0, T = 8 },
	{ Name = "W3", X = -186.6, Z = 116.6, T = 6 },
	{ Name = "E1", X = 186.6, Z = -116.6, T = 10 },
	{ Name = "E2", X = 220, Z = 0, T = 8 },
	{ Name = "E3", X = 186.6, Z = 116.6, T = 6 },
}
for _, s in V.Sanct do
	local len = sqrt(s.X * s.X + s.Z * s.Z)
	s.AX, s.AZ = -s.X / len, -s.Z / len -- unit vector toward the altar
end
V.FlatR = 52 -- flat terrace radius (sanctuary 48 + wall)
V.ApronLen, V.ApronHalf = 66, 17 -- forecourt toward the altar
V.MesaSlope = 1.4

V.Spire = { X = 0, Z = -252, R = 42, Top = 28 }
V.Terrace = { R0 = 140, R1 = 180, Half = 44, Top = 12 }
V.WaterLevel = -1

-- Valley edge radius by |bearing| (degrees clockwise from north). The river gaps (W2/W3, E2/E3) reach further out.
local EDGE_W = { { 0, 300 }, { 30, 300 }, { 45, 286 }, { 60, 272 }, { 90, 274 }, { 95, 276 }, { 99, 304 }, { 110, 304 }, { 114, 272 }, { 130, 262 }, { 140, 238 }, { 150, 208 }, { 165, 188 }, { 180, 184 } }
local EDGE_E = { { 0, 300 }, { 30, 300 }, { 45, 286 }, { 60, 272 }, { 90, 274 }, { 95, 276 }, { 99, 318 }, { 110, 318 }, { 114, 272 }, { 130, 262 }, { 140, 238 }, { 150, 208 }, { 165, 188 }, { 180, 184 } }

local function edgeAt(th: number): number
	local tbl = if th < 0 then EDGE_W else EDGE_E
	local a = abs(th)
	for i = 2, #tbl do
		if a <= tbl[i][1] then
			local p, q = tbl[i - 1], tbl[i]
			return lerp(p[2], q[2], (a - p[1]) / (q[1] - p[1]))
		end
	end
	return tbl[#tbl][2]
end

-- Ridge height by bearing, with saddles behind the four portal gates (landmarks show through them).
local SADDLES = { -40, -15, 15, 40 }
local function peakAt(th: number): number
	local a = abs(th)
	local p = lerp(115, 145, smooth((a - 42) / 20))
	p = lerp(p, 110, smooth((a - 135) / 25))
	for _, s in SADDLES do
		local d = abs(th - s)
		if d < 9 then
			p -= 50 * (1 - smooth(d / 9))
		end
	end
	return p
end

local function mountain(x: number, z: number, u: number, th: number): number
	local p = peakAt(th)
	local h = smooth(u / 45) * 0.3 * p + smooth((u - 25) / 150) * 0.66 * p
	if u > 230 then
		h -= smooth((u - 230) / 170) * 0.45 * p
	end
	h += noise(x / 95, z / 95, 2.7) * 22 * smooth(u / 70) + noise(x / 55, z / 55, 5.1) * 4 * smooth(u / 30)
	return h
end

-- North: portal terrace (crescent), the slope behind it, and the Spire hill.
local function northH(x: number, z: number, R: number, th: number): number
	local T = V.Terrace
	local a = abs(th)
	local sideOut = max(0, math.rad(a - T.Half) * R)
	local frontOut = max(0, T.R0 - R)
	local out = sqrt(sideOut * sideOut + frontOut * frontOut)
	local top = T.Top
	if R > T.R1 then
		top = T.Top + smooth((R - T.R1) / 120) * 26 + noise(x / 50, z / 50, 3.3) * 3 * smooth((R - T.R1) / 40)
	end
	local h = top - out * 1.35
	local S = V.Spire
	local dx, dz = x - S.X, z - S.Z
	local d = sqrt(dx * dx + dz * dz)
	return max(h, S.Top - max(0, d - S.R) * 0.5)
end

-- Water: river centerline (x, z, half-width), ponds, pools, the channel on top of the waterfall cliff.
V.River = {
	{ -281, 60, 8 }, { -245, 59, 7 }, { -203, 58, 7 }, { -175, 52, 7 }, { -140, 54, 7 }, { -100, 60, 7 },
	{ -60, 63, 7 }, { -36, 63, 8 }, { 0, 63, 8 }, { 36, 63, 8 }, { 60, 63, 7 }, { 100, 60, 7 }, { 140, 54, 7 },
	{ 175, 52, 7 }, { 203, 58, 7 }, { 245, 59, 7 }, { 268, 60, 7 },
}
V.Ponds = { { X = -61, Z = 84, A = 31, B = 16 }, { X = 61, Z = 84, A = 31, B = 16 } }
V.FallPool = { X = -281, Z = 60, R = 14 }
V.LowPool = { X = 294, Z = 62, R = 14, Level = -7 }
V.TopChannel = { X0 = -304, Z0 = 58, X1 = -352, Z1 = 56, W = 5, Level = 60.5 }
V.CliffTop = 62
V.CliffSector = { -112, -96 }

local function segDist(px, pz, ax, az, bx, bz): (number, number)
	local vx, vz = bx - ax, bz - az
	local t = clamp(((px - ax) * vx + (pz - az) * vz) / (vx * vx + vz * vz), 0, 1)
	local cx, cz = ax + vx * t, az + vz * t
	return sqrt((px - cx) ^ 2 + (pz - cz) ^ 2), t
end

local function riverDist(x: number, z: number): (number, number)
	local best, width = math.huge, 5
	local pts = V.River
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		if x > min(a[1], b[1]) - 20 and x < max(a[1], b[1]) + 20 then
			local d, t = segDist(x, z, a[1], a[2], b[1], b[2])
			if d < best then
				best, width = d, lerp(a[3], b[3], t)
			end
		end
	end
	return best, width
end

-- Returns terrain height, water level (or nil) and a material hint: "bed" (river/pond bed), "rockbed", "flat"
-- (sanctuary floor), "paved" (flagstone: plaza base, market square, sanctuary rim and forecourt), "rock" (terrace
-- sides) or nil (grass, or rock by slope/height).
function V.Height(x: number, z: number): (number, number?, string?)
	local R = sqrt(x * x + z * z)
	local th = deg(atan2(x, -z))

	-- valley floor
	local h = 0.6 + noise(x / 70, z / 70, 1.3) * 0.7
	if R < 64 then
		h = lerp(1.0, h, smooth((R - 57) / 7))
	end
	local dm = sqrt(x * x + (z - 112) ^ 2)
	if dm < 42 then
		h = lerp(0.8, h, smooth((dm - 34) / 8))
	end
	if abs(x) < 16 and z > -135 and z < 175 then
		h = lerp(0.8, h, smooth((abs(x) - 10) / 6))
	end

	-- north: portal terrace, slope, Spire hill
	local rocky = false
	if abs(th) < 64 then
		local nh = northH(x, z, R, th)
		if nh > h then
			h = nh
			rocky = R < 190 and (R < V.Terrace.R0 or abs(th) > V.Terrace.Half) and nh > 1.5
		end
	end

	-- mountains around the valley
	-- (no edge wobble at the waterfall cliff and the east outlet, so the pools meet the cliff exactly)
	local c0, c1 = V.CliffSector[1], V.CliffSector[2]
	local cliffFade = 0
	if th > c0 - 4 and th < c1 + 4 then
		cliffFade = smooth((th - (c0 - 4)) / 4) * smooth(((c1 + 4) - th) / 4)
	end
	local calm = max(cliffFade, if th > 94 and th < 116 then 1 - smooth((abs(th - 105) - 7) / 4) else 0)
	local edge = edgeAt(th) + noise(x / max(R, 1) * 2.2, z / max(R, 1) * 2.2, 9.1) * 10 * (1 - calm)
	local u = R - edge
	if u > 0 then
		h = max(h, mountain(x, z, u, th))
		if cliffFade > 0 then
			h = max(h, V.CliffTop * smooth(u / 6) * cliffFade)
		end
	end

	-- Spire hill: flat top for the tower
	do
		local S = V.Spire
		if sqrt((x - S.X) ^ 2 + (z - S.Z) ^ 2) <= S.R then
			h = S.Top
		end
	end

	-- sanctuary terraces (flat top overrides everything)
	for _, s in V.Sanct do
		local vx, vz = x - s.X, z - s.Z
		local r = sqrt(vx * vx + vz * vz)
		if r < V.FlatR + 40 then
			local along = vx * s.AX + vz * s.AZ
			local lateral = abs(vx * s.AZ - vz * s.AX)
			local apron = math.huge
			if along > 0 then
				apron = sqrt(max(0, lateral - V.ApronHalf) ^ 2 + max(0, along - V.ApronLen) ^ 2)
			end
			local e = min(max(0, r - V.FlatR), apron)
			if e <= 0 then
				return s.T, nil, if r <= 48 then "flat" else "paved"
			end
			local mh = s.T - e * V.MesaSlope
			if mh > h then
				h = mh
				rocky = mh > 1.5
			end
		end
	end

	-- south gorge through the valley mouth
	if z > 150 then
		local floorG = 0.6 + max(0, z - 175) * 0.03 + max(0, z - 300) * 0.5
		local wall = floorG + max(0, abs(x) - 20) * 2.4
		h = min(h, lerp(h, wall, smooth((z - 150) / 20)))
	end

	-- water
	local level, hint = nil, nil
	local d, w = riverDist(x, z)
	if d < w + 8 then
		if d < w then
			h = min(h, -4.2)
		else
			h = min(h, lerp(-0.3, h, smooth((d - w) / 6)))
		end
		if d < w + 0.5 then
			level, hint = V.WaterLevel, "bed"
		end
	end
	for _, p in V.Ponds do
		local wob = 1 + noise(x / 18, z / 18, 4.4) * 0.08
		local q = sqrt(((x - p.X) / (p.A * wob)) ^ 2 + ((z - p.Z) / (p.B * wob)) ^ 2)
		if q < 1.35 then
			if q < 1 then
				h = min(h, -4.2)
			else
				h = min(h, lerp(-0.3, h, smooth((q - 1) / 0.3)))
			end
			if q < 1.02 then
				level, hint = V.WaterLevel, "bed"
			end
		end
	end
	local fp = V.FallPool
	local df = sqrt((x - fp.X) ^ 2 + (z - fp.Z) ^ 2)
	if df < fp.R + 6 then
		if df < fp.R then
			h = min(h, -4.2)
		else
			h = min(h, lerp(-0.3, h, smooth((df - fp.R) / 6)))
		end
		if df < fp.R + 0.5 then
			level, hint = V.WaterLevel, "rockbed"
		end
	end
	local lp = V.LowPool
	local dl = sqrt((x - lp.X) ^ 2 + (z - lp.Z) ^ 2)
	if dl < lp.R + 5 then
		if dl < lp.R then
			h = min(h, -8.2)
		else
			h = min(h, lerp(-6.3, h, smooth((dl - lp.R) / 4)))
		end
		if dl < lp.R + 0.5 then
			level, hint = lp.Level, "rockbed"
		end
	end
	local tc = V.TopChannel
	local dc = segDist(x, z, tc.X0, tc.Z0, tc.X1, tc.Z1)
	if dc < tc.W + 4 and h > tc.Level - 6 then
		if dc < tc.W then
			h = min(h, 55.8)
			level, hint = tc.Level, "rockbed"
		else
			h = min(h, lerp(tc.Level + 1, h, smooth((dc - tc.W) / 4)))
		end
	end
	if hint == nil then
		if R < 57 or dm < 30 then
			hint = "paved"
		elseif rocky then
			hint = "rock"
		end
	end
	return h, level, hint
end

V.Region = { X0 = -640, X1 = 640, Z0 = -640, Z1 = 640, Y0 = -48, Y1 = 272 }

-- Writes one 64 x 64-cell chunk (256 studs square) with its corner at (cx, cz).
function V.WriteChunk(cx: number, cz: number)
	local G = V.Region
	local CH = 64
	local ex, ez = min(cx + CH * RES, G.X1), min(cz + CH * RES, G.Z1)
	local nx, nz = (ex - cx) / RES, (ez - cz) / RES
	local ny = (G.Y1 - G.Y0) / RES
	-- heights on the cell grid (+1 border for slopes)
	local H, L, M = {}, {}, {}
	for ix = 1, nx + 1 do
		H[ix], L[ix], M[ix] = {}, {}, {}
		for iz = 1, nz + 1 do
			local wx, wz = cx + (ix - 0.5) * RES, cz + (iz - 0.5) * RES
			local h, level, hint = V.Height(wx, wz)
			H[ix][iz], L[ix][iz], M[ix][iz] = h, level or false, hint or false
		end
	end
	local mats, occs, liqs = {}, {}, {}
	local Air, Grass, Rock, Ground = Enum.Material.Air, Enum.Material.Grass, Enum.Material.Rock, Enum.Material.Ground
	for ix = 1, nx do
		local mx, ox, lx = {}, {}, {}
		mats[ix], occs[ix], liqs[ix] = mx, ox, lx
		for iy = 1, ny do
			mx[iy], ox[iy], lx[iy] = {}, {}, {}
		end
		for iz = 1, nz do
			local h, level, hint = H[ix][iz], L[ix][iz], M[ix][iz]
			local slope = max(abs(H[ix + 1][iz] - h), abs(H[ix][iz + 1] - h)) / RES
			local mat
			if hint == "bed" then
				mat = if level and h > level - 0.6 then Grass else Ground
			elseif hint == "paved" then
				mat = Enum.Material.Cobblestone
			elseif hint == "rock" then
				mat = Rock
			elseif hint == "rockbed" then
				mat = Rock
			elseif hint == "flat" then
				mat = Grass
			elseif slope > 1.15 then
				mat = Rock
			elseif h > 118 + noise((cx + ix * RES) / 36, (cz + iz * RES) / 36, 6.6) * 18 and slope > 0.6 then
				mat = Rock
			else
				mat = Grass
			end
			for iy = 1, ny do
				local bottom = G.Y0 + (iy - 1) * RES
				local occ = clamp((h - bottom) / RES, 0, 1)
				mx[iy][iz] = if occ > 0 then mat else Air
				ox[iy][iz] = occ
				lx[iy][iz] = if level and occ < 1 then max(0, clamp((level - bottom) / RES, 0, 1) - occ) else 0
			end
		end
	end
	local region = Region3.new(Vector3.new(cx, G.Y0, cz), Vector3.new(ex, G.Y1, ez))
	Terrain:WriteVoxelChannels(region, RES, { SolidMaterial = mats, SolidOccupancy = occs, LiquidOccupancy = liqs })
end

-- Writes chunk row `row` (1-5, north to south).
function V.WriteRow(row: number)
	local G = V.Region
	local cz = G.Z0 + (row - 1) * 256
	for cx = G.X0, G.X1 - 1, 256 do
		V.WriteChunk(cx, cz)
	end
end

return V
