--!strict
-- HUD layout for PC and phones. Everything visual comes from Config/UITheme via the UI kit (Controllers/UI).
--
-- Menu: a 2-column grid of icon tiles (UI/IconButton) on the left middle. PC: 74 px tiles, vertically centered.
-- Phone (screen short side <= UITheme.PhoneMaxShortSide): Roblox's thumbstick (bottom-left) and jump button
-- (bottom-right) own those corners, so the grid sits under the currency pills, between the top bar and the
-- thumbstick. Currencies (UI/CurrencyPill): bottom-left on PC, small pills top-left on phones.
-- The game is locked to landscape. Studio testing: set a LocalPlayer attribute "ForceLayout" = "Phone" or "PC".
--
-- Controllers don't place their own HUD buttons: they call AddMenuButton / AddCurrency, register popups (UI/Window
-- does this: drawn above the HUD, full size on phones, menu hidden while one is open on phones) and listen to
-- OnLayoutChanged. UI is created on first use, so it doesn't matter which controller's Init runs first.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Style = require(script.Parent.UI.Style)
local IconButton = require(script.Parent.UI.IconButton)
local CurrencyPill = require(script.Parent.UI.CurrencyPill)

type MenuEntry = { Button: IconButton.IconButton, Text: string, PhoneText: string }
type Popup = { Panel: GuiObject, PcSize: UDim2 }

local HudLayout = {}
HudLayout.Theme = UITheme

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
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

local function currencyHeight(): number
	local sizes = UITheme.Sizes
	if phone then
		return #pills * sizes.PhoneCurrencyRow + math.max(0, #pills - 1) * 4
	end
	return #pills * sizes.Currency.Y + math.max(0, #pills - 1) * sizes.Gap
end

local function layoutMenu()
	local sizes = UITheme.Sizes
	local count = 0
	for _ in entries do
		count += 1
	end
	local columns = sizes.MenuColumns
	local rows = math.max(1, math.ceil(count / columns))
	local cell = if phone then sizes.PhoneMenuButton else sizes.MenuButton
	local grid = menu:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
	grid.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	grid.CellPadding = UDim2.fromOffset(sizes.Gap, sizes.Gap)
	grid.FillDirectionMaxCells = columns
	menu.Size = UDim2.fromOffset(columns * cell.X + (columns - 1) * sizes.Gap, rows * cell.Y + (rows - 1) * sizes.Gap)
	if phone then
		menu.AnchorPoint = Vector2.new(0, 0)
		menu.Position = UDim2.fromOffset(sizes.PhoneMargin, sizes.PhoneMargin + currencyHeight() + sizes.Gap)
	else
		menu.AnchorPoint = Vector2.new(0, 0.5)
		menu.Position = UDim2.new(0, sizes.Margin, 0.5, -20)
	end
	for _, entry in entries do
		entry.Button:SetLabel(if phone then entry.PhoneText else entry.Text)
		entry.Button.Label.TextSize = if phone then sizes.PhoneMenuLabelSize else sizes.MenuLabelSize
	end
	menu.Visible = not (phone and anyPopupOpen())
end

local function layoutCurrency()
	local sizes = UITheme.Sizes
	local list = currency:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	list.Padding = UDim.new(0, if phone then 4 else sizes.Gap)
	if phone then
		list.VerticalAlignment = Enum.VerticalAlignment.Top
		currency.AnchorPoint = Vector2.new(0, 0)
		currency.Position = UDim2.fromOffset(sizes.PhoneMargin + 6, sizes.PhoneMargin)
		currency.AutomaticSize = Enum.AutomaticSize.X
		currency.Size = UDim2.fromOffset(0, currencyHeight())
	else
		list.VerticalAlignment = Enum.VerticalAlignment.Bottom
		currency.AnchorPoint = Vector2.new(0, 1)
		currency.Position = UDim2.new(0, sizes.Margin + 8, 1, -sizes.Margin)
		currency.AutomaticSize = Enum.AutomaticSize.None
		currency.Size = UDim2.fromOffset(sizes.Currency.X, currencyHeight())
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
	gui = screen

	menu = Instance.new("Frame")
	menu.Name = "Menu"
	menu.BackgroundTransparency = 1
	menu.Parent = screen
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = menu

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

-- Calls fn(isPhone) now and whenever the layout switches between PC and phone.
function HudLayout.OnLayoutChanged(fn: (boolean) -> ())
	ensure()
	table.insert(listeners, fn)
	task.spawn(fn, phone)
end

-- A menu tile with the look from UITheme.Menu[id] (icon, label, color, order). Returns its button.
function HudLayout.AddMenuButton(id: string): TextButton
	ensure()
	local look = UITheme.Menu[id] or { Label = id, Color = UITheme.Colors.Neutral, Order = 99, Icon = "" }
	local button = IconButton.new(menu, { Icon = look.Icon, Label = look.Label, Color = look.Color })
	button.Instance.Name = id
	button.Instance.LayoutOrder = look.Order
	entries[id] = { Button = button, Text = look.Label, PhoneText = look.Label }
	relayout()
	return button.Instance
end

-- Changes a menu tile's label (e.g. "Rebirth ★3"); phones can use a shorter one ("★3").
function HudLayout.SetMenuText(id: string, text: string, phoneText: string?)
	local entry = entries[id]
	if entry == nil then
		return
	end
	entry.Text = text
	entry.PhoneText = phoneText or text
	entry.Button:SetLabel(if phone then entry.PhoneText else entry.Text)
end

-- A red count on the tile (hidden at 0).
function HudLayout.SetBadge(id: string, count: number)
	local entry = entries[id]
	if entry then
		entry.Button:SetBadge(count)
	end
end

function HudLayout.SetPulse(id: string, on: boolean)
	local entry = entries[id]
	if entry then
		entry.Button:SetPulse(on)
	end
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
