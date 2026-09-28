--!strict
-- HUD layout for PC and phones. Everything visual comes from Config/UITheme via the UI kit (Controllers/UI).
--
-- Menu: the left column of big standalone icons (UI/HudIcon: Inventory, Quests, Shop, Rebirth; looks in
-- UITheme.Menu). PC: vertically centered on the left. Phone (screen short side <= UITheme.PhoneMaxShortSide): small
-- icons under the currency row, ending above Roblox's thumbstick (bottom-left); the jump button owns bottom-right.
-- Currencies (UI/CurrencyPill): bottom-left on PC; one row top-left under the top bar (and the gear) on phones.
-- Top bar: AddTopbarButton puts a round button (the Settings gear) right after Roblox's own top-bar buttons, lined up
-- with GuiService.TopbarInset. The game is locked to landscape. Studio: LocalPlayer attribute "ForceLayout" = "Phone"
-- or "PC".
--
-- Controllers don't place their own HUD buttons: they call AddMenuButton / AddCurrency / AddTopbarButton, register
-- popups (UI/Window does this: drawn above the HUD, full size on phones, menu hidden while one is open on phones)
-- and listen to OnLayoutChanged. UI is created on first use, so it doesn't matter which controller's Init runs first.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Style = require(script.Parent.UI.Style)
local HudIcon = require(script.Parent.UI.HudIcon)
local CurrencyPill = require(script.Parent.UI.CurrencyPill)

type MenuEntry = { Icon: HudIcon.HudIcon, Text: string, PhoneText: string }
type Popup = { Panel: GuiObject, PcSize: UDim2 }

local HudLayout = {}
HudLayout.Theme = UITheme

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local topbarGui: ScreenGui
local topbarRow: Frame
local menu: Frame
local currency: Frame
local phone = false
local entries: { [string]: MenuEntry } = {}
local pills: { CurrencyPill.CurrencyPill } = {}
local popups: { Popup } = {}
local listeners: { (boolean) -> () } = {}

-- Kept for controllers not yet on the kit.
HudLayout.Corner = function(instance: GuiObject, radius: number?)
	Style.Corner(instance, radius)
end
HudLayout.Pad = function(instance: GuiObject, amount: number)
	Style.Pad(instance, amount)
end

-- A ScreenGui on one of UITheme.Layers ("Hud", "Cards", "Popups", "Notifications").
function HudLayout.MakeScreenGui(name: string, layer: string): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = name
	screen.ResetOnSpawn = false
	screen.DisplayOrder = (UITheme.Layers :: any)[layer] or 0
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- children draw over their parent (the kit relies on it)
	screen.Parent = player:WaitForChild("PlayerGui")
	return screen
end

---------------------------------------------------------------------------------------------------------------
-- Layout

local function computePhone(): boolean
	local forced = player:GetAttribute("ForceLayout")
	if forced == "Phone" then
		return true
	elseif forced == "PC" then
		return false
	end
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
	return math.min(size.X, size.Y) <= UITheme.PhoneMaxShortSide
end

local function anyPopupOpen(): boolean
	for _, popup in popups do
		if popup.Panel.Visible then
			return true
		end
	end
	return false
end

-- Bottom of Roblox's top bar (pixels from the top of the screen).
function HudLayout.TopbarBottom(): number
	local inset = GuiService.TopbarInset
	return if inset.Height > 0 then inset.Max.Y else 44
end

-- Phone: the currency row's top (under the top bar).
local function phoneCurrencyTop(): number
	return HudLayout.TopbarBottom() + 2
end

local function layoutTopbar()
	local inset = GuiService.TopbarInset
	local height = if inset.Height > 0 then inset.Height else 44
	local size = math.floor(height * 0.8)
	topbarRow.Position = UDim2.fromOffset(inset.Min.X + UITheme.Sizes.TopbarGap, inset.Min.Y + (height - size) / 2)
	topbarRow.Size = UDim2.fromOffset(0, size)
	for _, child in topbarRow:GetChildren() do
		if child:IsA("GuiButton") then
			child.Size = UDim2.fromOffset(size, size)
		end
	end
end

local function layoutMenu()
	local sizes = UITheme.Sizes
	local iconSize = if phone then sizes.PhoneHudIcon else sizes.HudIcon
	local labelSize = if phone then sizes.PhoneHudLabel else sizes.HudLabel
	local gap = if phone then sizes.PhoneHudGap else sizes.HudGap
	local list = menu:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	list.Padding = UDim.new(0, gap)
	local count = 0
	for _, entry in entries do
		count += 1
		entry.Icon:Resize(iconSize, labelSize)
		entry.Icon:SetLabel(if phone then entry.PhoneText else entry.Text)
	end
	local width = math.max(iconSize, labelSize * 5)
	menu.Size = UDim2.fromOffset(width, count * (iconSize + labelSize + 2) + math.max(0, count - 1) * gap)
	if phone then
		menu.AnchorPoint = Vector2.new(0, 0)
		menu.Position = UDim2.fromOffset(sizes.PhoneMargin, phoneCurrencyTop() + sizes.PhoneCurrencyRow + sizes.Gap)
	else
		menu.AnchorPoint = Vector2.new(0, 0.5)
		menu.Position = UDim2.new(0, sizes.Margin, 0.5, -10)
	end
	menu.Visible = not (phone and anyPopupOpen())
end

local function layoutCurrency()
	local sizes = UITheme.Sizes
	local list = currency:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	if phone then
		-- one row under the top bar (and the gear)
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0, 14)
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		currency.AnchorPoint = Vector2.new(0, 0)
		currency.Position = UDim2.fromOffset(sizes.PhoneMargin + 8, phoneCurrencyTop())
		currency.AutomaticSize = Enum.AutomaticSize.X
		currency.Size = UDim2.fromOffset(0, sizes.PhoneCurrencyRow)
	else
		list.FillDirection = Enum.FillDirection.Vertical
		list.Padding = UDim.new(0, sizes.Gap)
		list.VerticalAlignment = Enum.VerticalAlignment.Bottom
		currency.AnchorPoint = Vector2.new(0, 1)
		currency.Position = UDim2.new(0, sizes.Margin + 10, 1, -sizes.Margin)
		currency.AutomaticSize = Enum.AutomaticSize.None
		currency.Size = UDim2.fromOffset(sizes.Currency.X, #pills * sizes.Currency.Y + math.max(0, #pills - 1) * sizes.Gap)
	end
	for _, pill in pills do
		pill:Layout(phone)
	end
end

local function layoutPopups()
	for _, popup in popups do
		popup.Panel.Size = if phone then UDim2.fromScale(0.96, 0.96) else popup.PcSize
	end
end

local function relayout()
	if gui == nil then
		return
	end
	layoutTopbar()
	layoutCurrency()
	layoutMenu()
	layoutPopups()
	for _, listener in listeners do
		task.spawn(listener, phone)
	end
end

local function ensure(): ScreenGui
	if gui then
		return gui
	end
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor -- phones: landscape only

	local screen = HudLayout.MakeScreenGui("Hud", "Hud")
	screen.ScreenInsets = Enum.ScreenInsets.None -- pixel positions line up with GuiService.TopbarInset
	gui = screen

	topbarGui = HudLayout.MakeScreenGui("HudTopbar", "Hud")
	topbarGui.ScreenInsets = Enum.ScreenInsets.None
	topbarRow = Instance.new("Frame")
	topbarRow.Name = "TopbarRow"
	topbarRow.BackgroundTransparency = 1
	topbarRow.AutomaticSize = Enum.AutomaticSize.X
	topbarRow.Parent = topbarGui
	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.Padding = UDim.new(0, 8)
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Parent = topbarRow

	menu = Instance.new("Frame")
	menu.Name = "Menu"
	menu.BackgroundTransparency = 1
	menu.Parent = screen
	local column = Instance.new("UIListLayout")
	column.SortOrder = Enum.SortOrder.LayoutOrder
	column.HorizontalAlignment = Enum.HorizontalAlignment.Center
	column.Parent = menu

	currency = Instance.new("Frame")
	currency.Name = "Currency"
	currency.BackgroundTransparency = 1
	currency.Parent = screen
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = currency

	phone = computePhone()
	local function check()
		local now = computePhone()
		if now ~= phone then
			phone = now
			relayout()
		end
	end
	player:GetAttributeChangedSignal("ForceLayout"):Connect(check)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(relayout)
	local function watchCamera()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(check)
		end
		check()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
	return screen
end

---------------------------------------------------------------------------------------------------------------
-- API

function HudLayout.IsPhone(): boolean
	ensure()
	return phone
end

-- Calls fn(isPhone) now and whenever the layout switches between PC and phone (or the top bar moves).
function HudLayout.OnLayoutChanged(fn: (boolean) -> ())
	ensure()
	table.insert(listeners, fn)
	task.spawn(fn, phone)
end

-- A left-column HUD icon with the look from UITheme.Menu[id] (icon, label, color, order). Returns its button.
function HudLayout.AddMenuButton(id: string): TextButton
	ensure()
	local look = UITheme.Menu[id] or { Label = id, Color = UITheme.Colors.Neutral, Order = 99, Icon = "" }
	local image = if look.Icon ~= "" then look.Icon else (look.Fallback or "")
	local icon = HudIcon.new(menu, { Image = image, Glyph = look.Glyph, Label = look.Label, Color = look.Color })
	icon.Instance.Name = id
	icon.Instance.LayoutOrder = look.Order
	entries[id] = { Icon = icon, Text = look.Label, PhoneText = look.Label }
	relayout()
	return icon.Instance
end

-- Changes a menu icon's label (e.g. "Rebirth ★3"); phones can use a shorter one ("★3").
function HudLayout.SetMenuText(id: string, text: string, phoneText: string?)
	local entry = entries[id]
	if entry == nil then
		return
	end
	entry.Text = text
	entry.PhoneText = phoneText or text
	entry.Icon:SetLabel(if phone then entry.PhoneText else entry.Text)
end

-- A red count on the icon (hidden at 0).
function HudLayout.SetBadge(id: string, count: number)
	local entry = entries[id]
	if entry then
		entry.Icon:SetBadge(count)
	end
end

function HudLayout.SetPulse(id: string, on: boolean)
	local entry = entries[id]
	if entry then
		entry.Icon:SetPulse(on)
	end
end

-- "Ready" emphasis (gold glow, hop, sparkle ring, READY! tag), e.g. Rebirth affordable.
function HudLayout.SetReady(id: string, on: boolean)
	local entry = entries[id]
	if entry then
		entry.Icon:SetReady(on)
	end
end

-- Progress ring (0..1) around a calm icon; nil hides it.
function HudLayout.SetProgress(id: string, progress: number?)
	local entry = entries[id]
	if entry then
		entry.Icon:SetProgress(progress)
	end
end

-- A round button right after Roblox's own top-bar buttons (dark translucent circle like theirs, white image).
function HudLayout.AddTopbarButton(id: string, image: string, order: number): TextButton
	ensure()
	local button = Instance.new("TextButton")
	button.Name = id
	button.Text = ""
	button.AutoButtonColor = false
	button.LayoutOrder = order
	button.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
	button.BackgroundTransparency = 0.3
	button.Parent = topbarRow
	Style.Round(button)
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.62, 0.62)
	icon.Image = image
	icon.Parent = button
	Style.AttachPress(button)
	relayout()
	return button
end

-- A currency pill (icon = UITheme.Icons key). Returns the pill; call pill:Set(text).
function HudLayout.AddCurrency(icon: string, color: Color3, order: number): CurrencyPill.CurrencyPill
	ensure()
	local pill = CurrencyPill.new(currency, icon, color)
	pill.Instance.LayoutOrder = order
	table.insert(pills, pill)
	relayout()
	return pill
end

-- One window at a time: a window or station panel calls ClaimFocus(owner, close) when it opens, which first closes
-- whatever else holds focus, and ReleaseFocus(owner) when it closes. UI/Window does this for every window; other
-- panels (e.g. the Spire card) use TrackPanel. HUD pills, toasts and timers never take focus.
local focused: { Owner: any, Close: () -> () }? = nil
local focusClearedListeners: { () -> () } = {}

function HudLayout.ClaimFocus(owner: any, close: () -> ())
	local previous = focused
	focused = { Owner = owner, Close = close }
	if previous and previous.Owner ~= owner then
		previous.Close()
	end
end

function HudLayout.ReleaseFocus(owner: any)
	if focused and focused.Owner == owner then
		focused = nil
		for _, fn in focusClearedListeners do
			task.spawn(fn)
		end
	end
end

-- Calls fn whenever the open window/panel closes and nothing else is open (not when one window replaces another).
function HudLayout.OnFocusCleared(fn: () -> ())
	table.insert(focusClearedListeners, fn)
end

-- True while any window or station panel is open.
function HudLayout.HasFocus(): boolean
	return focused ~= nil
end

-- For panels that aren't UI/Window: claims focus whenever the panel becomes visible (closing other windows) and
-- calls close() when another window takes over.
function HudLayout.TrackPanel(panel: GuiObject, close: () -> ())
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			HudLayout.ClaimFocus(panel, close)
		else
			HudLayout.ReleaseFocus(panel)
		end
	end)
end

-- A centered popup panel: drawn above the HUD, nearly full screen on phones (pcSize on PC), and the phone menu
-- hides while it is open. UI/Window registers itself; older panels call this directly.
function HudLayout.RegisterPopup(panel: GuiObject, pcSize: UDim2)
	ensure()
	table.insert(popups, { Panel = panel, PcSize = pcSize })
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if menu then
			menu.Visible = not (phone and anyPopupOpen())
		end
	end)
	relayout()
end

return HudLayout
