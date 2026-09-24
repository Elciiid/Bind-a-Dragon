--!strict
-- Gold sinks besides leveling (numbers in Config/Economy):
--  * Star Merchant: any instance tagged "StarMerchant" (BasePart, or Model with a PrimaryPart) gets a "Buy Stardust"
--    prompt. Each purchase buys a bundle; the price rises per purchase and resets at dawn (new cycle).
--  * Roost upgrades: BuyRoostUpgrade("Slots" | "Income") buys the next extra slot or income level.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local MERCHANT_TAG = "StarMerchant"
local MIN_REQUEST_INTERVAL = 0.25 -- seconds between economy requests per player (anti-spam)

local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent
local buyRoostUpgrade = ReplicatedStorage.Remotes.BuyRoostUpgrade :: RemoteEvent

local lastRequest: { [Player]: number } = {}

local EconomyService = {}

local function allowRequest(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < MIN_REQUEST_INTERVAL then
		return false
	end
	lastRequest[player] = now
	return true
end

local function buyStardust(player: Player)
	if not allowRequest(player) then
		return
	end
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	-- A cycle starts at dawn, so the cycle's index doubles as "today" for the merchant.
	local today = Cycle.GetState().NightIndex
	local price = DragonStats.GetMerchantPrice(data, today)
	if data.Gold < price then
		notify:FireClient(player, `You need {Format.Number(price)} gold for Stardust.`, "error")
		return
	end

	data.Gold -= price
	if data.MerchantDay ~= today then
		data.MerchantDay = today
		data.MerchantPurchases = 0
	end
	data.MerchantPurchases += 1
	data.Stardust += Economy.Merchant.BundleSize
	local nextPrice = DragonStats.GetMerchantPrice(data, today)
	notify:FireClient(
		player,
		`+{Economy.Merchant.BundleSize} Stardust! Next bundle today: {Format.Number(nextPrice)} gold.`,
		"success"
	)
end

local function onBuyRoostUpgrade(player: Player, kind: unknown)
	if (kind ~= "Slots" and kind ~= "Income") or not allowRequest(player) then
		return
	end
	local data = DataService:GetData(player)
	if data == nil then
		return
	end

	local cost = if kind == "Slots" then DragonStats.GetNextSlotCost(data) else DragonStats.GetNextIncomeUpgradeCost(data)
	if cost == nil then
		notify:FireClient(player, "That roost upgrade is already maxed.", "error")
		return
	end
	if data.Gold < cost then
		notify:FireClient(player, `You need {Format.Number(cost)} gold for that upgrade.`, "error")
		return
	end

	data.Gold -= cost
	if kind == "Slots" then
		data.RoostSlotUpgrades += 1
		notify:FireClient(player, `Roost expanded to {DragonStats.GetRoostSlots(data)} slots!`, "success")
	else
		data.RoostIncomeLevel += 1
		local bonus = math.round((DragonStats.GetRoostIncomeMultiplier(data) - 1) * 100)
		notify:FireClient(player, `Roost income is now +{bonus}%!`, "success")
	end
end

local function setupMerchant(merchant: Instance)
	local part = if merchant:IsA("BasePart") then merchant elseif merchant:IsA("Model") then merchant.PrimaryPart else nil
	if part == nil then
		warn(`[EconomyService] StarMerchant {merchant:GetFullName()} needs to be a BasePart or a Model with a PrimaryPart`)
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyStardustPrompt"
	prompt.ActionText = "Buy Stardust" -- each client shows its own price (MerchantController)
	prompt.ObjectText = "Star Merchant"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = Economy.Merchant.PromptHoldSeconds
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(buyStardust)
end

function EconomyService:Start()
	buyRoostUpgrade.OnServerEvent:Connect(onBuyRoostUpgrade)
	CollectionService:GetInstanceAddedSignal(MERCHANT_TAG):Connect(setupMerchant)
	for _, merchant in CollectionService:GetTagged(MERCHANT_TAG) do
		setupMerchant(merchant)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return EconomyService
