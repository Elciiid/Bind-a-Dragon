--!strict
-- Rune Shrine (traits, costs Wyrm Runes) and Dragonstone Forge (grades, costs Dragonstones).
-- Stations are instances tagged "RuneShrine" / "DragonstoneForge" (BasePart, or Model with a PrimaryPart).
-- Walking up and pressing E opens a window: pick one of your dragons, see its current trait/grade, inscribe a rune /
-- temper it, and see the odds. Wording is in Config/Text. The server checks the player is at the station and has the currency. Styled with the UI kit.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local Button = require(script.Parent.UI.Button)
local Window = require(script.Parent.UI.Window)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Luck = require(ReplicatedStorage.Shared.Luck)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local TraitConfig = require(ReplicatedStorage.Shared.Config.Traits)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

type Kind = "Trait" | "Grade"

local STATIONS: { [string]: Kind } = { RuneShrine = "Trait", DragonstoneForge = "Grade" }
local CLOSE_DISTANCE = 25 -- the window closes when you walk this far from the station
local GREY = UITheme.Colors.TextMuted

local rollTrait = ReplicatedStorage.Remotes.RollTrait :: RemoteEvent
local rollGrade = ReplicatedStorage.Remotes.RollGrade :: RemoteEvent

local RollStationController = {}

local window: Window.Window
local owned: TextLabel
local ownedIcon: ImageLabel
local list: ScrollingFrame
local detail: TextLabel
local rollButton: Button.Button
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

local function oddsText(kind: Kind, rollLuck: number): string
	local entries: { any } = if kind == "Trait" then TraitConfig.Traits else TraitConfig.Grades
	local weights = Luck.GetTierWeights(entries, rollLuck)
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local lines = { if rollLuck > 1 then `Odds (Runebright {Format.Multiplier(rollLuck)} luck):` else "Odds:" }
	for index, entry in entries do
		local chance = weights[index] / total * 100
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
	local words = if kind == "Trait" then Text.RuneShrine else Text.DragonstoneForge
	window:SetTitle(words.Title)
	owned.Text = `{currency} {currencyName} · {words.Hint}`
	local iconKey = if kind == "Trait" then "WyrmRune" else "Dragonstone"
	if ownedIcon.Image ~= UITheme.Icons[iconKey] then
		ownedIcon.Image = UITheme.Icons[iconKey]
	end

	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
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
		-- Row: a card (gold outline when selected) with a transparent button over it.
		local row = Instance.new("Frame")
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -8, 0, 36)
		Style.CardLook(row, if dragon.Id == selectedId then UITheme.Colors.Title else nil)
		local text = Style.Label(row, `{if species then species.Name else "?"}  Lv {dragon.Level}  ·  {current}`, "Bold", 15, color)
		text.Position = UDim2.fromOffset(16, 0)
		text.Size = UDim2.new(1, -20, 1, 0)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextTruncate = Enum.TextTruncate.AtEnd
		local hit = Instance.new("TextButton")
		hit.Size = UDim2.fromScale(1, 1)
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.ZIndex = 3
		hit.Parent = row
		Style.AttachPress(hit)
		hit.Activated:Connect(function()
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
	rollButton:SetText(Text.Format(words.Button, { cost = cost }))
	rollButton:SetEnabled(canRoll)
	odds.Text = oddsText(kind, DragonStats.GetBoostMultiplier(data, "RollLuck"))
end

local function close()
	window:Close()
	openKind = nil
	openStation = nil
end

local function open(kind: Kind, station: BasePart)
	openKind = kind
	openStation = station
	window:Open()
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
	local words = if kind == "Trait" then Text.RuneShrine else Text.DragonstoneForge
	prompt.ActionText = words.PromptAction
	prompt.ObjectText = words.Title
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		open(kind, part)
	end)
	prompt.Parent = part
end

function RollStationController:Init()
	window = Window.new({
		Name = "RollStation",
		Title = "Rune Shrine", -- set per station on open; the currency row shows the rune/stone icon
		Size = UDim2.new(0.92, 0, 0.8, 0),
		MaxSize = Vector2.new(580, 540),
	})
	window:OnClose(function()
		openKind = nil
		openStation = nil
	end)
	local content = window.Content

	local ownedRow = Instance.new("Frame")
	ownedRow.BackgroundTransparency = 1
	ownedRow.Size = UDim2.new(1, 0, 0, 24)
	ownedRow.Parent = content
	ownedIcon = Icon.new(ownedRow, "WyrmRune") :: ImageLabel
	ownedIcon.Size = UDim2.fromOffset(24, 24)
	owned = Style.Label(ownedRow, "", "Heavy", 16, UITheme.Colors.Gold)
	owned.Position = UDim2.fromOffset(30, 0)
	owned.Size = UDim2.new(1, -30, 1, 0)
	owned.TextXAlignment = Enum.TextXAlignment.Left

	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.new(0, 0, 0, 30)
	list.Size = UDim2.new(1, 0, 0.55, -30)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = UITheme.Colors.Trim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	Style.Pad(list, 2, 3)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	detail = Style.Label(content, "", "Heavy", 17)
	detail.Position = UDim2.new(0, 2, 0.55, 6)
	detail.Size = UDim2.new(1, -4, 0, 22)
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextTruncate = Enum.TextTruncate.AtEnd

	rollButton = Button.new(content, {
		Text = Text.RuneShrine.PromptAction, -- replaced per station on open
		Kind = "Primary",
		OnClick = function()
			if selectedId == nil or openKind == nil then
				return
			end
			if openKind == "Trait" then
				rollTrait:FireServer(selectedId)
			else
				rollGrade:FireServer(selectedId)
			end
		end,
	})
	rollButton.Instance.Position = UDim2.new(0, 0, 0.55, 34)
	rollButton.Instance.Size = UDim2.new(1, 0, 0, 44)

	-- The odds scroll, so they stay readable when the window is short (phones).
	local oddsScroll = Instance.new("ScrollingFrame")
	oddsScroll.Position = UDim2.new(0, 0, 0.55, 86)
	oddsScroll.Size = UDim2.new(1, 0, 0.45, -86)
	oddsScroll.BackgroundTransparency = 1
	oddsScroll.BorderSizePixel = 0
	oddsScroll.ScrollBarThickness = 4
	oddsScroll.ScrollBarImageColor3 = UITheme.Colors.Trim
	oddsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	oddsScroll.CanvasSize = UDim2.new()
	oddsScroll.Parent = content
	odds = Style.Label(oddsScroll, "", "Body", 14, UITheme.Colors.TextMuted)
	odds.Size = UDim2.new(1, -8, 0, 0)
	odds.AutomaticSize = Enum.AutomaticSize.Y
	odds.TextXAlignment = Enum.TextXAlignment.Left
	odds.TextYAlignment = Enum.TextYAlignment.Top

	for _, key in { "Dragons", "WyrmRunes", "Dragonstones" } do
		DataController:OnChanged(key, function()
			if window.IsOpen then
				redraw()
			end
		end)
	end
	-- Timers change every second; only redraw when a Runebright Tonic starts or ends.
	local lastRollLuck = 1
	DataController:OnChanged("ActiveBoosts", function()
		local data = DataController:Get()
		local rollLuck = if data then DragonStats.GetBoostMultiplier(data, "RollLuck") else 1
		if rollLuck ~= lastRollLuck then
			lastRollLuck = rollLuck
			if window.IsOpen then
				redraw()
			end
		end
	end)
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

		-- Close the window when the player walks away from the station.
		local station = openStation
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if station and root and root:IsA("BasePart") and (root.Position - station.Position).Magnitude > CLOSE_DISTANCE then
			close()
		end
	end
end

return RollStationController
