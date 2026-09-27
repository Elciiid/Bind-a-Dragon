--!strict
-- Server-validated local hub teleports. The client may request only these three named destinations.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local RoostService = require(script.Parent.RoostService)

local travelTo = ReplicatedStorage.Remotes.TravelTo :: RemoteEvent
local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent
local lastTravel: { [Player]: number } = {}
local COOLDOWN = 1.25

local TravelService = {}

local function getInstanceCFrame(instance: Instance): CFrame?
	if instance:IsA("BasePart") then
		return instance.CFrame
	elseif instance:IsA("Model") then
		local entrance = instance:FindFirstChild("Entrance", true) or instance:FindFirstChild("Spawn", true)
		if entrance and entrance:IsA("BasePart") then
			return entrance.CFrame
		end
		return instance:GetPivot()
	end
	return nil
end

local function getTaggedCFrame(tag: string): CFrame?
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(workspace) then
			local frame = getInstanceCFrame(instance)
			if frame then
				return frame
			end
		end
	end
	return nil
end

local function getDestination(player: Player, destination: string): CFrame?
	if destination == "Home" then
		local plot = RoostService:GetPlot(player)
		if plot == nil then
			return nil
		end
		local center = plot:GetAttribute("RoamCenter")
		if typeof(center) == "Vector3" then
			return CFrame.new(center + Vector3.new(0, 4, 0))
		end
		return plot:GetPivot() + Vector3.new(0, 5, 0)
	elseif destination == "Shop" then
		local merchant = getTaggedCFrame("StarMerchant")
		return if merchant then merchant * CFrame.new(0, 4, -8) else nil
	elseif destination == "DragonSpire" then
		local spire = getTaggedCFrame("DragonSpire")
		return if spire then spire * CFrame.new(0, 4, -10) else nil
	end
	return nil
end

local function onTravel(player: Player, requested: unknown)
	if typeof(requested) ~= "string" or (requested ~= "Home" and requested ~= "Shop" and requested ~= "DragonSpire") then
		return
	end
	local now = os.clock()
	if now - (lastTravel[player] or 0) < COOLDOWN then
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

	local target = getDestination(player, requested)
	if target == nil then
		notify:FireClient(player, `{requested} is not available right now.`, "error")
		return
	end
	character:PivotTo(target)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	local label = if requested == "Home" then "your Roost" elseif requested == "Shop" then "the Star Merchant" else "DragonSpire"
	notify:FireClient(player, `Traveled to {label}.`, "info")
end

function TravelService:Start()
	travelTo.OnServerEvent:Connect(onTravel)
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)
end

return TravelService
