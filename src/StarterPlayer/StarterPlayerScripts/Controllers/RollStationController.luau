--!strict
-- Rune Shrine (traits, costs Wyrm Runes) and Dragonstone Forge (grades, costs Dragonstones).
-- Stations are instances tagged "RuneShrine" / "DragonstoneForge" (BasePart, or Model with a PrimaryPart).
-- Walking up and pressing E opens a responsive window: a dragon picker, the chosen dragon and its current trait/grade,
-- the resource count, Inscribe / Temper and readable outcome rows. Narrow screens stack these inside a scroll instead
-- of shrinking a two-column layout. Wording is in Config/Text. The server checks the player is at
-- the station and has the currency. Styled with the UI kit.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local Button = require(script.Parent.UI.Button)
local Window = require(script.Parent.UI.Window)
local DragonPicture = require(script.Parent.UI.DragonPicture)
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
local CLOSE_DISTANCE = 25 -- existing station-close boundary; purchases remain server validated
local GREY = UITheme.Colors.TextMuted
local Mobile = UITheme.MobileUI

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
local odds: Frame
local body: ScrollingFrame
local columns: Frame
local side: Frame
local selectionLayout: UIListLayout
local rowFrames: { Frame } = {}
local oddsCount = 0

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
			return Text.Station.NoTrait, GREY
		end
		local parts = {}
		if trait.Income > 1 then
			table.insert(parts, Text.Format(Text.Station.TraitGold, { n = trait.Income }))
		end
		if trait.Power > 1 then
			table.insert(parts, Text.Format(Text.Station.TraitPower, { n = trait.Power }))
		end
		return `{trait.Name} ({table.concat(parts, ", ")})`, rarityColor(trait.Tier)
	end
	local grade = DragonStats.GetGrade(dragon)
	if grade == nil then
		return Text.Station.NoGrade, GREY
	end
	return Text.Format(Text.Station.GradeStats, { grade = grade.Id, n = grade.Multiplier }), rarityColor(grade.Tier)
end

local function chanceText(chance: number): string
	return if chance >= 1
		then string.format("%.0f%%", chance)
		elseif chance >= 0.1 then string.format("%.1f%%", chance)
		else string.format("%.2f%%", chance)
end

-- One outcome row per trait/grade (name + chance), colored by its tier.
local function layoutStation()
	if columns == nil then return end
	local width = math.max(1, body.AbsoluteSize.X - Mobile.Scrollbar - Mobile.Padding * 2)
	local stacked = width < Mobile.StationColumnsAt
	local selectionHeight = if stacked then Mobile.RowHeight + Mobile.Scrollbar + Mobile.Padding else math.max(Mobile.RowHeight, body.AbsoluteSize.Y - Mobile.Padding * 2)
	list.Position = UDim2.new()
	list.Size = if stacked then UDim2.new(1, 0, 0, selectionHeight) else UDim2.fromOffset(Mobile.StationDragonWidth, selectionHeight)
	list.AutomaticCanvasSize = if stacked then Enum.AutomaticSize.X else Enum.AutomaticSize.Y
	list.ScrollingDirection = if stacked then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y
	selectionLayout.FillDirection = if stacked then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	for _, row in rowFrames do
		row.Size = if stacked then UDim2.fromOffset(Mobile.StationDragonWidth, Mobile.RowHeight) else UDim2.new(1, -Mobile.Scrollbar, 0, Mobile.RowHeight)
	end
	local sideX = if stacked then 0 else Mobile.StationDragonWidth + Mobile.Gap
	local sideY = if stacked then selectionHeight + Mobile.Gap else 0
	side.Position = UDim2.fromOffset(sideX, sideY)
	local oddsTop = Mobile.Touch + Mobile.Gap + Mobile.StationSelectedHeight + Mobile.Gap + Mobile.Touch + Mobile.Gap + Mobile.Title + Mobile.Gap
	local oddsHeight = oddsCount * Mobile.StationOddsRow + math.max(0, oddsCount - 1) * Mobile.Gap
	side.Size = UDim2.new(1, -sideX, 0, oddsTop + oddsHeight)
	odds.Size = UDim2.new(1, 0, 0, oddsHeight)
	columns.Size = UDim2.new(1, -Mobile.Scrollbar - Mobile.Padding * 2, 0, math.max(selectionHeight, sideY + side.Size.Y.Offset))
end

local function drawOdds(kind: Kind, rollLuck: number)
	for _, child in odds:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local entries: { any } = if kind == "Trait" then TraitConfig.Traits else TraitConfig.Grades
	oddsCount = #entries
	local weights = Luck.GetTierWeights(entries, rollLuck)
	local total = 0
	for _, weight in weights do
		total += weight
	end
	for index, entry in entries do
		local color = rarityColor(entry.Tier)
		local chip = Instance.new("Frame")
		chip.LayoutOrder = index
		chip.Size = UDim2.new(1, 0, 0, Mobile.StationOddsRow)
		chip.BackgroundColor3 = UITheme.Colors.CardBottom
		chip.BackgroundTransparency = 0.2
		Style.Corner(chip, 6)
		local stroke = Style.Stroke(chip, color, 1.5)
		stroke.Transparency = 0.3
		local name = Style.Label(chip, entry.Name or Text.Format(Text.Station.Grade, { grade = entry.Id }), "Bold", Mobile.Body, color)
		name.Position = UDim2.fromOffset(Mobile.Padding, 0)
		name.Size = UDim2.new(1, -Mobile.Touch * 2 - Mobile.Padding * 2, 1, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local chance = Style.Label(chip, chanceText(weights[index] / total * 100), "Bold", Mobile.Body, UITheme.Colors.Text)
		chance.AnchorPoint = Vector2.new(1, 0)
		chance.Position = UDim2.new(1, -Mobile.Padding, 0, 0)
		chance.Size = UDim2.new(0, Mobile.Touch * 2, 1, 0)
		chance.TextXAlignment = Enum.TextXAlignment.Right
		chip.Parent = odds
	end
	layoutStation()
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
		local buttonIcon = rollButton.Instance:FindFirstChild("Icon", true)
		if buttonIcon and buttonIcon:IsA("ImageLabel") then
			buttonIcon.Image = UITheme.Icons[iconKey]
		end
	end
	chancesTitle.Text = words.Chances

	local previousSelection = GuiService.SelectedObject
	local restoreSelection = previousSelection ~= nil and previousSelection:IsDescendantOf(list)
	local selectedHit: TextButton? = nil
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	table.clear(rowFrames)
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
		row.Size = UDim2.new(1, -Mobile.Scrollbar, 0, Mobile.RowHeight)
		Style.CardLook(row, if dragon.Id == selectedId then UITheme.Colors.Title else nil)
		local picture = Instance.new("Frame")
		picture.BackgroundTransparency = 1
		picture.AnchorPoint = Vector2.new(0, 0.5)
		picture.Position = UDim2.new(0, Mobile.Padding, 0.5, 0)
		picture.Size = UDim2.fromOffset(Mobile.Touch, Mobile.Touch)
		picture.ZIndex = 3
		picture.Parent = row
		DragonPicture.new(picture, dragon.SpeciesId, dragon.Level)
		local name = Style.Label(row, Text.Format(Text.Station.DragonLevel, { name = if species then species.Name else "?", level = dragon.Level }), "Bold", Mobile.Body, UITheme.Colors.Text)
		Style.Outline(name, 1.5)
		name.Position = UDim2.fromOffset(Mobile.Touch + Mobile.Padding * 2, Mobile.Padding / 2)
		name.Size = UDim2.new(1, -(Mobile.Touch + Mobile.Padding * 3), 0, Mobile.Body * 2 + Mobile.Gap)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local text = Style.Label(row, current, "Body", Mobile.Small, color)
		text.Position = UDim2.fromOffset(Mobile.Touch + Mobile.Padding * 2, Mobile.RowHeight - Mobile.Small * 2 - Mobile.Padding / 2)
		text.Size = UDim2.new(1, -(Mobile.Touch + Mobile.Padding * 3), 0, Mobile.Small * 2)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextWrapped = true
		local hit = Instance.new("TextButton")
		hit.Size = UDim2.fromScale(1, 1)
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.ZIndex = 3
		hit.Parent = row
		if dragon.Id == selectedId then selectedHit = hit end
		Style.AttachPress(hit)
		hit.Activated:Connect(function()
			selectedId = dragon.Id
			redraw()
		end)
		row.Parent = list
		table.insert(rowFrames, row)
	end

	local selected = if selectedId then data.Dragons[selectedId] else nil
	if selected then
		local species = Dragons[selected.SpeciesId]
		local current, color = describe(selected, kind)
		chosenName.Text = Text.Format(Text.Station.DragonLevel, { name = if species then species.Name else "?", level = selected.Level })
		chosenName.TextColor3 = if species then rarityColor(species.Rarity) else UITheme.Colors.Text
		detail.Text = current
		detail.TextColor3 = color
	else
		chosenName.Text = words.NoDragons
		chosenName.TextColor3 = GREY
		detail.Text = ""
	end
	local canRoll = selected ~= nil and currency >= cost
	if selected and currency < cost then
		hint.Text = Text.Format(Text.Station.RollUnavailable, {
			count = cost, resource = if kind == "Trait" then Text.Items.WyrmRunes.Name else Text.Items.Dragonstones.Name,
		})
	end
	rollButton:SetText(Text.Format(words.Button, { cost = cost }))
	rollButton:SetEnabled(canRoll)
	drawOdds(kind, DragonStats.GetBoostMultiplier(data, "RollLuck"))
	if restoreSelection then GuiService.SelectedObject = selectedHit end
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
		Title = Text.RuneShrine.Title,
		Icon = "WyrmRune",
		Size = UDim2.new(0.92, 0, 0.8, 0),
		MaxSize = Vector2.new(Mobile.StationColumnsAt + Mobile.StationDragonWidth, Mobile.StationColumnsAt),
	})
	window:OnClose(function()
		openKind = nil
		openStation = nil
	end)
	local content = window.Content

	-- Count stays visible; the selection/details area scrolls rather than shrinking text on short phones.
	ownedIcon = Icon.new(content, "WyrmRune") :: ImageLabel
	ownedIcon.Size = UDim2.fromOffset(Mobile.Touch, Mobile.Touch)
	owned = Style.Label(content, "", "Title", Mobile.Title, UITheme.Colors.Gold)
	owned.Position = UDim2.fromOffset(Mobile.Touch + Mobile.Gap, 0)
	owned.Size = UDim2.new(1, -(Mobile.Touch + Mobile.Gap), 0, Mobile.Touch)
	owned.TextXAlignment = Enum.TextXAlignment.Left

	body = Instance.new("ScrollingFrame")
	body.Name = "StationBody"
	body.Position = UDim2.fromOffset(0, Mobile.StationHeaderHeight)
	body.Size = UDim2.new(1, 0, 1, -Mobile.StationHeaderHeight)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = Mobile.Scrollbar
	body.ScrollBarImageColor3 = UITheme.Colors.Trim
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.CanvasSize = UDim2.new()
	body.Parent = content
	Style.Pad(body, Mobile.Padding)
	columns = Instance.new("Frame")
	columns.Name = "Columns"
	columns.BackgroundTransparency = 1
	columns.Parent = body

	-- On narrow screens the dragon picker becomes a horizontal carousel above the full-width detail pane.
	list = Instance.new("ScrollingFrame")
	list.Name = "Dragons"
	list.Size = UDim2.new(0.5, -6, 1, 0)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = Mobile.Scrollbar
	list.ScrollBarImageColor3 = UITheme.Colors.Trim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = columns
	selectionLayout = Instance.new("UIListLayout")
	selectionLayout.Padding = UDim.new(0, Mobile.Gap)
	selectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	selectionLayout.Parent = list

	-- Right column: runes/stones owned, the chosen dragon, the button, the chances
	side = Instance.new("Frame")
	side.Name = "Side"
	side.BackgroundTransparency = 1
	side.Parent = columns
	hint = Style.Label(side, "", "Body", Mobile.Body, UITheme.Colors.TextMuted)
	hint.Size = UDim2.new(1, 0, 0, Mobile.Touch)
	hint.TextXAlignment = Enum.TextXAlignment.Left

	chosenCard = Instance.new("Frame")
	chosenCard.Name = "Chosen"
	chosenCard.Position = UDim2.fromOffset(0, Mobile.Touch + Mobile.Gap)
	chosenCard.Size = UDim2.new(1, 0, 0, Mobile.StationSelectedHeight)
	Style.CardLook(chosenCard, UITheme.Colors.Title)
	chosenCard.Parent = side
	chosenName = Style.Label(chosenCard, "", "Title", Mobile.Title)
	chosenName.Position = UDim2.fromOffset(Mobile.Padding, Mobile.Padding / 2)
	chosenName.Size = UDim2.new(1, -Mobile.Padding * 2, 0, Mobile.Title * 2)
	chosenName.TextXAlignment = Enum.TextXAlignment.Left
	chosenName.TextStrokeTransparency = 0
	detail = Style.Label(chosenCard, "", "Body", Mobile.Small)
	detail.Position = UDim2.fromOffset(Mobile.Padding, Mobile.StationSelectedHeight - Mobile.Small * 2 - Mobile.Padding / 2)
	detail.Size = UDim2.new(1, -Mobile.Padding * 2, 0, Mobile.Small * 2)
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextWrapped = true

	rollButton = Button.new(side, {
		Text = Text.RuneShrine.PromptAction, -- replaced per station on open
		Kind = "Confirm",
		Icon = "WyrmRune",
		TextSize = Mobile.Title,
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
	local actionTop = Mobile.Touch + Mobile.Gap + Mobile.StationSelectedHeight + Mobile.Gap
	rollButton.Instance.Position = UDim2.fromOffset(0, actionTop)
	rollButton.Instance.Size = UDim2.new(1, 0, 0, Mobile.Touch)

	chancesTitle = Style.Label(side, "", "Title", Mobile.Title, UITheme.Colors.Title)
	chancesTitle.Position = UDim2.fromOffset(0, actionTop + Mobile.Touch + Mobile.Gap)
	chancesTitle.Size = UDim2.new(1, 0, 0, Mobile.Title)
	chancesTitle.TextXAlignment = Enum.TextXAlignment.Left
	-- One readable row per outcome; the entire station body supplies the scroll on short screens.
	odds = Instance.new("Frame")
	odds.Name = "Chances"
	odds.Position = UDim2.fromOffset(0, actionTop + Mobile.Touch + Mobile.Gap + Mobile.Title + Mobile.Gap)
	odds.BackgroundTransparency = 1
	odds.BorderSizePixel = 0
	odds.Parent = side
	local oddsList = Instance.new("UIListLayout")
	oddsList.Padding = UDim.new(0, Mobile.Gap)
	oddsList.SortOrder = Enum.SortOrder.LayoutOrder
	oddsList.Parent = odds
	body:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutStation)
	HudLayout.OnLayoutChanged(layoutStation)

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
