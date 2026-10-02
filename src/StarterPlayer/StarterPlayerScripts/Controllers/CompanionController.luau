--!strict
-- Carried dragon companions: every client draws the dragon each player carries (HotbarService publishes it as Player attributes
-- CarrySpecies / CarryMutation / CarryStage / CarryChampion) flying beside that player at a small size (Config/Hotbar
-- Companion*). Purely visual and local: the model is a client-only clone from ReplicatedStorage.Assets.Dragons (the shared
-- placeholder, tinted by element, when a species has no art), scaled by stage (Config/Hotbar CompanionLengthFraction), with a mutation aura (Sparkles named
-- MutationAura, in the mutation's color; checkpoint 5 gives each mutation its own look). Real art with a bone map in
-- Config/DragonRigs flaps its wings (Controllers/DragonRig). Companions farther than RenderDistance from the camera aren't drawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DragonRig = require(script.Parent.DragonRig)
local EffectsQuality = require(script.Parent.EffectsQuality)
local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Evolution = require(ReplicatedStorage.Shared.Config.Evolution)
local HotbarConfig = require(ReplicatedStorage.Shared.Config.Hotbar)
local MilestoneConfig = require(ReplicatedStorage.Shared.Config.RebirthMilestones)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local RigConfig = require(ReplicatedStorage.Shared.Config.DragonRigs)

local CompanionController = {}

type Companion = {
	Model: Model,
	Key: string, -- what the model was built for
	Rig: DragonRig.Rig?,
	Pose: DragonRig.Pose,
	Size: number, -- studs (Config/Hotbar CompanionLengthFraction x the stage length)
	Position: Vector3?,
	Yaw: number,
	Bank: number,
	Pitch: number,
	Frame: number,
	Seed: number,
}

local companions: { [Player]: Companion } = {}
local folder: Folder

local function findTemplate(speciesId: string, stageId: string): (Model?, boolean)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local dragons = assets and assets:FindFirstChild("Dragons")
	if dragons == nil then
		return nil, false
	end
	local art = dragons:FindFirstChild(speciesId)
	if art then
		local stageArt = art:FindFirstChild(stageId)
		if stageArt and stageArt:IsA("Model") then
			return stageArt, false
		end
		if art:IsA("Model") then
			return art, false
		end
	end
	local placeholder = dragons:FindFirstChild("Placeholder")
	return if placeholder and placeholder:IsA("Model") then placeholder else nil, true
end

local function attrString(player: Player, name: string): string
	local value = player:GetAttribute(name)
	return if type(value) == "string" then value else ""
end

-- Size in studs for a stage: a fraction of the stage's roost length, never below the minimum.
local function companionSize(stageId: string): number
	for _, stage in Evolution.Stages do
		if stage.Id == stageId then
			return math.max(HotbarConfig.CompanionMinLength, stage.Length * HotbarConfig.CompanionLengthFraction)
		end
	end
	return HotbarConfig.CompanionMinLength
end

local function buildModel(speciesId: string, mutationId: string, stageId: string, champion: boolean): Model?
	local species = Dragons[speciesId]
	if species == nil then
		return nil
	end
	local template, isPlaceholder = findTemplate(speciesId, stageId)
	if template == nil then
		return nil
	end
	local model = template:Clone()
	model.Name = "Companion"
	for _, item in model:GetDescendants() do
		if item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		end
	end
	if isPlaceholder then
		local element = Elements[species.Element]
		local primary = if element then element.Color else Color3.new(1, 1, 1)
		local tints = { Primary = primary, Secondary = primary:Lerp(Color3.new(0, 0, 0), 0.45), Accent = primary:Lerp(Color3.new(1, 1, 1), 0.6) }
		for _, part in model:GetDescendants() do
			local tint = part:GetAttribute("Tint")
			if part:IsA("BasePart") and type(tint) == "string" and (tints :: any)[tint] then
				part.Color = (tints :: any)[tint]
			end
		end
	end
	local extents = model:GetExtentsSize()
	local span = math.max(extents.X, extents.Z)
	if span > 0.1 then
		model:ScaleTo(model:GetScale() * companionSize(stageId) / span)
	end
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
		elseif part:IsA("BillboardGui") then
			part:Destroy() -- no nameplates on companions
		end
	end
	-- mutation aura (identification only; never replaces the art)
	local mutation = Mutations.Get(mutationId)
	if anchor and not EffectsQuality.IsLow() then
		if mutation.Id ~= Mutations.NormalId then
			local sparkles = Instance.new("Sparkles")
			sparkles.Name = "MutationAura"
			sparkles.SparkleColor = mutation.Color
			sparkles.Parent = anchor
		elseif champion then
			local sparkles = Instance.new("Sparkles")
			sparkles.Name = "MutationAura"
			sparkles.SparkleColor = MilestoneConfig.Champion.Color
			sparkles.Parent = anchor
		end
	end
	return model
end

local function destroyCompanion(player: Player)
	local companion = companions[player]
	if companion then
		companion.Model:Destroy()
		companions[player] = nil
	end
end

-- Rebuilds a player's companion to match their Carry* attributes (or removes it).
local function refresh(player: Player)
	local species = attrString(player, "CarrySpecies")
	if species == "" then
		destroyCompanion(player)
		return
	end
	local mutation, stage = attrString(player, "CarryMutation"), attrString(player, "CarryStage")
	local champion = player:GetAttribute("CarryChampion") == true
	local key = `{species}/{mutation}/{stage}/{champion}`
	local existing = companions[player]
	if existing and existing.Key == key then
		return
	end
	local model = buildModel(species, mutation, stage, champion)
	if model == nil then
		destroyCompanion(player)
		return
	end
	local keepPosition = if existing then existing.Position else nil
	local keepYaw = if existing then existing.Yaw else 0
	destroyCompanion(player)
	local rigConfig = RigConfig.Rigs[`{species}/{stage}`]
	local rng = Random.new(player.UserId)
	companions[player] = {
		Model = model,
		Key = key,
		Rig = if rigConfig then DragonRig.Build(model, rigConfig, nil) else nil,
		Pose = {
			Air = 1,
			Flap = rng:NextNumber(0, 5),
			Gait = 0,
			Walk = 0,
			Clock = rng:NextNumber(0, 10),
			Rest = 0,
			Hover = 0.2,
			Turn = 0,
			Pitch = 0,
			LookYaw = 0,
			LookPitch = 0,
			Action = nil,
			ActionT = 0,
			Seed = rng:NextInteger(0, 999),
		},
		Size = companionSize(stage),
		Position = keepPosition,
		Yaw = keepYaw,
		Bank = 0,
		Pitch = 0,
		Frame = 0,
		Seed = rng:NextInteger(0, 999),
	}
end

local function watch(player: Player)
	for _, name in { "CarrySpecies", "CarryMutation", "CarryStage", "CarryChampion" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			task.defer(refresh, player) -- several attributes change together: rebuild once
		end)
	end
	refresh(player)
end

local function angleDelta(target: number, current: number): number
	return (target - current + math.pi) % (2 * math.pi) - math.pi
end

function CompanionController:Start()
	folder = Instance.new("Folder")
	folder.Name = "Companions"
	folder.Parent = workspace
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(destroyCompanion)

	RunService.PreRender:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		local now = os.clock()
		for player, companion in companions do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local model = companion.Model
			if root == nil or not root:IsA("BasePart") then
				model.Parent = nil
				companion.Position = nil
				continue
			end
			local cameraDistance = (root.Position - camera.CFrame.Position).Magnitude
			if cameraDistance > HotbarConfig.RenderDistance then
				model.Parent = nil
				continue
			end
			if model.Parent ~= folder then
				model.Parent = folder
			end
			local bob = math.sin(now * HotbarConfig.BobSpeed * 2 + companion.Seed) * HotbarConfig.BobHeight
			local size = companion.Size
			local side = HotbarConfig.FollowSide + HotbarConfig.FollowSidePerStud * size
			local up = HotbarConfig.FollowUp + HotbarConfig.FollowUpPerStud * size
			local back = HotbarConfig.FollowBack + HotbarConfig.FollowBackPerStud * size
			local target = (root.CFrame * CFrame.new(side, up, back)).Position + Vector3.new(0, bob, 0)
			local previous = companion.Position
			local position: Vector3
			if previous == nil or (previous - target).Magnitude > HotbarConfig.TeleportDistance then
				position = target
				previous = target
			else
				position = previous:Lerp(target, 1 - math.exp(-HotbarConfig.FollowResponse * dt))
			end
			companion.Position = position
			local velocity = if dt > 0 then (position - previous :: Vector3) / dt else Vector3.zero

			-- face the way the player faces; bank into sideways drift, tilt with climbing
			local look = root.CFrame.LookVector
			local desiredYaw = math.atan2(-look.X, -look.Z)
			companion.Yaw += angleDelta(desiredYaw, companion.Yaw) * (1 - math.exp(-6 * dt))
			local right = Vector3.new(math.cos(companion.Yaw), 0, -math.sin(companion.Yaw))
			local bankTarget = math.clamp(-velocity:Dot(right) * 0.06, -HotbarConfig.MaxBank, HotbarConfig.MaxBank)
			companion.Bank += (bankTarget - companion.Bank) * (1 - math.exp(-5 * dt))
			local pitchTarget = math.clamp(velocity.Y * 0.04, -0.4, 0.4)
			companion.Pitch += (pitchTarget - companion.Pitch) * (1 - math.exp(-5 * dt))
			model:PivotTo(CFrame.new(position) * CFrame.Angles(0, companion.Yaw, 0) * CFrame.Angles(companion.Pitch, 0, companion.Bank))

			local rig = companion.Rig
			if rig then
				local pose = companion.Pose
				pose.Flap += dt * HotbarConfig.FlapRate
				pose.Clock += dt
				pose.Turn = math.clamp(companion.Bank / HotbarConfig.MaxBank, -1, 1)
				pose.Pitch = math.clamp(companion.Pitch / 0.4, -1, 1)
				companion.Frame += 1
				if cameraDistance < HotbarConfig.FullRigDistance then
					DragonRig.Apply(rig, pose, "Full")
				elseif companion.Frame % 3 == 0 then
					DragonRig.Apply(rig, pose, "Simple")
				end
			end
		end
	end)
end

return CompanionController
