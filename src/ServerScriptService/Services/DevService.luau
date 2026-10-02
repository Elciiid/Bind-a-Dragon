--!strict
-- Studio-only test hooks (does nothing in a live server). Creates ServerStorage.DevTools.GiveDragons, a
-- BindableFunction that Studio tools (command bar, the MCP) can invoke on the server during Play:
--   GiveDragons:Invoke(player, { "Solflare", "Borealis" }, level, placeInRoost?)
-- adds one dragon per species id at that level (capped at the player's level cap) and, with placeInRoost, puts the
-- new dragons first in the roost (the roost redraws on the next payout). Returns the new dragon ids.
--   SetRoostSlots:Invoke(player, slots) sets the roost slot upgrades so the roost has that many slots (max MaxSlots).
-- A BindableFunction in ServerStorage can't be reached by clients; it is never created outside Studio.
-- Studio tools whose thread may not invoke the bindables (the MCP's execute_luau) set the Workspace string attribute
-- "DevCommand" to JSON instead: { "Op": "Items", "Args": {...} } | { "Op": "Dragons", "Ids": [..], "Level": n, "Place": true,
-- "Mutation": "Hoardscale" } | { "Op": "Slots", "Slots": n } | { "Op": "UseBoost", "Id": "GildedDraught" } | { "Op": "Level", "Id": dragonId, "Count": n } | { "Op": "Hotbar", "Slot": 1, "Id": dragonId } | { "Op": "Carry", "Slot": 1 } | { "Op": "SellDragons", "Ids": [..], "Confirmed": false } | { "Op": "SellInventory", "Confirmed": false, "Expected": n } | { "Op": "Favorite", "Id": dragonId, "Favorite": true } | { "Op": "AutoSell", "Settings": {..} } | { "Op": "AutoSellNew", "Species": "Frostling", "Mutation": nil, "NewSpecies": false } | { "Op": "SpireAction", "Action": "Start", "Value": nil } | { "Op": "FireClient", "Remote": "BindResult", "Args": [..] } | { "Op": "Get", "Keys": ["Gold"] } | { "Op": "Teleport", "X": 0, "Y": 5, "Z": 0 } | { "Op": "SimStart", "Job": "x", "Profile": "Dedicated", "Runs": 10, "Days": 60, "Variants": { "SellSurplus": true } } | { "Op": "SimResult", "Job": "x" } | { "Op": "Config", "Module": "Spire", "Key": "FightSeconds", "Value": 1 } | { "Op": "Set", "Key": "Gold", "Value": 5 }; it acts on the first
-- player and answers in the attribute "DevResult" (JSON).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local BoostService = require(script.Parent.BoostService)
local DataService = require(script.Parent.DataService)
local DragonService = require(script.Parent.DragonService)
local HotbarService = require(script.Parent.HotbarService)
local SellService = require(script.Parent.SellService)
local SpireService = require(script.Parent.SpireService)
local IndexService = require(script.Parent.IndexService)
local MilestoneService = require(script.Parent.MilestoneService)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local BindingOdds = require(ReplicatedStorage.Shared.BindingOdds)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local RoostConfig = require(ReplicatedStorage.Shared.Config.Roost)

local RebirthMilestones = require(ReplicatedStorage.Shared.RebirthMilestones)
local Rewards = require(ReplicatedStorage.Shared.Rewards)

local DevService = {}

local function giveDragons(player: Player, speciesIds: { string }, level: number, placeInRoost: boolean?, mutationId: string?): { string }
	assert(typeof(player) == "Instance" and player:IsA("Player"), "GiveDragons: player expected")
	local data = DataService:GetData(player)
	assert(data, "GiveDragons: player data not loaded yet")
	local cap = DragonStats.GetLevelCap(data)
	local ids = {}
	local mutation = Mutations.Get(mutationId)
	assert(mutationId == nil or Mutations.ById[mutationId] ~= nil, `GiveDragons: unknown mutation {mutationId}`)
	for _, speciesId in speciesIds do
		assert(Dragons[speciesId], `GiveDragons: unknown species {speciesId}`)
		local dragonId = tostring(data.NextDragonId)
		data.NextDragonId += 1
		data.Dragons[dragonId] = {
			Id = dragonId,
			SpeciesId = speciesId,
			Level = math.clamp(math.floor(level), 1, cap),
			ObtainedAt = os.time(),
			MutationId = if mutation.Id ~= Mutations.NormalId then mutation.Id else nil,
		}
		table.insert(ids, dragonId)
	end
	if placeInRoost then
		local slots = DragonStats.GetRoostSlots(data)
		local roost = table.clone(ids)
		for _, id in data.RoostDragonIds do
			if #roost < slots and not table.find(roost, id) then
				table.insert(roost, id)
			end
		end
		while #roost > slots do
			table.remove(roost)
		end
		table.clear(data.RoostDragonIds)
		for _, id in roost do
			table.insert(data.RoostDragonIds, id)
		end
	end
	IndexService:Sync(player, data)
	return ids
end

local function simulateBinding(areaId: string, element: string?, luck: number, samples: number, seed: number?): any
	local count = math.clamp(math.floor(samples), 1, 5_000_000)
	local rng = Random.new(seed or 12345)
	local results: { [string]: number } = {}
	for _ = 1, count do
		local outcome = BindingOdds.Roll(rng, areaId, element, luck)
		assert(outcome, "SimulateBinding: empty eligible pool")
		local key = `{outcome.SpeciesId}:{outcome.MutationId}`
		results[key] = (results[key] or 0) + 1
	end
	return { Samples = count, Counts = results, Expected = BindingOdds.GetPool(areaId, element, luck) }
end

local function setRoostSlots(player: Player, slots: number): number
	local data = DataService:GetData(player)
	assert(data, "SetRoostSlots: player data not loaded yet")
	data.RoostSlotUpgrades = math.clamp(math.floor(slots) - RoostConfig.BaseSlots, 0, RoostConfig.MaxSlots - RoostConfig.BaseSlots)
	return DragonStats.GetRoostSlots(data)
end

-- GiveItems:Invoke(player, { Sigils = n, Gold = n, Rebirths = n (adds; also celebrates milestones), Potions = { GildedDraught = 2 }, WyrmRunes = n, Dragonstones = n, Stardust = n })
-- adds test items to a player's data (Sigils respect the Config/Binding cap).
local function giveItems(player: Player, items: any): any
	local data = DataService:GetData(player)
	assert(data, "GiveItems: player data not loaded yet")
	if items.Gold then
		data.Gold = math.max(0, data.Gold + items.Gold)
	end
	if items.Rebirths then
		data.Rebirths = math.max(0, data.Rebirths + math.floor(items.Rebirths))
		MilestoneService:OnRebirth(player, data) -- celebrate milestones like a real rebirth would (no gold cost)
	end
	if items.Sigils then
		data.EchoSigils = math.clamp(data.EchoSigils + math.floor(items.Sigils), 0, RebirthMilestones.GetEchoSigilCap(data.Rebirths))
	end
	Rewards.Apply(data, { Potions = items.Potions, WyrmRunes = items.WyrmRunes, Dragonstones = items.Dragonstones, Stardust = items.Stardust })
	return { EchoSigils = data.EchoSigils, Gold = data.Gold, Rebirths = data.Rebirths }
end

function DevService:Start()
	if not RunService:IsStudio() then
		return
	end
	local folder = ServerStorage:FindFirstChild("DevTools") or Instance.new("Folder")
	folder.Name = "DevTools"
	folder.Parent = ServerStorage
	local give = Instance.new("BindableFunction")
	give.Name = "GiveDragons"
	give.OnInvoke = giveDragons
	give.Parent = folder
	local slots = Instance.new("BindableFunction")
	slots.Name = "SetRoostSlots"
	slots.OnInvoke = setRoostSlots
	slots.Parent = folder
	local items = Instance.new("BindableFunction")
	items.Name = "GiveItems"
	items.OnInvoke = giveItems
	items.Parent = folder
	workspace:GetAttributeChangedSignal("DevCommand"):Connect(function()
		local raw = workspace:GetAttribute("DevCommand")
		if type(raw) ~= "string" or raw == "" then
			return
		end
		workspace:SetAttribute("DevCommand", nil)
		local ok, result = pcall(function()
			local cmd = HttpService:JSONDecode(raw)
			local player = Players:GetPlayers()[1]
			assert(player, "no player")
			if cmd.Op == "Items" then
				return giveItems(player, cmd.Args)
			elseif cmd.Op == "Dragons" then
				return giveDragons(player, cmd.Ids, cmd.Level or 1, cmd.Place, cmd.Mutation)
			elseif cmd.Op == "Slots" then
				return setRoostSlots(player, cmd.Slots)
			elseif cmd.Op == "UseBoost" then
				BoostService.Use(player, cmd.Id)
				return cmd.Id
			elseif cmd.Op == "Level" then
				local data = DataService:GetData(player)
				assert(data and data.Dragons[cmd.Id], "unknown dragon")
				local before = data.Gold
				local leveled = DragonService:BuyLevels(player, data, data.Dragons[cmd.Id], cmd.Count or 1)
				return { Leveled = leveled, Spent = before - data.Gold, Level = data.Dragons[cmd.Id].Level }
			elseif cmd.Op == "Hotbar" then
				HotbarService.HandleSet(player, cmd.Slot, cmd.Id)
				return cmd.Slot
			elseif cmd.Op == "SellDragons" then
				SellService.HandleSellDragons(player, cmd.Ids, cmd.Confirmed == true)
				return cmd.Ids
			elseif cmd.Op == "SellInventory" then
				SellService.HandleSellInventory(player, cmd.Confirmed == true, cmd.Expected)
				return cmd.Expected
			elseif cmd.Op == "AutoSellNew" then
				-- gives a dragon and runs the bind-time auto sell on it, like BindingService does
				local ids = giveDragons(player, { cmd.Species }, 1, false, cmd.Mutation)
				local data = DataService:GetData(player)
				assert(data, "no data")
				SellService:AutoSellNewDragon(player, data, ids[1], cmd.NewSpecies == true)
				return { Id = ids[1], Sold = data.Dragons[ids[1]] == nil }
			elseif cmd.Op == "Favorite" then
				SellService.HandleSetFavorite(player, cmd.Id, cmd.Favorite == true)
				return cmd.Id
			elseif cmd.Op == "AutoSell" then
				SellService.HandleSetAutoSell(player, cmd.Settings)
				return cmd.Settings
			elseif cmd.Op == "Carry" then
				HotbarService.HandleCarry(player, cmd.Slot)
				return cmd.Slot
			elseif cmd.Op == "SpireAction" then
				SpireService.HandleAction(player, cmd.Action, cmd.Value)
				return cmd.Action
			elseif cmd.Op == "FireClient" then
				local remote = ReplicatedStorage.Remotes:FindFirstChild(cmd.Remote)
				assert(remote and remote:IsA("RemoteEvent"), "unknown remote")
				remote:FireClient(player, table.unpack(cmd.Args or {}))
				return cmd.Remote
			elseif cmd.Op == "Config" then
				-- Studio-only: change a Config value in the running server (e.g. Spire FightSeconds to speed up a loop test)
				local config = require(ReplicatedStorage.Shared.Config[cmd.Module])
				config[cmd.Key] = cmd.Value
				return config[cmd.Key]
			elseif cmd.Op == "Get" then
				local data = DataService:GetData(player)
				assert(data, "no data")
				local out = {}
				for _, key in cmd.Keys do
					out[key] = data[key]
				end
				return out
			elseif cmd.Op == "Teleport" then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				assert(root and root:IsA("BasePart"), "no character")
				player.Character:PivotTo(CFrame.new(cmd.X, cmd.Y, cmd.Z))
				return "ok"
			elseif cmd.Op == "SimStart" then
				-- tools/sim/CohortSim.luau copied to ReplicatedStorage.TempCohortSim (never committed): a background cohort run
				local Sim = require(ReplicatedStorage:WaitForChild("TempCohortSim")) :: any
				local folder = ServerStorage:FindFirstChild("SimTools") or Instance.new("Folder")
				folder.Name = "SimTools"
				folder.Parent = ServerStorage
				Sim.Reset()
				for key, value in cmd.Variants or {} do
					Sim.SetVariant(key, value)
				end
				for _, change in cmd.Config or {} do
					Sim.Set(change.Module, change.Key, change.Value)
				end
				Sim.Start(cmd.Job, cmd.Profile, cmd.Runs, cmd.Days, cmd.Weeks)
				return cmd.Job
			elseif cmd.Op == "SimResult" then
				local box = ServerStorage:FindFirstChild("SimTools") and ServerStorage.SimTools:FindFirstChild("Result_" .. cmd.Job)
				return if box then (box :: StringValue).Value else "no such job"
			elseif cmd.Op == "Set" then
				local data = DataService:GetData(player)
				assert(data and type(cmd.Key) == "string", "bad Set")
				data[cmd.Key] = cmd.Value
				return cmd.Value
			end
			error("unknown Op " .. tostring(cmd.Op))
		end)
		workspace:SetAttribute("DevResult", HttpService:JSONEncode({ Ok = ok, Result = if ok then result else tostring(result) }))
	end)
	local simulate = Instance.new("BindableFunction")
	simulate.Name = "SimulateBinding"
	simulate.OnInvoke = simulateBinding
	simulate.Parent = folder
end

return DevService
