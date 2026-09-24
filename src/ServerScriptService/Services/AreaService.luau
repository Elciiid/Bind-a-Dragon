--!strict
-- Area portals. A BasePart tagged "AreaPortal" with a string attribute "AreaId" teleports players who touch it to
-- that area's spawn: a BasePart tagged "AreaSpawn" with the same "AreaId". Locked areas (not enough rebirths,
-- see Config/Areas) refuse with a message. The check is on the server, so it can't be skipped by the client.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)

local PORTAL_TAG = "AreaPortal"
local SPAWN_TAG = "AreaSpawn"
local COOLDOWN = 2 -- seconds before the same player can use a portal again

local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local lastUse: { [Player]: number } = {}

local AreaService = {}

local function findSpawn(areaId: string): BasePart?
	for _, spawnPart in CollectionService:GetTagged(SPAWN_TAG) do
		if spawnPart:IsA("BasePart") and spawnPart:GetAttribute("AreaId") == areaId then
			return spawnPart
		end
	end
	return nil
end

local function onPortalTouched(portal: BasePart, hit: BasePart)
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if player == nil or character == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	local now = os.clock()
	if now - (lastUse[player] or 0) < COOLDOWN then
		return
	end
	lastUse[player] = now

	local areaId = portal:GetAttribute("AreaId")
	local area = if type(areaId) == "string" then Areas[areaId] else nil
	local data = DataService:GetData(player)
	if area == nil or data == nil or type(areaId) ~= "string" then
		return
	end
	if not DragonStats.IsAreaUnlocked(data, areaId) then
		local needed = area.RebirthsRequired
		notify:FireClient(player, `{area.Name} unlocks at {needed} rebirth{if needed == 1 then "" else "s"}.`, "error")
		return
	end

	local destination = findSpawn(areaId)
	if destination == nil then
		warn(`[AreaService] No AreaSpawn for {areaId}`)
		return
	end
	character:PivotTo(destination.CFrame + Vector3.new(0, 4, 0))
	notify:FireClient(player, `Welcome to {area.Name}!`, "info")
end

local function setupPortal(portal: Instance)
	if not portal:IsA("BasePart") then
		return
	end
	portal.Touched:Connect(function(hit)
		onPortalTouched(portal, hit)
	end)
end

function AreaService:Start()
	CollectionService:GetInstanceAddedSignal(PORTAL_TAG):Connect(setupPortal)
	for _, portal in CollectionService:GetTagged(PORTAL_TAG) do
		setupPortal(portal)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
end

return AreaService
