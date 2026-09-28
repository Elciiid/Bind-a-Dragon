--!strict
-- Themed ProximityPrompts (client only). Every prompt in the world switches to Style = Custom here and is drawn in the
-- window style made small (Style.WorldPanel: navy glass, gold border, gold end diamonds): a round amethyst key badge
-- with a gold ring (keyboard key, gamepad button or "Tap") that fills with gold while a hold prompt is held, an
-- optional icon popping out, the object name and the action in the title font. It pops in with a bounce and sparkles
-- when used. Tapping/clicking the pill triggers the prompt (phones). Icons per prompt: Config/WorldUI Prompts.Icons;
-- look in UITheme.WorldPanel.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local WorldUI = require(ReplicatedStorage.Shared.Config.WorldUI)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local PromptConfig = WorldUI.Prompts

local PromptController = {}

local shown: { [ProximityPrompt]: BillboardGui } = {}
local playerGui: PlayerGui

local function useCustom(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		instance.Style = Enum.ProximityPromptStyle.Custom
	end
end

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return PromptConfig.TouchLabel
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		local name = prompt.GamepadKeyCode.Name
		return (name:gsub("^Button", ""))
	end
	local mapped = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	return if mapped ~= "" then mapped else prompt.KeyboardKeyCode.Name
end

local function iconFor(prompt: ProximityPrompt): string?
	if prompt.Name == "RollPrompt" then
		return if prompt.ObjectText:find("Forge") then "Dragonstone" else "WyrmRune"
	end
	return PromptConfig.Icons[prompt.Name]
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	if shown[prompt] then
		return
	end
	local theme = UITheme
	local scale = if HudLayout.IsPhone() then PromptConfig.PhoneScale else 1
	local width, height = PromptConfig.Size.X * scale, PromptConfig.Size.Y * scale

	local gui = Instance.new("BillboardGui")
	gui.Name = "Prompt_" .. prompt.Name
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(width, height)
	gui.StudsOffset = Vector3.new(0, 1.5, 0)
	gui.Active = true
	gui.ResetOnSpawn = false
	gui.Adornee = prompt.Parent
	gui.Parent = playerGui

	gui.ClipsDescendants = false
	local world = theme.WorldPanel

	local button = Instance.new("TextButton")
	button.Text = ""
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.5)
	button.Size = UDim2.new(1, -12, 1, -6)
	Style.WorldPanel(button)
	button.Parent = gui

	-- Key badge (a round jewel with a gold ring) with the hold fill
	local badgeSize = height - 8
	local badge = Instance.new("Frame")
	badge.Name = "Key"
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, -4, 0.5, 0)
	badge.Size = UDim2.fromOffset(badgeSize, badgeSize)
	badge.BackgroundColor3 = Color3.new(1, 1, 1)
	badge.ZIndex = 6
	Style.Gradient(badge, world.KeyBadgeTop, world.KeyBadgeBottom)
	Style.Round(badge)
	badge.Parent = button
	local ring = Style.GoldBorder(badge, 3)
	local fill = Instance.new("Frame")
	fill.AnchorPoint = Vector2.new(0.5, 0.5)
	fill.Position = UDim2.fromScale(0.5, 0.5)
	fill.Size = UDim2.fromScale(0, 0)
	fill.BackgroundColor3 = theme.Colors.Gold
	fill.BackgroundTransparency = 0.35
	fill.ZIndex = 7
	Style.Round(fill)
	fill.Parent = badge
	local keyLabel = Style.Label(badge, keyText(prompt, inputType), "Title", 20, theme.Colors.Text)
	keyLabel.Size = UDim2.fromScale(1, 1)
	keyLabel.TextScaled = true
	keyLabel.ZIndex = 8
	Style.Outline(keyLabel, 1.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.2, 0), UDim.new(0.2, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.24, 0), UDim.new(0.2, 0)
	pad.Parent = keyLabel

	local left = badgeSize + 2
	local iconId = iconFor(prompt)
	if iconId then
		local icon = Icon.new(button, iconId)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, left, 0.5, 0)
		icon.Size = UDim2.fromOffset(height - 12, height - 12)
		icon.ZIndex = 3
		left += height - 8
	end
	local object = Style.Label(button, prompt.ObjectText, "Bold", 13, theme.Colors.TextMuted)
	object.Position = UDim2.fromOffset(left, 5)
	object.Size = UDim2.new(1, -(left + 10), 0.34, 0)
	object.TextXAlignment = Enum.TextXAlignment.Left
	object.TextScaled = true
	object.ZIndex = 3
	local action = Style.Label(button, prompt.ActionText, "Title", 20, theme.Colors.Text)
	action.Position = UDim2.new(0, left, 0.34, 3)
	action.Size = UDim2.new(1, -(left + 10), 0.58, -6)
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.TextScaled = true
	action.ZIndex = 3
	Style.Outline(action, 1.5)

	local connections: { RBXScriptConnection } = {}
	table.insert(connections, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
		action.Text = prompt.ActionText
	end))
	table.insert(connections, prompt:GetPropertyChangedSignal("ObjectText"):Connect(function()
		object.Text = prompt.ObjectText
	end))

	-- Hold progress
	local holdStart: number? = nil
	table.insert(connections, prompt.PromptButtonHoldBegan:Connect(function()
		holdStart = os.clock()
		ring.Thickness = 4
	end))
	table.insert(connections, prompt.PromptButtonHoldEnded:Connect(function()
		holdStart = nil
		ring.Thickness = 3
		fill.Size = UDim2.fromScale(0, 0)
	end))
	table.insert(connections, prompt.Triggered:Connect(function()
		Style.Play("Click")
		Style.SparkleBurst(button, Vector2.new(badgeSize / 2 - 4, (height - 6) / 2), world.TriggerSparkles, 26)
	end))
	table.insert(connections, RunService.RenderStepped:Connect(function()
		local start = holdStart
		if start and prompt.HoldDuration > 0 then
			local t = math.clamp((os.clock() - start) / prompt.HoldDuration, 0, 1)
			fill.Size = UDim2.fromScale(t, t)
		end
	end))

	-- Tap / click the pill to use the prompt
	table.insert(connections, button.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldBegin()
		end
	end))
	table.insert(connections, button.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
		end
	end))

	-- pop in with a little bounce
	local scaleObject = Instance.new("UIScale")
	scaleObject.Scale = 0.6
	scaleObject.Parent = button
	TweenService:Create(scaleObject, TweenInfo.new(world.PopTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	gui.Destroying:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
	shown[prompt] = gui
end

local function hide(prompt: ProximityPrompt)
	local gui = shown[prompt]
	if gui then
		shown[prompt] = nil
		gui:Destroy()
	end
end

function PromptController:Start()
	playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	for _, instance in workspace:GetDescendants() do
		useCustom(instance)
	end
	workspace.DescendantAdded:Connect(useCustom)
	ProximityPromptService.PromptShown:Connect(show)
	ProximityPromptService.PromptHidden:Connect(hide)
end

return PromptController
