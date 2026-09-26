--!strict
-- Tooltips: hover on PC, long-press on touch screens. One shared tooltip card follows the pointer.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Style = require(script.Parent.Style)

local Tooltip = {}

local gui: ScreenGui? = nil
local card: Frame
local label: TextLabel
local owner: GuiObject? = nil

local function ensure()
	if gui then
		return
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "Tooltip"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = Style.Theme.Layers.Notifications + 1
	screen.IgnoreGuiInset = true -- mouse positions are screen coordinates
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = screen

	card = Instance.new("Frame")
	card.AutomaticSize = Enum.AutomaticSize.XY
	card.Size = UDim2.fromOffset(0, 0)
	card.Visible = false
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Gradient(card, Style.Theme.Colors.PanelTop, Style.Theme.Colors.PanelBottom)
	Style.Corner(card, 6)
	Style.Stroke(card, Style.Theme.Colors.Trim, 1.5)
	Style.Pad(card, 8, 5)
	card.Parent = screen

	label = Style.Label(card, "", "Bold", Style.Theme.TextSizes.Small)
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.TextWrapped = false
end

local function show(target: GuiObject, text: string, position: Vector2)
	ensure()
	owner = target
	label.Text = text
	card.Position = UDim2.fromOffset(position.X + 14, position.Y + 10)
	card.Visible = true
end

local function hide(target: GuiObject)
	if owner == target and card then
		card.Visible = false
		owner = nil
	end
end

-- getText is called each time the tooltip shows, so it can read live values.
function Tooltip.Attach(target: GuiObject, getText: () -> string)
	target.MouseEnter:Connect(function(x, y)
		if not UserInputService.TouchEnabled then
			show(target, getText(), Vector2.new(x, y))
		end
	end)
	target.MouseMoved:Connect(function(x, y)
		if owner == target then
			card.Position = UDim2.fromOffset(x + 14, y + 10)
		end
	end)
	target.MouseLeave:Connect(function()
		hide(target)
	end)
	target.TouchLongPress:Connect(function(positions, state)
		if state == Enum.UserInputState.Begin then
			local p = positions[1]
			show(target, getText(), Vector2.new(p.X, p.Y))
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			hide(target)
		end
	end)
end

return Tooltip
