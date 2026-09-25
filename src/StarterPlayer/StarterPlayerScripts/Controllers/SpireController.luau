--!strict
-- Dragon Spire display: a panel (bottom center) that follows the server's climb (SpireUpdate): the current floor,
-- your dragon vs the enemy with a fight timer, rewards per floor, and the result. Buttons: Stop, Climb again.
-- The server decides every result; this only shows it. Placeholder UI until the Spire interior exists.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local SpireConfig = require(ReplicatedStorage.Shared.Config.Spire)

local spireAction = ReplicatedStorage.Remotes.SpireAction :: RemoteEvent
local spireUpdate = ReplicatedStorage.Remotes.SpireUpdate :: RemoteEvent

local DARK = Color3.fromRGB(15, 15, 30)
local GOLD = Color3.fromRGB(255, 210, 70)
local RED = Color3.fromRGB(230, 80, 80)
local GREEN = Color3.fromRGB(130, 230, 140)
local SPIRE_COLOR = Color3.fromRGB(230, 120, 90)
local LOG_LINES = 4

local SpireController = {}

local panel: Frame
local title: TextLabel
local matchup: TextLabel
local barFill: Frame
local logLabel: TextLabel
local stopButton: TextButton
local againButton: TextButton

local timerStart = 0
local timerSeconds = 0
local log: { string } = {}

local function round(instance: GuiObject)
	Instance.new("UICorner").Parent = instance
end

local function label(parent: Instance, color: Color3, bold: boolean, y: number, height: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.new(0, 12, 0, y)
	l.Size = UDim2.new(1, -24, 0, height)
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = ""
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, color: Color3, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.TextColor3 = DARK
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.Text = text
	round(b)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 5)
	pad.PaddingBottom = UDim.new(0, 5)
	pad.Parent = b
	b.Parent = parent
	b.Activated:Connect(onClick)
	return b
end

local function addLog(line: string)
	table.insert(log, 1, line)
	while #log > LOG_LINES do
		table.remove(log)
	end
	logLabel.Text = table.concat(log, "\n")
end

local function startTimer(seconds: number)
	timerStart = os.clock()
	timerSeconds = seconds
end

local function onUpdate(update: { [string]: any })
	panel.Visible = true
	local phase = update.Phase
	if phase == "Fast" then
		log = {}
		title.Text = `Climbing floors {update.From}–{update.To}...`
		matchup.Text = `Far below your record ({update.Record}): no drops`
		matchup.TextColor3 = Color3.fromRGB(190, 190, 205)
		startTimer(update.Seconds)
		stopButton.Visible, againButton.Visible = true, false
		logLabel.Text = ""
	elseif phase == "Fight" then
		if update.Floor == 1 then
			log = {}
			logLabel.Text = ""
		end
		title.Text = `Floor {update.Floor}{if update.Boss then "  ·  BOSS" else ""}  ·  record {update.Record}/{SpireConfig.MaxFloors}`
		matchup.Text = `{update.Dragon} ({Format.Number(update.Power)})  vs  {update.Enemy} ({Format.Number(update.EnemyPower)})`
		matchup.TextColor3 = if update.Power >= update.EnemyPower then GREEN else RED
		startTimer(update.Seconds)
		stopButton.Visible, againButton.Visible = true, false
	elseif phase == "Won" then
		local rewards = if update.Rewards ~= "" then `: {update.Rewards}` else ""
		addLog(`Floor {update.Floor} {if update.FirstClear then "cleared (first time!)" else "cleared"}{rewards}`)
	elseif phase == "Ended" then
		local text = if update.Result == "Lost"
			then `Defeated on floor {update.Floor}.`
			elseif update.Result == "Top" then "You reached the top of the Spire!"
			else "Climb stopped."
		title.Text = `{text}  Record: {update.Record}/{SpireConfig.MaxFloors}`
		matchup.Text = "Level up, roll traits and grades, or use a Wyrmblood Tonic to go higher."
		matchup.TextColor3 = Color3.fromRGB(190, 190, 205)
		timerSeconds = 0
		stopButton.Visible, againButton.Visible = false, true
	end
end

function SpireController:Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Spire"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -16)
	panel.Size = UDim2.new(0.6, 0, 0, 200)
	panel.BackgroundColor3 = DARK
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	round(panel)
	panel.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 200)
	limit.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = SPIRE_COLOR
	stroke.Thickness = 1.5
	stroke.Parent = panel

	title = label(panel, SPIRE_COLOR, true, 8, 24)
	matchup = label(panel, Color3.new(1, 1, 1), true, 36, 20)

	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0, 12, 0, 62)
	bar.Size = UDim2.new(1, -24, 0, 10)
	bar.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	round(bar)
	bar.Parent = panel
	barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = SPIRE_COLOR
	round(barFill)
	barFill.Parent = bar

	logLabel = label(panel, GOLD, false, 78, 76)
	logLabel.TextScaled = false
	logLabel.TextSize = 14
	logLabel.TextWrapped = true
	logLabel.TextXAlignment = Enum.TextXAlignment.Left
	logLabel.TextYAlignment = Enum.TextYAlignment.Top

	stopButton = button(panel, "Stop climbing", RED, function()
		spireAction:FireServer("Stop")
	end)
	againButton = button(panel, "Climb again", GREEN, function()
		spireAction:FireServer("Start")
	end)
	local close = button(panel, "Hide", Color3.fromRGB(170, 170, 185), function()
		panel.Visible = false
	end)
	-- Stop and Climb again share the left spot (only one shows at a time); Hide sits on the right.
	for _, b in { stopButton, againButton, close } do
		b.AnchorPoint = Vector2.new(0, 1)
		b.Size = UDim2.new(if b == close then 0.25 else 0.35, -8, 0, 32)
		b.Position = if b == close then UDim2.new(0.75, 0, 1, -8) else UDim2.new(0, 12, 1, -8)
	end
	againButton.Visible = false

	spireUpdate.OnClientEvent:Connect(onUpdate)
end

function SpireController:Start()
	RunService.RenderStepped:Connect(function()
		if timerSeconds > 0 and panel.Visible then
			barFill.Size = UDim2.fromScale(math.clamp((os.clock() - timerStart) / timerSeconds, 0, 1), 1)
		end
	end)
end

return SpireController
