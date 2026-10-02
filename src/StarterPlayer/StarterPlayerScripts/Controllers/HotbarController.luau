--!strict
-- Dragon Hotbar: ten slots at the bottom center (keys 1-9 and 0, or tap), in the game's own UI style (Roblox's Backpack bar is
-- off). Each slot shows the dragon's picture on a card tinted in its rarity color; mutated dragons get a mutation-colored
-- glow; the carried dragon's slot has a gold outline. Pressing a slot asks the server to carry that dragon beside the player
-- (the same slot again puts it away); CompanionController draws it for everybody. Dragons are added/removed from the Inventory
-- cards (InventoryController) which send SetHotbarSlot. Numbers in Config/Hotbar, wording in Text.Hotbar.
-- The bar shows BACKPACK dragons (not in the sanctuary); the server fills it (HotbarService). Arrange by drag and drop (UI/DragDrop): drag a
-- Dragons-tab card onto a slot, drag between slots to swap, drag a slot out onto the screen to clear it (touch: long press, then drag).
--
-- Phones: the bar shrinks to fit between the thumbstick zone (left) and the jump button (right), Config/Hotbar PhoneSideReserve.
-- It hides while the Spire HUD is open (it sits in the same place) and, on phones, while a window is open.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local NotificationController = require(script.Parent.NotificationController)
local DragonPicture = require(script.Parent.UI.DragonPicture)
local DragDrop = require(script.Parent.UI.DragDrop)
local Style = require(script.Parent.UI.Style)
local Tooltip = require(script.Parent.UI.Tooltip)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local HotbarConfig = require(ReplicatedStorage.Shared.Config.Hotbar)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local carryDragon = ReplicatedStorage.Remotes.CarryDragon :: RemoteEvent
local setHotbarSlot = ReplicatedStorage.Remotes.SetHotbarSlot :: RemoteEvent

local HotbarController = {}

local KEY_SLOTS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10,
}
local KEY_NAMES = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }

type Slot = {
	Button: TextButton,
	Gradient: UIGradient,
	Border: UIStroke,
	Glow: ImageLabel,
	Number: TextLabel,
	Star: TextLabel, -- shown on a favorite
	PictureHolder: Frame,
	Picture: GuiObject?,
	DragonId: string,
	Look: string, -- what the picture was drawn for ("<id>/<stage>")
	Tip: string,
}

local root: Frame
local slots: { Slot } = {}
local isPhone = false
local phonePage = 1 -- phones show one page of PhoneSlotsPerPage slots at a time
local arrow: TextButton

local function rarityColor(rarityId: string): Color3
	local rarity = (UITheme.Rarity :: any)[rarityId]
	return if rarity then rarity.Color else UITheme.Colors.Gold
end

local function carriedId(): string
	local id = Players.LocalPlayer:GetAttribute("CarryDragonId")
	return if type(id) == "string" then id else ""
end

-- Writes one slot's look for the dragon in it (or the empty look).
local function refreshSlot(index: number, data: any)
	local slot = slots[index]
	local colors = UITheme.Colors
	local id = if data and data.Hotbar then data.Hotbar[index] else ""
	local dragon = if type(id) == "string" and id ~= "" and data then data.Dragons[id] else nil
	local carried = dragon ~= nil and carriedId() == id
	slot.DragonId = if dragon then id else ""
	if dragon == nil then
		if slot.Picture then
			slot.Picture:Destroy()
			slot.Picture = nil
		end
		slot.Look = ""
		slot.Button.BackgroundTransparency = HotbarConfig.EmptyTransparency
		slot.Gradient.Color = ColorSequence.new(colors.CardTop, colors.CardBottom)
		slot.Border.Color = colors.Trim
		slot.Border.Transparency = 0.5
		slot.Border.Thickness = 1.5
		slot.Glow.ImageTransparency = 1
		slot.Number.TextTransparency = 0.35
		slot.Star.Visible = false
		slot.Tip = Text.Format(Text.Hotbar.TipEmpty, { n = KEY_NAMES[index] })
		return
	end
	local species = Dragons[dragon.SpeciesId]
	local mutation = Mutations.Get(dragon.MutationId)
	local mutated = mutation.Id ~= Mutations.NormalId
	local accent = rarityColor(if species then species.Rarity else "Common")
	slot.Button.BackgroundTransparency = 0.04
	slot.Gradient.Color = ColorSequence.new(colors.CardTop:Lerp(accent, 0.38), colors.CardBottom:Lerp(accent, 0.16))
	slot.Border.Color = if carried then HotbarConfig.CarriedColor else Style.Shade(accent, 0.25)
	slot.Border.Transparency = 0
	slot.Border.Thickness = if carried then 3.5 else 2.25
	-- mutation glow (strong, in the mutation's color); others a soft rarity glow; the carried slot glows gold
	slot.Glow.ImageColor3 = if carried then HotbarConfig.CarriedColor elseif mutated then mutation.Color else accent
	slot.Glow.ImageTransparency = if carried then 0.25 elseif mutated then 0.3 else 0.75
	slot.Number.TextTransparency = 0
	slot.Star.Visible = dragon.Favorite == true
	local stage = DragonStats.GetStage(dragon.Level)
	local look = `{id}/{stage.Id}`
	if slot.Look ~= look then
		slot.Look = look
		if slot.Picture then
			slot.Picture:Destroy()
			slot.Picture = nil
		end
		slot.Picture = DragonPicture.new(slot.PictureHolder, dragon.SpeciesId, dragon.Level)
	end
	local name = if species then species.Name else dragon.SpeciesId
	local label = `{if mutated then mutation.Name .. " " else ""}{name} · Lv {dragon.Level}`
	slot.Tip = label
		.. "\n"
		.. Text.Format(if carried then Text.Hotbar.TipPutAway else Text.Hotbar.TipCarry, { key = KEY_NAMES[index] })
end

local function refreshAll()
	local data = DataController:Get()
	for index = 1, HotbarConfig.Slots do
		refreshSlot(index, data)
	end
end

local function layout(phone: boolean)
	isPhone = phone
	local camera = workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280
	local gap = if phone then HotbarConfig.PhoneSlotGap else HotbarConfig.SlotGap
	local base = if phone then HotbarConfig.PhoneSlotSize else HotbarConfig.SlotSize
	-- phones: one page of PhoneSlotsPerPage slots + a page arrow; PC: all slots
	local perPage = if phone then HotbarConfig.PhoneSlotsPerPage else HotbarConfig.Slots
	local first = if phone then (phonePage - 1) * perPage + 1 else 1
	local count = if phone then perPage else HotbarConfig.Slots
	local cells = count + (if phone then 1 else 0) -- the arrow takes the width of one narrower cell
	local usable = if phone then width - 2 * HotbarConfig.PhoneSideReserve else width - 2 * 48
	local minimum = if phone then HotbarConfig.PhoneMinSlotSize else HotbarConfig.MinSlotSize
	local size = math.clamp(math.floor((usable - (cells - 1) * gap) / cells), minimum, base)
	local arrowWidth = math.floor(size * 0.62)
	local total = count * size + (count - 1) * gap + (if phone then gap + arrowWidth else 0)
	root.Size = UDim2.fromOffset(total, size)
	root.Position = UDim2.new(0.5, 0, 1, -(if phone then HotbarConfig.PhoneBottomMargin else HotbarConfig.BottomMargin))
	local list = root:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	list.Padding = UDim.new(0, gap)
	for index, slot in slots do
		slot.Button.Visible = index >= first and index < first + count
		slot.Button.Size = UDim2.fromOffset(size, size)
		slot.Number.TextSize = math.max(10, math.floor(size * 0.3))
	end
	arrow.Visible = phone
	arrow.Size = UDim2.fromOffset(arrowWidth, size)
	arrow.Text = if phonePage == 1 then ">" else "<"
	arrow.TextSize = math.floor(size * 0.5)
end

local function press(index: number)
	local slot = slots[index]
	if slot == nil then
		return
	end
	if slot.DragonId == "" then
		NotificationController:Show(Text.Hotbar.EmptySlot)
		return
	end
	carryDragon:FireServer(index)
end

function HotbarController:Init()
	-- our own bar replaces Roblox's Backpack bar (the game has no tools)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	local gui = HudLayout.MakeScreenGui("Hotbar", "Hud")
	HudLayout.HideWithPopups(gui)
	root = Instance.new("Frame")
	root.Name = "Hotbar"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = root

	for index = 1, HotbarConfig.Slots do
		local button = Instance.new("TextButton")
		button.Name = `Slot{index}`
		button.LayoutOrder = index
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundColor3 = Color3.new(1, 1, 1)
		button.ClipsDescendants = false
		button.Parent = root
		Style.Corner(button, UITheme.SmallCorner + 2)
		local colors = UITheme.Colors
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new(colors.CardTop, colors.CardBottom)
		gradient.Parent = button
		local border = Instance.new("UIStroke")
		border.Name = "Border"
		border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		border.Color = colors.Trim
		border.Parent = button
		local glow = Style.Glow(button, colors.Gold, 7, 1, 0)
		local holder = Instance.new("Frame")
		holder.Name = "PictureHolder"
		holder.BackgroundTransparency = 1
		holder.Position = UDim2.fromOffset(3, 3)
		holder.Size = UDim2.new(1, -6, 1, -6)
		holder.ZIndex = 3
		holder.Parent = button
		local number = Style.Label(button, KEY_NAMES[index], "Title", 14, colors.Text)
		number.Name = "Number"
		number.AnchorPoint = Vector2.new(0, 0)
		number.Position = UDim2.fromOffset(4, 1)
		number.Size = UDim2.fromOffset(20, 16)
		number.TextXAlignment = Enum.TextXAlignment.Left
		number.TextWrapped = false
		number.ZIndex = 6
		Style.Outline(number, 1.5)
		local star = Style.Label(button, "★", "Heavy", 16, UITheme.Colors.Gold)
		star.Name = "Star"
		star.AnchorPoint = Vector2.new(1, 0)
		star.Position = UDim2.new(1, -3, 0, 1)
		star.Size = UDim2.fromOffset(18, 18)
		star.TextWrapped = false
		star.ZIndex = 6
		star.Visible = false
		Style.Outline(star, 1.5)
		Style.AttachPress(button)
		local slot: Slot = {
			Button = button,
			Gradient = gradient,
			Border = border,
			Glow = glow,
			Number = number,
			Star = star,
			PictureHolder = holder,
			Picture = nil,
			DragonId = "",
			Look = "",
			Tip = "",
		}
		slots[index] = slot
		button.Activated:Connect(function()
			if DragDrop.JustDragged() then
				return
			end
			press(index)
		end)
		-- drag this slot's dragon to another slot (swap) or out onto the screen (clears it)
		DragDrop.Attach(button, function()
			if slot.DragonId == "" then
				return nil
			end
			return { DragonId = slot.DragonId, Slot = index, Source = "Hotbar" }
		end, function(ghost, payload)
			local data = DataController:Get()
			local dragon = data and data.Dragons[payload.DragonId]
			if dragon then
				DragonPicture.new(ghost, dragon.SpeciesId, dragon.Level)
			end
		end)
		DragDrop.AddTarget(button, function(payload)
			if payload.Slot == index then
				return
			end
			setHotbarSlot:FireServer(index, payload.DragonId)
		end)
		Tooltip.Attach(button, function()
			return slot.Tip
		end)
	end

	-- phones: the page arrow flips between slots 1-5 and 6-10
	arrow = Instance.new("TextButton")
	arrow.Name = "PageArrow"
	arrow.LayoutOrder = HotbarConfig.Slots + 1
	arrow.AutoButtonColor = false
	arrow.Text = ">"
	arrow.Font = UITheme.Fonts.Title
	arrow.TextColor3 = UITheme.Colors.Gold
	arrow.BackgroundColor3 = UITheme.Colors.PanelBottom
	arrow.BackgroundTransparency = 0.1
	arrow.Visible = false
	arrow.Parent = root
	Style.Round(arrow)
	Style.Stroke(arrow, UITheme.Colors.Trim, 2)
	Style.AttachPress(arrow)
	arrow.Activated:Connect(function()
		phonePage = if phonePage == 1 then 2 else 1
		layout(isPhone)
	end)

	-- the Spire HUD sits in the same place: hide the bar while it is open
	local function refreshSpire()
		root.Visible = Players.LocalPlayer:GetAttribute("SpireHudVisible") ~= true
	end
	Players.LocalPlayer:GetAttributeChangedSignal("SpireHudVisible"):Connect(refreshSpire)
	refreshSpire()

	-- a slot dragged out onto the screen (not onto another slot) empties it
	DragDrop.OnDropOutside = function(payload, point)
		if payload.Source == "Hotbar" and payload.Slot then
			setHotbarSlot:FireServer(payload.Slot, "")
		end
	end

	HudLayout.OnLayoutChanged(layout)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
		layout(isPhone)
	end)
end

function HotbarController:Start()
	for _, key in { "Hotbar", "Dragons" } do
		DataController:OnChanged(key, refreshAll)
	end
	Players.LocalPlayer:GetAttributeChangedSignal("CarryDragonId"):Connect(refreshAll)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if Players.LocalPlayer:GetAttribute("MerchantDialog") == true then
			return -- the merchant's numbered choices use 1-5
		end
		local index = KEY_SLOTS[input.KeyCode]
		if index then
			press(index)
		end
	end)
	refreshAll()
end

return HotbarController
