--!strict
-- Mutation auras (checkpoint 5, Config/Auras): every mutated dragon the player can see gets its own look, on client-only objects.
--   Hoardscale gold coin glints, Warcrest red embers, Aetherwing cyan wisps + circling orbs, Primordial a rainbow starlight ring.
-- Tracked kinds: "Roost" (the dragon models on the sanctuaries; found by scanning the RoostPlot models for a MutationId attribute),
-- "Companion" (CompanionController calls Track), "Reveal" (the bind ceremony calls Track with force = always full detail).
-- Cost control (all numbers in Config/Auras): auras beyond a distance are off, the orbiting parts only run within a shorter distance and for
-- at most MaxOrbiting dragons, at most MaxHighlights dragons get a Highlight outline, Low effects draw a fraction and no Highlights or
-- orbiting parts, Reduced Motion keeps the ring/orbs but standing still.
-- Other code: MutationAuraController:Track(model, mutationId, kind, force?) / :Untrack(model).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AuraConfig = require(ReplicatedStorage.Shared.Config.Auras)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local EffectsQuality = require(script.Parent.EffectsQuality)

type Tracked = {
	Model: Model,
	Anchor: BasePart,
	Def: AuraConfig.Aura,
	Kind: string,
	Force: boolean,
	Length: number, -- the dragon's nose-to-tail length in studs
	Scale: number, -- particle size/rate scale from the length
	Emitters: { ParticleEmitter },
	Orbiters: { BasePart },
	Detail: number, -- 0 off, 1 particles, 2 particles + orbiting parts
	Distance: number,
	Seed: number,
	Highlight: Highlight?,
	Destroying: RBXScriptConnection?,
}

local tracked: { [Model]: Tracked } = {}
local folder: Folder? = nil
local light = false -- Low effects (setting or low graphics quality; Reduced Motion alone is not "light")

local MutationAuraController = {}

local function parts(): Folder
	if folder == nil or folder.Parent == nil then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "MutationAuras"
		newFolder.Parent = workspace
		folder = newFolder
	end
	return folder :: Folder
end

local function reducedMotion(): boolean
	return Players.LocalPlayer:GetAttribute("ReducedMotion") == true
end

local function isLight(): boolean
	return Players.LocalPlayer:GetAttribute("LowEffects") == true or EffectsQuality.QualityIsLow()
end

local function sizeScale(length: number): number
	return math.clamp(length / AuraConfig.SizeReference, AuraConfig.MinSizeScale, AuraConfig.MaxSizeScale)
end

local function newEmitter(anchor: BasePart, def: AuraConfig.Emitter, scale: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "MutationAura"
	emitter.Texture = def.Texture
	emitter.Rate = def.Rate * scale
	emitter.Lifetime = def.Lifetime
	emitter.Speed = def.Speed
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, def.Size * scale), NumberSequenceKeypoint.new(1, def.Size * scale * 0.35) })
	emitter.Color = def.Color
	emitter.Transparency = def.Transparency
	emitter.LightEmission = def.LightEmission
	emitter.LightInfluence = 0
	emitter.Acceleration = Vector3.new(0, def.Rise, 0)
	emitter.Drag = def.Drag or 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = def.Spin or NumberRange.new(0, 0)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.Enabled = false
	emitter.Parent = anchor
	return emitter
end

local function orbitScale(item: Tracked): number
	return if item.Kind == "Companion" then AuraConfig.CompanionOrbitScale else 1
end

local function buildOrbiters(item: Tracked)
	local orbit = item.Def.Orbit
	if orbit == nil or #item.Orbiters > 0 then
		return
	end
	local count = if light then math.max(2, math.floor(orbit.Count * AuraConfig.LowScale + 0.5)) else orbit.Count
	for index = 1, count do
		local size = math.max(0.25, orbit.Size * item.Length * orbitScale(item))
		local part = Instance.new("Part")
		part.Name = "AuraOrb"
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * size
		part.Material = Enum.Material.Neon
		part.Color = orbit.Color or item.Def.Color
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		if orbit.Trail then
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position, a1.Position = Vector3.new(0, size * 0.45, 0), Vector3.new(0, -size * 0.45, 0)
			a0.Parent, a1.Parent = part, part
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = a0, a1
			trail.Lifetime = 0.7
			trail.Color = ColorSequence.new(orbit.Color or item.Def.Color)
			trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
			trail.LightEmission = 1
			trail.Parent = part
		end
		part.Parent = parts()
		item.Orbiters[index] = part
	end
end

local function clearOrbiters(item: Tracked)
	for _, part in item.Orbiters do
		part:Destroy()
	end
	table.clear(item.Orbiters)
end

local function setHighlight(item: Tracked, on: boolean)
	if on then
		if item.Highlight == nil then
			local highlight = Instance.new("Highlight")
			highlight.Name = "MutationHighlight"
			highlight.Adornee = item.Model
			highlight.FillColor = item.Def.Color
			highlight.OutlineColor = item.Def.Color
			highlight.FillTransparency = AuraConfig.Highlight.FillTransparency
			highlight.OutlineTransparency = AuraConfig.Highlight.OutlineTransparency
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Parent = parts()
			item.Highlight = highlight
		end
	elseif item.Highlight then
		item.Highlight:Destroy()
		item.Highlight = nil
	end
end

local function release(item: Tracked)
	if item.Destroying then
		item.Destroying:Disconnect()
	end
	for _, emitter in item.Emitters do
		emitter:Destroy()
	end
	clearOrbiters(item)
	setHighlight(item, false)
	tracked[item.Model] = nil
end

-- Starts an aura on a dragon model (no-op for unmutated dragons / unknown ids / models with no part). kind = "Roost" | "Companion" |
-- "Reveal"; force = always full detail (the reveal is right in front of the camera).
function MutationAuraController:Track(model: Model, mutationId: string?, kind: string, force: boolean?)
	local mutation = Mutations.Get(mutationId)
	local def = (AuraConfig.Auras :: any)[mutation.Id] :: AuraConfig.Aura?
	if mutation.Id == Mutations.NormalId or def == nil then
		return
	end
	local existing = tracked[model]
	if existing then
		return
	end
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if anchor == nil then
		return
	end
	local extents = model:GetExtentsSize()
	local length = math.max(extents.X, extents.Z, 1)
	local scale = sizeScale(length)
	local item: Tracked = {
		Model = model,
		Anchor = anchor,
		Def = def,
		Kind = kind,
		Force = force == true,
		Length = length,
		Scale = scale,
		Emitters = {},
		Orbiters = {},
		Detail = 0,
		Distance = math.huge,
		Seed = (model:GetPivot().Position.X * 3.1 + model:GetPivot().Position.Z * 1.7) % 6.28,
		Highlight = nil,
		Destroying = nil,
	}
	for _, emitterDef in def.Emitters do
		table.insert(item.Emitters, newEmitter(anchor, emitterDef, scale))
	end
	item.Destroying = model.Destroying:Connect(function()
		release(item)
	end)
	tracked[model] = item
	if force then
		MutationAuraController:Refresh() -- the reveal is on right now
	end
end

function MutationAuraController:Untrack(model: Model)
	local item = tracked[model]
	if item then
		release(item)
	end
end

-- Decides each aura's detail from its distance, the Low effects switch and the caps; runs a few times a second.
local function classify()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	light = isLight()
	local distances = AuraConfig.Distances
	local cameraPosition = camera.CFrame.Position
	local orbiting: { Tracked } = {}
	local visible: { Tracked } = {}
	for model, item in tracked do
		if not model:IsDescendantOf(workspace) then
			-- a streamed-out roost dragon / a finished reveal is dropped (the scan finds a roost dragon again); a companion stays tracked
			-- while it is out of range
			if item.Kind == "Companion" then
				item.Detail = 0
				item.Distance = math.huge
			else
				release(item)
			end
			continue
		end
		item.Distance = (item.Anchor.Position - cameraPosition).Magnitude
		local emitLimit = if light then distances.LowEmit elseif item.Kind == "Companion" then distances.Companion else distances.Emit
		local orbitLimit = if light then distances.LowOrbit else distances.Orbit
		local hidden = item.Anchor.Transparency >= 0.99
		if item.Force then
			item.Detail = 2
		elseif hidden or item.Distance > emitLimit then
			item.Detail = 0
		else
			item.Detail = 1
			if item.Def.Orbit and item.Distance <= orbitLimit then
				table.insert(orbiting, item)
			end
		end
		if item.Detail > 0 then
			table.insert(visible, item)
		end
	end
	-- the nearest MaxOrbiting dragons get their orbiting parts
	table.sort(orbiting, function(a, b)
		return a.Distance < b.Distance
	end)
	for index, item in orbiting do
		if index <= AuraConfig.MaxOrbiting then
			item.Detail = 2
		end
	end
	-- the nearest MaxHighlights dragons get a Highlight (never with Low effects)
	table.sort(visible, function(a, b)
		return a.Distance < b.Distance
	end)
	local rateScale = if light then AuraConfig.LowScale else 1
	for model, item in tracked do
		for index, emitter in item.Emitters do
			-- write only changes: re-setting a ParticleEmitter's Rate restarts its emission timer
			local enabled = item.Detail > 0
			if emitter.Enabled ~= enabled then
				emitter.Enabled = enabled
			end
			local rate = item.Def.Emitters[index].Rate * item.Scale * rateScale
			if math.abs(emitter.Rate - rate) > 0.001 then
				emitter.Rate = rate
			end
		end
		if item.Detail >= 2 and item.Def.Orbit then
			buildOrbiters(item)
		else
			clearOrbiters(item)
		end
		local wantsHighlight = false
		if not light then
			local rank = table.find(visible, item)
			wantsHighlight = rank ~= nil and rank <= AuraConfig.MaxHighlights
		end
		setHighlight(item, wantsHighlight)
	end
end

function MutationAuraController:Refresh()
	classify()
end

-- Moves the orbiting parts (every frame, only for dragons at detail 2).
local function stepOrbits(now: number)
	local still = reducedMotion()
	for _, item in tracked do
		local orbit = item.Def.Orbit
		if item.Detail < 2 or orbit == nil or #item.Orbiters == 0 then
			continue
		end
		local pivot = item.Model:GetPivot().Position
		local center = pivot + Vector3.new(0, item.Length * orbit.Height, 0)
		local radius = item.Length * orbit.Radius * orbitScale(item)
		local count = #item.Orbiters
		for index, part in item.Orbiters do
			local angle = (index - 1) * (math.pi * 2 / count) + item.Seed + (if still then 0 else now * orbit.Speed)
			local bob = if still then 0 else math.sin(now * 1.7 + index * 1.3 + item.Seed) * orbit.Wobble * item.Length
			part.Position = center + Vector3.new(math.cos(angle) * radius, bob, math.sin(angle) * radius)
			if orbit.Rainbow then
				part.Color = Color3.fromHSV(((index - 1) / count + (if still then 0 else now * 0.08)) % 1, 0.8, 1)
			end
			local trail = part:FindFirstChildOfClass("Trail")
			if trail then
				trail.Enabled = not still
			end
		end
	end
end

-- Finds mutated dragons on the roost plots (the server builds them with a MutationId attribute) and starts their auras.
local function scan()
	for _, plot in CollectionService:GetTagged("RoostPlot") do
		for _, child in plot:GetChildren() do
			if child:IsA("Model") and tracked[child] == nil then
				local mutationId = child:GetAttribute("MutationId")
				if type(mutationId) == "string" and mutationId ~= Mutations.NormalId then
					MutationAuraController:Track(child, mutationId, "Roost")
				end
			end
		end
	end
end

function MutationAuraController:Start()
	light = isLight()
	task.spawn(function()
		while true do
			scan()
			task.wait(AuraConfig.ScanSeconds)
		end
	end)
	task.spawn(function()
		while true do
			classify()
			task.wait(AuraConfig.ClassifySeconds)
		end
	end)
	RunService.Heartbeat:Connect(function()
		stepOrbits(os.clock())
	end)
	EffectsQuality.OnChanged(function()
		classify()
	end)
end

return MutationAuraController
