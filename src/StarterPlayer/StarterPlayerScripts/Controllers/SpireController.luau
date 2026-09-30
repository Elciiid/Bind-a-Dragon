--!strict
-- Dragon Spire battle HUD (UI renewal part 2), bottom center, following the server's climb (SpireUpdate):
--  * a big floor badge on the top edge ("Floor 40", a gold BOSS tag on boss floors) with the record small under it;
--  * your dragon's portrait vs the enemy's (VS in the middle), each with a health bar that drains over the fight
--    (the server already decided the winner: the stronger dragon; the bars only show it);
--  * no text log: each cleared floor pops a "Floor 39 cleared!" chip that fades (first clears sparkle), and the drops
--    fly as small icons into the Inventory button;
--  * Stop = a small rose button; Hide (–) minimizes the HUD to a small floor badge (tap it to open again).
-- Between climbs, near the Spire: your best dragon with Climb / Elevator (Tower Elevator pass or an Elevator Skip:
-- starts above the record). Floor clears never use the toast queue. Sizes/motion in UITheme, words in Text.Spire.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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

local spireAction = ReplicatedStorage.Remotes.SpireAction :: RemoteEvent
local spireUpdate = ReplicatedStorage.Remotes.SpireUpdate :: RemoteEvent

local words = Text.Spire

type Portrait = { Root: Frame, Card: Frame, Holder: Frame, Name: TextLabel, Fill: Frame, Key: string }
type Mode = "Ready" | "Fast" | "Fight" | "Ended"

local SpireController = {}

local gui: ScreenGui
local hud: Frame
local hudScale: UIScale
local mini: TextButton
local miniLabel: TextLabel
local floorLabel: TextLabel
local bossTag: TextLabel
local recordLabel: TextLabel
local vsLabel: TextLabel
local message: TextLabel
local fastTrack: Frame
local fastFill: Frame
local mine: Portrait
local enemy: Portrait
local stopButton: Button.Button
local climbButton: Button.Button
local elevatorButton: Button.Button
local chip: TextLabel? = nil

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

local function updateElevator()
	local data = DataController:Get()
	local hasPass = Players.LocalPlayer:GetAttribute("Pass_ElevatorPass") == true
	local skips = if data then data.ElevatorSkips else 0
	elevatorButton.Instance.Visible = climbButton.Instance.Visible
		and (hasPass or skips > 0)
		and record > 0
		and record < SpireConfig.MaxFloors
	elevatorButton:SetText(if hasPass
		then format(words.Elevator, { floor = record + 1 })
		else format(words.ElevatorLeft, { floor = record + 1, n = skips }))
	-- Climb fills the row alone, or shares it with the Elevator
	climbButton.Instance.Size = UDim2.new(if elevatorButton.Instance.Visible then 0.5 else 1, -4, 0, 42)
end

local function setFloorBadge(text: string, boss: boolean)
	floorLabel.Text = text
	bossTag.Visible = boss
	miniLabel.Text = text
end

local function setMode(newMode: Mode)
	mode = newMode
	local fighting = newMode == "Fight"
	enemy.Root.Visible = fighting
	vsLabel.Visible = fighting
	recordLabel.Visible = fighting
	message.Visible = not fighting
	fastTrack.Visible = newMode == "Fast"
	stopButton.Instance.Visible = fighting or newMode == "Fast"
	climbButton.Instance.Visible = newMode == "Ready" or newMode == "Ended"
	-- the Stop button: under VS in a fight, bottom-right while zooming up
	stopButton.Instance.AnchorPoint = if fighting then Vector2.new(0.5, 1) else Vector2.new(1, 1)
	stopButton.Instance.Position = if fighting then UDim2.new(0.5, 0, 1, -10) else UDim2.new(1, -14, 1, -10)
	if not fighting then
		timerSeconds = if newMode == "Fast" then timerSeconds else 0
	end
	updateElevator()
end

local function showHud()
	if minimized then
		mini.Visible = true
		hud.Visible = false
	else
		mini.Visible = false
		hud.Visible = true
	end
end

local function hideAll()
	hud.Visible = false
	mini.Visible = false
end

-- Between climbs, near the Spire: your best dragon and Climb / Elevator.
local function showReady()
	local data = DataController:Get()
	record = if data then data.SpireRecord else record
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
	if update.Phase == "Ended" and not HudLayout.HasFocus() then
		hiddenByWindow = false
	end
	if not hiddenByWindow then
		showHud()
	end
	climbing = update.Phase ~= "Ended"
	record = update.Record or record
	recordLabel.Text = format(words.Record, { record = record })
	local phase = update.Phase
	if phase == "Fast" then
		setFloorBadge(format(words.Floors, { from = update.From, to = update.To }), false)
		message.Text = words.Fast
		timerStart, timerSeconds = os.clock(), update.Seconds
		setMode("Fast")
	elseif phase == "Fight" then
		setFloorBadge(format(words.Floor, { floor = update.Floor }), update.Boss == true)
		local mutation = Mutations.Get(update.MutationId)
		local dragonName = if mutation.Id ~= Mutations.NormalId then `{mutation.Name} {update.Dragon}` else update.Dragon
		setPortrait(mine, update.SpeciesId, update.Level, dragonName)
		-- fast fights change enemy every fraction of a second: keep the last picture, just rename
		if update.Fast and enemy.Key ~= "" then
			enemy.Name.Text = update.Enemy
		else
			setPortrait(enemy, update.EnemyId, math.max(1, update.Floor), update.Enemy)
		end
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
	recordLabel.Size = UDim2.fromOffset(160, 16)
	recordLabel.ZIndex = 3
	Style.Outline(recordLabel, 1.2)

	mine = makePortrait(hud, Theme.Colors.Confirm, 0)
	enemy = makePortrait(hud, Theme.Colors.Cancel, 1)

	vsLabel = Style.Label(hud, words.Vs, "Title", 46, Theme.Colors.Title)
	vsLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	vsLabel.Position = UDim2.new(0.5, 0, 0, 68)
	vsLabel.Size = UDim2.fromOffset(110, 50)
	vsLabel.ZIndex = 4
	vsLabel.Rotation = -6
	Style.Outline(vsLabel, 3)

	-- between climbs / while zooming up: a message, a progress bar, the buttons
	local portraitRight = 12 + sizes.SpirePortrait + 12
	message = Style.Label(hud, "", "Title", 22, Theme.Colors.Text)
	message.Position = UDim2.fromOffset(portraitRight, 30)
	message.Size = UDim2.new(1, -(portraitRight + 16), 0, 40)
	message.TextScaled = true
	message.ZIndex = 3
	Style.Outline(message, 2)
	local messageLimit = Instance.new("UITextSizeConstraint")
	messageLimit.MaxTextSize = 24
	messageLimit.Parent = message
	Tooltip.Attach(message, function()
		return Text.SpireStuckTip
	end)
	fastTrack, fastFill = makeBar(hud, Theme.Colors.Trim)
	fastTrack.Position = UDim2.fromOffset(portraitRight, 78)
	fastTrack.Size = UDim2.new(1, -(portraitRight + 16), 0, 14)

	local row = Instance.new("Frame")
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
	elevatorButton = Button.new(row, { Text = "", Kind = "Neutral", TextSize = 18, OnClick = function()
		spireAction:FireServer("Start", true)
	end })
	elevatorButton.Instance.LayoutOrder = 2
	elevatorButton.Instance.Size = UDim2.new(0.5, -4, 0, 42)

	stopButton = Button.new(hud, { Text = words.Stop, Kind = "Cancel", TextSize = 16, OnClick = function()
		spireAction:FireServer("Stop")
	end })
	stopButton.Instance.Size = UDim2.fromOffset(92, 34)
	stopButton.Instance.ZIndex = 4

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
		hudScale.Scale = if isPhone then sizes.PhoneSpireScale else 1
		hud.Position = UDim2.new(0.5, 0, 1, if isPhone then -6 else -16)
		mini.Position = UDim2.new(0.5, 0, 1, if isPhone then -6 else -16)
		mini.Size = UDim2.fromOffset(math.floor(sizes.SpireMini.X * hudScale.Scale), math.floor(sizes.SpireMini.Y * hudScale.Scale))
	end)

	spireUpdate.OnClientEvent:Connect(onUpdate)
	DataController:OnChanged("ElevatorSkips", updateElevator)
	Players.LocalPlayer:GetAttributeChangedSignal("Pass_ElevatorPass"):Connect(updateElevator)
	setMode("Ready")
end

function SpireController:Start()
	local lastHit = 0
	local hitter = 0
	RunService.RenderStepped:Connect(function()
		if timerSeconds <= 0 then
			return
		end
		local t = math.clamp((os.clock() - timerStart) / timerSeconds, 0, 1)
		if mode == "Fast" then
			fastFill.Size = UDim2.fromScale(t, 1)
			return
		end
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
		task.wait(0.5)
	end
end

return SpireController
