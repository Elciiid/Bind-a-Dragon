--!strict
-- Selling to the Star Merchant (numbers in Config/Economy.Selling; the same price functions the client shows:
-- DragonStats.GetSellValue / GetSellProtection / IsRiskySale). Everything is decided here:
--   SellDragons(dragonIds, confirmedRisky)       "I want to sell this!": sells the listed backpack dragons (the carried one).
--   SellInventory(confirmedRisky, expectedCount) "I want to sell my inventory!": sells EVERY backpack dragon (not in the roost) that is not
--       favorited. The server builds the list itself; expectedCount is what the client showed, a different count aborts the sale.
--   SetDragonFavorite(dragonId, favorite)        the star on the Inventory cards: a favorited dragon can never be sold.
--   SetAutoSell(settings)                        the merchant's "Edit auto sell settings" panel (data.AutoSell).
--   SellService:AutoSellNewDragon(...)           called by BindingService right after a bind: sells the new dragon when it matches the settings.
-- Sales are atomic: a dragon that is not the player's, is in the roost, favorited or the champion cancels the whole request. Epic or better
-- and mutated dragons need confirmedRisky = true (the client's second confirm). Selling needs the player alive and near a Star Merchant
-- (EconomyService:NearMerchant); requests are type-checked and rate limited. Gold banked at the rebirth cap is clamped like every other reward.
-- Every sale bumps the player attribute MerchantSales so the merchant NPC can react (hop + coin toss) on every client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local HotbarService = require(script.Parent.HotbarService)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local sellDragons = ReplicatedStorage.Remotes.SellDragons :: RemoteEvent
local sellInventory = ReplicatedStorage.Remotes.SellInventory :: RemoteEvent
local setFavorite = ReplicatedStorage.Remotes.SetDragonFavorite :: RemoteEvent
local setAutoSell = ReplicatedStorage.Remotes.SetAutoSell :: RemoteEvent
local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local Selling = Economy.Selling
local MAX_ID_LENGTH = 20
local RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

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

-- Removes the dragons, pays gold + runes/stones; returns the totals. The caller has validated everything.
local function completeSale(player: Player, data: PlayerDataTypes.PlayerData, chosen: { PlayerDataTypes.Dragon }): (number, number, number)
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
	HotbarService:OnDragonsRemoved(player)
	player:SetAttribute("MerchantSales", (player:GetAttribute("MerchantSales") or 0) + 1)
	return gold, runes, stones
end

local function saleText(count: number, gold: number, runes: number, stones: number): string
	local parts = { `{Format.Number(gold)} gold` }
	if runes > 0 then
		table.insert(parts, `{runes} Wyrm Runes`)
	end
	if stones > 0 then
		table.insert(parts, `{stones} Dragonstones`)
	end
	return `Sold {count} dragon{if count == 1 then "" else "s"}: {table.concat(parts, ", ")}.`
end

-- Validates and sells a list of dragon ids (as the client chose them). Returns true when sold.
local function sellList(player: Player, data: PlayerDataTypes.PlayerData, ids: { unknown }, confirmedRisky: boolean): boolean
	local seen: { [string]: boolean } = {}
	local chosen: { PlayerDataTypes.Dragon } = {}
	local risky = false
	for index = 1, #ids do
		local id = ids[index]
		if typeof(id) ~= "string" or #id > MAX_ID_LENGTH or seen[id] then
			return false
		end
		seen[id] = true
		local dragon = data.Dragons[id]
		if dragon == nil or Dragons[dragon.SpeciesId] == nil then
			notify:FireClient(player, "That dragon isn't yours to sell anymore.", "error")
			return false
		end
		local why = DragonStats.GetSellProtection(dragon, data)
		if why ~= nil then
			notify:FireClient(player, if why == "Favorite" then "Favorite dragons can't be sold." else "That dragon can't be sold (it is in your sanctuary).", "error")
			return false
		end
		if DragonStats.IsRiskySale(dragon) then
			risky = true
		end
		table.insert(chosen, dragon)
	end
	if risky and not confirmedRisky then
		notify:FireClient(player, "Confirm to sell Epic or better and mutated dragons.", "error")
		return false
	end
	local gold, runes, stones = completeSale(player, data, chosen)
	notify:FireClient(player, saleText(#chosen, gold, runes, stones), "success")
	return true
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
	sellList(player, data, list, confirmedRisky)
end

local function onSellInventory(player: Player, confirmedRisky: unknown, expectedCount: unknown)
	if typeof(confirmedRisky) ~= "boolean" or typeof(expectedCount) ~= "number" or expectedCount ~= math.floor(expectedCount) or expectedCount < 1 then
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
	local chosen = DragonStats.GetSellableInventory(data)
	if #chosen ~= expectedCount then
		notify:FireClient(player, "Your backpack changed. Talk to the merchant again.", "error")
		return
	end
	local risky = false
	for _, dragon in chosen do
		if Dragons[dragon.SpeciesId] == nil then
			return
		end
		if DragonStats.IsRiskySale(dragon) then
			risky = true
		end
	end
	if risky and not confirmedRisky then
		notify:FireClient(player, "Confirm to sell Epic or better and mutated dragons.", "error")
		return
	end
	local gold, runes, stones = completeSale(player, data, chosen)
	notify:FireClient(player, saleText(#chosen, gold, runes, stones), "success")
end

local function onSetFavorite(player: Player, dragonId: unknown, favorite: unknown)
	if typeof(dragonId) ~= "string" or #dragonId > MAX_ID_LENGTH or typeof(favorite) ~= "boolean" then
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
	dragon.Favorite = if favorite then true else nil
end

local function onSetAutoSell(player: Player, settings: unknown)
	if typeof(settings) ~= "table" then
		return
	end
	if not allow(player) then
		return
	end
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	local incoming = settings :: { [string]: unknown }
	local clean = table.clone(data.AutoSell)
	for _, key in RARITIES do
		local value = incoming[key]
		if typeof(value) == "boolean" then
			(clean :: any)[key] = value
		end
	end
	for _, key in { "KeepMutated", "KeepNewSpecies" } do
		local value = incoming[key]
		if typeof(value) == "boolean" then
			(clean :: any)[key] = value
		end
	end
	data.AutoSell = clean
end

-- Called by BindingService right after a bind (before the Index records the species): sells the new dragon when it matches the player's
-- auto sell settings and returns the gold it paid (nil = kept). `newSpecies` = the species was not in the Index before this bind. The
-- reveal pop-up shows the sale (BindResult.AutoSoldGold), so there is no separate toast.
function SellService:AutoSellNewDragon(player: Player, data: PlayerDataTypes.PlayerData, dragonId: string, newSpecies: boolean): number?
	local dragon = data.Dragons[dragonId]
	local settings = data.AutoSell
	local species = dragon and Dragons[dragon.SpeciesId]
	if dragon == nil or species == nil or settings == nil then
		return
	end
	if (settings :: any)[species.Rarity] ~= true then
		return
	end
	if settings.KeepMutated and Mutations.Get(dragon.MutationId).Id ~= Mutations.NormalId then
		return
	end
	if settings.KeepNewSpecies and newSpecies then
		return
	end
	if DragonStats.GetSellProtection(dragon, data) ~= nil then
		return
	end
	return (completeSale(player, data, { dragon }))
end

function SellService:Start()
	sellDragons.OnServerEvent:Connect(onSellDragons)
	sellInventory.OnServerEvent:Connect(onSellInventory)
	setFavorite.OnServerEvent:Connect(onSetFavorite)
	setAutoSell.OnServerEvent:Connect(onSetAutoSell)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

-- Same handlers the remotes run (Studio tools call them through DevService).
SellService.HandleSellDragons = onSellDragons
SellService.HandleSellInventory = onSellInventory
SellService.HandleSetFavorite = onSetFavorite
SellService.HandleSetAutoSell = onSetAutoSell

return SellService
