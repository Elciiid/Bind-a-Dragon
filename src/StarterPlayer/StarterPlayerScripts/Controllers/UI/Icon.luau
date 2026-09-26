--!strict
-- An icon from UITheme.Icons (by key, e.g. "Gold", "Potion_HoardElixir") or a raw "rbxassetid://" id.
-- A missing or empty id falls back to a styled tile: a rounded square in the given color with the name's initial.

local Style = require(script.Parent.Style)

local Icon = {}

function Icon.new(parent: Instance, key: string, fallbackColor: Color3?, fallbackText: string?): GuiObject
	local icons = Style.Theme.Icons :: { [string]: string }
	local id = icons[key] or (if key:find("^rbxasset") then key else "")
	if id ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "Icon"
		image.BackgroundTransparency = 1
		image.Image = id
		image.ScaleType = Enum.ScaleType.Fit
		image.Parent = parent
		return image
	end
	local tile = Instance.new("TextLabel")
	tile.Name = "Icon"
	tile.BackgroundColor3 = fallbackColor or Style.Theme.Colors.Neutral
	tile.Text = string.upper(string.sub(fallbackText or key:gsub("^%a+_", ""), 1, 1))
	tile.TextScaled = true
	Style.Text(tile, "Heavy")
	tile.BackgroundTransparency = 0
	Style.Corner(tile, 6)
	Style.Stroke(tile, Style.Theme.Colors.TextStroke, 1.5)
	tile.Parent = parent
	return tile
end

return Icon
