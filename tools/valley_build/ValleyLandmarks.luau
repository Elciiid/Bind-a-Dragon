-- Valley landmarks (remaster checkpoint D): builds the Meadow's horizon models in ReplicatedStorage.Assets.Horizon
-- (shown client-side by HorizonController, placed by Config/Horizon). Studio build helper, not used by the game.
-- Usage: local L = require(ServerStorage.RemasterTools.ValleyLandmarks:Clone()); L.BuildAll()
-- The live copy is ServerStorage.RemasterTools.ValleyLandmarks in the place; this file is the reference copy.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local L = {}
local KIT = ServerStorage.PropKits.Enchanted
local HORIZON = ReplicatedStorage.Assets.Horizon
local M = Enum.Material
local rad = math.rad

-- AI-generated meshes (Studio mesh generation, owned by the place's creator)
L.Generated = {
	Volcano = 113680587339499, -- parts "rock" + "lava"
	Range = 109152359884573, -- rocky range with pine forest at its base
}

local function loadGenerated(id: number): Model
	local container = InsertService:LoadAsset(id)
	local m = container:GetChildren()[1] :: Model
	m.Parent = nil
	container:Destroy()
	return m
end

local function aabb(m: Instance): (Vector3, Vector3)
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local cf, s = d.CFrame, d.Size / 2
			for _, c in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1), Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) } do
				local w = cf:PointToWorldSpace(s * c)
				mn = mn:Min(w)
				mx = mx:Max(w)
			end
		end
	end
	return mn, mx
end

-- Stretch a model non-uniformly around its bottom center (sizes and offsets of every part).
local function stretch(m: Model, k: Vector3)
	local mn, mx = aabb(m)
	local origin = Vector3.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = d.Position - origin
			d.Size = d.Size * k
			d.CFrame = CFrame.new(origin + rel * k) * d.CFrame.Rotation
		end
	end
end

-- A root part at the model's bottom center becomes the PrimaryPart, so the pivot is the base (Config/Horizon Position).
local function rootAtBase(m: Model)
	local mn, mx = aabb(m)
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CFrame = CFrame.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2)
	root.Parent = m
	m.PrimaryPart = root
end

local function replace(name: string, m: Model)
	local old = HORIZON:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	m.Name = name
	m:PivotTo(CFrame.new())
	m.Parent = HORIZON
end

-- The volcano behind the Volcano Peak gate: dark stone cone, glowing lava streams, a smoke plume.
function L.BuildVolcano()
	local v = loadGenerated(L.Generated.Volcano)
	for _, p in v:GetDescendants() do
		if p:IsA("MeshPart") then
			p.TextureID = ""
			if p.Name:lower():find("lava") then
				p.Name = "Lava"
				p.Material = M.Neon
				p.Color = Color3.fromRGB(255, 105, 35)
			else
				p.Name = "Rock"
				p.Material = M.Slate
				p.Color = Color3.fromRGB(86, 72, 66)
			end
		end
	end
	stretch(v, Vector3.new(1.15, 1.75, 1.15)) -- steeper cone, ~320 tall
	-- turn it so the lava streams face the valley (the model's -Z faces the meadow)
	local mn0, mx0 = aabb(v)
	local c0 = Vector3.new((mn0.X + mx0.X) / 2, mn0.Y, (mn0.Z + mx0.Z) / 2)
	local turn = CFrame.new(c0) * CFrame.Angles(0, rad(131.1), 0) * CFrame.new(-c0)
	for _, d in v:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = turn * d.CFrame
			if d.Name == "Rock" then
				d.Material = M.Rock
				d.Color = Color3.fromRGB(70, 60, 57)
			end
		end
	end
	local mn, mx = aabb(v)
	-- smoke plume from the crater (the old plume's emitters, made bigger)
	local plume = HORIZON:FindFirstChild("VolcanoPlume")
	if plume and plume:FindFirstChild("Plume") then
		local p = plume.Plume:Clone()
		p.Transparency = 1
		p.Size = Vector3.new(60, 4, 60)
		p.CFrame = CFrame.new((mn.X + mx.X) / 2, mx.Y - 6, (mn.Z + mx.Z) / 2)
		for _, e in p:GetDescendants() do
			if e:IsA("ParticleEmitter") then
				local s = e.Size.Keypoints
				local scaled = {}
				for _, kp in s do
					table.insert(scaled, NumberSequenceKeypoint.new(kp.Time, kp.Value * 3, kp.Envelope * 3))
				end
				e.Size = NumberSequence.new(scaled)
				e.Speed = NumberRange.new(e.Speed.Min * 2, e.Speed.Max * 2)
			end
		end
		p.Parent = v
	end
	rootAtBase(v)
	replace("ValleyVolcano", v)
end

-- The floating island behind the Eclipse Isles gate: realistic boulders hanging below, grass, firs and silver ruins
-- on top, and the eclipse (dark sun with its gold corona, "Spinner") above it.
function L.BuildIsland()
	local m = Instance.new("Model")
	local function boulder(name: string, scale: number, cf: CFrame)
		local b = KIT[name]:Clone()
		b:ScaleTo(scale)
		b:PivotTo(cf)
		for _, d in b:GetDescendants() do
			if d:IsA("BasePart") then
				d.Parent = m
			end
		end
		b:Destroy()
	end
	-- underside: boulders upside down (pivot at their base, which becomes the island's top plane)
	local flip = CFrame.Angles(math.pi, 0, 0)
	boulder("Store_Boulder1", 2.4, CFrame.new(0, 2, 0) * flip)
	boulder("Store_Boulder13", 1.6, CFrame.new(38, 2, 10) * CFrame.Angles(0, rad(40), 0) * flip)
	boulder("Store_Boulder10", 1.4, CFrame.new(-36, 2, -8) * CFrame.Angles(0, rad(-70), 0) * flip)
	boulder("Store_Boulder6", 1.3, CFrame.new(4, 2, 40) * CFrame.Angles(0, rad(150), 0) * flip)
	boulder("Store_Boulder3", 1.5, CFrame.new(-6, 2, -40) * CFrame.Angles(0, rad(95), 0) * flip)
	-- grass top
	local top = Instance.new("Part")
	top.Name = "Grass"
	top.Shape = Enum.PartType.Cylinder
	top.Size = Vector3.new(5, 118, 118)
	top.CFrame = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.pi / 2)
	top.Material = M.Grass
	top.Color = Color3.fromRGB(64, 132, 60)
	top.Anchored = true
	top.Parent = m
	-- firs and silver ruins with violet runes
	local rng = Random.new(3)
	for i = 1, 7 do
		local a, r = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(12, 48)
		local fir = KIT["Store_Fir" .. rng:NextInteger(1, 8)]:Clone()
		fir:ScaleTo(rng:NextNumber(1.6, 2.2))
		fir:PivotTo(CFrame.new(math.cos(a) * r, 3.5, math.sin(a) * r) * CFrame.Angles(0, a, 0))
		for _, d in fir:GetDescendants() do
			if d:IsA("SurfaceAppearance") then
				(d :: any).Color = Color3.new(0.88, 1, 0.82)
			end
		end
		fir.Parent = m
	end
	for i, spec in { { -14, -6, 18 }, { -4, -8, 13 }, { 8, -7, 18 }, { 18, -3, 9 } } do
		local col = Instance.new("Part")
		col.Name = "Ruin"
		col.Shape = Enum.PartType.Cylinder
		col.Size = Vector3.new(spec[3], 3.2, 3.2)
		col.CFrame = CFrame.new(spec[1], 4 + spec[3] / 2, spec[2] - 20) * CFrame.Angles(0, 0, math.pi / 2)
		col.Material = M.Marble
		col.Color = Color3.fromRGB(214, 218, 232)
		col.Anchored = true
		col.Parent = m
		local rune = Instance.new("Part")
		rune.Name = "Rune"
		rune.Size = Vector3.new(0.6, spec[3] * 0.5, 0.6)
		rune.CFrame = CFrame.new(spec[1], 4 + spec[3] * 0.55, spec[2] - 18.3)
		rune.Material = M.Neon
		rune.Color = Color3.fromRGB(165, 120, 255)
		rune.Anchored = true
		rune.Parent = m
	end
	-- the eclipse above
	local sunSource = HORIZON:FindFirstChild("EclipseSun")
	if sunSource then
		local sun = sunSource:Clone()
		sun:ScaleTo(0.6)
		local _, smx = aabb(m)
		local smn, ssmx = aabb(sun)
		-- sit the sun's center ~130 above the island top, ring facing the meadow (-Z)
		local center = (smn + ssmx) / 2
		sun:PivotTo(sun:GetPivot() + (Vector3.new(0, smx.Y + 130, 0) - center))
		for _, d in sun:GetChildren() do
			d.Parent = m
		end
		sun:Destroy()
	end
	rootAtBase(m)
	-- the island's base is its underside tip; move the pivot to the grass top so Config/Horizon sets the top height
	local root = m.PrimaryPart :: BasePart
	root.CFrame = CFrame.new(root.Position.X, 4, root.Position.Z)
	replace("ValleyIsland", m)
end

-- Distant mountain ranges all around the valley, beyond the terrain (one model, pivot at the valley center).
L.RangeRadius = 830
function L.BuildRanges()
	local src = loadGenerated(L.Generated.Range)
	for _, p in src:GetDescendants() do
		if p:IsA("MeshPart") then
			p.Name = "Range"
			p.RenderFidelity = Enum.RenderFidelity.Automatic
		end
	end
	local m = Instance.new("Model")
	local rng = Random.new(12)
	local count = 11
	for i = 1, count do
		local bearing = (i - 0.5) / count * 360 + rng:NextNumber(-6, 6)
		local r = rad(bearing)
		local piece = src:Clone()
		stretch(piece, Vector3.new(rng:NextNumber(2.2, 2.7), rng:NextNumber(1.9, 2.5), 1.6))
		local mn, mx = aabb(piece)
		local R = L.RangeRadius + rng:NextNumber(-60, 60)
		local base = Vector3.new(R * math.sin(r), -70, -R * math.cos(r))
		local offset = base - Vector3.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2)
		for _, d in piece:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = d.CFrame + offset
			end
		end
		-- turn the piece around its base to face the valley (a little random)
		local facing = CFrame.lookAt(base, Vector3.new(0, base.Y, 0)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
		local turn = CFrame.new(base) * facing.Rotation * CFrame.new(-base)
		for _, d in piece:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = turn * d.CFrame
				d.Parent = m
			end
		end
		piece:Destroy()
	end
	src:Destroy()
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CFrame = CFrame.new()
	root.Parent = m
	m.PrimaryPart = root
	replace("MeadowRanges", m)
end

-- The kept older landmarks, made more natural (run once; safe to re-run): the ice spire loses its plastic slab and
-- its crystals rise straight out of the ridge; the storm tower's cloud balls become a dark swirling storm cloud.
function L.TuneExisting()
	local ice = HORIZON:FindFirstChild("IceSpire")
	if ice and ice:FindFirstChild("Cliff", true) then
		for _, n in { "Cliff", "Snow" } do
			local p = ice:FindFirstChild(n, true)
			if p then
				p:Destroy()
			end
		end
		local mesh = ice:FindFirstChild("LandmarkMesh", true) :: BasePart
		local root = ice.PrimaryPart :: BasePart
		local drop = root.CFrame:ToObjectSpace(mesh.CFrame).Y - mesh.Size.Y / 2
		mesh.CFrame -= Vector3.new(0, drop, 0)
		local sparkle = ice:FindFirstChild("Sparkle", true) :: BasePart?
		if sparkle then
			sparkle.CFrame -= Vector3.new(0, drop, 0)
		end
	end
	local storm = HORIZON:FindFirstChild("StormTower")
	if storm and storm:FindFirstChild("StormCloud") == nil then
		for _, c in storm:GetDescendants() do
			if c.Name == "Cloud" and c:IsA("BasePart") then
				c:Destroy()
			end
		end
		local mesa = storm:FindFirstChild("Mesa", true) :: BasePart?
		if mesa then
			mesa.Material = M.Rock
			mesa.Color = Color3.fromRGB(64, 60, 70)
		end
		local cloud = Instance.new("Part")
		cloud.Name = "StormCloud"
		cloud.Size = Vector3.new(120, 20, 120)
		cloud.Transparency = 1
		cloud.Anchored = true
		cloud.CanCollide = false
		cloud.CFrame = (storm.PrimaryPart :: BasePart).CFrame * CFrame.new(0, 385, 0)
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(58, 52, 78), Color3.fromRGB(96, 86, 122))
		e.LightInfluence = 0.6
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 40), NumberSequenceKeypoint.new(0.5, 90), NumberSequenceKeypoint.new(1, 120) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.25), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(8, 12)
		e.Rate = 5
		e.Speed = NumberRange.new(2, 6)
		e.SpreadAngle = Vector2.new(180, 180)
		e.RotSpeed = NumberRange.new(-12, 12)
		e.Rotation = NumberRange.new(0, 360)
		e.Acceleration = Vector3.new(0, 0.5, 0)
		e.Parent = cloud
		cloud.Parent = storm
	end
end

function L.BuildAll()
	L.BuildVolcano()
	L.BuildIsland()
	L.BuildRanges()
	L.TuneExisting()
end

return L
