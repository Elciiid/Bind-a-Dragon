--!strict
-- HUD layout for PC and phones. Everything visual comes from Config/UITheme via the UI kit (Controllers/UI).
--
-- Menu: the left column of big standalone icons (UI/HudIcon: Inventory, Quests, Shop, Rebirth; looks in
-- UITheme.Menu). PC: vertically centered on the left. Phone (screen short side <= UITheme.PhoneMaxShortSide): small
-- icons under the currency row, ending above Roblox's thumbstick (bottom-left); the jump button owns bottom-right.
-- Currencies (UI/CurrencyPill): bottom-left on PC; one row top-left under the top bar (and the gear) on phones.
-- Top bar: AddTopbarButton puts a round button (the Settings gear) right after Roblox's own top-bar buttons, lined up
-- with GuiService.TopbarInset. Layout (PC and phone alike; phones just scale down): travel row top-center, the 4 menu
-- icons left (margin from the device safe area: every gui uses ScreenInsets.CoreUISafeInsets), the timer stack bottom-right
-- (GetTimerStack: day/night timer above the potion timers), bottom-center free for the Dragon Hotbar. Landscape only.
-- Studio: LocalPlayer attribute "ForceLayout" = "Phone" or "PC".
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
local timerStack: Frame
local menu: Frame
local currency: Frame
local phone = false
local entries: { [string]: MenuEntry } = {}
local pills: { CurrencyPill.CurrencyPill } = {}
local popups: { Popup } = {}
local hiddenWithPopups: { ScreenGui } = {} -- phones: HUD guis hidden while a window is open (HideWithPopups)
local listeners: { (boolean) -> () } = {}
local screens: { ScreenGui } = {}
local revealActive = false
local revealEnabled: { [ScreenGui]: boolean } = {}
local safeProbe: Frame

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
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.Parent = player:WaitForChild("PlayerGui")
	table.insert(screens, screen)
	if revealActive and name ~= "Ceremony" and name ~= "Reveal" then
		revealEnabled[screen] = true
		screen.Enabled = false
	end
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

-- Phones: while a window is open, the menu, currencies and the guis given to HideWithPopups (travel row, day/night
-- pill) hide, so nothing peeks around the window's banner.
local function updatePopupHiding()
	local hide = revealActive or (phone and anyPopupOpen())
	if menu then
		menu.Visible = not hide
	end
	if currency then
		currency.Visible = not hide
	end
	for _, screen in hiddenWithPopups do
		screen.Enabled = not hide
	end
end

-- Bottom of Roblox's top bar (pixels from the top of the screen).
function HudLayout.TopbarBottom(): number
	local inset = GuiService.TopbarInset
	return if inset.Height > 0 then inset.Max.Y else 44
end

-- The bottom of the travel row (screen pixels from the top): windows and toasts start below it.
function HudLayout.TravelBottom(): number
	local sizes = UITheme.Sizes
	return if phone
		then sizes.PhoneTravelTop + sizes.PhoneTravelHomeIcon + sizes.PhoneHudLabel
		else sizes.TravelTop + sizes.TravelHomeIcon + sizes.HudLabel
end

-- Where windows and toasts may start (screen pixels): under the travel row with a gap.
function HudLayout.TopReserved(): number
	return HudLayout.TravelBottom() + UITheme.Sizes.Gap
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
	-- the same arrangement on PC and phone: a column, vertically centered on the left
	menu.AnchorPoint = Vector2.new(0, 0.5)
	menu.Position = UDim2.new(0, if phone then sizes.PhoneLeftMargin else sizes.LeftMargin, 0.5, -(if phone then sizes.PhoneMenuRaise else sizes.MenuRaise))
	updatePopupHiding()
end

local function layoutCurrency()
	local sizes = UITheme.Sizes
	local list = currency:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	-- stacked bottom-left on PC and phone alike (phones use smaller pills)
	local size = if phone then sizes.PhoneCurrency else sizes.Currency
	local edge = if phone then sizes.PhoneLeftMargin else sizes.LeftMargin
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, sizes.Gap)
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	currency.AnchorPoint = Vector2.new(0, 1)
	currency.Position = UDim2.new(0, edge + 10, 1, -(if phone then sizes.PhoneMargin else sizes.Margin))
	currency.AutomaticSize = Enum.AutomaticSize.None
	currency.Size = UDim2.fromOffset(size.X, #pills * size.Y + math.max(0, #pills - 1) * sizes.Gap)
	for _, pill in pills do
		pill:Layout(phone)
	end
end

-- Windows sit below the travel row (TopReserved), with room for the banner hanging over their top edge; on phones they are
-- 94% of the safe width. The window guis start under Roblox's top bar (CoreUISafeInsets), so the reserve is measured from
-- there. Each window's UISizeConstraint still caps its size.
local function layoutPopups()
	local sizes = UITheme.Sizes
	local overhang = if phone then sizes.PhoneBanner / 2 + sizes.PhoneBannerStar * 0.62 else sizes.Banner / 2 + sizes.BannerStar * 0.62
	local available = safeProbe.AbsoluteSize
	local margin = if phone then sizes.PhoneMargin else sizes.Margin
	local top = math.max(0, HudLayout.TopReserved() - GuiService:GetGuiInset().Y) + sizes.PopupTopGap
	local space = available.Y - top - margin
	for _, popup in popups do
		local pc = popup.PcSize
		local wanted = if phone then available.X * 0.94 else available.X * pc.X.Scale + pc.X.Offset
		local width = math.max(1, math.min(available.X - margin * 2, wanted))
		local height = math.max(1, space - overhang)
		local limit = popup.Panel:FindFirstChildOfClass("UISizeConstraint")
		if limit then
			width = math.min(width, limit.MaxSize.X)
			height = math.min(height, limit.MaxSize.Y)
		end
		popup.Panel.Size = UDim2.fromOffset(width, height)
		-- center the whole envelope (panel + the ornament above it) in the free area
		local envelopeTop = top + (space - height - overhang) / 2
		popup.Panel.Position = UDim2.fromOffset(available.X / 2, envelopeTop + overhang + height / 2)
	end
end

-- Bottom-right timer stack: near the corner (RightMargin from the edge), PC and phone alike.
local function layoutTimers()
	local sizes = UITheme.Sizes
	-- the same bottom-right spot on PC and phone
	if phone then
		timerStack.Position = UDim2.new(1, -sizes.PhoneRightMargin, 1, -sizes.PhoneMargin)
	else
		timerStack.Position = UDim2.new(1, -sizes.RightMargin, 1, -sizes.Margin)
	end
end

local function relayout()
	if gui == nil then
		return
	end
	layoutTopbar()
	layoutCurrency()
	layoutMenu()
	layoutTimers()
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
	playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor -- landscape only

	local screen = HudLayout.MakeScreenGui("Hud", "Hud")
	gui = screen
	safeProbe = Instance.new("Frame")
	safeProbe.Name = "SafeBounds"
	safeProbe.Size = UDim2.fromScale(1, 1)
	safeProbe.BackgroundTransparency = 1
	safeProbe.Parent = screen

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

	local timersGui = HudLayout.MakeScreenGui("Timers", "Cards")
	timerStack = Instance.new("Frame")
	timerStack.Name = "TimerStack"
	timerStack.AnchorPoint = Vector2.new(1, 1)
	timerStack.AutomaticSize = Enum.AutomaticSize.XY
	timerStack.Size = UDim2.fromOffset(0, 0)
	timerStack.BackgroundTransparency = 1
	timerStack.Parent = timersGui
	local stackList = Instance.new("UIListLayout")
	stackList.FillDirection = Enum.FillDirection.Vertical
	stackList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	stackList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	stackList.Padding = UDim.new(0, UITheme.Sizes.TimerGap)
	stackList.SortOrder = Enum.SortOrder.LayoutOrder
	stackList.Parent = timerStack

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
		phone = now
		relayout()
	end
	player:GetAttributeChangedSignal("ForceLayout"):Connect(check)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(relayout)
	safeProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	safeProbe:GetPropertyChangedSignal("AbsolutePosition"):Connect(relayout)
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

-- The bottom-right stack of timer rows (UI/TimerRow): LayoutOrder 0 = the day/night timer on top, potions below it.
function HudLayout.GetTimerStack(): Frame
	ensure()
	return timerStack
end

function HudLayout.IsPhone(): boolean
	ensure()
	return phone
end

-- The safe rectangle in SCREEN pixels (for guis with ScreenInsets.None, e.g. the dim and the pointer tooltip). Children of a
-- CoreUISafeInsets gui report positions from the inset corner (AbsolutePosition of the probe is always 0, 0), so the
-- top-left inset (GuiService:GetGuiInset) is added back.
function HudLayout.GetUsableRect(): Rect
	ensure()
	local topLeft = GuiService:GetGuiInset()
	return Rect.new(topLeft, topLeft + safeProbe.AbsoluteSize)
end

function HudLayout.SetRevealActive(active: boolean)
	ensure()
	if revealActive == active then return end
	revealActive = active
	for _, screen in screens do
		if screen.Parent and not screen:GetAttribute("RevealLayer") and screen.Name ~= "Ceremony" then
			if active then
				revealEnabled[screen] = screen.Enabled
				screen.Enabled = false
			else
				screen.Enabled = revealEnabled[screen] ~= false
				revealEnabled[screen] = nil
			end
		end
	end
	updatePopupHiding()
end

-- Calls fn(isPhone) now and on every viewport or safe-inset change, including same-mode resizes.
function HudLayout.OnLayoutChanged(fn: (boolean) -> ())
	ensure()
	table.insert(listeners, fn)
	task.spawn(fn, phone)
	return function()
		local index = table.find(listeners, fn)
		if index then table.remove(listeners, index) end
	end
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

-- A left-column icon's button (e.g. to fly Spire drops into "Inventory"), or nil if it doesn't exist.
function HudLayout.GetMenuButton(id: string): GuiObject?
	local entry = entries[id]
	return if entry then entry.Icon.Instance else nil
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

-- Phones: hide this HUD gui while a window is open (e.g. the travel row and the day/night pill).
function HudLayout.HideWithPopups(screen: ScreenGui)
	table.insert(hiddenWithPopups, screen)
	updatePopupHiding()
end

-- A centered popup panel: drawn above the HUD, nearly full screen on phones (pcSize on PC), and the phone menu
-- hides while it is open. UI/Window registers itself; older panels call this directly.
function HudLayout.RegisterPopup(panel: GuiObject, pcSize: UDim2)
	ensure()
	table.insert(popups, { Panel = panel, PcSize = pcSize })
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if menu then
			updatePopupHiding()
		end
	end)
	relayout()
end

return HudLayout
