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
local PromptPill = require(script.Parent.UI.PromptPill)
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
	local pill = PromptPill.new(gui, {
		Key = keyText(prompt, inputType),
		Object = prompt.ObjectText,
		Action = prompt.ActionText,
		Icon = iconFor(prompt),
		Height = height,
	})
	local button, object, action = pill.Button, pill.Object, pill.Action

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
		pill:SetHold(0.01)
	end))
	table.insert(connections, prompt.PromptButtonHoldEnded:Connect(function()
		holdStart = nil
		pill:SetHold(0)
	end))
	table.insert(connections, prompt.Triggered:Connect(function()
		Style.Play("Click")
		pill:Burst()
	end))
	table.insert(connections, RunService.RenderStepped:Connect(function()
		local start = holdStart
		if start and prompt.HoldDuration > 0 then
			pill:SetHold(math.clamp((os.clock() - start) / prompt.HoldDuration, 0, 1))
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
	TweenService:Create(scaleObject, TweenInfo.new(UITheme.WorldPanel.PopTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

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
