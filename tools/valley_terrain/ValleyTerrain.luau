-- Valley terrain (remaster checkpoint B). Studio build helper, not used by the game.
-- Writes the whole Starter Meadow terrain (x/z -640..640, y -48..400) from a height function, water included.
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
-- Rock pillars in each sanctuary's flight zone (future perches): angle from straight back (degrees), height above
-- the floor. They stand 43 studs out, outside the flight circle (fliers roam up to 34 studs out).
V.PillarR, V.PillarDist = 6, 43
V.Pillars = { { -55, 18 }, { -20, 28 }, { 20, 24 }, { 55, 20 } }
for _, s in V.Sanct do
	s.PillarList = {}
	local bx, bz = -s.AX, -s.AZ
	for _, pl in V.Pillars do
		local a = math.rad(pl[1])
		local dx, dz = bx * math.cos(a) - bz * math.sin(a), bx * math.sin(a) + bz * math.cos(a)
		table.insert(s.PillarList, { X = s.X + dx * V.PillarDist, Z = s.Z + dz * V.PillarDist, Top = s.T + pl[2] })
	end
end

V.Spire = { X = 0, Z = -252, R = 42, Top = 28 }

-- Road material: terrain Brick with the realistic Valley_Flagstone override (MaterialService). Not Cobblestone:
-- overrides restyle parts too, and hundreds of wall/bridge parts use Cobblestone; no part uses Brick.
V.RoadMaterial = Enum.Material.Brick

-- Flagstone roads (terrain V.RoadMaterial), each a polyline with a half-width. The W3/E3 roads bend to cross the river
-- square to it on the side bridges; the bridges themselves are parts.
V.Roads = {
	{ W = 8, { 0, 205 }, { 0, 140 } }, -- valley mouth, entrance gate, into the market square
	{ W = 8, { 0, 84 }, { 0, 72 } }, -- square to the grand bridge
	{ W = 7, { 0, -54 }, { 0, -124 } }, -- plaza to the grand stairs of the portal terrace
	{ W = 5, { -56, 0 }, { -142, 0 } }, -- W2
	{ W = 5, { 56, 0 }, { 142, 0 } }, -- E2
	{ W = 5, { -47.5, -29.7 }, { -120.4, -75.2 } }, -- W1
	{ W = 5, { 47.5, -29.7 }, { 120.4, -75.2 } }, -- E1
	{ W = 5, { -47.5, 29.7 }, { -102, 46 } }, -- W3: plaza to the west side bridge
	{ W = 5, { -98, 74 }, { -123.8, 77.4 } }, -- W3: side bridge to the sanctuary stairs
	{ W = 5, { 47.5, 29.7 }, { 97.7, 46 } }, -- E3
	{ W = 5, { 102.3, 74 }, { 123.8, 77.4 } },
}
V.SpawnPlaza = { X = 0, Z = 160, R = 12 }
V.Walkway = { R0 = 142, R1 = 158, Half = 42 } -- paved promenade on the portal terrace, in front of the gates
V.Terrace = { R0 = 133, R1 = 180, Half = 44, Top = 12 } -- front face at R0 is steep: the retaining wall (parts) stands there
V.SpireCourt = { X = 0, Z = -214, R = 16 } -- paved court at the Spire entrance
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
V.EdgeAt = edgeAt

-- Ridge height by bearing, and how deep the saddles behind the four portal gates cut (landmarks show through them).
local SADDLES = { -40, -15, 15, 40 }
local function peakAt(th: number): (number, number)
	local a = abs(th)
	local p = lerp(175, 235, smooth((a - 40) / 25))
	p = lerp(p, 190, smooth((a - 135) / 25))
	local saddle = 0
	for _, s in SADDLES do
		saddle = max(saddle, 1 - smooth(abs(th - s) / 10))
	end
	return p, saddle
end

-- 0..1, sharp crests where the noise crosses zero (jagged ridgelines)
local function ridged(x: number, z: number, scale: number, seed: number): number
	return 1 - min(1, abs(noise(x / scale, z / scale, seed)) * 2.2)
end

local function mountain(x: number, z: number, u: number, th: number): number
	local p, saddle = peakAt(th)
	p *= 1 - 0.62 * saddle
	-- green foothills (forest at D) with rock cliff bands in places, then the main rise, then jagged rocky crests
	local foot = smooth(u / 75) * 0.2 * p
	local band = smooth((u - 22) / 7) * 16 * smooth((noise(x / 70, z / 70, 7.3) - 0.05) * 5)
	local rise = smooth((u - 55) / 140) * 0.42 * p
	local crest = (ridged(x, z, 150, 2.7) ^ 2) * 0.42 * p * smooth((u - 90) / 110)
	local teeth = (ridged(x, z, 48, 5.1) ^ 1.5) * 0.13 * p * smooth((u - 80) / 70)
	local h = foot + band + rise + (crest + teeth) * (1 - 0.7 * saddle) + noise(x / 20, z / 20, 8.8) * 3 * smooth(u / 40)
	if u > 280 then
		h -= smooth((u - 280) / 160) * 0.4 * p
	end
	return h
end

-- North: portal terrace (crescent), the slope behind it, and the Spire hill.
local function northH(x: number, z: number, R: number, th: number): number
	local T = V.Terrace
	local a = abs(th)
	local sideOut = max(0, math.rad(a - T.Half) * R)
	local frontOut = max(0, T.R0 - R)
	local out = sqrt((sideOut * 1.35) ^ 2 + (frontOut * 4) ^ 2)
	local top = T.Top
	if R > T.R1 then
		top = T.Top + smooth((R - T.R1) / 120) * 26 + noise(x / 50, z / 50, 3.3) * 3 * smooth((R - T.R1) / 40)
	end
	local h = top - out
	local S = V.Spire
	local dx, dz = x - S.X, z - S.Z
	local d = sqrt(dx * dx + dz * dz)
	return max(h, S.Top - max(0, d - S.R) * 0.5)
end

-- Water: river centerline (x, z, half-width), ponds, pools, the channel on top of the waterfall cliff.
-- (winds between fixed points: the W2/W3 gap, the side bridges at x = -100 / 100, the grand bridge at x = 0, the E2/E3 gap)
V.River = {
	{ -281, 60, 9 }, { -264, 67, 9 }, { -246, 66, 7 }, { -228, 61, 6 }, { -205, 58, 6 }, { -186, 51, 8 },
	{ -168, 46, 11 }, { -148, 50, 10 }, { -128, 57, 7 }, { -112, 61, 6 }, { -100, 60, 6 }, { -88, 57, 7 },
	{ -72, 53, 10 }, { -54, 58, 11 }, { -36, 63, 9 }, { -18, 64, 8 }, { 0, 63, 8 }, { 18, 62, 8 }, { 36, 59, 9 },
	{ 54, 57, 11 }, { 72, 59, 10 }, { 88, 62, 7 }, { 100, 60, 6 }, { 114, 57, 7 }, { 132, 51, 10 }, { 152, 47, 11 },
	{ 172, 50, 8 }, { 190, 55, 6 }, { 205, 58, 6 }, { 224, 62, 7 }, { 243, 67, 10 }, { 258, 65, 8 }, { 270, 61, 7 },
}
-- round the bends: Catmull-Rom through the points above, 4 steps per segment
do
	local src, out = V.River, {}
	for i = 1, #src - 1 do
		local p0, p1, p2, p3 = src[max(1, i - 1)], src[i], src[i + 1], src[min(#src, i + 2)]
		for k = 0, 3 do
			local t = k / 4
			local t2, t3 = t * t, t * t * t
			local function cr(a, b, c, d)
				return 0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (3 * b - a - 3 * c + d) * t3)
			end
			table.insert(out, { cr(p0[1], p1[1], p2[1], p3[1]), cr(p0[2], p1[2], p2[2], p3[2]), lerp(p1[3], p2[3], t) })
		end
	end
	table.insert(out, src[#src])
	V.River = out
end
-- rocks in the river: x, z, radius (tops a little above the water)
V.RiverRocks = { { -262, 69, 4.5 }, { -166, 43, 4 }, { -70, 50, 4 }, { 56, 53, 4 }, { 150, 44, 4.5 }, { 244, 70, 4 } }
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

local function roadDist(x: number, z: number): (number, number)
	local best, width = math.huge, 0
	for _, road in V.Roads do
		for i = 1, #road - 1 do
			local d = segDist(x, z, road[i][1], road[i][2], road[i + 1][1], road[i + 1][2])
			if d - road.W < best - width then
				best, width = d, road.W
			end
		end
	end
	return best, width
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
	local rd, rw = roadDist(x, z)
	if rd < rw + 3 then
		h = lerp(0.8, h, smooth((rd - rw) / 3))
	end
	local paved = rd < rw or sqrt((x - V.SpawnPlaza.X) ^ 2 + (z - V.SpawnPlaza.Z) ^ 2) < V.SpawnPlaza.R

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

	-- sanctuary terraces (flat top overrides everything), their rock pillars and the cliff behind them
	for _, s in V.Sanct do
		local vx, vz = x - s.X, z - s.Z
		local r = sqrt(vx * vx + vz * vz)
		if r < V.FlatR + 40 then
			for _, pl in s.PillarList do
				local dp = sqrt((x - pl.X) ^ 2 + (z - pl.Z) ^ 2)
				if dp < V.PillarR * (1 + noise(x / 7, z / 7, 3.9) * 0.3) then
					return pl.Top, nil, "rock"
				end
			end
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
			if along > V.ApronLen - 1 and lateral < 7.5 then
				mh = min(mh, s.T - (along - V.ApronLen) * 0.7 - 1.7) -- room for the steps (parts) down to the road
			end
			if mh > h then
				h = mh
				rocky = mh > 1.5
			end
			-- behind the back half: a ledge 13 studs up, then the cliff rises to 22 (ledges for perching later)
			local back = -along
			if back > 5 then
				local cliff = s.T + 13 + smooth((r - 58) / 6) * 9 + noise(x / 12, z / 12, 6.1) * 2
				local ch = lerp(h, cliff, smooth((back - 5) / 25))
				if ch > h then
					h = ch
				end
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
	for _, rk in V.RiverRocks do
		local dr = sqrt((x - rk[1]) ^ 2 + (z - rk[2]) ^ 2)
		if dr < rk[3] then
			h = max(h, 0.2 + (1 - (dr / rk[3]) ^ 2) * 2.2)
			level, hint = nil, "rockbed"
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
		local W = V.Walkway
		local onWalkway = R > W.R0 and R < W.R1 and abs(th) < W.Half and h > V.Terrace.Top - 0.5
		local SC = V.SpireCourt
		local onCourt = sqrt((x - SC.X) ^ 2 + (z - SC.Z) ^ 2) < SC.R and h > V.Spire.Top - 0.5
		if R < 57 or dm < 34 or paved or onWalkway or onCourt then
			hint = "paved"
		elseif rocky then
			hint = "rock"
		end
	end
	return h, level, hint
end

V.Region = { X0 = -640, X1 = 640, Z0 = -640, Z1 = 640, Y0 = -48, Y1 = 400 }
-- Solid terrain ends up ~2 studs above its voxel fill height (measured with raycasts and by walking, 2026-09-27;
-- water levels are exact), so solids are written 2 studs lower to put every surface at its designed height.
V.SurfaceLift = 2
V.SnowLine = 195 -- snowcaps above this height (+/- 20 with noise); terrain Sand is colored white for them

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
				mat = V.RoadMaterial
			elseif hint == "rock" then
				mat = Rock
			elseif hint == "rockbed" then
				mat = Rock
			elseif hint == "flat" then
				mat = Grass
			else
				-- mountains: green up to the tree line (rock only on real cliffs low down), rock higher up, snowcaps on the
				-- highest peaks (Sand tinted white: the Snow material carries the Frozen area's stylized override)
				local n = noise((cx + ix * RES) / 60, (cz + iz * RES) / 60, 6.6)
				if h > V.SnowLine + n * 20 and slope < 1.9 then
					mat = Enum.Material.Sand
				elseif slope > (if h < 90 then 1.9 elseif h < 150 then 1.35 else 0.9) and h > 3 then
					mat = Rock
				elseif h > 150 + n * 20 and slope > 0.55 then
					mat = Rock
				else
					mat = Grass
				end
			end
			for iy = 1, ny do
				local bottom = G.Y0 + (iy - 1) * RES
				local occ = clamp((h - V.SurfaceLift - bottom) / RES, 0, 1)
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
