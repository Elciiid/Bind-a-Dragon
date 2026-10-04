--!strict
-- The Inventory: one window (UI/Window) with tabs (UITheme.InventoryTabs: Dragons | Potions | Items | Collection),
-- opened by the "Inventory" HUD icon. Controllers add their tab with AddTab(id) and get back a Tab that works like a
-- UI/Window for them (Content, IsOpen, Open/Close/Toggle, OnOpen/OnClose), so their code barely changes. A tab's
-- badge count shows on the tab, and the HUD icon's badge is the sum; a pulsing tab makes the HUD icon pulse.
-- Not a service (no Init/Start): built on first use, so it doesn't matter which controller's Init runs first.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local Window = require(script.Parent.UI.Window)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Text = require(ReplicatedStorage.Shared.Config.Text)

local InventoryWindow = {}

export type Tab = {
	Id: string,
	Content: Frame,
	IsOpen: boolean,
	Button: TextButton,
	Badge: TextLabel,
	Count: number,
	Pulsing: boolean,
	OpenCallbacks: { () -> () },
	CloseCallbacks: { () -> () },
	Open: (Tab) -> (),
	Close: (Tab) -> (),
	Toggle: (Tab) -> (),
	OnOpen: (Tab, () -> ()) -> (),
	OnClose: (Tab, () -> ()) -> (),
	SetBadge: (Tab, number) -> (),
	SetPulse: (Tab, boolean) -> (),
}

local window: Window.Window? = nil
local tabBar: ScrollingFrame
local pages: Frame
local tabs: { [string]: Tab } = {}
local current: string? = nil

local function layoutTabs()
	if not window then return end
	local mobile = UITheme.MobileUI
	local count = 0
	for _ in tabs do count += 1 end
	local available = window.Content.AbsoluteSize.X
	local width = math.max(mobile.TabMinWidth, math.floor((available - math.max(0, count - 1) * mobile.Gap) / math.max(1, count)))
	tabBar.Size = UDim2.new(1, 0, 0, mobile.TabHeight + mobile.Scrollbar)
	pages.Position = UDim2.fromOffset(0, mobile.TabHeight + mobile.Scrollbar + mobile.Gap)
	pages.Size = UDim2.new(1, 0, 1, -(mobile.TabHeight + mobile.Scrollbar + mobile.Gap))
	for _, tab in tabs do
		(tab.Button.Parent :: Frame).Size = UDim2.fromOffset(width, mobile.TabHeight)
	end
end

local function updateHud()
	local total, pulse = 0, false
	for _, tab in tabs do
		total += tab.Count
		pulse = pulse or tab.Pulsing
	end
	HudLayout.SetBadge("Inventory", total)
	HudLayout.SetPulse("Inventory", pulse)
end

local function paintTabs()
	local colors = UITheme.Colors
	for id, tab in tabs do
		local selected = id == current
		local back = tab.Button.Parent :: Frame?
		if back then
			local gradient = back:FindFirstChildOfClass("UIGradient")
			if gradient then
				gradient.Color = if selected
					then ColorSequence.new(colors.BannerTop, colors.BannerBottom)
					else ColorSequence.new(colors.TabTop, colors.TabBottom)
			end
			local stroke = back:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if selected then colors.Trim else colors.ButtonStroke
				stroke.Thickness = if selected then 3 else UITheme.Strokes.Button
			end
		end
		tab.Content.Visible = selected
	end
end

-- Shows tab `id` (the window stays as it is); runs callbacks of the tab that closes and the one that opens.
local function select(id: string)
	local win = window :: Window.Window
	if current == id then
		return
	end
	local previous = if current then tabs[current] else nil
	current = id
	paintTabs()
	if win.IsOpen then
		if previous then
			previous.IsOpen = false
			for _, fn in previous.CloseCallbacks do
				task.spawn(fn)
			end
		end
		local tab = tabs[id]
		tab.IsOpen = true
		for _, fn in tab.OpenCallbacks do
			task.spawn(fn)
		end
	end
end

local function ensure(): Window.Window
	if window then
		return window
	end
	local win = Window.new({
		Name = "Inventory",
		Title = Text.Inventory.Title,
		Icon = "Menu_Inventory",
		Size = UDim2.new(0.92, 0, 0.8, 0),
		MaxSize = Vector2.new(740, 580),
	})
	window = win

	tabBar = Instance.new("ScrollingFrame")
	tabBar.Name = "Tabs"
	tabBar.BackgroundTransparency = 1
	tabBar.BorderSizePixel = 0
	tabBar.CanvasSize = UDim2.new()
	tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabBar.ScrollingDirection = Enum.ScrollingDirection.X
	tabBar.ScrollBarThickness = UITheme.MobileUI.Scrollbar
	tabBar.ScrollBarImageColor3 = UITheme.Colors.Trim
	tabBar.Parent = win.Content
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, UITheme.MobileUI.Gap)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.Parent = tabBar

	pages = Instance.new("Frame")
	pages.Name = "Pages"
	pages.BackgroundTransparency = 1
	pages.ClipsDescendants = true
	pages.Parent = win.Content

	HudLayout.OnLayoutChanged(layoutTabs)
	win.Content:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTabs)

	win:OnOpen(function()
		if current == nil then
			local first, order = nil, math.huge
			for id in tabs do
				local look = UITheme.InventoryTabs[id]
				if look and look.Order < order then
					first, order = id, look.Order
				end
			end
			current = first
			paintTabs()
		end
		local tab = if current then tabs[current] else nil
		if tab then
			tab.IsOpen = true
			for _, fn in tab.OpenCallbacks do
				task.spawn(fn)
			end
		end
	end)
	win:OnClose(function()
		local tab = if current then tabs[current] else nil
		if tab then
			tab.IsOpen = false
			for _, fn in tab.CloseCallbacks do
				task.spawn(fn)
			end
		end
	end)

	local open = HudLayout.AddMenuButton("Inventory")
	HudLayout.RegisterTutorialTarget("Inventory", open)
	open.Activated:Connect(function()
		win:Toggle()
	end)
	return win
end

-- Opens the window on tab `id` (e.g. a potion timer opens Potions).
function InventoryWindow.Open(id: string?)
	local win = ensure()
	if id and tabs[id] then
		select(id)
	end
	win:Open()
end

function InventoryWindow.AddTab(id: string): Tab
	local win = ensure()
	local look = UITheme.InventoryTabs[id] or { Label = id, Order = 99, Icon = "" }
	local colors = UITheme.Colors

	-- the tab: a gradient frame in the bar, the (transparent) button filling it
	local back = Instance.new("Frame")
	back.Name = id
	back.LayoutOrder = look.Order
	back.Size = UDim2.new(0.24, -6, 1, 0)
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.Parent = tabBar
	Style.Gradient(back, colors.TabTop, colors.TabBottom)
	Style.Corner(back, UITheme.SmallCorner + 4)
	Style.Stroke(back, colors.ButtonStroke, UITheme.Strokes.Button)
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Text = ""
	button.AutoButtonColor = false
	button.Selectable = true
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromScale(1, 1)
	button.Parent = back
	local iconKey = if (UITheme.Icons[look.Icon] or "") ~= "" then look.Icon else (look.Fallback or look.Icon)
	local icon = Icon.new(button, iconKey)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 6, 0.5, 0)
	icon.Size = UDim2.fromOffset(UITheme.MobileUI.ButtonIcon, UITheme.MobileUI.ButtonIcon)
	icon.ZIndex = 3
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = icon
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Font = UITheme.Fonts.Bold
	label.Text = look.Label
	label.TextColor3 = colors.IconLabel
	label.TextSize = UITheme.MobileUI.Body
	label.TextScaled = true
	label.TextWrapped = true
	local minimum = Instance.new("UITextSizeConstraint")
	minimum.MinTextSize = UITheme.MobileUI.Small
	minimum.MaxTextSize = UITheme.MobileUI.Body
	minimum.Parent = label
	label.Position = UDim2.fromOffset(UITheme.MobileUI.ButtonIcon + UITheme.MobileUI.Padding, 0)
	label.Size = UDim2.new(1, -(UITheme.MobileUI.ButtonIcon + UITheme.MobileUI.Padding + UITheme.MobileUI.Gap), 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 3
	label.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.IconLabelStroke
	stroke.Thickness = 0.5
	stroke.Parent = label
	local badge = Style.Label(button, "", "Heavy", 12)
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -4, 0, 4)
	badge.Size = UDim2.fromOffset(20, 20)
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = colors.Badge
	badge.TextScaled = true
	badge.Visible = false
	badge.ZIndex = 5
	Style.Round(badge)
	Style.Stroke(badge, colors.Text, 1.5)
	Style.Pad(badge, 2)
	Style.AttachPress(button)

	local content = Instance.new("Frame")
	content.Name = id
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.Visible = false
	content.ClipsDescendants = true
	content.Parent = pages

	local tab = {} :: Tab
	tab.Id = id
	tab.Content = content
	tab.IsOpen = false
	tab.Button = button
	tab.Badge = badge
	tab.Count = 0
	tab.Pulsing = false
	tab.OpenCallbacks = {}
	tab.CloseCallbacks = {}
	function tab.Open(self: Tab)
		InventoryWindow.Open(self.Id)
	end
	function tab.Close(self: Tab)
		if self.IsOpen then
			win:Close()
		end
	end
	function tab.Toggle(self: Tab)
		if self.IsOpen then
			win:Close()
		else
			InventoryWindow.Open(self.Id)
		end
	end
	function tab.OnOpen(self: Tab, fn: () -> ())
		table.insert(self.OpenCallbacks, fn)
	end
	function tab.OnClose(self: Tab, fn: () -> ())
		table.insert(self.CloseCallbacks, fn)
	end
	function tab.SetBadge(self: Tab, count: number)
		self.Count = count
		self.Badge.Text = if count > 99 then "99+" else tostring(count)
		self.Badge.Visible = count > 0
		updateHud()
	end
	function tab.SetPulse(self: Tab, on: boolean)
		self.Pulsing = on
		updateHud()
	end
	tabs[id] = tab

	button.Activated:Connect(function()
		select(id)
	end)
	layoutTabs()
	paintTabs()
	return tab
end

return InventoryWindow
