--!strict
-- Boosts: a "Boosts" button opens a panel with every potion (count owned, effect, time left) and a Use / Arm button
-- per potion, and a small HUD column (top right) shows active timers and the armed luck charge.
-- The Boosts button shows a count and pulses while there are unused potions.
-- The server checks everything (BoostService). Timers pause while offline. Placeholder UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataController = require(script.Parent.DataController)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)

local useBoost = ReplicatedStorage.Remotes.UseBoost :: RemoteEvent

local DARK = Color3.fromRGB(15, 15, 30)
local CARD = Color3.fromRGB(32, 32, 55)
local GREY = Color3.fromRGB(120, 120, 130)
local GOLD = Color3.fromRGB(255, 210, 70)

local BoostController = {}

type Row = { Count: TextLabel, Timer: TextLabel, Button: TextButton }

local panel: Frame
local hud: Frame
local rows: { [string]: Row } = {}
local hudLabels: { [string]: TextLabel } = {}

local function formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function round(instance: GuiObject)
	Instance.new("UICorner").Parent = instance
end

local function pad(instance: GuiObject, amount: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, amount)
	p.PaddingBottom = UDim.new(0, amount)
	p.PaddingLeft = UDim.new(0, amount)
	p.PaddingRight = UDim.new(0, amount)
	p.Parent = instance
end

local function text(parent: Instance, value: string, color: Color3, bold: boolean, position: UDim2, size: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = position
	l.Size = size
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = color
	l.Text = value
	l.Parent = parent
	return l
end

local openButton: TextButton
local badge: TextLabel

-- Boosts button: a count badge and a pulsing outline while the player owns potions they haven't used.
local function updateBadge(data: any)
	local unused = 0
	for potionId, count in data.Potions do
		local potion = Boosts.ById[potionId]
		if potion and not (potion.Kind == "LuckCharge" and data.ArmedLuckPotion == potionId) then
			unused += count
		end
	end
	badge.Text = tostring(unused)
	badge.Visible = unused > 0
	openButton:SetAttribute("Pulse", unused > 0)
end

local function refresh()
	local data = DataController:Get()
	if data == nil then
		return
	end
	updateBadge(data)
	for _, potion in Boosts.Potions do
		local count = data.Potions[potion.Id] or 0
		local left = data.ActiveBoosts[potion.Id] or 0
		local armed = data.ArmedLuckPotion == potion.Id

		local row = rows[potion.Id]
		row.Count.Text = `x{count}`
		if potion.Kind == "LuckCharge" then
			row.Timer.Text = if armed then "Armed for your next bind" else "Arm it, then bind at night"
			row.Button.Text = if armed then "Disarm" else "Arm"
			row.Button.BackgroundColor3 = if armed or count > 0 then potion.Color else GREY
		else
			row.Timer.Text = if left > 0 then `Active: {formatTime(left)} left` else `{potion.Minutes} min per potion`
			row.Button.Text = "Use"
			row.Button.BackgroundColor3 = if count > 0 then potion.Color else GREY
		end

		-- HUD: active timers and the armed charge.
		local hudLabel = hudLabels[potion.Id]
		if left > 0 then
			hudLabel.Text = `{potion.Name}  {formatTime(left)}`
			hudLabel.Visible = true
		elseif armed then
			hudLabel.Text = `{potion.Name}  armed`
			hudLabel.Visible = true
		else
			hudLabel.Visible = false
		end
	end
end

local function makeRow(list: Instance, potion: Boosts.Potion, order: number)
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	card.Size = UDim2.new(1, -8, 0, 58)
	card.BackgroundColor3 = CARD
	round(card)
	card.Parent = list

	text(card, potion.Name, potion.Color, true, UDim2.new(0, 10, 0, 6), UDim2.new(0.5, -10, 0, 20))
	local count = text(card, "x0", Color3.new(1, 1, 1), true, UDim2.new(0.5, 0, 0, 6), UDim2.new(0.2, 0, 0, 20))
	text(card, potion.Description, Color3.fromRGB(200, 200, 215), false, UDim2.new(0, 10, 0, 28), UDim2.new(0.7, -10, 0, 12))
	local timer = text(card, "", Color3.fromRGB(170, 220, 255), false, UDim2.new(0, 10, 0, 42), UDim2.new(0.7, -10, 0, 12))

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.new(0.25, 0, 0, 36)
	button.TextColor3 = DARK
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.BackgroundColor3 = GREY
	round(button)
	pad(button, 6)
	button.Parent = card
	button.Activated:Connect(function()
		useBoost:FireServer(potion.Id) -- the server checks the count and the 60-minute limit
	end)

	rows[potion.Id] = { Count = count, Timer = timer, Button = button }
end

function BoostController:Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Boosts"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local open = Instance.new("TextButton")
	openButton = open
	open.AnchorPoint = Vector2.new(0, 1)
	open.Position = UDim2.new(0, 16, 1, -208) -- above the Dragons button
	open.Size = UDim2.new(0, 160, 0, 40)
	open.BackgroundColor3 = Color3.fromRGB(200, 150, 255)
	open.TextColor3 = DARK
	open.Font = Enum.Font.GothamBold
	open.TextScaled = true
	open.Text = "Boosts"
	round(open)
	pad(open, 6)
	open.Parent = gui

	badge = Instance.new("TextLabel")
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -4, 0, 4)
	badge.Size = UDim2.new(0, 24, 0, 24)
	badge.BackgroundColor3 = Color3.fromRGB(230, 70, 70)
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Font = Enum.Font.GothamBold
	badge.TextScaled = true
	badge.Visible = false
	badge.ZIndex = 2
	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(1, 0)
	badgeCorner.Parent = badge
	pad(badge, 3)
	badge.Parent = open
	local pulse = Instance.new("UIStroke")
	pulse.Color = Color3.new(1, 1, 1)
	pulse.Thickness = 0
	pulse.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	pulse.Parent = open

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.92, 0, 0.75, 0)
	panel.BackgroundColor3 = DARK
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	round(panel)
	panel.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, 520)
	limit.Parent = panel

	text(panel, "Boosts", Color3.new(1, 1, 1), true, UDim2.new(0, 14, 0, 10), UDim2.new(1, -70, 0, 26))
	text(
		panel,
		`Timers pause while you're offline. Up to {Boosts.MaxStoredMinutes} min per potion. Premium: +{math.floor(Boosts.PremiumDurationBonus * 100)}% time.`,
		Color3.fromRGB(190, 190, 205),
		false,
		UDim2.new(0, 14, 0, 38),
		UDim2.new(1, -28, 0, 14)
	)

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 8)
	close.Size = UDim2.new(0, 36, 0, 30)
	close.BackgroundColor3 = GOLD
	close.TextColor3 = DARK
	close.Font = Enum.Font.GothamBold
	close.TextScaled = true
	close.Text = "X"
	round(close)
	pad(close, 4)
	close.Parent = panel
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.new(0, 10, 0, 60)
	list.Size = UDim2.new(1, -20, 1, -70)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- HUD column, top right, below the sky bar.
	hud = Instance.new("Frame")
	hud.AnchorPoint = Vector2.new(1, 0)
	hud.Position = UDim2.new(1, -16, 0, 70)
	hud.Size = UDim2.new(0, 200, 0, 0)
	hud.AutomaticSize = Enum.AutomaticSize.Y
	hud.BackgroundTransparency = 1
	hud.Parent = gui
	local hudLayout = Instance.new("UIListLayout")
	hudLayout.Padding = UDim.new(0, 4)
	hudLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hudLayout.Parent = hud

	for index, potion in Boosts.Potions do
		makeRow(list, potion, index)

		local hudLabel = Instance.new("TextLabel")
		hudLabel.LayoutOrder = index
		hudLabel.Size = UDim2.new(1, 0, 0, 24)
		hudLabel.BackgroundColor3 = DARK
		hudLabel.BackgroundTransparency = 0.3
		hudLabel.TextColor3 = potion.Color
		hudLabel.Font = Enum.Font.GothamBold
		hudLabel.TextScaled = true
		hudLabel.Visible = false
		round(hudLabel)
		pad(hudLabel, 4)
		hudLabel.Parent = hud
		hudLabels[potion.Id] = hudLabel
	end

	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
		refresh()
	end)
	for _, key in { "Potions", "ActiveBoosts", "ArmedLuckPotion" } do
		DataController:OnChanged(key, refresh)
	end
end

function BoostController:Start()
	-- Pulse the Boosts button's outline while there are unused potions.
	local pulse = openButton:FindFirstChildOfClass("UIStroke") :: UIStroke
	RunService.RenderStepped:Connect(function()
		if openButton:GetAttribute("Pulse") == true then
			pulse.Thickness = 1.5 + 1.5 * math.sin(os.clock() * 5)
		else
			pulse.Thickness = 0
		end
	end)
end

return BoostController
