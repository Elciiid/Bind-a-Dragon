--!strict
-- Gold and Stardust counters in the bottom-left corner. Placeholder UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)

local CurrencyController = {}

local function makeCounter(parent: Instance, name: string, color: Color3, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.Size = UDim2.new(0, 260, 0, 40)
	label.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = `{name}: ...`
	Instance.new("UICorner").Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 7)
	padding.PaddingBottom = UDim.new(0, 7)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = label
	label.Parent = parent
	return label
end

function CurrencyController:Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Currency"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local column = Instance.new("Frame")
	column.AnchorPoint = Vector2.new(0, 1)
	column.Position = UDim2.new(0, 16, 1, -16)
	column.Size = UDim2.new(0, 260, 0, 86)
	column.BackgroundTransparency = 1
	column.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = column

	local gold = makeCounter(column, "Gold", Color3.fromRGB(255, 210, 70), 1)
	local stardust = makeCounter(column, "Stardust", Color3.fromRGB(170, 220, 255), 2)

	-- Gold shows the roost's income too, e.g. "Gold: 1.2K (+25/s)".
	local function updateGold()
		local data = DataController:Get()
		if data == nil then
			return
		end
		local income = DragonStats.GetRoostIncome(data)
		local incomeText = if income > 0 then `  (+{Format.Number(income)}/s)` else ""
		gold.Text = `Gold: {Format.Number(data.Gold)}{incomeText}`
	end
	DataController:OnChanged("Gold", updateGold)
	DataController:OnChanged("Dragons", updateGold)
	DataController:OnChanged("RoostDragonIds", updateGold)
	DataController:OnChanged("Stardust", function(value: number)
		stardust.Text = `Stardust: {Format.Number(value)}`
	end)
end

return CurrencyController
