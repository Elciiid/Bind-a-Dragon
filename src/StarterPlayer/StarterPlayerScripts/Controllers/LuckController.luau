--!strict
-- At night, near a Star Altar: shows the player's current bind luck with a breakdown of every source (right side, vertically
-- centered; phones draw the same panel smaller), and keeps
-- the altar prompts up to date for this player (offer cost, hidden once they've bound). Styled with the UI kit.
-- Uses Shared/Luck, the same math the server rolls with. A button cycles which luck charge (Config/Boosts) is
-- armed for this bind: none -> each owned charge -> none.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Banner = require(script.Parent.UI.Banner)
local Icon = require(script.Parent.UI.Icon)
local Button = require(script.Parent.UI.Button)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local Format = require(ReplicatedStorage.Shared.Format)
local Luck = require(ReplicatedStorage.Shared.Luck)
local RebirthMilestones = require(ReplicatedStorage.Shared.RebirthMilestones)
local BindingOdds = require(ReplicatedStorage.Shared.BindingOdds)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local Theme = require(ReplicatedStorage.Shared.Config.UITheme)
local LuckConfig = require(ReplicatedStorage.Shared.Config.Luck)

local ALTAR_TAG = "StarAltar"
local SHOW_DISTANCE = LuckConfig.GroupRadius -- show the panel within this many studs of an altar
local UPDATE_INTERVAL = 0.25

local useBoost = ReplicatedStorage.Remotes.UseBoost :: RemoteEvent

local LuckController = {}

local panel: Frame
local title: TextLabel
local details: TextLabel
local pill: Frame -- phone pill (gradient frame holding a transparent button)
local pillButton: TextButton
local active = false -- at an altar at night
local expanded = false -- phone: pill tapped open
local phone = false
local panelScale: UIScale
local rowsFrame: Frame
local luckRows: { { Frame: Frame, Name: TextLabel, Value: TextLabel } } = {}
local armButton: Button.Button

local function getAltarPart(altar: Instance): BasePart?
	return if altar:IsA("BasePart") then altar elseif altar:IsA("Model") then altar.PrimaryPart else nil
end

local function findNearestAltar(position: Vector3): (Instance?, BasePart?)
	local bestAltar, bestPart, bestDistance = nil, nil, SHOW_DISTANCE
	for _, altar in CollectionService:GetTagged(ALTAR_TAG) do
		local part = getAltarPart(altar)
		if part then
			local distance = (part.Position - position).Magnitude
			if distance <= bestDistance then
				bestAltar, bestPart, bestDistance = altar, part, distance
			end
		end
	end
	return bestAltar, bestPart
end

-- Owned luck charges in Config/Boosts order.
local function ownedCharges(data: any): { Boosts.Potion }
	local owned = {}
	for _, potion in Boosts.Potions do
		if potion.Kind == "LuckCharge" and (data.Potions[potion.Id] or 0) > 0 then
			table.insert(owned, potion)
		end
	end
	return owned
end

-- Arms the next owned charge after the armed one; after the last one, disarms.
local function cycleCharge()
	local data = DataController:Get()
	if data == nil then
		return
	end
	local owned = ownedCharges(data)
	local armedIndex = 0
	for index, potion in owned do
		if potion.Id == data.ArmedLuckPotion then
			armedIndex = index
		end
	end
	local nextPotion = owned[armedIndex + 1]
	if nextPotion then
		useBoost:FireServer(nextPotion.Id) -- arms it (replaces the armed one)
	elseif data.ArmedLuckPotion ~= "" then
		useBoost:FireServer(data.ArmedLuckPotion) -- same Id again disarms
	end
end

-- "Favors Volcano Peak" when tonight favors another area (so players know where to go).
local function favoredHint(constellation: { Element: string? }): string
	local areaId = Luck.GetFavoredAreaId(constellation)
	local area = areaId and Areas[areaId]
	return if area then `Tonight favors {area.Name}` else "Tonight favors no area"
end

-- The panel shows whenever the player is at an altar at night, on PC and phone alike (phones draw it smaller).
local function setActive(on: boolean)
	active = on
	pill.Visible = false -- the phone pill is retired: phones show the same panel as PC, scaled down
	panel.Visible = active
	pillButton.Text = `{title.Text}  {if expanded then "-" else "+"}` -- ASCII: the fonts have no arrow glyphs
end

local function update()
	local data = DataController:Get()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local state = Cycle.GetState()
	if data == nil or root == nil or not root:IsA("BasePart") or not state.IsNight then
		setActive(false)
		return
	end

	local altar, part = findNearestAltar(root.Position)
	if altar == nil or part == nil then
		setActive(false)
		return
	end

	local boundTonight = data.LastBindNight == state.NightIndex
	local canBind = not boundTonight or data.EchoSigils > 0
	local offeringCount = Luck.GetOfferingCount(data, state.NightIndex)
	local nextOffering = Luck.GetNextOffering(offeringCount)

	-- Local-only prompt tweaks (the server still validates everything).
	local bindPrompt = part:FindFirstChild("BindPrompt")
	local offerPrompt = part:FindFirstChild("OfferPrompt")
	if bindPrompt and bindPrompt:IsA("ProximityPrompt") then
		bindPrompt.Enabled = canBind
		bindPrompt.ActionText = if boundTonight then `Bind · Echo Sigil ({data.EchoSigils})` else "Bind"
	end
	if offerPrompt and offerPrompt:IsA("ProximityPrompt") then
		offerPrompt.Enabled = not boundTonight and nextOffering ~= nil
		if nextOffering then
			offerPrompt.ActionText = `Offer {nextOffering.Cost} Stardust`
		end
	end

	armButton.Instance.Visible = canBind
	details.Visible = not canBind
	rowsFrame.Visible = canBind
	if not canBind then
		title.Text = "Bound tonight"
		details.Text = "Come back next night to bind again."
		setActive(true)
		return
	end

	local areaId = altar:GetAttribute("AreaId")
	local luck = Luck.Compute(
		if type(areaId) == "string" then areaId else "StarterMeadow",
		state.NightIndex,
		offeringCount,
		Luck.CountPlayersNear(part.Position, LuckConfig.GroupRadius),
		Luck.GetArmedPotionLuck(data),
		RebirthMilestones.GetAscendedLuck(data.Rebirths)
	)
	local areaKey = if type(areaId) == "string" then areaId else "StarterMeadow"
	local area = Areas[areaKey]
	local element = if area and area.Element then area.Element else state.Constellation.Element
	local primordialBase, primordialCurrent = 0, 0
	for _, outcome in BindingOdds.GetPool(areaKey, element, luck.Total) do
		if outcome.MutationId == "Primordial" then
			primordialBase += outcome.BaseProbability
			primordialCurrent += outcome.EffectiveProbability
		end
	end

	local atMax = luck.Total >= (if luck.Potion > 1 then LuckConfig.PotionCap else LuckConfig.Cap)
	title.Text = if atMax
		then Text.Format(Text.LuckPanel.Max, { luck = Format.Multiplier(luck.Total) })
		else Format.Multiplier(luck.Total)
	-- one row per factor: the name left, the multiplier big on the right (factors at x1 are dimmed)
	local lines: { { string } } = {
		{ "Any Primordial", `1/{math.round(1 / primordialBase)} → 1/{math.round(1 / primordialCurrent)}` },
		{ "Area", Format.Multiplier(luck.Area) },
		{ luck.MoonName, Format.Multiplier(luck.Moon) },
		{ state.Constellation.Name, Format.Multiplier(luck.Constellation) },
		if luck.Favored > 1 then { "Favored area", Format.Multiplier(luck.Favored) } else { favoredHint(state.Constellation), "" },
		{ `Stardust {offeringCount}/{#LuckConfig.Offerings}`, Format.Multiplier(luck.Stardust) },
		{ `Group ({luck.GroupSize})`, Format.Multiplier(luck.Group) },
	}
	if luck.Ascended > 1 then
		table.insert(lines, { Text.Milestones.Items.Ascended.Name, Format.Multiplier(luck.Ascended) })
	end
	local armed = Boosts.ById[data.ArmedLuckPotion]
	if luck.Potion > 1 and armed then
		table.insert(lines, { armed.Name, Format.Multiplier(luck.Potion) })
	end
	local owned = ownedCharges(data)
	if #owned == 0 then
		armButton:SetText("No luck potions")
		armButton:SetEnabled(false)
	else
		armButton:SetEnabled(true)
		-- Short texts: the button is one line on a 250 px panel.
		armButton.Label.Text = if luck.Potion > 1 and armed
			then `Armed: {armed.Name} x{data.Potions[armed.Id]}`
			else `Arm a luck potion ({#owned})`
	end
	for index, row in luckRows do
		local line = lines[index]
		row.Frame.Visible = line ~= nil
		if line then
			row.Name.Text = line[1]
			row.Value.Text = line[2]
			local calm = line[2] == "x1" or line[2] == ""
			row.Name.TextColor3 = if calm then Theme.Colors.TextMuted else Theme.Colors.Text
			row.Value.TextColor3 = if calm then Theme.Colors.TextMuted else Theme.Colors.Gold
		end
	end
	setActive(true)
end

function LuckController:Init()
	local gui = HudLayout.MakeScreenGui("Luck", "Cards")
	gui.DisplayOrder += 1 -- the opened panel draws over the boost timers (phones)

	panel = Instance.new("Frame")
	panel.Name = "LuckPanel"
	panel.Size = UDim2.new(0, 250, 0, 240)
	panel.Visible = false
	Style.PanelLook(panel, 5)
	panel.Parent = gui
	local banner = Banner.new(panel, { Text = Text.LuckPanel.Title, Icon = "Stardust" })
	banner.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Holder.Position = UDim2.fromScale(0.5, 0)
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.ZIndex = 2
	inner.Parent = panel

	title = Style.Label(inner, "", "Title", 30, Theme.Colors.Title) -- the total luck, big
	title.Size = UDim2.new(1, 0, 0, 34)
	title.TextScaled = true
	title.TextStrokeTransparency = 0

	details = Style.Label(inner, "", "Bold", 16, Theme.Colors.Text) -- "bound tonight" message
	details.Position = UDim2.new(0, 0, 0, 34)
	details.Size = UDim2.new(1, 0, 1, -72)
	details.TextYAlignment = Enum.TextYAlignment.Top

	rowsFrame = Instance.new("Frame")
	rowsFrame.Name = "Factors"
	rowsFrame.BackgroundTransparency = 1
	rowsFrame.Parent = inner
	local rowsList = Instance.new("UIListLayout")
	rowsList.SortOrder = Enum.SortOrder.LayoutOrder
	rowsList.Parent = rowsFrame
	for index = 1, 9 do
		local row = Instance.new("Frame")
		row.LayoutOrder = index
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 1 / 9, 0)
		row.Parent = rowsFrame
		local name = Style.Label(row, "", "Bold", 15, Theme.Colors.Text)
		name.Size = UDim2.new(0.72, 0, 1, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextWrapped = false
		local value = Style.Label(row, "", "Title", 17, Theme.Colors.Gold)
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.fromScale(1, 0)
		value.Size = UDim2.new(0.28, 0, 1, 0)
		value.TextXAlignment = Enum.TextXAlignment.Right
		Style.Outline(value, 1.5)
		table.insert(luckRows, { Frame = row, Name = name, Value = value })
	end

	armButton = Button.new(inner, { Text = "Arm a luck potion", Kind = "Confirm", TextSize = 15, Icon = "Potion_MoonfireTonic", OnClick = cycleCharge })
	armButton.Instance.AnchorPoint = Vector2.new(0, 1)
	armButton.Instance.Position = UDim2.new(0, 0, 1, 0)
	armButton.Instance.Size = UDim2.new(1, 0, 0, 36)

	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	-- (retired) Phone pill: gradient pill with the Stardust icon; the whole pill is the tap target.
	pill = Instance.new("Frame")
	pill.Name = "LuckPill"
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Visible = false
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Gradient(pill, Theme.Colors.PanelTop, Theme.Colors.PanelBottom)
	Style.Round(pill)
	Style.Stroke(pill, Theme.Colors.Trim, 2)
	pill.Parent = gui
	local pillIcon = Icon.new(pill, "Stardust", Theme.Colors.Stardust)
	pillIcon.AnchorPoint = Vector2.new(0, 0.5)
	pillIcon.Position = UDim2.new(0, -4, 0.5, 0)
	pillIcon.Size = UDim2.fromOffset(32, 32)
	pillButton = Instance.new("TextButton")
	pillButton.Name = "Tap"
	pillButton.Position = UDim2.fromOffset(26, 0)
	pillButton.Size = UDim2.new(1, -32, 1, 0)
	pillButton.TextScaled = true
	Style.Text(pillButton, "Heavy", nil, Theme.Colors.Stardust)
	pillButton.Parent = pill
	Style.AttachPress(pillButton)
	pillButton.Activated:Connect(function()
		expanded = not expanded
		setActive(active)
	end)

	HudLayout.OnLayoutChanged(function(isPhone)
		phone = isPhone
		local sizes = Theme.Sizes
		-- the same panel on PC and phone, right side, scaled down on phones (PC: vertically centered; phones: from the top,
		-- so it never covers the timer stack above the jump button on a short screen)
		panel.AnchorPoint = Vector2.new(1, if isPhone then 0 else 0.5)
		panel.Position = UDim2.new(1, -(if isPhone then sizes.PhoneRightMargin else sizes.RightMargin), if isPhone then 0 else 0.5, if isPhone then sizes.PhoneMargin + 12 else 0) -- + room for the banner hanging over the panel's top edge
		panel.Size = UDim2.fromOffset(260, 270)
		panelScale.Scale = if isPhone then sizes.PhoneLuckPanelScale else 1
		banner:Layout(38, 22, 26)
		inner.Position, inner.Size = UDim2.fromOffset(14, 26), UDim2.new(1, -28, 1, -40)
		title.Size = UDim2.new(1, 0, 0, 34)
		details.Position, details.Size = UDim2.fromOffset(0, 40), UDim2.new(1, 0, 1, -80)
		rowsFrame.Position, rowsFrame.Size = UDim2.fromOffset(0, 40), UDim2.new(1, 0, 1, -86)
		details.TextSize = 16
		armButton.Instance.Size = UDim2.new(1, 0, 0, 36)
		setActive(active)
	end)
end

function LuckController:Start()
	while true do
		update()
		task.wait(UPDATE_INTERVAL)
	end
end

return LuckController
