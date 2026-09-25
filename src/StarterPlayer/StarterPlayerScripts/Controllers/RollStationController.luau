--!strict
-- Rune Shrine (traits, costs Wyrm Runes) and Dragonstone Forge (grades, costs Dragonstones).
-- Stations are instances tagged "RuneShrine" / "DragonstoneForge" (BasePart, or Model with a PrimaryPart).
-- Walking up and pressing E opens a panel: pick one of your dragons, see its current trait/grade, roll,
-- and see the odds. The server checks the player is at the station and has the currency. Placeholder UI.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local TraitConfig = require(ReplicatedStorage.Shared.Config.Traits)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

type Kind = "Trait" | "Grade"

local STATIONS: { [string]: Kind } = { RuneShrine = "Trait", DragonstoneForge = "Grade" }
local CLOSE_DISTANCE = 25 -- the panel closes when you walk this far from the station
local DARK = Color3.fromRGB(15, 15, 30)
local ROW = Color3.fromRGB(32, 32, 55)
local SELECTED = Color3.fromRGB(70, 70, 120)
local GOLD = Color3.fromRGB(255, 210, 70)
local GREY = Color3.fromRGB(120, 120, 130)

local rollTrait = ReplicatedStorage.Remotes.RollTrait :: RemoteEvent
local rollGrade = ReplicatedStorage.Remotes.RollGrade :: RemoteEvent

local RollStationController = {}

local panel: Frame
local title: TextLabel
local owned: TextLabel
local list: ScrollingFrame
local detail: TextLabel
local rollButton: TextButton
local odds: TextLabel

local openKind: Kind? = nil
local openStation: BasePart? = nil
local selectedId: string? = nil

local function rarityColor(tierId: string): Color3
	local rarity = DragonStats.GetRarity(tierId)
	return if rarity then rarity.Color else Color3.new(1, 1, 1)
end

local function describe(dragon: PlayerDataTypes.Dragon, kind: Kind): (string, Color3)
	if kind == "Trait" then
		local trait = DragonStats.GetTrait(dragon)
		if trait == nil then
			return "No trait", GREY
		end
		local parts = {}
		if trait.Income > 1 then
			table.insert(parts, `x{trait.Income} gold`)
		end
		if trait.Power > 1 then
			table.insert(parts, `x{trait.Power} power`)
		end
		return `{trait.Name} ({table.concat(parts, ", ")})`, rarityColor(trait.Tier)
	end
	local grade = DragonStats.GetGrade(dragon)
	if grade == nil then
		return "No grade", GREY
	end
	return `Grade {grade.Id} (x{grade.Multiplier} gold and power)`, rarityColor(grade.Tier)
end

local function oddsText(kind: Kind): string
	local entries: { any } = if kind == "Trait" then TraitConfig.Traits else TraitConfig.Grades
	local total = 0
	for _, entry in entries do
		total += entry.Weight
	end
	local lines = { "Odds:" }
	for _, entry in entries do
		local chance = entry.Weight / total * 100
		local chanceText = if chance >= 1
			then string.format("%.0f%%", chance)
			elseif chance >= 0.1 then string.format("%.1f%%", chance)
			else string.format("%.2f%%", chance)
		table.insert(lines, `{entry.Name or ("Grade " .. entry.Id)}  {chanceText}`)
	end
	return table.concat(lines, "   ")
end

local function redraw()
	local data = DataController:Get()
	local kind = openKind
	if data == nil or kind == nil then
		return
	end
	local currency = if kind == "Trait" then data.WyrmRunes else data.Dragonstones
	local currencyName = if kind == "Trait" then "Wyrm Runes" else "Dragonstones"
	local cost = if kind == "Trait" then TraitConfig.TraitRollCost else TraitConfig.GradeRollCost
	title.Text = if kind == "Trait" then "Rune Shrine: roll a trait" else "Dragonstone Forge: roll a grade"
	owned.Text = `You have {currency} {currencyName}. Pick a dragon:`

	for _, child in list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local sorted = {}
	for _, dragon in data.Dragons do
		table.insert(sorted, dragon)
	end
	table.sort(sorted, function(a, b)
		return DragonStats.GetPower(a) > DragonStats.GetPower(b)
	end)
	if selectedId == nil or data.Dragons[selectedId] == nil then
		selectedId = if sorted[1] then sorted[1].Id else nil
	end

	for index, dragon in sorted do
		local species = Dragons[dragon.SpeciesId]
		local current, color = describe(dragon, kind)
		local row = Instance.new("TextButton")
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -8, 0, 34)
		row.BackgroundColor3 = if dragon.Id == selectedId then SELECTED else ROW
		row.TextColor3 = color
		row.Font = Enum.Font.Gotham
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = `  {if species then species.Name else "?"}  Lv {dragon.Level}  ·  {current}`
		Instance.new("UICorner").Parent = row
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.Parent = row
		row.Activated:Connect(function()
			selectedId = dragon.Id
			redraw()
		end)
		row.Parent = list
	end

	local selected = if selectedId then data.Dragons[selectedId] else nil
	if selected then
		local species = Dragons[selected.SpeciesId]
		local current, color = describe(selected, kind)
		detail.Text = `{if species then species.Name else "?"}: {current}`
		detail.TextColor3 = color
	else
		detail.Text = "You have no dragons yet."
		detail.TextColor3 = GREY
	end
	local canRoll = selected ~= nil and currency >= cost
	rollButton.Text = `Roll ({cost} {if kind == "Trait" then "Wyrm Rune" else "Dragonstone"})`
	rollButton.BackgroundColor3 = if canRoll then GOLD else GREY
	odds.Text = oddsText(kind)
end

local function close()
	panel.Visible = false
	openKind = nil
	openStation = nil
end

local function open(kind: Kind, station: BasePart)
	openKind = kind
	openStation = station
	panel.Visible = true
	redraw()
end

local function stationPart(instance: Instance): BasePart?
	return if instance:IsA("BasePart") then instance elseif instance:IsA("Model") then instance.PrimaryPart else nil
end

local function setupStation(instance: Instance, kind: Kind)
	local part = stationPart(instance)
	if part == nil or part:FindFirstChild("RollPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RollPrompt"
	prompt.ActionText = if kind == "Trait" then "Roll traits" else "Roll grades"
	prompt.ObjectText = if kind == "Trait" then "Rune Shrine" else "Dragonstone Forge"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		open(kind, part)
	end)
	prompt.Parent = part
end

local function makeLabel(parent: Instance, y: number, height: number, bold: boolean): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.new(0, 14, 0, y)
	l.Size = UDim2.new(1, -28, 0, height)
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Parent = parent
	return l
end

function RollStationController:Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RollStation"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.92, 0, 0.8, 0)
	panel.BackgroundColor3 = DARK
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	Instance.new("UICorner").Parent = panel
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 540)
	limit.Parent = panel

	title = makeLabel(panel, 10, 28, true)
	title.Size = UDim2.new(1, -70, 0, 28)
	owned = makeLabel(panel, 42, 20, false)

	local closeButton = Instance.new("TextButton")
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -10, 0, 8)
	closeButton.Size = UDim2.new(0, 36, 0, 30)
	closeButton.BackgroundColor3 = GOLD
	closeButton.TextColor3 = DARK
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextScaled = true
	closeButton.Text = "X"
	Instance.new("UICorner").Parent = closeButton
	closeButton.Activated:Connect(close)
	closeButton.Parent = panel

	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.new(0, 10, 0, 70)
	list.Size = UDim2.new(1, -20, 0.55, -70)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	detail = makeLabel(panel, 0, 24, true)
	detail.Position = UDim2.new(0, 14, 0.55, 8)

	rollButton = Instance.new("TextButton")
	rollButton.Position = UDim2.new(0, 14, 0.55, 40)
	rollButton.Size = UDim2.new(1, -28, 0, 44)
	rollButton.TextColor3 = DARK
	rollButton.Font = Enum.Font.GothamBold
	rollButton.TextScaled = true
	Instance.new("UICorner").Parent = rollButton
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = rollButton
	rollButton.Activated:Connect(function()
		if selectedId == nil or openKind == nil then
			return
		end
		if openKind == "Trait" then
			rollTrait:FireServer(selectedId)
		else
			rollGrade:FireServer(selectedId)
		end
	end)
	rollButton.Parent = panel

	odds = makeLabel(panel, 0, 0, false)
	odds.Position = UDim2.new(0, 14, 0.55, 94)
	odds.Size = UDim2.new(1, -28, 0.45, -104)
	odds.TextScaled = false
	odds.TextSize = 14
	odds.TextWrapped = true
	odds.TextYAlignment = Enum.TextYAlignment.Top
	odds.TextColor3 = Color3.fromRGB(190, 190, 205)

	for _, key in { "Dragons", "WyrmRunes", "Dragonstones" } do
		DataController:OnChanged(key, function()
			if panel.Visible then
				redraw()
			end
		end)
	end
end

function RollStationController:Start()
	for tag, kind in STATIONS do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			setupStation(instance, kind)
		end)
		for _, instance in CollectionService:GetTagged(tag) do
			setupStation(instance, kind)
		end
	end

	while true do
		task.wait(0.5)
		-- With streaming, a station model can arrive before its parts; keep trying until its prompt exists.
		for tag, kind in STATIONS do
			for _, instance in CollectionService:GetTagged(tag) do
				setupStation(instance, kind)
			end
		end

		-- Close the panel when the player walks away from the station.
		local station = openStation
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if station and root and root:IsA("BasePart") and (root.Position - station.Position).Magnitude > CLOSE_DISTANCE then
			close()
		end
	end
end

return RollStationController
