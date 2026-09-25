--!strict
-- Dragon Spire display: a panel (bottom center) that follows the server's climb (SpireUpdate): the current floor,
-- your dragon vs the enemy with a fight timer, rewards per floor, and the result. Buttons: Stop, Climb again,
-- Elevator (Tower Elevator pass or an Elevator Skip: starts above the record).
-- The server decides every result; this only shows it. Placeholder UI until the Spire interior exists.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataController = require(script.Parent.DataController)
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
local elevatorButton: TextButton
local record = 0

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

-- Elevator: shown between climbs when the player has the pass or an Elevator Skip.
local function updateElevator()
	local data = DataController:Get()
	local hasPass = Players.LocalPlayer:GetAttribute("Pass_ElevatorPass") == true
	local skips = if data then data.ElevatorSkips else 0
	elevatorButton.Visible = againButton.Visible
		and (hasPass or skips > 0)
		and record > 0
		and record < SpireConfig.MaxFloors
	elevatorButton.Text = if hasPass then `Elevator to {record + 1}` else `Elevator to {record + 1} ({skips} left)`
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
	againButton.Text = "Climb"
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
	panel.Visible = true
	climbing = update.Phase ~= "Ended"
	againButton.Text = "Climb again"
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
	updateElevator()
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
	elevatorButton = button(panel, "Elevator", Color3.fromRGB(200, 150, 255), function()
		spireAction:FireServer("Start", true)
	end)
	elevatorButton.AnchorPoint = Vector2.new(0, 1)
	elevatorButton.Size = UDim2.new(0.35, -8, 0, 32)
	elevatorButton.Position = UDim2.new(0.37, 0, 1, -8)
	elevatorButton.Visible = false
	local close = button(panel, "Hide", Color3.fromRGB(170, 170, 185), function()
		panel.Visible = false
		hiddenHere = true
	end)
	-- Stop and Climb again share the left spot (only one shows at a time); Hide sits on the right.
	for _, b in { stopButton, againButton, close } do
		b.AnchorPoint = Vector2.new(0, 1)
		b.Size = UDim2.new(if b == close then 0.25 else 0.35, -8, 0, 32)
		b.Position = if b == close then UDim2.new(0.75, 0, 1, -8) else UDim2.new(0, 12, 1, -8)
	end
	againButton.Visible = false

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
