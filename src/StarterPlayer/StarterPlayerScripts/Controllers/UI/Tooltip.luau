--!strict
-- One wrapped, measured details card. Hover follows the pointer; Details buttons latch on touch.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local Style = require(script.Parent.Style)
local HudLayout = require(script.Parent.Parent.HudLayout)
local Layout = require(ReplicatedStorage.Shared.Config.Layout)
local Tooltip = {}
local gui: ScreenGui? = nil
local card: ScrollingFrame
local label: TextLabel
local owner: GuiObject? = nil
local reader: (() -> string)? = nil
local position = Vector2.zero
local latched = false

local function hide()
	if card then card.Visible = false end
	owner = nil
	reader = nil
	latched = false
end

local function redraw()
	if not owner or not reader then return end
	local bounds = HudLayout.GetUsableRect()
	local margin = Layout.SafeMargin
	local width = math.max(1, math.min(Layout.TooltipWidth, bounds.Width - margin * 2))
	local padding = Layout.TooltipPadding
	label.Text = reader()
	local measure = TextService:GetTextSize(label.Text, label.TextSize, label.Font, Vector2.new(math.max(1, width - padding * 2), math.huge))
	local contentHeight = math.ceil(measure.Y) + padding * 2
	local height = math.min(contentHeight, math.max(1, bounds.Height - margin * 2))
	card.Size = UDim2.fromOffset(width, height)
	card.CanvasSize = UDim2.fromOffset(0, contentHeight)
	label.Position = UDim2.fromOffset(padding, padding)
	label.Size = UDim2.fromOffset(width - padding * 2, measure.Y)
	local x = position.X + Layout.TooltipOffset.X
	local y = position.Y + Layout.TooltipOffset.Y
	if x + width > bounds.Max.X - margin then x = position.X - width - Layout.TooltipOffset.X end
	if y + height > bounds.Max.Y - margin then y = position.Y - height - Layout.TooltipOffset.Y end
	card.Position = UDim2.fromOffset(math.clamp(x, bounds.Min.X + margin, math.max(bounds.Min.X + margin, bounds.Max.X - width - margin)), math.clamp(y, bounds.Min.Y + margin, math.max(bounds.Min.Y + margin, bounds.Max.Y - height - margin)))
end

local function ensure()
	if gui then return end
	local screen = HudLayout.MakeScreenGui("Tooltip", "Notifications")
	screen.DisplayOrder = Style.Theme.Layers.Notifications + 1
	screen.ScreenInsets = Enum.ScreenInsets.None -- pointer and safe rectangle are screen coordinates
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = screen
	card = Instance.new("ScrollingFrame")
	card.Visible = false
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.BorderSizePixel = 0
	card.ScrollBarThickness = 4
	Style.Gradient(card, Style.Theme.Colors.PanelTop, Style.Theme.Colors.PanelBottom)
	Style.Corner(card, 6)
	Style.Stroke(card, Style.Theme.Colors.Trim, 1.5)
	card.Parent = screen
	label = Style.Label(card, "", "Bold", Style.Theme.TextSizes.Small)
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < Layout.TooltipRefreshSeconds then return end
		elapsed = 0
		if owner then
			local ancestor: Instance? = owner
			while ancestor do
				if (ancestor:IsA("GuiObject") and not ancestor.Visible) or (ancestor:IsA("ScreenGui") and not ancestor.Enabled) then hide(); return end
				ancestor = ancestor.Parent
			end
			redraw()
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if latched and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
			local p = Vector2.new(input.Position.X, input.Position.Y)
			local withinCard = p.X >= card.AbsolutePosition.X and p.X <= card.AbsolutePosition.X + card.AbsoluteSize.X and p.Y >= card.AbsolutePosition.Y and p.Y <= card.AbsolutePosition.Y + card.AbsoluteSize.Y
			local target = owner
			local withinOwner = target ~= nil and p.X >= target.AbsolutePosition.X and p.X <= target.AbsolutePosition.X + target.AbsoluteSize.X and p.Y >= target.AbsolutePosition.Y and p.Y <= target.AbsolutePosition.Y + target.AbsoluteSize.Y
			if not withinCard and not withinOwner then hide() end
		end
	end)
end

local function show(target: GuiObject, getText: () -> string, p: Vector2)
	ensure()
	owner = target
	reader = getText
	position = p
	card.CanvasPosition = Vector2.zero
	redraw()
	card.Visible = true
end

function Tooltip.Toggle(target: GuiObject, getText: () -> string, p: Vector2)
	if owner == target and latched then hide(); return end
	show(target, getText, p)
	latched = true
end

function Tooltip.Attach(target: GuiObject, getText: () -> string)
	target.MouseEnter:Connect(function(x, y)
		if not UserInputService.TouchEnabled and not latched then show(target, getText, Vector2.new(x, y)) end
	end)
	target.MouseMoved:Connect(function(x, y)
		if owner == target and not latched then position = Vector2.new(x, y); redraw() end
	end)
	target.MouseLeave:Connect(function() if owner == target and not latched then hide() end end)
	target:GetPropertyChangedSignal("Visible"):Connect(function() if not target.Visible and owner == target then hide() end end)
	target.AncestryChanged:Connect(function() if target.Parent == nil and owner == target then hide() end end)
	-- Touch uses an explicit Details button so pressing Upgrade never opens a tooltip.
end

return Tooltip
