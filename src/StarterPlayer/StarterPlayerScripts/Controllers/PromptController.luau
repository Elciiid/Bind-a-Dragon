--!strict
-- Themed ProximityPrompts (client only). Every prompt in the world switches to Style = Custom here and is drawn with
-- the UI kit: a night-sky pill with gold trim, a key badge (keyboard key, gamepad button or "Tap"), an optional icon,
-- the object name and the action, and a gold ring that fills while a hold prompt is held. Tapping/clicking the pill
-- triggers the prompt (phones). Icons per prompt: Config/WorldUI Prompts.Icons.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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

	local button = Instance.new("TextButton")
	button.Text = ""
	button.AutoButtonColor = false
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Gradient(button, theme.Colors.PanelTop, theme.Colors.PanelBottom)
	Style.Corner(button, theme.Corner)
	Style.Stroke(button, theme.Colors.Trim, 2)
	button.Parent = gui

	-- Key badge with a hold ring
	local badgeSize = height - 14
	local badge = Instance.new("Frame")
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, 7, 0.5, 0)
	badge.Size = UDim2.fromOffset(badgeSize, badgeSize)
	badge.BackgroundColor3 = theme.Colors.TitleBar
	Style.Round(badge)
	badge.Parent = button
	local ring = Style.Stroke(badge, theme.Colors.TrimDark, 3)
	local keyLabel = Style.Label(badge, keyText(prompt, inputType), "Heavy", 16, theme.Colors.Gold)
	keyLabel.Size = UDim2.fromScale(1, 1)
	keyLabel.TextScaled = true
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.18, 0), UDim.new(0.18, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.22, 0), UDim.new(0.22, 0)
	pad.Parent = keyLabel
	local fill = Instance.new("Frame")
	fill.AnchorPoint = Vector2.new(0.5, 0.5)
	fill.Position = UDim2.fromScale(0.5, 0.5)
	fill.Size = UDim2.fromScale(0, 0)
	fill.BackgroundColor3 = theme.Colors.Gold
	fill.BackgroundTransparency = 0.55
	fill.ZIndex = 0
	Style.Round(fill)
	fill.Parent = badge

	local left = badgeSize + 14
	local iconId = iconFor(prompt)
	if iconId then
		local icon = Icon.new(button, iconId)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, left, 0.5, 0)
		icon.Size = UDim2.fromOffset(height - 22, height - 22)
		left += height - 16
	end
	local object = Style.Label(button, prompt.ObjectText, "Bold", 13, theme.Colors.TextMuted)
	object.Position = UDim2.fromOffset(left, 5)
	object.Size = UDim2.new(1, -(left + 8), 0.38, 0)
	object.TextXAlignment = Enum.TextXAlignment.Left
	object.TextScaled = true
	local action = Style.Label(button, prompt.ActionText, "Heavy", 18, theme.Colors.Text)
	action.Position = UDim2.new(0, left, 0.38, 3)
	action.Size = UDim2.new(1, -(left + 8), 0.55, -6)
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.TextScaled = true

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
		ring.Color = theme.Colors.Gold
	end))
	table.insert(connections, prompt.PromptButtonHoldEnded:Connect(function()
		holdStart = nil
		ring.Color = theme.Colors.TrimDark
		fill.Size = UDim2.fromScale(0, 0)
	end))
	table.insert(connections, prompt.Triggered:Connect(function()
		Style.Play("Click")
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

	-- pop in
	local scaleObject = Instance.new("UIScale")
	scaleObject.Scale = 0.8
	scaleObject.Parent = button
	local popStart = os.clock()
	local pop: RBXScriptConnection
	pop = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - popStart) / 0.12, 0, 1)
		scaleObject.Scale = 0.8 + 0.2 * t
		if t >= 1 then
			pop:Disconnect()
		end
	end)
	table.insert(connections, pop)

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
