--!strict
-- A row of reward icons with counts ("[potion] x2  [rune] x1 ...") for a Shared/Rewards reward table.
-- Tooltips name each item. Height sets icon size; the row grows to fit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)
local Tooltip = require(script.Parent.Tooltip)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)

export type Reward = {
	Potions: { [string]: number }?,
	WyrmRunes: number?,
	Dragonstones: number?,
	Stardust: number?,
}

local RewardRow = {}

-- Items in a stable order: potions (Config/Boosts order), then Wyrm Runes, Dragonstones, Stardust.
local function items(reward: Reward): { { Icon: string, Count: number, Name: string, Color: Color3 } }
	local list = {}
	for _, potion in Boosts.Potions do
		local count = reward.Potions and reward.Potions[potion.Id]
		if count and count > 0 then
			table.insert(list, { Icon = `Potion_{potion.Id}`, Count = count, Name = potion.Name, Color = potion.Color })
		end
	end
	if reward.WyrmRunes and reward.WyrmRunes > 0 then
		table.insert(list, { Icon = "WyrmRune", Count = reward.WyrmRunes, Name = "Wyrm Rune", Color = Color3.fromRGB(200, 160, 255) })
	end
	if reward.Dragonstones and reward.Dragonstones > 0 then
		table.insert(list, { Icon = "Dragonstone", Count = reward.Dragonstones, Name = "Dragonstone", Color = Color3.fromRGB(255, 150, 120) })
	end
	if reward.Stardust and reward.Stardust > 0 then
		table.insert(list, { Icon = "Stardust", Count = reward.Stardust, Name = "Stardust", Color = Style.Theme.Colors.Stardust })
	end
	return list
end

function RewardRow.new(parent: Instance, reward: Reward, height: number): Frame
	local row = Instance.new("Frame")
	row.Name = "Rewards"
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Size = UDim2.fromOffset(0, height)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	for index, item in items(reward) do
		local holder = Instance.new("Frame")
		holder.LayoutOrder = index
		holder.BackgroundTransparency = 1
		holder.AutomaticSize = Enum.AutomaticSize.X
		holder.Size = UDim2.fromOffset(0, height)
		holder.Parent = row
		local holderLayout = Instance.new("UIListLayout")
		holderLayout.FillDirection = Enum.FillDirection.Horizontal
		holderLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		holderLayout.Padding = UDim.new(0, 1)
		holderLayout.Parent = holder
		local icon = Icon.new(holder, item.Icon, item.Color, item.Name)
		icon.Size = UDim2.fromOffset(height, height)
		local count = Style.Label(holder, `x{item.Count}`, "Heavy", math.max(12, height - 8), item.Color)
		count.AutomaticSize = Enum.AutomaticSize.X
		count.Size = UDim2.fromOffset(0, height)
		count.TextWrapped = false
		Tooltip.Attach(holder, function()
			return `{item.Count} {item.Name}`
		end)
	end
	row.Parent = parent
	return row
end

return RewardRow
