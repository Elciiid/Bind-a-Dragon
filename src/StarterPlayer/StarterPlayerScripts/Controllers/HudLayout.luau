--!strict
-- HUD layout for PC and phones, and the start of the UI component kit. Everything visual comes from Config/Theme.
--
-- PC: labeled menu column bottom-left, above the Gold/Stardust counters.
-- Phone (screen short side <= Theme.PhoneMaxShortSide): Roblox's thumbstick (bottom-left) and jump button
-- (bottom-right) own those corners, so the menu is a 2-column grid of square buttons on the left middle, and the
-- currencies are small rows top-left under the Roblox top bar. The game is locked to landscape.
-- Studio testing: set a LocalPlayer attribute "ForceLayout" = "Phone" or "PC".
--
-- Controllers don't place their own HUD buttons: they call AddMenuButton / AddCurrencyLabel, register their popups
-- (drawn above the HUD, full size on phones, menu hidden while one is open on phones) and listen to OnLayoutChanged.
-- UI is created on first use, so it doesn't matter which controller's Init runs first.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)

type MenuEntry = { Button: TextButton, Badge: TextLabel, Stroke: UIStroke, Text: string, PhoneText: string, Pulse: boolean }
type Popup = { Panel: GuiObject, PcSize: UDim2 }

local HudLayout = {}
HudLayout.Theme = Theme

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local menu: Frame
local currency: Frame
local phone = false
local entries: { [string]: MenuEntry } = {}
local currencyLabels: { TextLabel } = {}
local popups: { Popup } = {}
local listeners: { (boolean) -> () } = {}

---------------------------------------------------------------------------------------------------------------
-- Component helpers (shared styling; the UI pass extends these)

function HudLayout.Corner(instance: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.Sizes.Corner)
	corner.Parent = instance
end

function HudLayout.Pad(instance: GuiObject, amount: number)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, amount)
	pad.PaddingBottom = UDim.new(0, amount)
	pad.PaddingLeft = UDim.new(0, amount)
	pad.PaddingRight = UDim.new(0, amount)
	pad.Parent = instance
end

-- A ScreenGui on one of Theme.Layers ("Hud", "Cards", "Popups", "Notifications").
function HudLayout.MakeScreenGui(name: string, layer: string): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = name
	screen.ResetOnSpawn = false
	screen.DisplayOrder = (Theme.Layers :: any)[layer] or 0
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
	return math.min(size.X, size.Y) <= Theme.PhoneMaxShortSide
end

local function anyPopupOpen(): boolean
	for _, popup in popups do
		if popup.Panel.Visible then
			return true
		end
	end
	return false
end

local function layoutMenu()
	local sizes = Theme.Sizes
	for _, child in menu:GetChildren() do
		if child:IsA("UIListLayout") or child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
	local count = 0
	for _ in entries do
		count += 1
	end

	if phone then
		local columns = sizes.PhoneMenuColumns
		local rows = math.max(1, math.ceil(count / columns))
		local cell = sizes.PhoneMenuButton
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(cell.X, cell.Y)
		grid.CellPadding = UDim2.fromOffset(sizes.Gap, sizes.Gap)
		grid.FillDirectionMaxCells = columns
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = menu
		menu.AnchorPoint = Vector2.new(0, 0)
		local currencyHeight = #currencyLabels * sizes.PhoneCurrencyRow + math.max(0, #currencyLabels - 1) * 4
		menu.Position = UDim2.fromOffset(sizes.PhoneMargin, sizes.PhoneMargin + currencyHeight + sizes.Gap)
		menu.Size = UDim2.fromOffset(columns * cell.X + (columns - 1) * sizes.Gap, rows * cell.Y + (rows - 1) * sizes.Gap)
	else
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, sizes.Gap)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.VerticalAlignment = Enum.VerticalAlignment.Bottom
		list.Parent = menu
		local currencyHeight = 2 * sizes.Currency.Y + sizes.Gap
		menu.AnchorPoint = Vector2.new(0, 1)
		menu.Position = UDim2.new(0, sizes.Margin, 1, -(sizes.Margin + currencyHeight + sizes.Gap))
		menu.Size = UDim2.fromOffset(sizes.MenuButton.X, count * (sizes.MenuButton.Y + sizes.Gap))
	end

	for _, entry in entries do
		entry.Button.Text = if phone then entry.PhoneText else entry.Text
		entry.Button.TextScaled = not phone -- phone: one fixed size for every button
		entry.Button.TextSize = sizes.PhoneMenuTextSize
		entry.Button.TextWrapped = true
		entry.Button.Size = if phone
			then UDim2.fromOffset(sizes.PhoneMenuButton.X, sizes.PhoneMenuButton.Y)
			else UDim2.fromOffset(sizes.MenuButton.X, sizes.MenuButton.Y)
		local pad = entry.Button:FindFirstChildOfClass("UIPadding")
		if pad then
			local amount = UDim.new(0, if phone then 2 else 6)
			pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = amount, amount, amount, amount
		end
	end
	menu.Visible = not (phone and anyPopupOpen())
end

local function layoutCurrency()
	local sizes = Theme.Sizes
	for _, child in currency:GetChildren() do
		if child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, if phone then 4 else sizes.Gap)
	if phone then
		currency.AnchorPoint = Vector2.new(0, 0)
		currency.Position = UDim2.fromOffset(sizes.PhoneMargin, sizes.PhoneMargin)
		currency.Size = UDim2.fromOffset(0, #currencyLabels * sizes.PhoneCurrencyRow + math.max(0, #currencyLabels - 1) * 4)
		currency.AutomaticSize = Enum.AutomaticSize.X
	else
		list.VerticalAlignment = Enum.VerticalAlignment.Bottom
		currency.AnchorPoint = Vector2.new(0, 1)
		currency.Position = UDim2.new(0, sizes.Margin, 1, -sizes.Margin)
		currency.AutomaticSize = Enum.AutomaticSize.None
		currency.Size = UDim2.fromOffset(sizes.Currency.X, 2 * sizes.Currency.Y + sizes.Gap)
	end
	list.Parent = currency
	for _, label in currencyLabels do
		if phone then
			label.TextScaled = false
			label.TextSize = sizes.PhoneCurrencyTextSize
			label.AutomaticSize = Enum.AutomaticSize.X
			label.Size = UDim2.fromOffset(0, sizes.PhoneCurrencyRow)
		else
			label.TextScaled = true
			label.AutomaticSize = Enum.AutomaticSize.None
			label.Size = UDim2.new(1, 0, 0, sizes.Currency.Y)
		end
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
	layoutMenu()
	layoutCurrency()
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

	currency = Instance.new("Frame")
	currency.Name = "Currency"
	currency.BackgroundTransparency = 1
	currency.Parent = screen

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

	-- Pulsing outlines on menu buttons that ask for attention.
	RunService.RenderStepped:Connect(function()
		local thickness = 1.5 + 1.5 * math.sin(os.clock() * 5)
		for _, entry in entries do
			entry.Stroke.Thickness = if entry.Pulse then thickness else 0
		end
	end)
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

-- A menu button with the look from Theme.Menu[id] (label, color, order).
function HudLayout.AddMenuButton(id: string): TextButton
	ensure()
	local look = Theme.Menu[id] or { Label = id, Color = Theme.Colors.Gold, Order = 99 }
	local button = Instance.new("TextButton")
	button.Name = id
	button.LayoutOrder = look.Order
	button.BackgroundColor3 = look.Color
	button.TextColor3 = Theme.Colors.TextOnButton
	button.Font = Theme.Fonts.Bold
	button.TextScaled = true
	button.Text = look.Label
	HudLayout.Corner(button)
	HudLayout.Pad(button, 6)
	button.Parent = menu

	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -4, 0, 4)
	badge.Size = UDim2.fromOffset(Theme.Sizes.Badge, Theme.Sizes.Badge)
	badge.BackgroundColor3 = Theme.Colors.Badge
	badge.TextColor3 = Theme.Colors.Text
	badge.Font = Theme.Fonts.Bold
	badge.TextScaled = true
	badge.Visible = false
	badge.ZIndex = 2
	HudLayout.Corner(badge, Theme.Sizes.Badge)
	HudLayout.Pad(badge, 3)
	badge.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Text
	stroke.Thickness = 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button

	entries[id] = { Button = button, Badge = badge, Stroke = stroke, Text = look.Label, PhoneText = look.Label, Pulse = false }
	relayout()
	return button
end

-- Changes a menu button's text (e.g. "Rebirth  ★3"); the phone grid can use a shorter one ("Rebirth\n★3").
function HudLayout.SetMenuText(id: string, text: string, phoneText: string?)
	local entry = entries[id]
	if entry == nil then
		return
	end
	entry.Text = text
	entry.PhoneText = phoneText or text
	entry.Button.Text = if phone then entry.PhoneText else entry.Text
end

-- A red count on the button (hidden at 0).
function HudLayout.SetBadge(id: string, count: number)
	local entry = entries[id]
	if entry then
		entry.Badge.Text = tostring(count)
		entry.Badge.Visible = count > 0
	end
end

function HudLayout.SetPulse(id: string, on: boolean)
	local entry = entries[id]
	if entry then
		entry.Pulse = on
	end
end

-- A currency counter: a row in the PC column (bottom-left) or a small row top-left on phones.
function HudLayout.AddCurrencyLabel(name: string, color: Color3, order: number): TextLabel
	ensure()
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.BackgroundColor3 = Theme.Colors.Panel
	label.BackgroundTransparency = 0.25
	label.TextColor3 = color
	label.Font = Theme.Fonts.Bold
	label.TextXAlignment = Enum.TextXAlignment.Left
	HudLayout.Corner(label)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 5)
	pad.PaddingBottom = UDim.new(0, 5)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = label
	label.Parent = currency
	table.insert(currencyLabels, label)
	relayout()
	return label
end

-- A centered popup panel: drawn above the HUD, nearly full screen on phones (pcSize on PC), and the phone menu
-- hides while it is open. Its ScreenGui should come from MakeScreenGui(name, "Popups").
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
