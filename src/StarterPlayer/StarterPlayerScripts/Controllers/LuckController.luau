--!strict
-- At night, near a Star Altar: shows the player's current bind luck with a breakdown of every source, and keeps
-- the altar prompts up to date for this player (offer cost, hidden once they've bound). Placeholder UI.
-- Uses Shared/Luck, the same math the server rolls with.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local Format = require(ReplicatedStorage.Shared.Format)
local Luck = require(ReplicatedStorage.Shared.Luck)
local LuckConfig = require(ReplicatedStorage.Shared.Config.Luck)

local ALTAR_TAG = "StarAltar"
local SHOW_DISTANCE = LuckConfig.GroupRadius -- show the panel within this many studs of an altar
local UPDATE_INTERVAL = 0.25

local LuckController = {}

local panel: Frame
local title: TextLabel
local details: TextLabel

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
		Luck.CountPlayersNear(part.Position, LuckConfig.GroupRadius)
	)

	title.Text = `Bind luck {Format.Multiplier(luck.Total)}` .. (if luck.Capped then " (max)" else "")
	local lines = {
		`Area  {Format.Multiplier(luck.Area)}`,
		`{luck.MoonName}  {Format.Multiplier(luck.Moon)}`,
		`{state.Constellation.Name}  {Format.Multiplier(luck.Constellation)}`,
		`Stardust ({offeringCount}/{#LuckConfig.Offerings})  {Format.Multiplier(luck.Stardust)}`,
		`Group ({luck.GroupSize} here)  {Format.Multiplier(luck.Group)}`,
	}
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
	panel.Size = UDim2.new(0, 250, 0, 170)
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
	details.Size = UDim2.new(1, 0, 1, -34)
	details.BackgroundTransparency = 1
	details.TextColor3 = Color3.new(1, 1, 1)
	details.Font = Enum.Font.Gotham
	details.TextSize = 16
	details.TextXAlignment = Enum.TextXAlignment.Left
	details.TextYAlignment = Enum.TextYAlignment.Top
	details.Parent = panel
end

function LuckController:Start()
	while true do
		update()
		task.wait(UPDATE_INTERVAL)
	end
end

return LuckController
