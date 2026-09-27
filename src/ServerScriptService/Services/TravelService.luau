--!strict
-- Travel ("Waystones"): TravelTo(destinationId) teleports the player to a spot in the Valley (Config/Travel).
-- Server-checked: the id must be a configured destination, the player must be alive and in the Valley, with a
-- cooldown; the landing spot comes from Workspace.StarterMeadow.TravelPoints (the player's own sanctuary = the point
-- named after their plot). The destination is streamed in first, like AreaService.
-- Based on Kyle's TravelService (Hakai branch).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local RoostService = require(script.Parent.RoostService)
local CurrentArea = require(ReplicatedStorage.Shared.CurrentArea)
local Travel = require(ReplicatedStorage.Shared.Config.Travel)
local Text = require(ReplicatedStorage.Shared.Config.Text)

local travelTo = ReplicatedStorage.Remotes.TravelTo :: RemoteEvent
local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local lastTravel: { [Player]: number } = {}

local TravelService = {}

local function findDestination(id: string): { Id: string, Point: string?, Kind: string }?
	for _, destination in Travel.Destinations do
		if destination.Id == id then
			return destination
		end
	end
	return nil
end

local function landingPoint(player: Player, pointName: string?): BasePart?
	local meadow = workspace:FindFirstChild("StarterMeadow")
	local points = meadow and meadow:FindFirstChild("TravelPoints")
	if points == nil then
		return nil
	end
	local name = pointName
	if name == nil then
		local plot = RoostService:GetPlot(player)
		name = if plot then plot.Name else nil
	end
	local part = if name then points:FindFirstChild(name) else nil
	return if part and part:IsA("BasePart") then part else nil
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
	if CurrentArea.At(root.Position) ~= Travel.Area then
		notify:FireClient(player, Text.Travel.OnlyInValley, "error")
		return
	end

	local place = Text.Travel.Places[destination.Id] or destination.Id
	local point = landingPoint(player, destination.Point)
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

function TravelService:Start()
	travelTo.OnServerEvent:Connect(onTravel)
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)
end

return TravelService
