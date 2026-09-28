--!strict
-- Rune Shrine (traits, costs Wyrm Runes) and Dragonstone Forge (grades, costs Dragonstones).
-- Stations are instances tagged "RuneShrine" / "DragonstoneForge" (BasePart, or Model with a PrimaryPart).
-- Walking up and pressing E opens a window in two columns: your dragons on the left (rarity icon, level, current
-- trait/grade), and on the right the rune/stone count, the chosen dragon, a big Inscribe / Temper button and a grid of
-- what can come out with the chances (colored by tier). Wording is in Config/Text. The server checks the player is at
-- the station and has the currency. Styled with the UI kit.

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
local hint: TextLabel
local list: ScrollingFrame
local chosenCard: Frame
local chosenName: TextLabel
local detail: TextLabel
local rollButton: Button.Button
local chancesTitle: TextLabel
local odds: ScrollingFrame

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

local function chanceText(chance: number): string
	return if chance >= 1
		then string.format("%.0f%%", chance)
		elseif chance >= 0.1 then string.format("%.1f%%", chance)
		else string.format("%.2f%%", chance)
end

-- The chances grid: one chip per trait/grade (name + chance), colored by its tier.
local function drawOdds(kind: Kind, rollLuck: number)
	for _, child in odds:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local entries: { any } = if kind == "Trait" then TraitConfig.Traits else TraitConfig.Grades
	local weights = Luck.GetTierWeights(entries, rollLuck)
	local total = 0
	for _, weight in weights do
		total += weight
	end
	for index, entry in entries do
		local color = rarityColor(entry.Tier)
		local chip = Instance.new("Frame")
		chip.LayoutOrder = index
		chip.BackgroundColor3 = UITheme.Colors.CardBottom
		chip.BackgroundTransparency = 0.2
		Style.Corner(chip, 6)
		local stroke = Style.Stroke(chip, color, 1.5)
		stroke.Transparency = 0.3
		local name = Style.Label(chip, entry.Name or ("Grade " .. entry.Id), "Bold", 13, color)
		name.Position = UDim2.fromOffset(6, 0)
		name.Size = UDim2.new(0.66, -6, 1, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local chance = Style.Label(chip, chanceText(weights[index] / total * 100), "Heavy", 13, UITheme.Colors.Text)
		chance.AnchorPoint = Vector2.new(1, 0)
		chance.Position = UDim2.new(1, -6, 0, 0)
		chance.Size = UDim2.new(0.34, 0, 1, 0)
		chance.TextXAlignment = Enum.TextXAlignment.Right
		chip.Parent = odds
	end
end

local function redraw()
	local data = DataController:Get()
	local kind = openKind
	if data == nil or kind == nil then
		return
	end
	local currency = if kind == "Trait" then data.WyrmRunes else data.Dragonstones
	local cost = if kind == "Trait" then TraitConfig.TraitRollCost else TraitConfig.GradeRollCost
	local words = if kind == "Trait" then Text.RuneShrine else Text.DragonstoneForge
	window:SetTitle(words.Title)
	owned.Text = Text.Format(words.Owned, { count = Format.Number(currency) })
	hint.Text = words.Hint
	local iconKey = if kind == "Trait" then "WyrmRune" else "Dragonstone"
	if ownedIcon.Image ~= UITheme.Icons[iconKey] then
		ownedIcon.Image = UITheme.Icons[iconKey]
		window:SetIcon(iconKey)
	end
	chancesTitle.Text = words.Chances

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
		-- Row: a card (gold outline when chosen) with the rarity icon, name + level, and the current trait/grade.
		local row = Instance.new("Frame")
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -8, 0, 46)
		Style.CardLook(row, if dragon.Id == selectedId then UITheme.Colors.Title else nil)
		local rarity = if species then species.Rarity else ""
		local badge = Icon.new(row, `Rarity_{rarity}`, rarityColor(rarity))
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.new(0, 12, 0.5, 0)
		badge.Size = UDim2.fromOffset(28, 28)
		local name = Style.Label(row, `{if species then species.Name else "?"}  Lv {dragon.Level}`, "Heavy", 16, UITheme.Colors.Text)
		name.Position = UDim2.fromOffset(48, 3)
		name.Size = UDim2.new(1, -54, 0, 20)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local text = Style.Label(row, current, "Bold", 14, color)
		text.Position = UDim2.fromOffset(48, 23)
		text.Size = UDim2.new(1, -54, 0, 18)
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
		chosenName.Text = `{if species then species.Name else "?"}  Lv {selected.Level}`
		chosenName.TextColor3 = if species then rarityColor(species.Rarity) else UITheme.Colors.Text
		detail.Text = current
		detail.TextColor3 = color
	else
		chosenName.Text = words.NoDragons
		chosenName.TextColor3 = GREY
		detail.Text = ""
	end
	local canRoll = selected ~= nil and currency >= cost
	rollButton:SetText(Text.Format(words.Button, { cost = cost }))
	rollButton:SetEnabled(canRoll)
	drawOdds(kind, DragonStats.GetBoostMultiplier(data, "RollLuck"))
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
		Title = "Rune Shrine", -- set per station on open, with its rune/stone icon
		Icon = "WyrmRune",
		Size = UDim2.new(0.92, 0, 0.8, 0),
		MaxSize = Vector2.new(720, 520),
	})
	window:OnClose(function()
		openKind = nil
		openStation = nil
	end)
	local content = window.Content

	-- Left column: your dragons
	list = Instance.new("ScrollingFrame")
	list.Name = "Dragons"
	list.Size = UDim2.new(0.5, -6, 1, 0)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = UITheme.Colors.Trim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	Style.Pad(list, 2, 3)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- Right column: runes/stones owned, the chosen dragon, the button, the chances
	local side = Instance.new("Frame")
	side.Name = "Side"
	side.AnchorPoint = Vector2.new(1, 0)
	side.Position = UDim2.fromScale(1, 0)
	side.Size = UDim2.new(0.5, -6, 1, 0)
	side.BackgroundTransparency = 1
	side.Parent = content

	ownedIcon = Icon.new(side, "WyrmRune") :: ImageLabel
	ownedIcon.Size = UDim2.fromOffset(34, 34)
	owned = Style.Label(side, "", "Title", 22, UITheme.Colors.Gold)
	owned.Position = UDim2.fromOffset(42, 0)
	owned.Size = UDim2.new(1, -42, 0, 34)
	owned.TextXAlignment = Enum.TextXAlignment.Left
	owned.TextStrokeTransparency = 0
	hint = Style.Label(side, "", "Bold", 14, UITheme.Colors.TextMuted)
	hint.Position = UDim2.fromOffset(0, 36)
	hint.Size = UDim2.new(1, 0, 0, 18)
	hint.TextXAlignment = Enum.TextXAlignment.Left

	chosenCard = Instance.new("Frame")
	chosenCard.Name = "Chosen"
	chosenCard.Position = UDim2.fromOffset(0, 60)
	chosenCard.Size = UDim2.new(1, 0, 0, 64)
	Style.CardLook(chosenCard, UITheme.Colors.Title)
	chosenCard.Parent = side
	chosenName = Style.Label(chosenCard, "", "Title", 22)
	chosenName.Position = UDim2.fromOffset(16, 4)
	chosenName.Size = UDim2.new(1, -24, 0, 30)
	chosenName.TextXAlignment = Enum.TextXAlignment.Left
	chosenName.TextStrokeTransparency = 0
	chosenName.TextTruncate = Enum.TextTruncate.AtEnd
	detail = Style.Label(chosenCard, "", "Heavy", 15)
	detail.Position = UDim2.fromOffset(16, 34)
	detail.Size = UDim2.new(1, -24, 0, 22)
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextTruncate = Enum.TextTruncate.AtEnd

	rollButton = Button.new(side, {
		Text = Text.RuneShrine.PromptAction, -- replaced per station on open
		Kind = "Primary",
		TextSize = 20,
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
	rollButton.Instance.Position = UDim2.fromOffset(0, 132)
	rollButton.Instance.Size = UDim2.new(1, 0, 0, 50)

	chancesTitle = Style.Label(side, "", "Title", 16, UITheme.Colors.Title)
	chancesTitle.Position = UDim2.fromOffset(0, 190)
	chancesTitle.Size = UDim2.new(1, 0, 0, 20)
	chancesTitle.TextXAlignment = Enum.TextXAlignment.Left
	-- The chances scroll, so they stay readable when the window is short (phones).
	odds = Instance.new("ScrollingFrame")
	odds.Name = "Chances"
	odds.Position = UDim2.fromOffset(0, 214)
	odds.Size = UDim2.new(1, 0, 1, -214)
	odds.BackgroundTransparency = 1
	odds.BorderSizePixel = 0
	odds.ScrollBarThickness = 4
	odds.ScrollBarImageColor3 = UITheme.Colors.Trim
	odds.AutomaticCanvasSize = Enum.AutomaticSize.Y
	odds.CanvasSize = UDim2.new()
	odds.Parent = side
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -4, 0, 24)
	grid.CellPadding = UDim2.fromOffset(4, 4)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = odds
	Style.Pad(odds, 1, 1)

	HudLayout.OnLayoutChanged(function(phone)
		-- phones: tighter rows so the button and a few chances fit on the short screen
		chosenCard.Position = UDim2.fromOffset(0, if phone then 56 else 60)
		chosenCard.Size = UDim2.new(1, 0, 0, if phone then 56 else 64)
		rollButton.Instance.Position = UDim2.fromOffset(0, if phone then 118 else 132)
		rollButton.Instance.Size = UDim2.new(1, 0, 0, if phone then 40 else 50)
		chancesTitle.Position = UDim2.fromOffset(0, if phone then 162 else 190)
		odds.Position = UDim2.fromOffset(0, if phone then 184 else 214)
		odds.Size = UDim2.new(1, 0, 1, if phone then -184 else -214)
		grid.CellSize = UDim2.new(0.5, -4, 0, if phone then 20 else 24)
	end)

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
