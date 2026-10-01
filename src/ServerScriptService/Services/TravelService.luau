--!strict
-- Travel: TravelTo(destinationId) teleports the player to a spot in the Valley (Config/Travel), from any area.
-- Server-checked: the id must be a configured destination, the player must be alive, with a cooldown; the landing
-- spot comes from Workspace.StarterMeadow.TravelPoints (Home = the point named after the player's plot, or the
-- destination's Fallback while they have none). The destination is streamed in first, like AreaService.
-- Based on Kyle's TravelService (Hakai branch).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local RebirthMilestones = require(ReplicatedStorage.Shared.RebirthMilestones)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local MilestoneConfig = require(ReplicatedStorage.Shared.Config.RebirthMilestones)
local RoostService = require(script.Parent.RoostService)
local Travel = require(ReplicatedStorage.Shared.Config.Travel)
local Text = require(ReplicatedStorage.Shared.Config.Text)

local travelTo = ReplicatedStorage.Remotes.TravelTo :: RemoteEvent
local travelToAltar = ReplicatedStorage.Remotes.TravelToAltar :: RemoteEvent
local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local lastTravel: { [Player]: number } = {}

local TravelService = {}

local function findDestination(id: string): { Id: string, Point: string?, Fallback: string? }?
	for _, destination in Travel.Destinations do
		if destination.Id == id then
			return destination
		end
	end
	return nil
end

-- The landing part, and whether it is the destination's fallback (Home without a sanctuary).
local function landingPoint(player: Player, destination: { Point: string?, Fallback: string? }): (BasePart?, boolean)
	local meadow = workspace:FindFirstChild("StarterMeadow")
	local points = meadow and meadow:FindFirstChild("TravelPoints")
	if points == nil then
		return nil, false
	end
	local name = destination.Point
	if name == nil then
		local plot = RoostService:GetPlot(player)
		name = if plot then plot.Name else nil
	end
	local part = if name then points:FindFirstChild(name) else nil
	if part and part:IsA("BasePart") then
		return part, false
	end
	local fallback = if destination.Fallback then points:FindFirstChild(destination.Fallback) else nil
	return if fallback and fallback:IsA("BasePart") then fallback else nil, true
end

local function onTravel(player: Player, requested: unknown)
	if typeof(requested) ~= "string" or #requested > 20 then
		return
	end
	local destination = findDestination(requested)
	if destination == nil then
		return
	end
	local now = os.clock()
	if now - (lastTravel[player] or 0) < Travel.Cooldown then
		return
	end
	lastTravel[player] = now
	if DataService:GetData(player) == nil then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local point, isFallback = landingPoint(player, destination)
	local place = if isFallback then Text.Travel.HomeFallback else (Text.Travel.Places[destination.Id] or destination.Id)
	if point == nil then
		notify:FireClient(player, Text.Format(Text.Travel.Unavailable, { place = place }), "error")
		return
	end
	local target = point.CFrame + Vector3.new(0, Travel.LandHeight, 0)
	pcall(function()
		player:RequestStreamAroundAsync(target.Position, Travel.StreamTimeout)
	end)
	if character.Parent == nil or humanoid.Health <= 0 then
		return
	end
	character:PivotTo(target)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	notify:FireClient(player, Text.Format(Text.Travel.Arrived, { place = place }), "info")
end

-- Altar Travel (R18 milestone): go to the front of any unlocked area's Star Altar. Checked here: the milestone, a real
-- area the player has unlocked, an altar that exists, a live character, the shared cooldown.
local function onTravelToAltar(player: Player, requested: unknown)
	if typeof(requested) ~= "string" or #requested > 30 or Areas[requested] == nil then
		return
	end
	local now = os.clock()
	if now - (lastTravel[player] or 0) < Travel.Cooldown then
		return
	end
	local data = DataService:GetData(player)
	if data == nil or not RebirthMilestones.Has(data.Rebirths, "AltarTravel") or not DragonStats.IsAreaUnlocked(data, requested) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local altarPart: BasePart? = nil
	for _, altar in CollectionService:GetTagged("StarAltar") do
		if altar:GetAttribute("AreaId") == requested and altar:IsA("Model") and altar.PrimaryPart then
			altarPart = altar.PrimaryPart
			break
		end
	end
	local place = Areas[requested].Name
	if altarPart == nil then
		notify:FireClient(player, Text.Format(Text.Milestones.Altars.Unavailable, { place = place }), "error")
		return
	end
	lastTravel[player] = now
	local position = altarPart.Position + MilestoneConfig.AltarTravel.Offset
	pcall(function()
		player:RequestStreamAroundAsync(position, Travel.StreamTimeout)
	end)
	if character.Parent == nil or humanoid.Health <= 0 then
		return
	end
	character:PivotTo(CFrame.lookAt(position, Vector3.new(altarPart.Position.X, position.Y, altarPart.Position.Z)))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	notify:FireClient(player, Text.Format(Text.Milestones.Altars.Arrived, { place = place }), "info")
end

function TravelService:Start()
	travelTo.OnServerEvent:Connect(onTravel)
	travelToAltar.OnServerEvent:Connect(onTravelToAltar)
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)
end

return TravelService
