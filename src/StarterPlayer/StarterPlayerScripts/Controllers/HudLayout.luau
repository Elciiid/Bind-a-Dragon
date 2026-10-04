--!strict
-- HUD layout for PC and phones. Everything visual comes from Config/UITheme via the UI kit (Controllers/UI).
--
-- Menu: the left column of big standalone icons (UI/HudIcon: Inventory, Quests, Shop, Rebirth; looks in
-- UITheme.Menu). PC: vertically centered on the left. Phone (screen short side <= UITheme.PhoneMaxShortSide): small
-- icons in one vertically centered column, kept clear of bottom-left currency; jump owns bottom-right.
-- Currencies (UI/CurrencyPill): stacked bottom-left on both PC and phones.
-- Top bar: AddTopbarButton puts a round button (the Settings gear) right after Roblox's own top-bar buttons, lined up
-- with GuiService.TopbarInset. Travel has a small safe-top margin, centered on the whole display, with gapped buttons;
-- menu icons are centered vertically on the left (not a phone grid). The 4 menu
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
local UserInputService = game:GetService("UserInputService")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local HotbarConfig = require(ReplicatedStorage.Shared.Config.Hotbar)
local Geometry = require(ReplicatedStorage.Shared.UIGeometry)
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
local menu: ScrollingFrame
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
local focused: { Owner: any, Close: () -> () }? = nil
local travelBottom: number? = nil -- actual bottom in CoreUISafeInsets coordinates, supplied by TravelController

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
	local hide = revealActive or player:GetAttribute("RewardPopupOpen") == true or (phone and (anyPopupOpen() or focused ~= nil))
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
	if travelBottom then return travelBottom end
	local sizes = UITheme.Sizes
	return if phone
		then UITheme.MobileUI.WindowTop + UITheme.MobileUI.TravelHeight
		else UITheme.MobileUI.WindowTop + sizes.TravelHomeIcon + sizes.HudLabel
end

-- Where windows and toasts may start (screen pixels): under the travel row with a gap.
function HudLayout.TopReserved(): number
	return math.max(0, HudLayout.TravelBottom()) + (if phone then UITheme.MobileUI.Gap else UITheme.Sizes.Gap)
end

local function layoutTopbar()
	local inset = GuiService.TopbarInset
	local height = if inset.Height > 0 then inset.Height else 44
	local size = math.max(UITheme.MobileUI.Touch, math.floor(height * 0.8))
	-- This host already starts AFTER Roblox's microphone/chat controls and the device cutout.
	-- Use local offsets: mixing TopbarInset coordinates with a full-display host put the gear inside the mic.
	topbarRow.Position = UDim2.fromOffset(UITheme.Sizes.TopbarGap, (height - size) / 2)
	topbarRow.Size = UDim2.fromOffset(0, size)
	for _, child in topbarRow:GetChildren() do
		if child:IsA("GuiButton") then
			child.Size = UDim2.fromOffset(size, size)
		end
	end
end

local function layoutMenu()
	local sizes = UITheme.Sizes
	local mobile = UITheme.MobileUI
	local iconSize = if phone then mobile.SideIcon else sizes.HudIcon
	local labelSize = if phone then mobile.Small else sizes.HudLabel
	local gap = if phone then mobile.SideGap else sizes.HudGap
	local existing = menu:FindFirstChildOfClass("UIGridLayout") or menu:FindFirstChildOfClass("UIListLayout")
	if existing and existing:IsA("UIGridLayout") then existing:Destroy(); existing = nil end
	if not existing then
		existing = Instance.new("UIListLayout")
		existing.SortOrder = Enum.SortOrder.LayoutOrder
		existing.Parent = menu
	end
	local count = 0
	for _ in entries do count += 1 end
	local column = Geometry.SideColumn(safeProbe.AbsoluteSize.Y, count, currency.Size.Y.Offset,
		iconSize, labelSize, mobile.Touch, gap, mobile.SideTop, mobile.CurrencyBottom, mobile.SideCurrencyGap)
	if phone then iconSize, gap = column.Icon, column.Gap end
	local list = existing :: UIListLayout
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.Padding = UDim.new(0, gap)
	for _, entry in entries do
		entry.Icon:Resize(iconSize, labelSize)
		if phone then entry.Icon.Instance.Size = UDim2.fromOffset(math.max(iconSize, labelSize * 5), column.Row) end
		entry.Icon:SetLabel(if phone then entry.PhoneText else entry.Text)
	end
	local width = math.max(iconSize, labelSize * 5)
	menu.Size = if phone then UDim2.fromOffset(width + (if column.Content > column.Height then mobile.Scrollbar else 0), column.Height)
		else UDim2.fromOffset(width, count * (iconSize + labelSize + 2) + math.max(0, count - 1) * gap)
	menu.ScrollBarThickness = if phone and column.Content > column.Height then mobile.Scrollbar else 0
	menu.ScrollingEnabled = phone and column.Content > column.Height
	menu.AnchorPoint = Vector2.new(0, if phone then 0 else 0.5)
	menu.Position = if phone then UDim2.fromOffset(mobile.SideLeft, column.Y)
		else UDim2.new(0, sizes.LeftMargin, 0.5, 0)
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
	currency.Position = if phone then UDim2.new(0, UITheme.MobileUI.CurrencyLeft, 1, -UITheme.MobileUI.CurrencyBottom)
		else UDim2.new(0, edge + 10, 1, -sizes.Margin)
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
	local margin = if phone then UITheme.MobileUI.WindowMargin else sizes.Margin
	local top = if phone then UITheme.MobileUI.WindowTop else HudLayout.TopReserved() + sizes.PopupTopGap
	-- PC: windows end above the hotbar, so a dragon can be dragged from the Dragons tab onto a slot (phones hide the bar while a window is open)
	local bottomReserve = if phone then 0 else HotbarConfig.SlotSize + HotbarConfig.BottomMargin + 6
	for _, popup in popups do
		local pc = popup.PcSize
		local limit = popup.Panel:FindFirstChildOfClass("UISizeConstraint")
		local box = Geometry.Popup(available.X, available.Y,
			if phone then available.X else available.X * pc.X.Scale + pc.X.Offset,
			if phone then available.Y else available.Y * pc.Y.Scale + pc.Y.Offset,
			top, bottomReserve, margin, overhang,
			if limit then limit.MaxSize.X else math.huge, if limit then limit.MaxSize.Y else math.huge)
		popup.Panel.Size = UDim2.fromOffset(box.Width, box.Height)
		popup.Panel.Position = UDim2.fromOffset(box.X, box.Y)
	end
end

-- Roblox's own jump button on touch devices (PlayerGui.TouchGui.TouchControlFrame.JumpButton), if it exists yet.
local function findJumpButton(): GuiObject?
	local touchGui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	return if jump and jump:IsA("GuiObject") then jump else nil
end

-- Pixels kept free above the bottom edge on phones, so the timer stack sits above the jump button: the real button's top
-- (touch devices) plus a gap, else the Config reserve (Studio / the phone mock).
local function jumpReserve(): number
	local sizes = UITheme.Sizes
	local jump = findJumpButton()
	local camera = workspace.CurrentCamera
	if UserInputService.TouchEnabled and jump and camera and jump.Visible and jump.AbsoluteSize.Y > 0 then
		return math.max(sizes.PhoneMargin, safeProbe.AbsolutePosition.Y + safeProbe.AbsoluteSize.Y - jump.AbsolutePosition.Y + sizes.PhoneJumpGap)
	end
	return sizes.PhoneJumpReserve
end

-- Bottom-right timer stack: near the corner (RightMargin from the edge), PC and phone alike; on phones lifted above the
-- jump button.
local function layoutTimers()
	local sizes = UITheme.Sizes
	local width = math.min(UITheme.MobileUI.TimerMaxWidth, safeProbe.AbsoluteSize.X * (if phone then UITheme.MobileUI.TimerPhoneFraction else 1) - sizes.RightMargin)
	timerStack.Size = UDim2.fromOffset(math.max(UITheme.MobileUI.Touch, width), 0)
	local captionSpace = if phone then safeProbe.AbsoluteSize.Y - jumpReserve() - HudLayout.TopReserved() - sizes.PhoneTimerIcon - sizes.TimerGap - UITheme.MobileUI.Gap else UITheme.MobileUI.TimerCaptionMaxHeight
	timerStack:SetAttribute("CaptionMaxHeight", math.max(UITheme.MobileUI.Small, math.min(UITheme.MobileUI.TimerCaptionMaxHeight, captionSpace)))
	timerStack.Visible = player:GetAttribute("TutorialGuideOpen") ~= true
	if phone then
		timerStack.Position = UDim2.new(1, -sizes.PhoneRightMargin, 1, -jumpReserve())
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
	topbarGui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
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
	table.insert(hiddenWithPopups, timersGui)
	timerStack = Instance.new("Frame")
	timerStack.Name = "TimerStack"
	timerStack.AnchorPoint = Vector2.new(1, 1)
	timerStack.AutomaticSize = Enum.AutomaticSize.Y
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

	menu = Instance.new("ScrollingFrame")
	menu.Name = "Menu"
	menu.BackgroundTransparency = 1
	menu.BorderSizePixel = 0
	menu.CanvasSize = UDim2.new()
	menu.AutomaticCanvasSize = Enum.AutomaticSize.Y
	menu.ScrollingDirection = Enum.ScrollingDirection.Y
	menu.ScrollBarImageColor3 = UITheme.Colors.Trim
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
	player:GetAttributeChangedSignal("RewardPopupOpen"):Connect(updatePopupHiding)
	player:GetAttributeChangedSignal("TutorialGuideOpen"):Connect(layoutTimers)
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
	-- touch devices: Roblox creates its jump button a little later; follow it so the timer stack stays above it
	if UserInputService.TouchEnabled then
		task.spawn(function()
			for _ = 1, 60 do
				local jump = findJumpButton()
				if jump then
					jump:GetPropertyChangedSignal("AbsolutePosition"):Connect(relayout)
					jump:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
					jump:GetPropertyChangedSignal("Visible"):Connect(relayout)
					relayout()
					return
				end
				task.wait(0.5)
			end
		end)
	end
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

-- All AbsolutePosition/InputObject.Position values use CoreUISafeInsets coordinates, even under ScreenInsets.None.
-- Never add GetGuiInset here: doing so offsets tooltips and pointers twice on notched devices.
function HudLayout.GetUsableRect(): Rect
	ensure()
	return Rect.new(safeProbe.AbsolutePosition, safeProbe.AbsolutePosition + safeProbe.AbsoluteSize)
end

-- Navigation targets may live above the core-safe origin, within the safe top bar. Their
-- tutorial outlines must use device bounds or a fully visible Home button would be discarded.
function HudLayout.GetTargetSafeRect(target: GuiObject?): Rect
	local host = target and target:FindFirstAncestorWhichIsA("ScreenGui")
	if host and host:IsA("ScreenGui") and host.ScreenInsets == Enum.ScreenInsets.TopbarSafeInsets then
		local ok, bounds = pcall(function() return GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets) end)
		if ok and bounds.Width > 0 and bounds.Height > 0 then return bounds end
	end
	return HudLayout.GetUsableRect()
end

-- TopbarSafeInsets excludes the native Roblox controls while letting navigation sit at the actual
-- top, rather than below an additional CoreUISafeInsets/top-padding reserve.
function HudLayout.GetTravelHost(): (Rect, Enum.ScreenInsets, number)
	ensure()
	local ok, bounds = pcall(function() return GuiService:GetInsetArea(Enum.ScreenInsets.TopbarSafeInsets) end)
	if not ok or bounds.Width <= 0 or bounds.Height <= 0 then
		return HudLayout.GetUsableRect(), Enum.ScreenInsets.CoreUISafeInsets, 0
	end
	local count, total = 0, 0
	for _, child in topbarRow:GetChildren() do
		if child:IsA("GuiButton") and child.Visible then count += 1; total += child.Size.X.Offset end
	end
	local list = topbarRow:FindFirstChildOfClass("UIListLayout")
	if list then total += math.max(0, count - 1) * list.Padding.Offset end
	local reserve = if count > 0 then total + UITheme.Sizes.TopbarGap + UITheme.MobileUI.TravelGap else 0
	return bounds, Enum.ScreenInsets.TopbarSafeInsets, reserve
end

function HudLayout.SetTravelBottom(bottom: number)
	bottom = math.max(0, bottom)
	if travelBottom ~= bottom then travelBottom = bottom; relayout() end
end

-- Resolve the actual visible portion, not just Visible=true. Scrolled-out tutorial targets and
-- buttons in hidden tabs must not receive an outline or initial gamepad selection.
function HudLayout.GetVisibleRect(target: GuiObject?): Rect?
	if not target or not target.Parent then return nil end
	local pos, size = target.AbsolutePosition, target.AbsoluteSize
	local safe = HudLayout.GetTargetSafeRect(target)
	local box = Geometry.Intersection(pos.X, pos.Y, pos.X + size.X, pos.Y + size.Y, safe.Min.X, safe.Min.Y, safe.Max.X, safe.Max.Y)
	local ancestor: Instance? = target
	while ancestor and box do
		if ancestor:IsA("GuiObject") then
			if not ancestor.Visible then return nil end
			if ancestor ~= target and (ancestor.ClipsDescendants or ancestor:IsA("ScrollingFrame")) then
				local clipPos, clipSize = ancestor.AbsolutePosition, ancestor.AbsoluteSize
				if ancestor:IsA("ScrollingFrame") then clipSize = ancestor.AbsoluteWindowSize end
				box = Geometry.Intersection(box.Left, box.Top, box.Right, box.Bottom, clipPos.X, clipPos.Y, clipPos.X + clipSize.X, clipPos.Y + clipSize.Y)
			end
		elseif ancestor:IsA("ScreenGui") and not ancestor.Enabled then return nil end
		ancestor = ancestor.Parent
	end
	return if box then Rect.new(box.Left, box.Top, box.Right, box.Bottom) else nil
end

-- Camera viewport / GetMouseLocation coordinates start at the full display; GUI positions start at the core-safe origin.
function HudLayout.ViewportToGui(point: Vector2): Vector2
	local ok, full = pcall(function() return GuiService:GetInsetArea(Enum.ScreenInsets.None) end)
	return point + (if ok then full.Min else -GuiService:GetGuiInset())
end

local tutorialTargets: { [string]: GuiObject } = {}
function HudLayout.RegisterTutorialTarget(id: string, target: GuiObject?)
	if tutorialTargets[id] == target then return end
	tutorialTargets[id] = target
	if target then target.Destroying:Connect(function() if tutorialTargets[id] == target then tutorialTargets[id] = nil end end) end
end

function HudLayout.GetTutorialTarget(id: string): GuiObject?
	return tutorialTargets[id]
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
local focusClearedListeners: { () -> () } = {}

function HudLayout.ClaimFocus(owner: any, close: () -> ())
	local previous = focused
	focused = { Owner = owner, Close = close }
	if previous and previous.Owner ~= owner then
		previous.Close()
	end
	updatePopupHiding()
end

function HudLayout.ReleaseFocus(owner: any)
	if focused and focused.Owner == owner then
		focused = nil
		for _, fn in focusClearedListeners do
			task.spawn(fn)
		end
		updatePopupHiding()
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
