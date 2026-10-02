--!strict
-- Dragon Hotbar + carried companion (numbers in Config/Hotbar; client UI in HotbarController, companion drawing in
-- CompanionController).
--
-- data.Hotbar is a fixed list of Config/Hotbar.Slots dragon ids ("" = empty); a dragon sits in one slot at most.
--   SetHotbarSlot(slot, dragonId)  put an owned dragon in a slot ("" empties it; the dragon moves if it was in another slot)
--   CarryDragon(slot)              carry the dragon in that slot beside the player; the same slot again puts it away.
--                                  One carried at a time.
-- The carried dragon is shown to everybody through Player attributes (other clients can't read each other's data):
--   CarryDragonId, CarrySpecies, CarryMutation ("Normal" or a Config/Mutations id), CarryStage (Config/Evolution stage id),
--   CarryChampion (bool). All are "" / false while nothing is carried. Every request is type-checked, rate limited and
--   checked against the player's own dragons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local HotbarConfig = require(ReplicatedStorage.Shared.Config.Hotbar)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local setSlot = ReplicatedStorage.Remotes.SetHotbarSlot :: RemoteEvent
local carry = ReplicatedStorage.Remotes.CarryDragon :: RemoteEvent
local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local MAX_ID_LENGTH = 20

local lastSet: { [Player]: number } = {}
local lastCarry: { [Player]: number } = {}

local HotbarService = {}

local function isSlot(value: unknown): boolean
	return typeof(value) == "number" and value == math.floor(value) and value >= 1 and value <= HotbarConfig.Slots
end

local function clearCarry(player: Player)
	player:SetAttribute("CarryDragonId", "")
	player:SetAttribute("CarrySpecies", "")
	player:SetAttribute("CarryMutation", "")
	player:SetAttribute("CarryStage", "")
	player:SetAttribute("CarryChampion", false)
end

-- Publishes the carried dragon's look (species, mutation, evolution stage) on the player.
local function publishCarry(player: Player, dragon: PlayerDataTypes.Dragon)
	local mutation = Mutations.Get(dragon.MutationId)
	player:SetAttribute("CarryDragonId", dragon.Id)
	player:SetAttribute("CarrySpecies", dragon.SpeciesId)
	player:SetAttribute("CarryMutation", mutation.Id)
	player:SetAttribute("CarryStage", DragonStats.GetStage(dragon.Level).Id)
	player:SetAttribute("CarryChampion", dragon.Champion == true)
end

-- Makes data.Hotbar a clean fixed-size list of owned, unique dragon ids.
local function sanitize(data: PlayerDataTypes.PlayerData)
	local list = if type(data.Hotbar) == "table" then data.Hotbar else {}
	local seen: { [string]: boolean } = {}
	for slot = 1, HotbarConfig.Slots do
		local id = list[slot]
		if type(id) ~= "string" or id == "" or data.Dragons[id] == nil or seen[id] then
			list[slot] = ""
		else
			seen[id] = true
		end
	end
	for slot = HotbarConfig.Slots + 1, #list do
		list[slot] = nil
	end
	data.Hotbar = list
end

local function carriedId(player: Player): string
	local id = player:GetAttribute("CarryDragonId")
	return if type(id) == "string" then id else ""
end

local function onSetSlot(player: Player, slot: unknown, dragonId: unknown)
	if not isSlot(slot) or typeof(dragonId) ~= "string" or #dragonId > MAX_ID_LENGTH then
		return
	end
	local now = os.clock()
	if now - (lastSet[player] or 0) < HotbarConfig.SetCooldown then
		return
	end
	lastSet[player] = now
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	sanitize(data)
	local index = slot :: number
	if dragonId ~= "" and data.Dragons[dragonId] == nil then
		return -- not the player's dragon
	end
	if dragonId ~= "" then
		for other = 1, HotbarConfig.Slots do
			if data.Hotbar[other] == dragonId then
				data.Hotbar[other] = "" -- a dragon sits in one slot at most
			end
		end
	end
	local previous = data.Hotbar[index]
	data.Hotbar[index] = dragonId
	-- a carried dragon that left the hotbar is put away
	local carried = carriedId(player)
	if carried ~= "" and not table.find(data.Hotbar, carried) then
		clearCarry(player)
	elseif previous ~= "" and previous == carried and dragonId ~= previous then
		-- the carried dragon moved to another slot: still carried
		publishCarry(player, data.Dragons[carried])
	end
end

local function onCarry(player: Player, slot: unknown)
	if not isSlot(slot) then
		return
	end
	local now = os.clock()
	if now - (lastCarry[player] or 0) < HotbarConfig.CarryCooldown then
		return
	end
	lastCarry[player] = now
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	sanitize(data)
	local id = data.Hotbar[slot :: number]
	if id == "" then
		return
	end
	if carriedId(player) == id then
		clearCarry(player) -- the same slot again: put it away
		return
	end
	local dragon = data.Dragons[id]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if dragon == nil or Dragons[dragon.SpeciesId] == nil then
		return
	end
	if humanoid == nil or humanoid.Health <= 0 then
		notify:FireClient(player, "You can't carry a dragon right now.", "error")
		return
	end
	publishCarry(player, dragon)
end

function HotbarService:Start()
	setSlot.OnServerEvent:Connect(onSetSlot)
	carry.OnServerEvent:Connect(onCarry)
	Players.PlayerAdded:Connect(clearCarry)
	for _, player in Players:GetPlayers() do
		clearCarry(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSet[player] = nil
		lastCarry[player] = nil
	end)
	-- keep the carried look current (the dragon evolves as it levels; it might no longer be owned)
	task.spawn(function()
		while true do
			task.wait(HotbarConfig.StageRefreshSeconds)
			for _, player in Players:GetPlayers() do
				local id = carriedId(player)
				if id == "" then
					continue
				end
				local data = DataService:GetData(player)
				local dragon = data and data.Dragons[id]
				if data == nil or dragon == nil or not table.find(data.Hotbar, id) then
					clearCarry(player)
				elseif player:GetAttribute("CarryStage") ~= DragonStats.GetStage(dragon.Level).Id then
					publishCarry(player, dragon)
				end
			end
		end
	end)
end

-- The same handlers the remotes run (Studio tools call them through DevService).
HotbarService.HandleSet = onSetSlot
HotbarService.HandleCarry = onCarry

-- Cleans a player's hotbar once their data is loaded (called by Studio tools / after dragons change owners).
function HotbarService:Sanitize(player: Player)
	local data = DataService:GetData(player)
	if data then
		sanitize(data)
	end
end

return HotbarService
