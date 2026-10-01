-- Valley terrain (remaster checkpoint B). Studio build helper, not used by the game.
-- Writes the whole Starter Meadow terrain (x/z -640..640, y -48..400) from a height function, water included.
-- Usage (Studio command bar / MCP): local V = require(ServerStorage.RemasterTools.ValleyTerrain:Clone())
--   for row = 1, 5 do V.WriteRow(row) end
--   V.PaintForest() -- after the trees are placed (ValleyDetail.BuildNature): forest/slope grass
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
	-- 150-stud sanctuaries (rim radius 75) on one horseshoe around the altar (layout A-N, 2026-10-02): centers 256 from
	-- the altar at bearings 50 / 90 / 130 (gate distance 181 for all six, 25 studs between neighbours). The W2/W3 and
	-- E2/E3 gaps carry the river. Before: (+-208, -184), (+-174, -30), (+-158, 150).
	-- Terrace heights T are multiples of 4 (12 / 8 / 8; before 10 / 8 / 6): the terrain voxels are 4 studs, and other values
	-- round the last 7 studs of the rim off, so the six plots came out with different flat areas.
	{ Name = "W1", X = -196, Z = -165, T = 12 },
	{ Name = "W2", X = -256, Z = 0, T = 8 },
	{ Name = "W3", X = -196, Z = 165, T = 8 },
	{ Name = "E1", X = 196, Z = -165, T = 12 },
	{ Name = "E2", X = 256, Z = 0, T = 8 },
	{ Name = "E3", X = 196, Z = 165, T = 8 },
}
for _, s in V.Sanct do
	local len = sqrt(s.X * s.X + s.Z * s.Z)
	s.AX, s.AZ = -s.X / len, -s.Z / len -- unit vector toward the altar
end
V.FlatR = 80 -- flat terrace radius (rim wall at 75, footing to 80)
V.ApronLen, V.ApronHalf = 97, 24 -- forecourt toward the altar (gate at 75, forecourt to 97)
V.MesaSlope = 1.4
-- Sanctuary slots (Valley rework): the gameplay layout every sanctuary look shares (gate, perches, zones, stands). Local
-- coordinates (x, y): a player standing in the sanctuary and looking at the far wall has +x on their right, and +y runs
-- toward the gate (and the altar). V.ToWorld(s, x, y) converts to world X, Z. Heights are above the terrace floor.
V.Slots = {
	Rim = 75, -- rim wall radius
	Roam = 64, -- fliers stay inside this radius (plot attribute RoamRadius)
	Gate = 75, -- the gate stands this far from the center toward the altar
	Forecourt = 22, -- paved forecourt beyond the gate
	GateHalf = 13, GateHeight = 28, -- the gate's pillars stand 13 studs off the center line; lintel top 28 up
	Stands = { { -14, 88 }, { 14, 88 } }, -- upgrade stands (Slots, Income), in front of the gate
	Nest = { X = -36, Y = 30, R = 19 },
	Meadow = { X = 14, Y = 16, R = 28 }, -- clear of the centerpiece zone (radius 24 at y -34)
	Center = { X = 0, Y = -34, R = 24, MaxHeight = 48 }, -- the hero piece
	Water = { X = -34, Y = -22, R = 17 },
	-- Elder-size perch pads (19 across) and Dragon-size pads (14 across): { x, y, height above the floor }
	ElderPerches = { { -58, -18, 26 }, { -42, -48, 32 }, { 0, -66, 38 }, { 42, -48, 32 }, { 58, -18, 26 } },
	DragonPerches = { { -62, 12, 12 }, { 62, 14, 16 }, { 30, -30, 20 } },
	Bask = { { 46, 40 }, { -8, 44 } }, -- basking rocks (18 across)
}
V.PillarR = 9.5 -- Elder perch pad radius
function V.ToWorld(s, x: number, y: number): (number, number)
	return s.X + s.AX * y + s.AZ * x, s.Z + s.AZ * y - s.AX * x
end
for _, s in V.Sanct do
	s.PillarList = {} -- the Elder perch spires (world X, Z, top height), for the tier art
	for _, pl in V.Slots.ElderPerches do
		local wx, wz = V.ToWorld(s, pl[1], pl[2])
		table.insert(s.PillarList, { X = wx, Z = wz, Top = s.T + pl[3] })
	end
end

V.Spire = { X = 0, Z = -252, R = 42, Top = 28 }

-- Road material: terrain Brick with the painterly cream flagstone override Valley_RoadA (MaterialService). Not
-- Cobblestone: overrides restyle parts too, and hundreds of wall/bridge parts use Cobblestone; no part uses Brick.
V.RoadMaterial = Enum.Material.Brick

-- Flagstone roads (terrain V.RoadMaterial), each a polyline with a half-width. The W3/E3 roads bend to cross the river
-- square to it on the side bridges; the bridges themselves are parts.
V.Roads = {
	{ W = 8, { 0, 205 }, { 0, 140 } }, -- valley mouth, entrance gate, into the market square
	{ W = 8, { 0, 84 }, { 0, 72 } }, -- square to the grand bridge
	{ W = 7, { 0, -54 }, { 0, -154 } }, -- plaza to the grand stairs of the portal terrace (north road)
	{ W = 5, { -56, 0 }, { -160, 0 } }, -- W2: plaza to the forecourt (straight spoke)
	{ W = 5, { 56, 0 }, { 160, 0 } }, -- E2
	{ W = 5, { -38.3, -32.1 }, { -121.7, -102.6 } }, -- W1: straight spoke
	{ W = 5, { 38.3, -32.1 }, { 121.7, -102.6 } }, -- E1
	{ W = 5, { -47.5, 29.7 }, { -102, 46 } }, -- W3: plaza to the west side bridge
	{ W = 5, { -99, 72 }, { -110, 87 }, { -121.7, 102.6 } }, -- W3: side bridge to the forecourt
	{ W = 5, { 47.5, 29.7 }, { 102, 46 } }, -- E3
	{ W = 5, { 99, 72 }, { 110, 87 }, { 121.7, 102.6 } },
}
V.SpawnPlaza = { X = 0, Z = 160, R = 12 }
-- Portal terrace (layout A-N): a flat polygon (top y 12) wrapping the Spire's south foot; the portals stand on its back
-- edge (z -262 / -286), the grand stairs climb to its front bay at (0, -176). The sides fall away steeply (retaining wall).
V.Terrace = { Top = 12, Slope = 3, Poly = { { -12, -176 }, { 12, -176 }, { 30, -185 }, { 60, -206 }, { 100, -224 }, { 140, -240 }, { 166, -300 }, { -166, -300 }, { -140, -240 }, { -100, -224 }, { -60, -206 }, { -30, -185 } } }
-- paved promenade in front of the portals, joining the pads and the Spire stairs (polylines, half-width W)
V.Walkway = { W = 7, Lines = { { { -139, -265 }, { -82, -239 }, { -30, -212 }, { 0, -200 }, { 0, -178 } }, { { 139, -265 }, { 82, -239 }, { 30, -212 }, { 0, -200 } } } }
V.SpireCourt = { X = 0, Z = -214, R = 16 } -- paved court at the Spire entrance
V.WaterLevel = -1

-- Valley edge radius by |bearing| (degrees clockwise from north). The river gaps (W2/W3, E2/E3) reach further out.
-- (layout A-N: the north reaches ~330-358 for the portal terrace behind the Spire; the plots' own bulge sets the flanks; the
-- 100-122 bump is the waterfall cliff / river outlet behind the W2/W3 and E2/E3 gaps)
local EDGE_W = { { 0, 325 }, { 20, 335 }, { 30, 358 }, { 38, 350 }, { 45, 290 }, { 60, 272 }, { 90, 274 }, { 95, 276 }, { 100, 330 }, { 104, 366 }, { 118, 366 }, { 122, 330 }, { 130, 262 }, { 140, 238 }, { 150, 208 }, { 165, 188 }, { 180, 184 } }
local EDGE_E = EDGE_W

local function tableEdgeAt(th: number): number
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
-- Distance along the ray at bearing th to the far side of a disc around each sanctuary: the mountains start behind it.
local function bulgeAt(th: number): number
	local t = math.rad(th)
	local dx, dz = math.sin(t), -math.cos(t)
	local best = 0
	for _, s in V.Sanct do
		local b = s.X * dx + s.Z * dz
		local disc = b * b - (s.X * s.X + s.Z * s.Z - (V.FlatR + 16) ^ 2)
		if b > 0 and disc > 0 then
			best = max(best, b + sqrt(disc))
		end
	end
	return best
end

local function edgeAt(th: number): number
	return max(tableEdgeAt(th), bulgeAt(th))
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

-- North (layout A-N): the portal terrace polygon (flat top, steep sides), the rise behind it and the Spire hill.
local function polyOut(poly, x: number, z: number): number
	-- 0 inside the polygon, else the distance to its outline
	local inside, best = false, math.huge
	local n = #poly
	local j = n
	for i = 1, n do
		local a, b = poly[i], poly[j]
		if (a[2] > z) ~= (b[2] > z) and x < (b[1] - a[1]) * (z - a[2]) / (b[2] - a[2]) + a[1] then
			inside = not inside
		end
		local vx, vz = b[1] - a[1], b[2] - a[2]
		local t = clamp(((x - a[1]) * vx + (z - a[2]) * vz) / (vx * vx + vz * vz), 0, 1)
		local dx, dz = x - (a[1] + vx * t), z - (a[2] + vz * t)
		best = min(best, sqrt(dx * dx + dz * dz))
		j = i
	end
	return if inside then 0 else best
end
V.PolyOut = polyOut

-- returns the height and the distance outside the terrace polygon
local function northH(x: number, z: number): (number, number)
	local T = V.Terrace
	local out = polyOut(T.Poly, x, z)
	local top = T.Top
	local back = max(0, -z - 295)
	if back > 0 then
		top = T.Top + smooth(back / 120) * 26 + noise(x / 50, z / 50, 3.3) * 3 * smooth(back / 40)
	end
	local h = top - out * T.Slope
	local S = V.Spire
	local dx, dz = x - S.X, z - S.Z
	local d = sqrt(dx * dx + dz * dz)
	return max(h, S.Top - max(0, d - S.R) * 1.0), out
end

-- Water: river centerline (x, z, half-width), ponds, pools, the channel on top of the waterfall cliff.
-- (layout A-N: from the waterfall pool through the W2/W3 gap, past the plaza's south side under the side bridges at x = -100 / 100 and the grand bridge at x = 0, through the E2/E3 gap to the lower pool)
V.River = {
	{ -322, 118, 9 }, { -296, 106, 8 }, { -262, 95, 6 }, { -226, 82, 4.5 }, { -190, 69, 6 }, { -160, 61, 7 }, { -128, 57, 7 },
	{ -112, 61, 6 }, { -100, 60, 6 }, { -88, 57, 7 }, { -72, 53, 10 }, { -54, 58, 11 }, { -36, 63, 9 }, { -18, 64, 8 },
	{ 0, 63, 8 }, { 18, 62, 8 }, { 36, 59, 9 }, { 54, 57, 11 }, { 72, 59, 10 }, { 88, 62, 7 }, { 100, 60, 6 }, { 114, 57, 7 },
	{ 132, 57, 8 }, { 160, 61, 7 }, { 190, 69, 6 }, { 226, 82, 4.5 }, { 262, 95, 6 }, { 296, 106, 8 }, { 309, 113, 8 },
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
V.RiverRocks = { { -280, 100, 4.5 }, { -170, 64, 4 }, { -70, 50, 4 }, { 56, 53, 4 }, { 170, 64, 4.5 }, { 280, 100, 4 } }
V.Ponds = { { X = -50, Z = 84, A = 25, B = 15 }, { X = 50, Z = 84, A = 25, B = 15 } } -- moved in 11 studs: W3/E3 forecourts
V.FallPool = { X = -322, Z = 118, R = 14 }
V.LowPool = { X = 332, Z = 121, R = 14, Level = -7 }
V.TopChannel = { X0 = -344, Z0 = 125, X1 = -389, Z1 = 139, W = 5, Level = 60.5 }
V.CliffTop = 62
V.CliffSector = { -117, -103 }

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
	if abs(x) < 16 and z > -150 and z < 175 then
		h = lerp(0.8, h, smooth((abs(x) - 10) / 6))
	end
	local rd, rw = roadDist(x, z)
	if rd < rw + 3 then
		h = lerp(0.8, h, smooth((rd - rw) / 3))
	end
	local paved = rd < rw or sqrt((x - V.SpawnPlaza.X) ^ 2 + (z - V.SpawnPlaza.Z) ^ 2) < V.SpawnPlaza.R

	-- north: portal terrace, slope, Spire hill
	local rocky = false
	if abs(th) < 64 and z < -120 then
		local nh, out = northH(x, z)
		if nh > h then
			h = nh
			rocky = out > 0.5 and nh > 1.5 and R < 340
		end
	end

	-- mountains around the valley
	-- (no edge wobble at the waterfall cliff and the east outlet, so the pools meet the cliff exactly)
	local c0, c1 = V.CliffSector[1], V.CliffSector[2]
	local cliffFade = 0
	if th > c0 - 4 and th < c1 + 4 then
		cliffFade = smooth((th - (c0 - 4)) / 4) * smooth(((c1 + 4) - th) / 4)
	end
	local calm = max(cliffFade, if th > 98 and th < 122 then 1 - smooth((abs(th - 110) - 7) / 4) else 0)
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

	-- sanctuary terraces (flat top overrides everything; the valley edge bulges out behind them, see edgeAt)
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
				return s.T, nil, if r <= V.Slots.Rim - 1 then "flat" else "paved"
			end
			local mh = s.T - e * V.MesaSlope
			if along > V.ApronLen - 1 and lateral < 7.5 then
				mh = min(mh, s.T - (along - V.ApronLen) * 0.7 - 1.7) -- room for the steps (parts) down to the road
			end
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
		local onWalkway = false
		if z < -170 and h > V.Terrace.Top - 0.5 then
			for _, line in V.Walkway.Lines do
				for i = 1, #line - 1 do
					if segDist(x, z, line[i][1], line[i][2], line[i + 1][1], line[i + 1][2]) < V.Walkway.W then
						onWalkway = true
					end
				end
			end
		end
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

-- Forest/slope grass (run after the terrain and the trees are built): surface Grass on steep ground, high ground and
-- around forest trees (StarterMeadow.Nature.Trees) becomes Mud, which carries the deeper teal-green Valley_ForestA
-- override (no grass blades there). The warm meadow Grass stays on the valley floor, terraces and flat tops.
-- Deterministic; rerun after moving trees. Returns the number of voxels changed.
function V.PaintForest(): number
	local G = V.Region
	local grid = {}
	local trees = workspace:FindFirstChild("StarterMeadow") and workspace.StarterMeadow:FindFirstChild("Nature")
	trees = trees and trees:FindFirstChild("Trees")
	for _, m in (if trees then trees:GetChildren() else {}) do
		local p = if m:IsA("Model") then m:GetPivot().Position elseif m:IsA("BasePart") then m.Position else nil
		if p then
			local k = math.floor(p.X / 16) .. "," .. math.floor(p.Z / 16)
			grid[k] = grid[k] or {}
			table.insert(grid[k], p)
		end
	end
	local function nearTree(x: number, z: number): boolean
		local gx, gz = math.floor(x / 16), math.floor(z / 16)
		local r = 9 + noise(x / 23, z / 23, 4.2) * 4
		for i = gx - 1, gx + 1 do
			for j = gz - 1, gz + 1 do
				for _, p in grid[i .. "," .. j] or {} do
					if (p.X - x) ^ 2 + (p.Z - z) ^ 2 < r * r then
						return true
					end
				end
			end
		end
		return false
	end
	local Grass, Mud, Water, Air = Enum.Material.Grass, Enum.Material.Mud, Enum.Material.Water, Enum.Material.Air
	local changed = 0
	-- chunks in order, each read with a 1-cell border for the slope (written back as read)
	for cz = G.Z0, G.Z1 - 1, 256 do
		for cx = G.X0, G.X1 - 1, 256 do
			local x0, z0 = cx - RES, cz - RES
			local region = Region3.new(Vector3.new(x0, G.Y0, z0), Vector3.new(min(cx + 256, G.X1) + RES, G.Y1, min(cz + 256, G.Z1) + RES))
			local ch = Terrain:ReadVoxelChannels(region, RES, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" })
			local mats, occs = ch.SolidMaterial, ch.SolidOccupancy
			local nx, ny, nz = #mats, #mats[1], #mats[1][1]
			local H, top = {}, {}
			for ix = 1, nx do
				H[ix], top[ix] = {}, {}
				for iz = 1, nz do
					local h, t = -1e9, nil
					for iy = ny, 1, -1 do
						local m = mats[ix][iy][iz]
						if occs[ix][iy][iz] > 0 and m ~= Water and m ~= Air then
							h, t = G.Y0 + (iy - 1) * RES + occs[ix][iy][iz] * RES, iy
							break
						end
					end
					H[ix][iz], top[ix][iz] = h, t
				end
			end
			for ix = 2, nx - 1 do
				for iz = 2, nz - 1 do
					local t = top[ix][iz]
					if t then
						local h = H[ix][iz]
						local slope = max(abs(H[ix + 1][iz] - h), abs(H[ix - 1][iz] - h), abs(H[ix][iz + 1] - h), abs(H[ix][iz - 1] - h)) / RES
						local x, z = x0 + (ix - 0.5) * RES, z0 + (iz - 0.5) * RES
						local n = noise(x / 40, z / 40, 7.7)
						if slope > 0.5 + n * 0.15 or h > 42 + n * 12 or nearTree(x, z) then
							for iy = t, max(1, t - 2), -1 do
								if mats[ix][iy][iz] == Grass then
									mats[ix][iy][iz] = Mud
									changed += 1
								end
							end
						end
					end
				end
			end
			Terrain:WriteVoxelChannels(region, RES, { SolidMaterial = mats, SolidOccupancy = occs, LiquidOccupancy = ch.LiquidOccupancy })
		end
	end
	return changed
end

return V
