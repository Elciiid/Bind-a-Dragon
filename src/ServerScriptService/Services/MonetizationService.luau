--!strict
-- Game passes and developer products (Config/Products).
--
-- Passes: ownership is checked on join and after an in-game purchase, cached per player, and mirrored to the client
-- as Player attributes "Pass_<Key>" (read-only for clients: attribute changes made by a client don't replicate).
-- Other services ask OwnsPass(player, key).
--
-- Developer products: ProcessReceipt grants the product, records the receipt's PurchaseId in the player's data,
-- and only returns PurchaseGranted once that data has been saved (ProfileStore LastSavedData), so a purchase is
-- never lost or granted twice.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataService = require(script.Parent.DataService)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local owned: { [Player]: { [string]: boolean } } = {}
local checked: { [Player]: boolean } = {} -- pass ownership has been looked up this session
local PASS_CHECK_TIMEOUT = 10

local MonetizationService = {}

local function setOwned(player: Player, key: string, value: boolean)
	owned[player] = owned[player] or {}
	owned[player][key] = value
	player:SetAttribute(`Pass_{key}`, value)
end

local function checkPasses(player: Player)
	for key, pass in Products.Passes do
		local has = false
		if pass.Id ~= 0 then
			local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			has = ok and result == true
		end
		if RunService:IsStudio() and player:GetAttribute(`TestPass_{key}`) == true then
			has = true
		end
		setOwned(player, key, has)
	end
	checked[player] = true
end

function MonetizationService:OwnsPass(player: Player, key: string): boolean
	local cache = owned[player]
	if cache and cache[key] then
		return true
	end
	-- Studio test attribute set after join.
	return RunService:IsStudio() and player:GetAttribute(`TestPass_{key}`) == true
end

-- Yields until the player's passes have been looked up (at most PASS_CHECK_TIMEOUT seconds).
-- Use before granting something on join that depends on a pass (offline income).
function MonetizationService:WaitForPasses(player: Player)
	local waited = 0
	while not checked[player] and waited < PASS_CHECK_TIMEOUT and player.Parent == Players do
		waited += task.wait(0.1)
	end
end

-- Uses the Tower Elevator for one climb: free with the pass, else spends one Elevator Skip.
function MonetizationService:UseElevator(player: Player, data: PlayerDataTypes.PlayerData): boolean
	if self:OwnsPass(player, "ElevatorPass") then
		return true
	end
	if data.ElevatorSkips > 0 then
		data.ElevatorSkips -= 1
		return true
	end
	return false
end

-- Product Id -> grant function. Runs once per receipt, before the save.
local grants: { [number]: (Player, PlayerDataTypes.PlayerData) -> () } = {}
if Products.Products.ElevatorSkip.Id ~= 0 then
	grants[Products.Products.ElevatorSkip.Id] = function(player, data)
		data.ElevatorSkips += 1
		notify:FireClient(player, "Elevator Skip added! Use it from the Spire panel.", "success")
	end
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries next time they join
	end
	local profile = DataService:GetProfile(player)
	local data = DataService:GetData(player)
	local grant = grants[receipt.ProductId]
	if profile == nil or data == nil or grant == nil then
		if grant == nil then
			warn(`[MonetizationService] No grant for product {receipt.ProductId}`)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receipt.PurchaseId)
	if DataService:RecordPurchaseId(player, purchaseId) then
		grant(player, data)
	end

	-- Only confirm once the grant (and its PurchaseId) is saved.
	local function isSaved(): boolean
		return table.find(profile.LastSavedData.PurchaseIds or {}, purchaseId) ~= nil
	end
	if not isSaved() then
		profile:Save()
		local waited = 0
		while not isSaved() and waited < Products.ReceiptSaveTimeout and profile:IsActive() do
			waited += task.wait(0.5)
		end
	end
	return if isSaved() then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

function MonetizationService:Init()
	MarketplaceService.ProcessReceipt = processReceipt
end

function MonetizationService:Start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, pass in Products.Passes do
			if pass.Id == passId then
				setOwned(player, key, true)
				notify:FireClient(player, `Thanks! {pass.Name} is now active.`, "success")
			end
		end
	end)
	Players.PlayerAdded:Connect(checkPasses)
	for _, player in Players:GetPlayers() do
		task.spawn(checkPasses, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		checked[player] = nil
	end)
end

return MonetizationService
