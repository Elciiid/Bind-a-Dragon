--!strict
-- Dragon Spire battle HUD (UI renewal part 2), bottom center, following the server's climb (SpireUpdate):
--  * a big floor badge on the top edge ("Floor 40", a gold BOSS tag on boss floors) with the record small under it;
--  * your dragon's portrait vs the enemy's (VS in the middle), each with a health bar that drains over the fight
--    (the server already decided the winner: the stronger dragon; the bars only show it);
--  * no text log: each cleared floor pops a "Floor 39 cleared!" chip that fades (first clears sparkle), and the drops
--    fly as small icons into the Inventory button;
--  * Stop = a small rose button; Hide (–) minimizes the HUD to a small floor badge (tap it to open again).
-- Between climbs, near the Spire: your best dragon with Climb and Auto-Repeat, and the difficulty picker (Easy / Medium / Hard /
-- Infinite; one that is not unlocked is greyed and says what clears it). Every run starts at stage 1. With Infinite picked a small
-- panel beside the HUD shows this week's top floors (the server's SpireLeaderboardService, asked for with SpireAction("Board")).
-- Floor clears never use the toast queue. Sizes/motion in UITheme, words in Text.Spire.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local DataController = require(script.Parent.DataController)
local EffectsQuality = require(script.Parent.EffectsQuality)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Button = require(script.Parent.UI.Button)
local Icon = require(script.Parent.UI.Icon)
local Tooltip = require(script.Parent.UI.Tooltip)
local DragonPicture = require(script.Parent.UI.DragonPicture)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local SpireConfig = require(ReplicatedStorage.Shared.Config.Spire)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local Theme = require(ReplicatedStorage.Shared.Config.UITheme)
local Layout = require(ReplicatedStorage.Shared.Config.Layout)

local spireAction = ReplicatedStorage.Remotes.SpireAction :: RemoteEvent
local spireUpdate = ReplicatedStorage.Remotes.SpireUpdate :: RemoteEvent

local words = Text.Spire

type Portrait = { Root: Frame, Card: Frame, Holder: Frame, Name: TextLabel, Fill: Frame, Key: string }
type Mode = "Ready" | "Fight" | "Ended"

local SpireController = {}

local gui: ScreenGui
local hud: Frame
local hudScale: UIScale
local mini: TextButton
local miniLabel: TextLabel
local floorLabel: TextLabel
local bossTag: TextLabel
local recordLabel: TextLabel
local vsLabel: GuiObject
local message: TextLabel
local mine: Portrait
local enemy: Portrait
local stopButton: Button.Button
local climbButton: Button.Button
local repeatButton: Button.Button
local buttonRow: Frame
local autoRepeat = false
local chip: TextLabel? = nil
local pickerRow: Frame
local pickerButtons: { [string]: Button.Button } = {}
local pickerCovers: { [string]: TextButton } = {}
local boardPanel: Frame
local boardTitle: TextLabel
local boardRows: { { Row: Frame, Rank: TextLabel, Name: TextLabel, Floor: TextLabel } } = {}
local boardMine: TextLabel
local boardReset: TextLabel
local boardEmpty: TextLabel
local lastBoard: { [string]: any }? = nil
local lastBoardRequest = -1e9
local difficulty = "Easy" -- the picked difficulty (data.SpireDifficulty; the server's pick while climbing)

local mode: Mode = "Ready"
local record = 0
local climbing = false
local minimized = false -- the player pressed Hide; stays minimized until they walk away
local hiddenByWindow = false -- a window hid the HUD; it comes back when that window closes
local timerStart, timerSeconds = 0, 0
local playerWins = true
local powerRatio = 0 -- the loser's power / the winner's (how much the winner's bar drains)
local flyers = 0
local phone = false
local near = false

local function format(text: string, values: { [string]: any }): string
	return Text.Format(text, values)
end

local function tween(instance: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props):Play()
end

local function formatDuration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days, hours, minutes = seconds // 86400, (seconds % 86400) // 3600, (seconds % 3600) // 60
	if days > 0 then
		return `{days}d {hours}h`
	elseif hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{minutes}m`
end

local function difficultyName(id: string): string
	return words.Difficulty[id] or id
end

-- The record of the picked difficulty.
local function recordOf(id: string): number
	local data = DataController:Get()
	return if data then DragonStats.GetSpireRecord(data, id) else 0
end

---------------------------------------------------------------------------------------------------------------
-- Building blocks

local function makeBar(parent: Instance, color: Color3): (Frame, Frame)
	local track = Instance.new("Frame")
	track.Name = "Bar"
	track.BackgroundColor3 = Theme.Colors.TextStroke
	track.BackgroundTransparency = 0.2
	track.ZIndex = 3
	Style.Round(track)
	Style.GoldBorder(track, 2)
	track.Parent = parent
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.ZIndex = 4
	Style.Gradient(fill, Style.Shade(color, 0.3), Style.Shade(color, -0.2))
	Style.Round(fill)
	fill.Parent = track
	return track, fill
end

local function makePortrait(parent: Instance, color: Color3, side: number): Portrait
	local size = Theme.Sizes.SpirePortrait
	local root = Instance.new("Frame")
	root.Name = if side == 0 then "Mine" else "Enemy"
	root.AnchorPoint = Vector2.new(side, 0)
	root.Position = UDim2.new(side, if side == 0 then 12 else -12, 0, 6)
	root.Size = UDim2.fromOffset(size, size + 34)
	root.BackgroundTransparency = 1
	root.Parent = parent

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromOffset(size, size)
	Style.CardLook(card, color)
	card.Parent = root
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card
	local holder = Instance.new("Frame")
	holder.Name = "Picture"
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(4, 4)
	holder.Size = UDim2.new(1, -8, 1, -8)
	holder.ZIndex = 3
	holder.Parent = card

	local name = Style.Label(root, "", "Title", 15, Theme.Colors.Text)
	name.Position = UDim2.fromOffset(-10, size + 2)
	name.Size = UDim2.new(1, 20, 0, 16)
	name.TextScaled = true
	name.ZIndex = 3
	Style.Outline(name, 1.5)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 16
	limit.Parent = name

	local track, fill = makeBar(root, color)
	track.Position = UDim2.fromOffset(0, size + 20)
	track.Size = UDim2.new(1, 0, 0, 12)
	return { Root = root, Card = card, Holder = holder, Name = name, Fill = fill, Key = "" }
end

-- Shows a dragon in a portrait (rebuilt only when the species or stage changes).
local function setPortrait(portrait: Portrait, speciesId: string?, level: number?, name: string?)
	portrait.Name.Text = name or (if speciesId and Dragons[speciesId] then Dragons[speciesId].Name else "?")
	local key = if speciesId then `{speciesId}:{DragonStats.GetStage(level or 1).Id}` else ""
	if key == portrait.Key then
		return
	end
	portrait.Key = key
	for _, child in portrait.Holder:GetChildren() do
		child:Destroy()
	end
	if speciesId then
		DragonPicture.new(portrait.Holder, speciesId, level)
	end
end

local function setBars(mineFill: number, enemyFill: number)
	mine.Fill.Size = UDim2.fromScale(math.clamp(mineFill, 0, 1), 1)
	enemy.Fill.Size = UDim2.fromScale(math.clamp(enemyFill, 0, 1), 1)
end

---------------------------------------------------------------------------------------------------------------
-- Floor chips and flying drops (never the toast queue)

local function popChip(floor: number, firstClear: boolean)
	if chip then
		chip:Destroy()
		chip = nil
	end
	local anchor: GuiObject = if hud.Visible then hud else mini
	local label = Style.Label(gui, format(words.Cleared, { floor = floor }), "Title", if phone then 22 else 34,
		if firstClear then Theme.Colors.Title else Theme.Colors.Text)
	label.Name = "FloorChip"
	label.AnchorPoint = Vector2.new(0.5, 1)
	local center = anchor.AbsolutePosition - gui.AbsolutePosition
	local y = center.Y - (if anchor == hud then 30 * hudScale.Scale else 8)
	label.Position = UDim2.fromOffset(center.X + anchor.AbsoluteSize.X / 2, y)
	label.Size = UDim2.fromOffset(360, if phone then 26 else 40)
	label.ZIndex = 20
	Style.Outline(label, if phone then 2 else 3)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = label
	label.Parent = gui
	chip = label
	tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	if firstClear then
		task.defer(function()
			Style.SparkleBurst(label, label.AbsoluteSize / 2, 14, 60)
		end)
	end
	task.delay(Theme.Motion.SpireChip, function()
		if label.Parent == nil then
			return
		end
		tween(label, 0.35, { TextTransparency = 1, Position = label.Position - UDim2.fromOffset(0, 20) })
		local outline = label:FindFirstChild("Outline")
		if outline then
			tween(outline, 0.35, { Transparency = 1 })
		end
		task.delay(0.4, function()
			label:Destroy()
			if chip == label then
				chip = nil
			end
		end)
	end)
end

local function dropIcons(reward: { [string]: any }): { string }
	local icons = {}
	for potionId, count in reward.Potions or {} do
		for _ = 1, math.min(count, 3) do
			table.insert(icons, `Potion_{potionId}`)
		end
	end
	for key, icon in { WyrmRunes = "WyrmRune", Dragonstones = "Dragonstone", Stardust = "Stardust" } do
		if (reward[key] or 0) > 0 then
			table.insert(icons, icon)
		end
	end
	return icons
end

local function flyDrops(reward: { [string]: any }?)
	local target = HudLayout.GetMenuButton("Inventory")
	if reward == nil or target == nil or target.AbsoluteSize.X <= 0 then
		return
	end
	local from: GuiObject = if hud.Visible then mine.Card else mini
	local start = from.AbsolutePosition + from.AbsoluteSize / 2 - gui.AbsolutePosition
	local finish = target.AbsolutePosition + target.AbsoluteSize / 2 - gui.AbsolutePosition
	local size = Theme.Sizes.SpireDropIcon * (if phone then 0.7 else 1)
	for index, key in dropIcons(reward) do
		if flyers >= Theme.Motion.SpireMaxFlyers then
			break
		end
		flyers += 1
		local icon = Icon.new(gui, key)
		icon.Name = "Drop"
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromOffset(start.X + (index - 1) * 14, start.Y)
		icon.Size = UDim2.fromOffset(0, 0)
		icon.ZIndex = 25
		task.delay((index - 1) * 0.12, function()
			tween(icon, 0.2, { Size = UDim2.fromOffset(size * 1.3, size * 1.3) }, Enum.EasingStyle.Back)
			task.wait(0.25)
			tween(icon, Theme.Motion.SpireFly, { Position = UDim2.fromOffset(finish.X, finish.Y), Size = UDim2.fromOffset(size * 0.6, size * 0.6) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(Theme.Motion.SpireFly)
			icon:Destroy()
			flyers -= 1
		end)
	end
end

---------------------------------------------------------------------------------------------------------------
-- States

-- Sets a button label to `size` (HUD units), shrunk until the text fits `width` (HUD units).
local function fitLabel(button: Button.Button, size: number, width: number)
	local label = button.Label
	while size > 9 and TextService:GetTextSize(label.Text, size, label.Font, Vector2.new(1000, 200)).X > width do
		size -= 1
	end
	label.TextSize = size
end

local function updateRepeat()
	repeatButton:SetText(if phone then (if autoRepeat then words.AutoRepeatOnShort else words.AutoRepeatOffShort) else (if autoRepeat then words.AutoRepeatOn else words.AutoRepeatOff))
	local height = if phone then Layout.DetailsSize.Y / hudScale.Scale else 42
	climbButton.Instance.Size = UDim2.new(0.5, -4, 0, height)
	local sizes = Theme.Sizes
	local rightWidth = sizes.SpireHud.X - (12 + sizes.SpirePortrait + 12) - 16
	fitLabel(repeatButton, 18 * (if phone then 1 / hudScale.Scale else 1), (if mode == "Fight" then sizes.SpireHud.X * 0.44 else rightWidth / 2) - 18)
end

local function setFloorBadge(text: string, boss: boolean)
	floorLabel.Text = text
	bossTag.Visible = boss
	miniLabel.Text = text
end

local function setMode(newMode: Mode)
	mode = newMode
	local fighting = newMode == "Fight"
	local height = if phone then Layout.DetailsSize.Y / hudScale.Scale else 34
	local rowHeight = if phone then height else 42
	local unit = if phone then 1 / hudScale.Scale else 1 -- phones: sizes are written in screen pixels, the HUD is scaled down
	local sizes = Theme.Sizes
	local rightWidth = sizes.SpireHud.X - (12 + sizes.SpirePortrait + 12) - 16 -- the space right of the portrait
	fitLabel(climbButton, 22 * unit, rightWidth / 2 - 18)
	fitLabel(repeatButton, 18 * unit, (if fighting then sizes.SpireHud.X * 0.44 else rightWidth / 2) - 18)
	fitLabel(stopButton, 16 * unit, 92 - 14)
	enemy.Root.Visible = fighting
	vsLabel.Visible = fighting
	recordLabel.Visible = fighting
	message.Visible = not fighting
	local rightEdge = 12 + Theme.Sizes.SpirePortrait + 12
	message.Position = UDim2.fromOffset(rightEdge, if phone then 22 else 26)
	message.Size = UDim2.new(1, -(rightEdge + 16), 0, if phone then 40 else 30)
	pickerRow.Visible = not fighting
	pickerRow.Position = UDim2.fromOffset(rightEdge, if phone then 72 else 70)
	pickerRow.Size = UDim2.new(1, -(rightEdge + 16), 0, if phone then height else 44)
	local smallest = math.huge
	for _, button in pickerButtons do
		fitLabel(button, (if phone then 17 else 18) * unit, (rightWidth - 24) / 4 - 14)
		smallest = math.min(smallest, button.Label.TextSize)
	end
	for _, button in pickerButtons do
		button.Label.TextSize = smallest -- one size for all four
	end
	stopButton.Instance.Visible = fighting
	climbButton.Instance.Visible = newMode == "Ready" or newMode == "Ended"
	repeatButton.Instance.Parent = if fighting then hud else buttonRow
	repeatButton.Instance.AnchorPoint = if fighting then Vector2.new(0.5, 1) else Vector2.zero
	repeatButton.Instance.Position = if fighting then UDim2.new(0.5, 0, 1, -10) else UDim2.new()
	repeatButton.Instance.Size = if fighting then UDim2.new(0.44, 0, 0, height) else UDim2.new(0.5, -4, 0, rowHeight)
	buttonRow.Size = UDim2.new(1, -(12 + Theme.Sizes.SpirePortrait + 12 + 16), 0, rowHeight)
	stopButton.Instance.Size = UDim2.fromOffset(92, height)
	-- the Stop button: under VS in a fight, bottom-right while zooming up
	stopButton.Instance.AnchorPoint = if fighting then Vector2.new(0.5, 1) else Vector2.new(1, 1)
	stopButton.Instance.Position = if fighting then UDim2.new(0.5, 0, 1, -(height + Theme.Sizes.Gap + 10)) else UDim2.new(1, -14, 1, -10)
	if not fighting then
		timerSeconds = 0
	end
	updateRepeat()
end

local function showHud()
	if minimized then
		mini.Visible = true
		hud.Visible = false
	else
		mini.Visible = false
		hud.Visible = true
	end
	Players.LocalPlayer:SetAttribute("SpireHudVisible", hud.Visible)
end

local function hideAll()
	hud.Visible = false
	mini.Visible = false
	Players.LocalPlayer:SetAttribute("SpireHudVisible", false)
end

-- Between climbs, near the Spire: your best dragon, Climb and Auto-Repeat.
local function showReady()
	local data = DataController:Get()
	difficulty = if data and SpireConfig.Difficulties[data.SpireDifficulty] ~= nil and DragonStats.IsDifficultyUnlocked(data, data.SpireDifficulty) then data.SpireDifficulty else "Easy"
	record = recordOf(difficulty)
	local best = if data then DragonStats.GetBestDragon(data) else nil
	local species = if best then Dragons[best.SpeciesId] else nil
	local mutation = if best then Mutations.Get(best.MutationId) else Mutations.Get(nil)
	local bestName = if species and mutation.Id ~= Mutations.NormalId then `{mutation.Name} {species.Name}` else if species then species.Name else nil
	setPortrait(mine, if best then best.SpeciesId else nil, if best then best.Level else nil, bestName)
	setBars(1, 1)
	setFloorBadge(format(words.Best, { record = record }), false)
	message.Text = words.Ready
	climbButton:SetText(words.Climb)
	setMode("Ready")
	if HudLayout.HasFocus() then
		hiddenByWindow = true -- a window is open: show up when it closes
	else
		showHud()
	end
end

local function onUpdate(update: { [string]: any })
	if typeof(update.AutoRepeat) == "boolean" then
		autoRepeat = update.AutoRepeat
		updateRepeat()
	end
	if typeof(update.Difficulty) == "string" and SpireConfig.Difficulties[update.Difficulty] ~= nil then
		difficulty = update.Difficulty
	end
	if update.Phase == "Board" then
		SpireController.OnBoard(update)
		return
	end
	if update.Phase == "State" then
		SpireController.RefreshPicker()
		if mode ~= "Fight" then
			record = recordOf(difficulty)
			setFloorBadge(format(words.Best, { record = record }), false)
		end
		return
	end
	if update.Phase == "Ended" and not HudLayout.HasFocus() then
		hiddenByWindow = false
	end
	if not hiddenByWindow then
		showHud()
	end
	climbing = update.Phase ~= "Ended"
	record = update.Record or record
	recordLabel.Text = format(words.DifficultyRecord, { difficulty = difficultyName(difficulty), record = record })
		.. (if update.Haste == true then ` · {words.HasteTag}` else "")
	local phase = update.Phase
	if phase == "Fight" then
		setFloorBadge(format(words.Floor, { floor = update.Floor }), update.Boss == true)
		local mutation = Mutations.Get(update.MutationId)
		local dragonName = if mutation.Id ~= Mutations.NormalId then `{mutation.Name} {update.Dragon}` else update.Dragon
		setPortrait(mine, update.SpeciesId, update.Level, dragonName)
		setPortrait(enemy, update.EnemyId, math.max(1, update.Floor), update.Enemy)
		playerWins = update.Power >= update.EnemyPower
		local stronger = math.max(update.Power, update.EnemyPower, 1)
		powerRatio = math.min(0.85, math.min(update.Power, update.EnemyPower) / stronger)
		setBars(1, 1)
		timerStart, timerSeconds = os.clock(), update.Seconds
		setMode("Fight")
	elseif phase == "Won" then
		setBars(if playerWins then 1 - powerRatio else 0, 0)
		timerSeconds = 0
		popChip(update.Floor, update.FirstClear == true)
		flyDrops(update.Reward)
	elseif phase == "Ended" then
		message.Text = if update.Result == "Lost"
			then format(words.Lost, { floor = update.Floor })
			elseif update.Result == "Top" then words.Top
			else words.Stopped
		if update.Result == "Lost" then
			setBars(0, 1)
		end
		setFloorBadge(format(words.Best, { record = record }), false)
		climbButton:SetText(words.Again)
		setMode("Ended")
		SpireController.RefreshPicker()
		if difficulty == SpireConfig.Leaderboard.Difficulty then
			SpireController.RequestBoard() -- your new best floor
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Build

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

local function smallRoundButton(parent: Instance, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Text = text
	b.Font = Theme.Fonts.Title
	b.TextColor3 = Theme.Colors.Text
	b.TextSize = 24
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Gradient(b, Style.Shade(color, 0.2), Style.Shade(color, -0.25))
	Style.Round(b)
	Style.GoldBorder(b, 2.5)
	Style.Outline(b, 1.5)
	Style.AttachPress(b)
	b.Parent = parent
	return b
end

---------------------------------------------------------------------------------------------------------------
-- Difficulty picker + weekly board

-- Which difficulty is shown as picked / unlocked / locked.
function SpireController.RefreshPicker()
	local data = DataController:Get()
	if data == nil then
		return
	end
	local picked = if climbing then difficulty else data.SpireDifficulty
	for id, button in pickerButtons do
		local unlocked = DragonStats.IsDifficultyUnlocked(data, id)
		button:SetEnabled(unlocked)
		if unlocked then
			button:SetKind(if id == picked then "Confirm" else "Neutral")
		end
		pickerCovers[id].Visible = not unlocked
	end
end

local flashToken = 0
local readyMessage = ""

-- Says what unlocks a greyed difficulty (in the message line, for a few seconds).
function SpireController.FlashLocked(id: string)
	local def = SpireConfig.Difficulties[id]
	local from = def and def.UnlockFrom
	if from == nil then
		return
	end
	if flashToken == 0 then
		readyMessage = message.Text
	end
	flashToken += 1
	local token = flashToken
	message.Text = format(words.Locked, { difficulty = difficultyName(from), floor = SpireConfig.Difficulties[from].MaxFloors })
	task.delay(3, function()
		if flashToken == token then
			flashToken = 0
			message.Text = readyMessage
		end
	end)
end

function SpireController.Pick(id: string)
	local data = DataController:Get()
	if climbing or data == nil or not DragonStats.IsDifficultyUnlocked(data, id) then
		return
	end
	difficulty = id
	record = recordOf(id)
	setFloorBadge(format(words.Best, { record = record }), false)
	for other, button in pickerButtons do
		if DragonStats.IsDifficultyUnlocked(data, other) then
			button:SetKind(if other == id then "Confirm" else "Neutral")
		end
	end
	spireAction:FireServer("Difficulty", id)
	if id == SpireConfig.Leaderboard.Difficulty then
		SpireController.RequestBoard()
	end
end

function SpireController.RequestBoard()
	lastBoardRequest = os.clock()
	spireAction:FireServer("Board")
end

local function boardRowCount(): number
	return if phone then SpireConfig.Leaderboard.PhoneRows else SpireConfig.Leaderboard.TopCount
end

function SpireController.BuildBoard()
	local sizes = Theme.Sizes
	boardPanel = Instance.new("Frame")
	boardPanel.Name = "SpireBoard"
	boardPanel.AnchorPoint = Vector2.new(0, 1)
	boardPanel.Position = UDim2.new(1, 14, 1, 0) -- beside the HUD (a child of it, so it scales with it and hides with it)
	boardPanel.Size = UDim2.fromOffset(sizes.SpireBoard.X, sizes.SpireBoard.Y)
	boardPanel.Visible = false
	Style.PanelLook(boardPanel, 4)
	boardPanel.Parent = hud
	local scale = Instance.new("UIScale")
	scale.Name = "BoardScale"
	scale.Parent = boardPanel
	boardTitle = Style.Label(boardPanel, words.Board.Title, "Title", 22, Theme.Colors.Title)
	boardTitle.Position = UDim2.fromOffset(10, 8)
	boardTitle.Size = UDim2.new(1, -20, 0, 26)
	boardTitle.ZIndex = 3
	Style.Outline(boardTitle, 2)
	boardReset = Style.Label(boardPanel, "", "Bold", 13, Theme.Colors.TextMuted)
	boardReset.Position = UDim2.fromOffset(10, 34)
	boardReset.Size = UDim2.new(1, -20, 0, 16)
	boardReset.ZIndex = 3
	for index = 1, SpireConfig.Leaderboard.TopCount do
		local row = Instance.new("Frame")
		row.Name = `Row{index}`
		row.BackgroundColor3 = Theme.Colors.Gold
		row.BackgroundTransparency = 1
		row.Visible = false -- shown by renderBoard for the rows the server sent
		row.Position = UDim2.fromOffset(8, 54 + (index - 1) * sizes.SpireBoardRow)
		row.Size = UDim2.new(1, -16, 0, sizes.SpireBoardRow - 2)
		row.ZIndex = 3
		Style.Round(row)
		row.Parent = boardPanel
		local rank = Style.Label(row, tostring(index), "Title", 15, Theme.Colors.Title)
		rank.Size = UDim2.new(0, 26, 1, 0)
		rank.ZIndex = 4
		local name = Style.Label(row, "", "Bold", 15, Theme.Colors.Text)
		name.Position = UDim2.fromOffset(30, 0)
		name.Size = UDim2.new(1, -86, 1, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.ZIndex = 4
		local floor = Style.Label(row, "", "Title", 15, Theme.Colors.Title)
		floor.AnchorPoint = Vector2.new(1, 0)
		floor.Position = UDim2.fromScale(1, 0)
		floor.Size = UDim2.new(0, 54, 1, 0)
		floor.TextXAlignment = Enum.TextXAlignment.Right
		floor.ZIndex = 4
		boardRows[index] = { Row = row, Rank = rank, Name = name, Floor = floor }
	end
	boardEmpty = Style.Label(boardPanel, words.Board.Empty, "Bold", 15, Theme.Colors.TextMuted)
	boardEmpty.Position = UDim2.fromOffset(10, 70)
	boardEmpty.Size = UDim2.new(1, -20, 0, 24)
	boardEmpty.ZIndex = 3
	boardMine = Style.Label(boardPanel, "", "Title", 16, Theme.Colors.Text)
	boardMine.AnchorPoint = Vector2.new(0, 1)
	boardMine.Position = UDim2.new(0, 10, 1, -8)
	boardMine.Size = UDim2.new(1, -20, 0, 20)
	boardMine.ZIndex = 3
	Style.Outline(boardMine, 1.5)
end

-- Draws the last board the server sent.
local function renderBoard()
	local board = lastBoard
	if board == nil then
		return
	end
	local entries: { any } = board.Entries or {}
	local shown = boardRowCount()
	for index, row in boardRows do
		local entry = entries[index]
		local visible = entry ~= nil and index <= shown
		row.Row.Visible = visible
		if visible then
			row.Rank.Text = tostring(entry.Rank)
			row.Name.Text = entry.Name
			row.Floor.Text = format(words.Board.Floor, { floor = entry.Score })
			local mineRow = entry.UserId == Players.LocalPlayer.UserId
			row.Row.BackgroundTransparency = if mineRow then 0.72 else 1
			row.Name.TextColor3 = if mineRow then Theme.Colors.Title else Theme.Colors.Text
		end
	end
	boardEmpty.Visible = #entries == 0
	boardReset.Text = (if board.Offline == true then `{words.Board.Offline} · ` else "") .. format(words.Board.Reset, { time = formatDuration(board.SecondsLeft or 0) })
	boardMine.Text = if (board.MyBest or 0) > 0 then format(words.Board.Mine, { floor = board.MyBest }) else words.Board.MineNone
end

function SpireController.OnBoard(update: { [string]: any })
	lastBoard = update
	renderBoard()
end

-- Beside the HUD, only with Infinite picked and the HUD open; as tall as its rows (at least 3).
function SpireController.LayoutBoard()
	local show = difficulty == SpireConfig.Leaderboard.Difficulty and hud.Visible
	boardPanel.Visible = show
	if not show then
		return
	end
	local sizes = Theme.Sizes
	local scale = boardPanel:FindFirstChild("BoardScale") :: UIScale
	scale.Scale = if phone then 1.15 else 1 -- phones: the HUD is at 0.6, keep the rows readable
	local count = if lastBoard and lastBoard.Entries then #lastBoard.Entries else 0
	local rows = math.clamp(count, 3, boardRowCount())
	boardPanel.Size = UDim2.fromOffset(sizes.SpireBoard.X, 54 + rows * sizes.SpireBoardRow + 34)
	renderBoard()
end

function SpireController:Init()
	local sizes = Theme.Sizes
	gui = HudLayout.MakeScreenGui("Spire", "Cards")

	hud = Instance.new("Frame")
	hud.Name = "SpireHud"
	hud.AnchorPoint = Vector2.new(0.5, 1)
	hud.Position = UDim2.new(0.5, 0, 1, -16)
	hud.Size = UDim2.fromOffset(sizes.SpireHud.X, sizes.SpireHud.Y)
	hud.Visible = false
	Style.PanelLook(hud, 4)
	hud.Parent = gui
	hudScale = Instance.new("UIScale")
	hudScale.Parent = hud

	-- the big floor badge on the top edge, the BOSS tag beside it, the record small under it
	local badge = Instance.new("Frame")
	badge.Name = "FloorBadge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.5, 0)
	badge.Size = UDim2.fromOffset(sizes.SpireFloorBadge.X, sizes.SpireFloorBadge.Y)
	badge.BackgroundColor3 = Color3.new(1, 1, 1)
	badge.ZIndex = 5
	Style.Gradient(badge, Style.Shade(Theme.Colors.BannerTop, 0.15), Style.Shade(Theme.Colors.BannerTop, -0.35))
	Style.Round(badge)
	Style.GoldBorder(badge, 3)
	Style.Glow(badge, Theme.Colors.BannerTop, 14, 0.5, 4)
	badge.Parent = hud
	floorLabel = Style.Label(badge, "", "Title", 28, Theme.Colors.Title)
	floorLabel.Size = UDim2.new(1, -16, 1, -6)
	floorLabel.Position = UDim2.fromOffset(8, 4)
	floorLabel.TextScaled = true
	floorLabel.ZIndex = 6
	Style.Outline(floorLabel, 2.5)
	local floorLimit = Instance.new("UITextSizeConstraint")
	floorLimit.MaxTextSize = 30
	floorLimit.Parent = floorLabel
	bossTag = Style.Label(badge, words.Boss, "Title", 18, Theme.Colors.TextStroke)
	bossTag.AnchorPoint = Vector2.new(0, 0.5)
	bossTag.Position = UDim2.new(1, -8, 0.5, 0)
	bossTag.Size = UDim2.fromOffset(66, 28)
	bossTag.BackgroundColor3 = Color3.new(1, 1, 1)
	bossTag.BackgroundTransparency = 0
	bossTag.ZIndex = 7
	bossTag.Rotation = 8
	Style.Gradient(bossTag, Theme.Colors.Title, Style.Shade(Theme.Colors.Primary, -0.2))
	Style.Round(bossTag)
	Style.GoldBorder(bossTag, 2)
	bossTag.Visible = false
	recordLabel = Style.Label(hud, "", "Title", 14, Theme.Colors.TextMuted)
	recordLabel.AnchorPoint = Vector2.new(0.5, 0)
	recordLabel.Position = UDim2.new(0.5, 0, 0, 26)
	recordLabel.Size = UDim2.fromOffset(240, 16)
	recordLabel.ZIndex = 3
	Style.Outline(recordLabel, 1.2)

	mine = makePortrait(hud, Theme.Colors.Confirm, 0)
	enemy = makePortrait(hud, Theme.Colors.Cancel, 1)

	vsLabel = Icon.new(hud, "VS", Theme.Colors.Title, words.Vs)
	vsLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	vsLabel.Position = UDim2.new(0.5, 0, 0, 68)
	vsLabel.Size = UDim2.fromOffset(64, 64)
	vsLabel.ZIndex = 4
	vsLabel.Rotation = -6

	-- between climbs / while zooming up: a message, a progress bar, the buttons
	local portraitRight = 12 + sizes.SpirePortrait + 12
	message = Style.Label(hud, "", "Title", 22, Theme.Colors.Text)
	message.Position = UDim2.fromOffset(portraitRight, 26)
	message.Size = UDim2.new(1, -(portraitRight + 16), 0, 30)
	message.TextScaled = true
	message.ZIndex = 3
	Style.Outline(message, 2)
	local messageLimit = Instance.new("UITextSizeConstraint")
	messageLimit.MaxTextSize = 22
	messageLimit.Parent = message
	Tooltip.Attach(message, function()
		return Text.SpireStuckTip
	end)

	local row = Instance.new("Frame")
	buttonRow = row
	row.Name = "Buttons"
	row.AnchorPoint = Vector2.new(0, 1)
	row.Position = UDim2.new(0, portraitRight, 1, -12)
	row.Size = UDim2.new(1, -(portraitRight + 16), 0, 42)
	row.BackgroundTransparency = 1
	row.ZIndex = 3
	row.Parent = hud
	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.Padding = UDim.new(0, 8)
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Parent = row
	climbButton = Button.new(row, { Text = words.Climb, Kind = "Confirm", TextSize = 22, OnClick = function()
		spireAction:FireServer("Start")
	end })
	climbButton.Instance.LayoutOrder = 1
	repeatButton = Button.new(row, { Text = words.AutoRepeatOff, Kind = "Neutral", TextSize = 18, OnClick = function()
		spireAction:FireServer("AutoRepeat", not autoRepeat)
	end })
	repeatButton.Instance.LayoutOrder = 2
	repeatButton.Instance.Size = UDim2.new(0.5, -4, 0, 42)

	stopButton = Button.new(hud, { Text = words.Stop, Kind = "Cancel", TextSize = 16, OnClick = function()
		spireAction:FireServer("Stop")
	end })
	stopButton.Instance.Size = UDim2.fromOffset(92, 34)
	stopButton.Instance.ZIndex = 4

	-- difficulty picker: four buttons in a row between the message and Climb
	pickerRow = Instance.new("Frame")
	pickerRow.Name = "Difficulty"
	pickerRow.BackgroundTransparency = 1
	pickerRow.Position = UDim2.fromOffset(portraitRight, 70)
	pickerRow.Size = UDim2.new(1, -(portraitRight + 16), 0, 44)
	pickerRow.ZIndex = 3
	pickerRow.Parent = hud
	local pickerList = Instance.new("UIListLayout")
	pickerList.FillDirection = Enum.FillDirection.Horizontal
	pickerList.Padding = UDim.new(0, 8)
	pickerList.SortOrder = Enum.SortOrder.LayoutOrder
	pickerList.Parent = pickerRow
	for order, id in SpireConfig.Difficulties.Order do
		local button = Button.new(pickerRow, { Text = difficultyName(id), Kind = "Neutral", TextSize = 18, OnClick = function()
			SpireController.Pick(id)
		end })
		button.Instance.LayoutOrder = order
		button.Instance.Size = UDim2.new(0.25, -6, 1, 0)
		button.Instance.ZIndex = 4
		pickerButtons[id] = button
		-- a greyed button still answers a tap with what unlocks it (touch has no hover)
		local cover = Instance.new("TextButton")
		cover.Name = "LockCover"
		cover.BackgroundTransparency = 1
		cover.Text = ""
		cover.Size = UDim2.fromScale(1, 1)
		cover.ZIndex = 12
		cover.Visible = false
		cover.Parent = button.Instance
		cover.Activated:Connect(function()
			SpireController.FlashLocked(id)
		end)
		pickerCovers[id] = cover
	end
	SpireController.BuildBoard()

	-- Hide: a small round button on the top-right corner; the HUD shrinks into the mini floor badge
	local hide = smallRoundButton(hud, "–", Theme.Colors.Neutral)
	hide.Name = "Hide"
	hide.AnchorPoint = Vector2.new(0.5, 0.5)
	hide.Position = UDim2.new(1, -6, 0, 6)
	hide.Size = UDim2.fromOffset(32, 32)
	hide.ZIndex = 8
	hide.Activated:Connect(function()
		minimized = true
		showHud()
	end)

	mini = smallRoundButton(gui, "", Theme.Colors.BannerTop)
	mini.Name = "SpireMini"
	mini.AnchorPoint = Vector2.new(0.5, 1)
	mini.Position = UDim2.new(0.5, 0, 1, -16)
	mini.Size = UDim2.fromOffset(sizes.SpireMini.X, sizes.SpireMini.Y)
	mini.Visible = false
	local miniIcon = Icon.new(mini, Theme.ShopIcons.ElevatorPass)
	miniIcon.AnchorPoint = Vector2.new(0, 0.5)
	miniIcon.Position = UDim2.new(0, -10, 0.5, 0)
	miniIcon.Size = UDim2.fromScale(1.2, 1.2)
	local miniRatio = Instance.new("UIAspectRatioConstraint")
	miniRatio.Parent = miniIcon
	miniIcon.ZIndex = 3
	miniLabel = Style.Label(mini, "", "Title", 22, Theme.Colors.Title)
	miniLabel.Position = UDim2.fromScale(0.3, 0)
	miniLabel.Size = UDim2.fromScale(0.66, 1)
	miniLabel.TextScaled = true
	miniLabel.ZIndex = 3
	Style.Outline(miniLabel, 2)
	local miniLimit = Instance.new("UITextSizeConstraint")
	miniLimit.MaxTextSize = 22
	miniLimit.Parent = miniLabel
	mini.Activated:Connect(function()
		minimized = false
		showHud()
	end)

	-- The HUD is a station panel: showing it closes other windows, and opening a window hides it (it comes back when
	-- that window closes, mid-climb).
	local function onWindow()
		hideAll()
		hiddenByWindow = true
	end
	HudLayout.TrackPanel(hud, onWindow)
	HudLayout.OnFocusCleared(function()
		if hiddenByWindow and (climbing or near) then
			hiddenByWindow = false
			showHud()
		end
	end)

	-- Phones: the same HUD, smaller, still bottom center (between the thumbstick and the jump button).
	HudLayout.OnLayoutChanged(function(isPhone)
		phone = isPhone
		local safe = HudLayout.GetUsableRect()
		if safe.Width <= Layout.SafeMargin * 2 or safe.Height <= 0 then return end
		hudScale.Scale = math.max(0.1, math.min(if isPhone then sizes.PhoneSpireScale else 1, (safe.Width - Layout.SafeMargin * 2) / sizes.SpireHud.X))
		hud.Size = UDim2.fromOffset(sizes.SpireHud.X, if isPhone then sizes.PhoneSpireHudHeight else sizes.SpireHud.Y)
		hud.Position = UDim2.new(0.5, 0, 1, if isPhone then -6 else -16)
		mini.Position = UDim2.new(0.5, 0, 1, if isPhone then -6 else -16)
		mini.Size = UDim2.fromOffset(math.floor(sizes.SpireMini.X * hudScale.Scale), math.floor(sizes.SpireMini.Y * hudScale.Scale))
		setMode(mode)
	end)

	spireUpdate.OnClientEvent:Connect(onUpdate)
	setMode("Ready")
	task.spawn(function()
		DataController:WaitForData()
		SpireController.RefreshPicker()
		for _, key in { "SpireDifficulty", "SpireRecords" } do
			DataController:OnChanged(key, function()
				SpireController.RefreshPicker()
				if mode ~= "Fight" then
					local data = DataController:Get()
					if data and SpireConfig.Difficulties[data.SpireDifficulty] ~= nil then
						difficulty = data.SpireDifficulty
					end
					record = recordOf(difficulty)
					setFloorBadge(format(words.Best, { record = record }), false)
				end
			end)
		end
	end)
end

function SpireController:Start()
	local lastHit = 0
	local hitter = 0
	RunService.RenderStepped:Connect(function()
		if timerSeconds <= 0 then
			return
		end
		local t = math.clamp((os.clock() - timerStart) / timerSeconds, 0, 1)
		if mode ~= "Fight" or not hud.Visible then
			return
		end
		local winner, loser = 1 - t * powerRatio, 1 - t
		if playerWins then
			setBars(winner, loser)
		else
			setBars(loser, winner)
		end
		-- a little back-and-forth: the attacker lunges toward the middle, the defender flinches
		if timerSeconds >= 2 and not EffectsQuality.IsLow() and os.clock() - lastHit >= Theme.Motion.SpireHit then
			lastHit = os.clock()
			hitter = 1 - hitter
			local attacker = if hitter == 0 then mine else enemy
			local defender = if hitter == 0 then enemy else mine
			local lunge = if hitter == 0 then 12 else -12
			tween(attacker.Card, 0.12, { Position = UDim2.fromOffset(lunge, -4) })
			task.delay(0.14, function()
				tween(attacker.Card, 0.2, { Position = UDim2.fromOffset(0, 0) })
			end)
			local flinch = defender.Card:FindFirstChildOfClass("UIScale")
			if flinch then
				flinch.Scale = 0.9
				tween(flinch, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
	end)
	-- Show the ready HUD on arrival at the Spire; hide it on leaving (unless a climb is going).
	local wasNear = false
	while true do
		near = isNearSpire()
		if near and not wasNear and not climbing then
			showReady()
		elseif not near and wasNear then
			minimized = false
			hiddenByWindow = false
			if not climbing then
				hideAll()
			end
		end
		wasNear = near
		-- the weekly board: asked for while the HUD shows with Infinite picked
		local wantBoard = difficulty == SpireConfig.Leaderboard.Difficulty and (hud.Visible or mini.Visible)
		if wantBoard and os.clock() - lastBoardRequest >= SpireConfig.Leaderboard.RefreshSeconds then
			SpireController.RequestBoard()
		end
		SpireController.LayoutBoard()
		task.wait(0.5)
	end
end

return SpireController
