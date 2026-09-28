--!strict
-- Roost upgrade stands in front of the local player's own pen ("UpgradeSlots" and "UpgradeIncome" parts in the plot).
-- Adds client-only prompts (so only the owner sees them) and asks the server to buy (BuyRoostUpgrade). The server
-- checks cost and limits. The stands' art, gems and level boards (seen by everyone) are UpgradeStandController.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local PLOT_TAG = "RoostPlot"
local UPDATE_INTERVAL = 0.4

local buyRoostUpgrade = ReplicatedStorage.Remotes.BuyRoostUpgrade :: RemoteEvent

local RoostUpgradeController = {}

type Stand = { Prompt: ProximityPrompt }
local stands: { [BasePart]: Stand } = {}

local function getOwnPlot(): Model?
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
			return plot
		end
	end
	return nil
end

local function ensureStand(part: BasePart, kind: string): Stand
	local existing = stands[part]
	if existing then
		return existing
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UpgradePrompt"
	prompt.ObjectText = if kind == "Slots" then "Expand roost" else "Roost income"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		buyRoostUpgrade:FireServer(kind)
	end)
	prompt.Parent = part

	local stand = { Prompt = prompt }
	stands[part] = stand
	return stand
end

local function update()
	-- Drop stands from a plot we no longer own (e.g. after rejoining a different server plot).
	local plot = getOwnPlot()
	for part, stand in stands do
		if plot == nil or not part:IsDescendantOf(plot) then
			stand.Prompt:Destroy()
			stands[part] = nil
		end
	end
	local data = DataController:Get()
	if plot == nil or data == nil then
		return
	end

	local slotsPart = plot:FindFirstChild("UpgradeSlots", true)
	if slotsPart and slotsPart:IsA("BasePart") then
		local stand = ensureStand(slotsPart, "Slots")
		local cost = DragonStats.GetNextSlotCost(data)
		stand.Prompt.ActionText = if cost then `+1 slot: {Format.Number(cost)} gold` else "Maxed"
		stand.Prompt.Enabled = cost ~= nil
	end

	local incomePart = plot:FindFirstChild("UpgradeIncome", true)
	if incomePart and incomePart:IsA("BasePart") then
		local stand = ensureStand(incomePart, "Income")
		local cost = DragonStats.GetNextIncomeUpgradeCost(data)
		local step = math.round(Economy.RoostUpgrades.IncomeBonusPerLevel * 100)
		stand.Prompt.ActionText = if cost then `+{step}% income: {Format.Number(cost)} gold` else "Maxed"
		stand.Prompt.Enabled = cost ~= nil
	end
end

function RoostUpgradeController:Start()
	while true do
		update()
		task.wait(UPDATE_INTERVAL)
	end
end

return RoostUpgradeController
