--!strict
-- Dragon Spire display: a panel (bottom center) that follows the server's climb (SpireUpdate): the current floor,
-- your dragon vs the enemy with a fight timer, rewards per floor, and the result. Buttons: Stop, Climb again,
-- Elevator (Tower Elevator pass or an Elevator Skip: starts above the record).
-- The server decides every result; this only shows it. Styled with the UI kit; the fight itself is a timer bar
-- until the Spire battle visuals exist.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Button = require(script.Parent.UI.Button)
local Format = require(ReplicatedStorage.Shared.Format)
local SpireConfig = require(ReplicatedStorage.Shared.Config.Spire)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local Theme = require(ReplicatedStorage.Shared.Config.UITheme)

local spireAction = ReplicatedStorage.Remotes.SpireAction :: RemoteEvent
local spireUpdate = ReplicatedStorage.Remotes.SpireUpdate :: RemoteEvent

local LOG_LINES = 4

local SpireController = {}

local panel: Frame
local title: TextLabel
local matchup: TextLabel
local barFill: Frame
local logLabel: TextLabel
local stopButton: TextButton
local againButton: TextButton
local elevatorButton: TextButton
local closeButton: TextButton
local logLines = LOG_LINES -- 1 on phones
local record = 0

local timerStart = 0
local timerSeconds = 0
local log: { string } = {}

local buttons: { [TextButton]: Button.Button } = {}

local function label(parent: Instance, kind: Style.TextKind, color: Color3, y: number, height: number): TextLabel
	local l = Style.Label(parent, "", kind, 16, color)
	l.Position = UDim2.new(0, 14, 0, y)
	l.Size = UDim2.new(1, -28, 0, height)
	l.TextScaled = true
	l.ZIndex = 2
	return l
end

local function button(parent: Instance, text: string, kind: Button.Kind, onClick: () -> ()): TextButton
	local b = Button.new(parent, { Text = text, Kind = kind, TextSize = 15, OnClick = onClick })
	b.Instance.ZIndex = 2
	buttons[b.Instance] = b
	return b.Instance
end

local function setText(b: TextButton, text: string)
	buttons[b]:SetText(text)
end

local function addLog(line: string)
	table.insert(log, 1, line)
	while #log > logLines do
		table.remove(log)
	end
	logLabel.Text = table.concat(log, "\n")
end

local function startTimer(seconds: number)
	timerStart = os.clock()
	timerSeconds = seconds
end

-- Elevator: shown between climbs when the player has the pass or an Elevator Skip.
local function updateElevator()
	local data = DataController:Get()
	local hasPass = Players.LocalPlayer:GetAttribute("Pass_ElevatorPass") == true
	local skips = if data then data.ElevatorSkips else 0
	elevatorButton.Visible = againButton.Visible
		and (hasPass or skips > 0)
		and record > 0
		and record < SpireConfig.MaxFloors
	setText(elevatorButton, if hasPass then `Elevator to {record + 1}` else `Elevator to {record + 1} ({skips} left)`)
end

local climbing = false
local hiddenHere = false -- the player pressed Hide at the Spire; stay hidden until they walk away

-- Between climbs, near the Spire: a ready panel with Climb / Elevator.
local function showReady()
	local data = DataController:Get()
	record = if data then data.SpireRecord else record
	title.Text = `Dragon Spire  ·  record {record}/{SpireConfig.MaxFloors}`
	matchup.Text = "Your strongest dragon fights one enemy per floor."
	matchup.TextColor3 = Color3.fromRGB(190, 190, 205)
	logLabel.Text = ""
	log = {}
	timerSeconds = 0
	barFill.Size = UDim2.fromScale(0, 1)
	stopButton.Visible, againButton.Visible = false, true
	setText(againButton, "Climb")
	panel.Visible = true
	updateElevator()
end

local function isNearSpire(): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	for _, spire in CollectionService:GetTagged("DragonSpire") do
		local position = if spire:IsA("Model") then spire:GetPivot().Position elseif spire:IsA("BasePart") then spire.Position else nil
		if position and (root.Position - position).Magnitude <= SpireConfig.EntranceRange then
			return true
		end
	end
	return false
end

local function onUpdate(update: { [string]: any })
	-- Stay hidden if the player hid the card or opened another window; the result shows again when the climb ends
	-- (unless a window is still open).
	if update.Phase == "Ended" and not HudLayout.HasFocus() then
		hiddenHere = false
	end
	if not hiddenHere then
		panel.Visible = true
	end
	climbing = update.Phase ~= "Ended"
	setText(againButton, "Climb again")
	record = update.Record or record
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
		title.Text = `Floor {update.Floor}{if update.Boss then "  ·  BOSS" else ""}{if update.Fast then "  ·  fast" else ""}  ·  record {update.Record}/{SpireConfig.MaxFloors}`
		matchup.Text = `{update.Dragon} ({Format.Number(update.Power)})  vs  {update.Enemy} ({Format.Number(update.EnemyPower)})`
		matchup.TextColor3 = if update.Power >= update.EnemyPower then Theme.Colors.Positive else Theme.Colors.Negative
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
		matchup.Text = Text.SpireStuckTip
		matchup.TextColor3 = Color3.fromRGB(190, 190, 205)
		timerSeconds = 0
		stopButton.Visible, againButton.Visible = false, true
	end
	updateElevator()
end

function SpireController:Init()
	local gui = HudLayout.MakeScreenGui("Spire", "Cards")

	panel = Instance.new("Frame")
	panel.Name = "SpireCard"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -16)
	panel.Size = UDim2.new(0.6, 0, 0, 200)
	panel.Visible = false
	Style.PanelLook(panel, 6)
	panel.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 200)
	limit.Parent = panel

	title = label(panel, "Title", Theme.Colors.Title, 8, 24)
	title.TextStrokeTransparency = 0
	matchup = label(panel, "Heavy", Theme.Colors.Text, 36, 20)

	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0, 14, 0, 62)
	bar.Size = UDim2.new(1, -28, 0, 10)
	bar.BackgroundColor3 = Theme.Colors.PanelInnerLine
	bar.ZIndex = 2
	Style.Round(bar)
	bar.Parent = panel
	barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = Color3.new(1, 1, 1)
	barFill.ZIndex = 2
	Style.Gradient(barFill, Theme.Colors.Trim, Theme.Colors.TrimDark)
	Style.Round(barFill)
	barFill.Parent = bar

	logLabel = label(panel, "Bold", Theme.Colors.Gold, 78, 76)
	logLabel.TextScaled = false
	logLabel.TextSize = 14
	logLabel.TextWrapped = true
	logLabel.TextXAlignment = Enum.TextXAlignment.Left
	logLabel.TextYAlignment = Enum.TextYAlignment.Top

	stopButton = button(panel, "Stop climbing", "Cancel", function()
		spireAction:FireServer("Stop")
	end)
	againButton = button(panel, "Climb again", "Confirm", function()
		spireAction:FireServer("Start")
	end)
	elevatorButton = button(panel, "Elevator", "Neutral", function()
		spireAction:FireServer("Start", true)
	end)
	elevatorButton.AnchorPoint = Vector2.new(0, 1)
	elevatorButton.Size = UDim2.new(0.35, -8, 0, 32)
	elevatorButton.Position = UDim2.new(0.37, 0, 1, -8)
	elevatorButton.Visible = false
	closeButton = button(panel, "Hide", "Neutral", function()
		panel.Visible = false
		hiddenHere = true
	end)
	-- The Spire card is a station panel: showing it closes other windows, and opening a window hides it.
	HudLayout.TrackPanel(panel, function()
		panel.Visible = false
		hiddenHere = true
	end)

	-- Stop and Climb again share the left spot (only one shows at a time); Hide sits on the right.
	for _, b in { stopButton, againButton, closeButton } do
		b.AnchorPoint = Vector2.new(0, 1)
		b.Size = UDim2.new(if b == closeButton then 0.25 else 0.35, -8, 0, 32)
		b.Position = if b == closeButton then UDim2.new(0.75, 0, 1, -8) else UDim2.new(0, 12, 1, -8)
	end
	againButton.Visible = false

	-- PC: a panel bottom-center. Phone: a compact card top-center under the sky HUD (the thumbstick and jump button
	-- own the bottom corners), showing only the latest log line.
	local bar = barFill.Parent :: Frame
	HudLayout.OnLayoutChanged(function(isPhone)
		local sizes = Theme.Sizes
		logLines = if isPhone then 1 else LOG_LINES
		if isPhone then
			panel.AnchorPoint = Vector2.new(0.5, 0)
			panel.Position = UDim2.new(0.5, 0, 0, sizes.PhoneCardTop)
			panel.Size = UDim2.fromOffset(380, 112)
			title.Position, title.Size = UDim2.fromOffset(10, 6), UDim2.new(1, -20, 0, 18)
			matchup.Position, matchup.Size = UDim2.fromOffset(10, 26), UDim2.new(1, -20, 0, 15)
			bar.Position, bar.Size = UDim2.fromOffset(10, 45), UDim2.new(1, -20, 0, 6)
			logLabel.Position, logLabel.Size = UDim2.fromOffset(10, 55), UDim2.new(1, -20, 0, 18)
			logLabel.TextSize = 12
			for _, b in { stopButton, againButton, elevatorButton, closeButton } do
				b.Size = UDim2.new(b.Size.X.Scale, b.Size.X.Offset, 0, 26)
				b.Position = UDim2.new(b.Position.X.Scale, b.Position.X.Offset, 1, -6)
			end
		else
			panel.AnchorPoint = Vector2.new(0.5, 1)
			panel.Position = UDim2.new(0.5, 0, 1, -16)
			panel.Size = UDim2.new(0.6, 0, 0, 200)
			title.Position, title.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 24)
			matchup.Position, matchup.Size = UDim2.fromOffset(12, 36), UDim2.new(1, -24, 0, 20)
			bar.Position, bar.Size = UDim2.fromOffset(12, 62), UDim2.new(1, -24, 0, 10)
			logLabel.Position, logLabel.Size = UDim2.fromOffset(12, 78), UDim2.new(1, -24, 0, 76)
			logLabel.TextSize = 14
			for _, b in { stopButton, againButton, elevatorButton, closeButton } do
				b.Size = UDim2.new(b.Size.X.Scale, b.Size.X.Offset, 0, 32)
				b.Position = UDim2.new(b.Position.X.Scale, b.Position.X.Offset, 1, -8)
			end
		end
		while #log > logLines do
			table.remove(log)
		end
		logLabel.Text = table.concat(log, "\n")
	end)

	spireUpdate.OnClientEvent:Connect(onUpdate)
	DataController:OnChanged("ElevatorSkips", updateElevator)
	Players.LocalPlayer:GetAttributeChangedSignal("Pass_ElevatorPass"):Connect(updateElevator)
end

function SpireController:Start()
	RunService.RenderStepped:Connect(function()
		if timerSeconds > 0 and panel.Visible then
			barFill.Size = UDim2.fromScale(math.clamp((os.clock() - timerStart) / timerSeconds, 0, 1), 1)
		end
	end)
	-- Show the ready panel on arrival at the Spire; hide it on leaving (unless a climb result is showing).
	local wasNear = false
	while true do
		local near = isNearSpire()
		if near and not wasNear and not climbing and not hiddenHere then
			showReady()
		elseif not near and wasNear then
			hiddenHere = false
			if not climbing then
				panel.Visible = false
			end
		end
		wasNear = near
		task.wait(0.5)
	end
end

return SpireController
