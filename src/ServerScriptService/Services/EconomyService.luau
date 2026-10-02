--!strict
-- Gold sinks besides leveling (numbers in Config/Economy):
--  * Star Merchant: any instance tagged "StarMerchant" (BasePart, or Model with a PrimaryPart) gets a "Buy Stardust"
--    prompt. Each purchase buys a bundle; the price rises per purchase and resets at dawn (new cycle).
--  * Roost upgrades: BuyRoostUpgrade("Slots" | "Income") buys the next extra slot or income level.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local RoostService = require(script.Parent.RoostService)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Text = require(ReplicatedStorage.Shared.Config.Text)

local MERCHANT_TAG = "StarMerchant"
local UPGRADE_STAND_RANGE = 16 -- studs from the player's own upgrade stand (the client prompt reaches 10)

local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent
local buyRoostUpgrade = ReplicatedStorage.Remotes.BuyRoostUpgrade :: RemoteEvent
local buyStardustRemote = ReplicatedStorage.Remotes.BuyStardust :: RemoteEvent

local lastRequest: { [Player]: number } = {}

local EconomyService = {}

-- GLB imports may lack PrimaryPart. Prefer an explicitly authored interaction anchor.
local function merchantPart(merchant: Instance): BasePart?
	if merchant:IsA("BasePart") then return merchant end
	local anchor = merchant:FindFirstChild("InteractionAnchor", true)
	if anchor and anchor:IsA("BasePart") then return anchor end
	if merchant:IsA("Model") and merchant.PrimaryPart then return merchant.PrimaryPart end
	return merchant:FindFirstChildWhichIsA("BasePart", true)
end

local function nearMerchant(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return false end
	for _, merchant in CollectionService:GetTagged(MERCHANT_TAG) do
		local anchor = merchantPart(merchant)
		if anchor and (root.Position - anchor.Position).Magnitude <= Economy.Merchant.PurchaseRange then return true end
	end
	return false
end

-- Is the player alive and within PurchaseRange of a Star Merchant? (also used by SellService)
function EconomyService:NearMerchant(player: Player): boolean
	return nearMerchant(player)
end

local function allowRequest(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < Economy.Merchant.RequestInterval then
		return false
	end
	lastRequest[player] = now
	return true
end

local function buyStardust(player: Player, request: unknown)
	if request ~= "Bundle" or not allowRequest(player) or not nearMerchant(player) then
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
	-- Must be standing at the matching stand in front of their own roost.
	local plot = RoostService:GetPlot(player)
	local stand = plot and plot:FindFirstChild(if kind == "Slots" then "UpgradeSlots" else "UpgradeIncome", true)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local standPosition = if stand and stand:IsA("BasePart")
		then stand.Position
		elseif stand and stand:IsA("Model") then stand:GetPivot().Position
		else nil
	if standPosition == nil or root == nil or not root:IsA("BasePart") or (root.Position - standPosition).Magnitude > UPGRADE_STAND_RANGE then
		notify:FireClient(player, "Buy roost upgrades at the stands in front of your roost.", "error")
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
	local part = merchantPart(merchant)
	if part == nil then
		warn(`[EconomyService] StarMerchant {merchant:GetFullName()} needs to be a BasePart or a Model with a PrimaryPart`)
		return
	end
	local existing = merchant:FindFirstChild("BuyStardustPrompt", true)
	local prompt = if existing and existing:IsA("ProximityPrompt") then existing else Instance.new("ProximityPrompt")
	prompt.Name = "BuyStardustPrompt"
	prompt.ActionText = Text.Merchant.Talk
	prompt.ObjectText = Text.Merchant.Title
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = Economy.Merchant.PromptHoldSeconds
	prompt.MaxActivationDistance = Economy.Merchant.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
end

function EconomyService:Start()
	buyRoostUpgrade.OnServerEvent:Connect(onBuyRoostUpgrade)
	buyStardustRemote.OnServerEvent:Connect(buyStardust)
	CollectionService:GetInstanceAddedSignal(MERCHANT_TAG):Connect(setupMerchant)
	for _, merchant in CollectionService:GetTagged(MERCHANT_TAG) do
		setupMerchant(merchant)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return EconomyService
