--!strict
-- Rarity tag: the rarity gem icon and its name in the rarity color (UITheme.Rarity). Sized by the caller's height.

local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)

local RarityTag = {}

function RarityTag.new(parent: Instance, rarityId: string, height: number, showName: boolean?): Frame
	local look = Style.Theme.Rarity[rarityId]
	local color = if look then look.Color else Style.Theme.Colors.TextMuted
	local frame = Instance.new("Frame")
	frame.Name = "RarityTag"
	frame.BackgroundTransparency = 1
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.Size = UDim2.fromOffset(0, height)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local gem = Icon.new(frame, if look then look.Icon else "", color, rarityId)
	gem.LayoutOrder = 1
	gem.Size = UDim2.fromOffset(height, height)
	if showName ~= false then
		local label = Style.Label(frame, rarityId, "Heavy", math.max(11, height - 4), color)
		label.LayoutOrder = 2
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromOffset(0, height)
		label.TextWrapped = false
	end
	frame.Parent = parent
	return frame
end

return RarityTag
