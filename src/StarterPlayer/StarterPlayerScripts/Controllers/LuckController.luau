--!strict
-- At night, near a Star Altar: shows the player's current bind luck with a breakdown of every source, and keeps
-- the altar prompts up to date for this player (offer cost, hidden once they've bound). Placeholder UI.
-- Uses Shared/Luck, the same math the server rolls with. A button cycles which luck charge (Config/Boosts) is
-- armed for this bind: none -> each owned charge -> none.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local Format = require(ReplicatedStorage.Shared.Format)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local LuckConfig = require(ReplicatedStorage.Shared.Config.Luck)

local ALTAR_TAG = "StarAltar"
local SHOW_DISTANCE = LuckConfig.GroupRadius -- show the panel within this many studs of an altar
local UPDATE_INTERVAL = 0.25

local useBoost = ReplicatedStorage.Remotes.UseBoost :: RemoteEvent

local LuckController = {}

local panel: Frame
local title: TextLabel
local details: TextLabel
local armButton: TextButton

local function getAltarPart(altar: Instance): BasePart?
	return if altar:IsA("BasePart") then altar elseif altar:IsA("Model") then altar.PrimaryPart else nil
end

local function findNearestAltar(position: Vector3): (Instance?, BasePart?)
	local bestAltar, bestPart, bestDistance = nil, nil, SHOW_DISTANCE
	for _, altar in CollectionService:GetTagged(ALTAR_TAG) do
		local part = getAltarPart(altar)
		if part then
			local distance = (part.Position - position).Magnitude
			if distance <= bestDistance then
				bestAltar, bestPart, bestDistance = altar, part, distance
			end
		end
	end
	return bestAltar, bestPart
end

-- Owned luck charges in Config/Boosts order.
local function ownedCharges(data: any): { Boosts.Potion }
	local owned = {}
	for _, potion in Boosts.Potions do
		if potion.Kind == "LuckCharge" and (data.Potions[potion.Id] or 0) > 0 then
			table.insert(owned, potion)
		end
	end
	return owned
end

-- Arms the next owned charge after the armed one; after the last one, disarms.
local function cycleCharge()
	local data = DataController:Get()
	if data == nil then
		return
	end
	local owned = ownedCharges(data)
	local armedIndex = 0
	for index, potion in owned do
		if potion.Id == data.ArmedLuckPotion then
			armedIndex = index
		end
	end
	local nextPotion = owned[armedIndex + 1]
	if nextPotion then
		useBoost:FireServer(nextPotion.Id) -- arms it (replaces the armed one)
	elseif data.ArmedLuckPotion ~= "" then
		useBoost:FireServer(data.ArmedLuckPotion) -- same Id again disarms
	end
end

local function update()
	local data = DataController:Get()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local state = Cycle.GetState()
	if data == nil or root == nil or not root:IsA("BasePart") or not state.IsNight then
		panel.Visible = false
		return
	end

	local altar, part = findNearestAltar(root.Position)
	if altar == nil or part == nil then
		panel.Visible = false
		return
	end

	local boundTonight = data.LastBindNight == state.NightIndex
	local offeringCount = Luck.GetOfferingCount(data, state.NightIndex)
	local nextOffering = Luck.GetNextOffering(offeringCount)

	-- Local-only prompt tweaks (the server still validates everything).
	local bindPrompt = part:FindFirstChild("BindPrompt")
	local offerPrompt = part:FindFirstChild("OfferPrompt")
	if bindPrompt and bindPrompt:IsA("ProximityPrompt") then
		bindPrompt.Enabled = not boundTonight
	end
	if offerPrompt and offerPrompt:IsA("ProximityPrompt") then
		offerPrompt.Enabled = not boundTonight and nextOffering ~= nil
		if nextOffering then
			offerPrompt.ActionText = `Offer {nextOffering.Cost} Stardust`
		end
	end

	armButton.Visible = not boundTonight
	if boundTonight then
		title.Text = "Bound tonight"
		details.Text = "Come back next night to bind again."
		panel.Visible = true
		return
	end

	local areaId = altar:GetAttribute("AreaId")
	local luck = Luck.Compute(
		if type(areaId) == "string" then areaId else "StarterMeadow",
		state.NightIndex,
		offeringCount,
		Luck.CountPlayersNear(part.Position, LuckConfig.GroupRadius),
		Luck.GetArmedPotionLuck(data)
	)

	local atMax = luck.Total >= (if luck.Potion > 1 then LuckConfig.PotionCap else LuckConfig.Cap)
	title.Text = `Bind luck {Format.Multiplier(luck.Total)}` .. (if atMax then " (max)" else "")
	local lines = {
		`Area  {Format.Multiplier(luck.Area)}`,
		`{luck.MoonName}  {Format.Multiplier(luck.Moon)}`,
		`{state.Constellation.Name}  {Format.Multiplier(luck.Constellation)}`,
		`Stardust ({offeringCount}/{#LuckConfig.Offerings})  {Format.Multiplier(luck.Stardust)}`,
		`Group ({luck.GroupSize} here)  {Format.Multiplier(luck.Group)}`,
	}
	local armed = Boosts.ById[data.ArmedLuckPotion]
	if luck.Potion > 1 and armed then
		table.insert(lines, `{armed.Name}  {Format.Multiplier(luck.Potion)} (max {Format.Multiplier(LuckConfig.PotionCap)})`)
	end
	local owned = ownedCharges(data)
	if #owned == 0 then
		armButton.Text = "No luck potions"
		armButton.AutoButtonColor = false
	else
		armButton.AutoButtonColor = true
		armButton.Text = if luck.Potion > 1 and armed
			then `Armed: {armed.Name} ({data.Potions[armed.Id]}) · tap to change`
			else `Arm a luck potion ({#owned} kind{if #owned > 1 then "s" else ""})`
	end
	details.Text = table.concat(lines, "\n")
	panel.Visible = true
end

function LuckController:Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Luck"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -16, 0.5, 0)
	panel.Size = UDim2.new(0, 250, 0, 220)
	panel.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
	panel.BackgroundTransparency = 0.25
	panel.Visible = false
	panel.Parent = gui
	Instance.new("UICorner").Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 28)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(170, 220, 255)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	details = Instance.new("TextLabel")
	details.Position = UDim2.new(0, 0, 0, 34)
	details.Size = UDim2.new(1, 0, 1, -72)
	details.BackgroundTransparency = 1
	details.TextColor3 = Color3.new(1, 1, 1)
	details.Font = Enum.Font.Gotham
	details.TextSize = 16
	details.TextXAlignment = Enum.TextXAlignment.Left
	details.TextYAlignment = Enum.TextYAlignment.Top
	details.Parent = panel

	armButton = Instance.new("TextButton")
	armButton.AnchorPoint = Vector2.new(0, 1)
	armButton.Position = UDim2.new(0, 0, 1, 0)
	armButton.Size = UDim2.new(1, 0, 0, 32)
	armButton.BackgroundColor3 = Color3.fromRGB(200, 150, 255)
	armButton.TextColor3 = Color3.fromRGB(15, 15, 30)
	armButton.Font = Enum.Font.GothamBold
	armButton.TextScaled = true
	armButton.Parent = panel
	Instance.new("UICorner").Parent = armButton
	local armPad = Instance.new("UIPadding")
	armPad.PaddingTop = UDim.new(0, 6)
	armPad.PaddingBottom = UDim.new(0, 6)
	armPad.PaddingLeft = UDim.new(0, 6)
	armPad.PaddingRight = UDim.new(0, 6)
	armPad.Parent = armButton
	armButton.Activated:Connect(cycleCharge)
end

function LuckController:Start()
	while true do
		update()
		task.wait(UPDATE_INTERVAL)
	end
end

return LuckController
