--!strict
-- Rebirth HUD icon (HudLayout: gold glow + READY! when the player can afford it, else a progress ring toward the
-- next rebirth) and a confirm window (UI/Window): a big "★ Rebirth N" heading, a cost card with the gold icon (and a
-- bar toward the cost while it's not affordable), reward chips (income bonus, level cap, a new area when this rebirth
-- unlocks one), one short line on what is kept, and big Rebirth! / Not yet buttons. Wording in Config/Text.Rebirth.
-- The server decides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local Button = require(script.Parent.UI.Button)
local ProgressBar = require(script.Parent.UI.ProgressBar)
local Window = require(script.Parent.UI.Window)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local requestRebirth = ReplicatedStorage.Remotes.RequestRebirth :: RemoteEvent

local RebirthController = {}

local words = Text.Rebirth
local colors = UITheme.Colors

local button: TextButton
local window: Window.Window
local heading: TextLabel
local costCard: Frame
local costLabel: TextLabel
local haveLabel: TextLabel
local costBar: ProgressBar.ProgressBar
local chips: Frame
local keeps: TextLabel
local confirm: Button.Button

type Chip = { Frame: Frame, Value: TextLabel }
local chipByKey: { [string]: Chip } = {}

local function makeChip(key: string, order: number, icon: string, title: string, color: Color3): Chip
	local chip = Instance.new("Frame")
	chip.Name = key
	chip.LayoutOrder = order
	chip.Size = UDim2.new(0.5, -5, 1, 0)
	Style.CardLook(chip)
	chip.Parent = chips
	local image = Icon.new(chip, icon, color)
	image.AnchorPoint = Vector2.new(0, 0.5)
	image.Position = UDim2.new(0, 8, 0.5, 0)
	image.Size = UDim2.fromScale(0.62, 0.62)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = image
	local name = Style.Label(chip, title, "Bold", 14, colors.TextMuted)
	name.Position = UDim2.new(0.3, 0, 0.1, 0)
	name.Size = UDim2.new(0.68, 0, 0.35, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local value = Style.Label(chip, "", "Title", 20, color)
	value.Position = UDim2.new(0.3, 0, 0.45, 0)
	value.Size = UDim2.new(0.68, 0, 0.45, 0)
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextScaled = true
	value.TextStrokeTransparency = 0
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 22
	limit.Parent = value
	local entry = { Frame = chip, Value = value }
	chipByKey[key] = entry
	return entry
end

local function refresh()
	local data = DataController:Get()
	if data == nil then
		return
	end
	local cost = DragonStats.GetRebirthCost(data.Rebirths)
	local next = data.Rebirths + 1
	if data.Rebirths > 0 then
		HudLayout.SetMenuText("Rebirth", `Rebirth ★{data.Rebirths}`, `★{data.Rebirths}`)
	end

	-- HUD: "ready" (gold glow, hop, sparkles, READY!) when affordable; otherwise calm with a progress ring
	local atCap = DragonStats.IsAtRebirthCap(data)
	local ready = not atCap and data.Gold >= cost
	HudLayout.SetReady("Rebirth", ready)
	HudLayout.SetProgress("Rebirth", if atCap or ready then nil else math.clamp(data.Gold / cost, 0, 1))

	if atCap then
		heading.Text = `★ {words.CapHeading}`
		costCard.Visible = false
		chips.Visible = false
		keeps.Text = words.CapInfo
		confirm:SetText(words.CapButton)
		confirm:SetEnabled(false)
		return
	end
	costCard.Visible = true
	chips.Visible = true

	heading.Text = "★ " .. Text.Format(words.Heading, { n = next })
	costLabel.Text = Text.Format(words.Cost, { cost = Format.Number(cost) })
	haveLabel.Text = Text.Format(words.Have, { gold = Format.Number(data.Gold) })
	local affordable = data.Gold >= cost
	costBar.Instance.Visible = not affordable
	if not affordable then
		costBar:Set(math.clamp(data.Gold / cost, 0, 1), `{math.floor(math.clamp(data.Gold / cost, 0, 1) * 100)}%`)
	end

	chipByKey.Income.Value.Text = `{Format.Multiplier(DragonStats.GetRebirthBonus(data.Rebirths))} → {Format.Multiplier(DragonStats.GetRebirthBonus(next))}`
	local capNow = DragonStats.GetLevelCap(data)
	chipByKey.LevelCap.Value.Text = `{capNow} → {capNow + Leveling.CapPerRebirth}`
	local unlocks = {}
	for _, area in Areas do
		if area.RebirthsRequired == next then
			table.insert(unlocks, area.Name)
		end
	end
	local area = chipByKey.Unlocks
	area.Frame.Visible = #unlocks > 0
	area.Value.Text = table.concat(unlocks, ", ")
	local shown = if #unlocks > 0 then 3 else 2
	for _, chip in chipByKey do
		chip.Frame.Size = UDim2.new(1 / shown, -10 * (shown - 1) / shown, 1, 0)
	end
	keeps.Text = words.Keeps

	confirm:SetText(if affordable then words.Confirm else words.NotEnough)
	confirm:SetEnabled(affordable)
end

function RebirthController:Init()
	button = HudLayout.AddMenuButton("Rebirth")
	window = Window.new({
		Name = "Rebirth",
		Title = "Rebirth",
		Icon = "Menu_Rebirth",
		Size = UDim2.new(0.9, 0, 0.9, 0), -- height scales with the screen, up to MaxSize
		MaxSize = Vector2.new(520, 420),
	})
	local content = window.Content

	local column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.Size = UDim2.new(1, 0, 1, -60)
	column.Parent = content
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = column

	heading = Style.Label(column, "", "Title", 32, colors.Title)
	heading.LayoutOrder = 1
	heading.Size = UDim2.new(1, 0, 0, 38)
	heading.TextStrokeTransparency = 0

	costCard = Instance.new("Frame")
	costCard.Name = "Cost"
	costCard.LayoutOrder = 2
	costCard.Size = UDim2.new(1, 0, 0, 66)
	Style.CardLook(costCard, colors.Gold)
	costCard.Parent = column
	local gold = Icon.new(costCard, "Gold", colors.Gold)
	gold.AnchorPoint = Vector2.new(0, 0.5)
	gold.Position = UDim2.new(0, 14, 0.5, 0)
	gold.Size = UDim2.fromOffset(48, 48)
	costLabel = Style.Label(costCard, "", "Title", 28, colors.Gold)
	costLabel.Position = UDim2.fromOffset(72, 6)
	costLabel.Size = UDim2.new(1, -84, 0, 32)
	costLabel.TextXAlignment = Enum.TextXAlignment.Left
	costLabel.TextStrokeTransparency = 0
	haveLabel = Style.Label(costCard, "", "Bold", 15, colors.TextMuted)
	haveLabel.Position = UDim2.fromOffset(72, 38)
	haveLabel.Size = UDim2.new(0.45, -72, 0, 20)
	haveLabel.TextXAlignment = Enum.TextXAlignment.Left
	costBar = ProgressBar.new(costCard, colors.Gold)
	costBar.Instance.AnchorPoint = Vector2.new(1, 0)
	costBar.Instance.Position = UDim2.new(1, -12, 0, 40)
	costBar.Instance.Size = UDim2.new(0.5, 0, 0, 16)

	chips = Instance.new("Frame")
	chips.Name = "Rewards"
	chips.LayoutOrder = 3
	chips.BackgroundTransparency = 1
	chips.Size = UDim2.new(1, 0, 0, 64)
	chips.Parent = column
	local chipList = Instance.new("UIListLayout")
	chipList.FillDirection = Enum.FillDirection.Horizontal
	chipList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	chipList.Padding = UDim.new(0, 10)
	chipList.SortOrder = Enum.SortOrder.LayoutOrder
	chipList.Parent = chips
	makeChip("Income", 1, "Gold", words.Income, colors.Positive)
	makeChip("LevelCap", 2, "Menu_Dragons", words.LevelCap, colors.Info)
	makeChip("Unlocks", 3, "Travel_Portals", words.Unlocks, colors.Title)

	keeps = Style.Label(column, "", "Bold", 15, colors.TextMuted)
	keeps.LayoutOrder = 4
	keeps.Size = UDim2.new(1, -20, 0, 40)
	keeps.TextWrapped = true

	confirm = Button.new(content, {
		Text = words.Confirm,
		Kind = "Confirm",
		Icon = "Menu_Rebirth",
		Sound = "Confirm",
		TextSize = 22,
		OnClick = function()
			local data = DataController:Get()
			if data and data.Gold >= DragonStats.GetRebirthCost(data.Rebirths) then
				requestRebirth:FireServer()
				window:Close()
			end
		end,
	})
	confirm.Instance.AnchorPoint = Vector2.new(0, 1)
	confirm.Instance.Position = UDim2.new(0, 0, 1, 0)
	confirm.Instance.Size = UDim2.new(0.6, -6, 0, 52)

	local cancel = Button.new(content, {
		Text = words.Cancel,
		Kind = "Cancel",
		TextSize = 20,
		OnClick = function()
			window:Close()
		end,
	})
	cancel.Instance.AnchorPoint = Vector2.new(1, 1)
	cancel.Instance.Position = UDim2.new(1, 0, 1, 0)
	cancel.Instance.Size = UDim2.new(0.4, -6, 0, 52)

	HudLayout.OnLayoutChanged(function(phone)
		heading.TextSize = if phone then 24 else 32
		heading.Size = UDim2.new(1, 0, 0, if phone then 28 else 38)
		costCard.Size = UDim2.new(1, 0, 0, if phone then 56 else 66)
		chips.Size = UDim2.new(1, 0, 0, if phone then 54 else 64)
		confirm.Instance.Size = UDim2.new(0.6, -6, 0, if phone then 42 else 52)
		cancel.Instance.Size = UDim2.new(0.4, -6, 0, if phone then 42 else 52)
		column.Size = UDim2.new(1, 0, 1, if phone then -48 else -60)
	end)

	button.Activated:Connect(function()
		refresh()
		window:Toggle()
	end)

	DataController:OnChanged("Gold", refresh)
	DataController:OnChanged("Rebirths", refresh)
end

return RebirthController
