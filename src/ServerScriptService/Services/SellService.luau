--!strict
-- Selling to the Star Merchant (numbers in Config/Economy.Selling; the same price functions the client shows:
-- DragonStats.GetSellValue / GetSellProtection / IsRiskySale). Everything is decided here:
--   SellDragons(dragonIds, confirmedRisky)  sells whole dragons for gold (+ Wyrm Runes / Dragonstones for rarer ones).
--       Atomic: if any id isn't the player's, is protected (in the roost, on the hotbar, carried, locked, the champion), or the
--       list is too long, nothing is sold. Epic+ and mutated dragons need confirmedRisky = true (the client's extra confirm).
--   SellItems(kind, id, count)              sells potions / Wyrm Runes / Dragonstones for gold = seconds of the player's roost income.
--   SetDragonLocked(dragonId, locked)       the lock toggle on the Inventory cards (anywhere, not only at the merchant).
-- Selling needs the player alive and near a Star Merchant (EconomyService:NearMerchant); requests are type-checked and
-- rate limited. Gold banked at the rebirth cap is clamped like every other gold reward.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local sellDragons = ReplicatedStorage.Remotes.SellDragons :: RemoteEvent
local sellItems = ReplicatedStorage.Remotes.SellItems :: RemoteEvent
local setLocked = ReplicatedStorage.Remotes.SetDragonLocked :: RemoteEvent
local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local Selling = Economy.Selling
local MAX_ID_LENGTH = 20

local lastRequest: { [Player]: number } = {}

local SellService = {}

local function allow(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < Selling.RequestInterval then
		return false
	end
	lastRequest[player] = now
	return true
end

-- Adds sale gold, respecting the rebirth-cap bank limit; returns the gold actually added.
local function addGold(data: PlayerDataTypes.PlayerData, gold: number): number
	local limit = DragonStats.GetGoldBankLimit(data)
	if limit then
		gold = math.max(0, math.min(gold, limit - data.Gold))
	end
	data.Gold += gold
	return gold
end

local function carriedId(player: Player): string
	local id = player:GetAttribute("CarryDragonId")
	return if type(id) == "string" then id else ""
end

local function onSellDragons(player: Player, ids: unknown, confirmedRisky: unknown)
	if typeof(ids) ~= "table" or typeof(confirmedRisky) ~= "boolean" then
		return
	end
	local list = ids :: { unknown }
	if #list < 1 or #list > Selling.MaxDragonsPerRequest then
		return
	end
	if not allow(player) then
		return
	end
	if not EconomyService:NearMerchant(player) then
		notify:FireClient(player, "Come closer to the Star Merchant to sell.", "error")
		return
	end
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	-- validate everything first (atomic)
	local seen: { [string]: boolean } = {}
	local chosen: { PlayerDataTypes.Dragon } = {}
	local risky = false
	local carried = carriedId(player)
	for index = 1, #list do
		local id = list[index]
		if typeof(id) ~= "string" or #id > MAX_ID_LENGTH or seen[id] then
			return
		end
		seen[id] = true
		local dragon = data.Dragons[id]
		if dragon == nil or Dragons[dragon.SpeciesId] == nil then
			notify:FireClient(player, "One of those dragons isn't yours to sell anymore.", "error")
			return
		end
		if DragonStats.GetSellProtection(dragon, data, carried) ~= nil then
			notify:FireClient(player, "Some of those dragons are protected (roost, hotbar, locked or carried).", "error")
			return
		end
		if DragonStats.IsRiskySale(dragon) then
			risky = true
		end
		table.insert(chosen, dragon)
	end
	if risky and not confirmedRisky then
		notify:FireClient(player, "Confirm to sell Epic or better and mutated dragons.", "error")
		return
	end

	local gold, runes, stones = 0, 0, 0
	for _, dragon in chosen do
		local value, rewards = DragonStats.GetSellValue(dragon, data)
		gold += value
		runes += rewards.WyrmRunes
		stones += rewards.Dragonstones
	end
	for _, dragon in chosen do
		data.Dragons[dragon.Id] = nil
		local unplaced = table.find(data.RoostUnplacedDragonIds, dragon.Id)
		if unplaced then
			table.remove(data.RoostUnplacedDragonIds, unplaced)
		end
	end
	gold = addGold(data, gold)
	data.WyrmRunes += runes
	data.Dragonstones += stones

	local parts = { `{Format.Number(gold)} gold` }
	if runes > 0 then
		table.insert(parts, `{runes} Wyrm Runes`)
	end
	if stones > 0 then
		table.insert(parts, `{stones} Dragonstones`)
	end
	notify:FireClient(player, `Sold {#chosen} dragon{if #chosen == 1 then "" else "s"}: {table.concat(parts, ", ")}.`, "success")
end

local function onSellItems(player: Player, kind: unknown, id: unknown, count: unknown)
	if typeof(kind) ~= "string" or typeof(id) ~= "string" or #id > 40 or typeof(count) ~= "number" then
		return
	end
	if count ~= count or count < 1 or count ~= math.floor(count) or count > Selling.Items.MaxPerRequest then
		return
	end
	if not allow(player) then
		return
	end
	if not EconomyService:NearMerchant(player) then
		notify:FireClient(player, "Come closer to the Star Merchant to sell.", "error")
		return
	end
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	local seconds: number?
	local name: string
	if kind == "Potion" then
		seconds = (Selling.Items.Potions :: any)[id]
		local potion = Boosts.ById[id]
		if seconds == nil or potion == nil then
			return
		end
		name = potion.Name
		local owned = data.Potions[id] or 0
		local keep = if data.ArmedLuckPotion == id then 1 else 0 -- the armed luck charge stays
		if owned - count < keep then
			notify:FireClient(player, "You don't have that many to spare.", "error")
			return
		end
	elseif kind == "WyrmRunes" or kind == "Dragonstones" then
		if id ~= kind then
			return
		end
		seconds = (Selling.Items :: any)[kind]
		name = if kind == "WyrmRunes" then "Wyrm Runes" else "Dragonstones"
		if (data :: any)[kind] < count then
			notify:FireClient(player, "You don't have that many.", "error")
			return
		end
	else
		return
	end
	if seconds == nil then
		return
	end
	local income = DragonStats.GetRoostIncome(data)
	local total = math.floor(income * (seconds :: number) * count)
	if total <= 0 then
		notify:FireClient(player, "Put a dragon in your roost first: items sell for a share of your roost income.", "error")
		return
	end
	if kind == "Potion" then
		data.Potions[id] -= count
		if data.Potions[id] <= 0 then
			data.Potions[id] = nil
		end
	else
		(data :: any)[kind] -= count
	end
	local paid = addGold(data, total)
	notify:FireClient(player, `Sold {count} {name}: {Format.Number(paid)} gold.`, "success")
end

local function onSetLocked(player: Player, dragonId: unknown, locked: unknown)
	if typeof(dragonId) ~= "string" or #dragonId > MAX_ID_LENGTH or typeof(locked) ~= "boolean" then
		return
	end
	if not allow(player) then
		return
	end
	local data = DataService:GetData(player)
	local dragon = data and data.Dragons[dragonId]
	if dragon == nil then
		return
	end
	dragon.Locked = if locked then true else nil
end

function SellService:Start()
	sellDragons.OnServerEvent:Connect(onSellDragons)
	sellItems.OnServerEvent:Connect(onSellItems)
	setLocked.OnServerEvent:Connect(onSetLocked)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

-- Same handlers the remotes run (Studio tools call them through DevService).
SellService.HandleSellDragons = onSellDragons
SellService.HandleSellItems = onSellItems
SellService.HandleSetLocked = onSetLocked

return SellService
