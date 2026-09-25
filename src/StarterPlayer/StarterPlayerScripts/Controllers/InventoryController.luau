--!strict
-- Dragon inventory: a "Dragons" button opens a panel with a card per dragon (rarity, element, stage, level,
-- gold/sec) and buttons to level up (+1 / +10 / Max) or place it in the roost. The server checks everything.
-- Placeholder UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local levelUpDragon = ReplicatedStorage.Remotes.LevelUpDragon :: RemoteEvent
local placeInRoost = ReplicatedStorage.Remotes.PlaceInRoost :: RemoteEvent

local DARK = Color3.fromRGB(15, 15, 30)
local CARD = Color3.fromRGB(32, 32, 55)
local GOLD = Color3.fromRGB(255, 210, 70)
local GREY = Color3.fromRGB(120, 120, 130)
local REFRESH_INTERVAL = 0.5 -- seconds; the panel only redraws while open

local InventoryController = {}

local panel: Frame
local header: TextLabel
local list: ScrollingFrame
local dirty = true

local function round(instance: GuiObject)
	Instance.new("UICorner").Parent = instance
end

local function label(parent: Instance, text: string, color: Color3, bold: boolean, y: number, height: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.new(0, 8, 0, y)
	l.Size = UDim2.new(1, -16, 0, height)
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = color
	l.Text = text
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, enabled: boolean, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = if enabled then GOLD else GREY
	b.TextColor3 = DARK
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.Text = text
	b.AutoButtonColor = enabled
	round(b)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = b
	b.Activated:Connect(function()
		if enabled then
			onClick()
		end
	end)
	b.Parent = parent
	return b
end

local function makeCard(dragon: PlayerDataTypes.Dragon, data: PlayerDataTypes.PlayerData, cap: number, inRoost: boolean, order: number)
	local species = Dragons[dragon.SpeciesId]
	local rarity = species and DragonStats.GetRarity(species.Rarity)
	local stage = DragonStats.GetStage(dragon.Level)

	local card = Instance.new("Frame")
	card.Name = `Dragon_{dragon.Id}`
	card.LayoutOrder = order
	card.BackgroundColor3 = CARD
	round(card)
	local stroke = Instance.new("UIStroke")
	stroke.Color = if rarity then rarity.Color else GREY
	stroke.Thickness = if inRoost then 2.5 else 1
	stroke.Parent = card
	card.Parent = list

	label(card, if species then species.Name else dragon.SpeciesId, if rarity then rarity.Color else GREY, true, 6, 22)
	label(card, `{if species then species.Rarity else "?"} {if species then species.Element else ""} · {stage.Name}`, Color3.fromRGB(200, 200, 215), false, 30, 16)
	label(card, `Lv {dragon.Level}/{cap} · {Format.Number(DragonStats.GetGoldPerSecond(dragon))} gold/s`, Color3.new(1, 1, 1), false, 48, 16)
	local trait = DragonStats.GetTrait(dragon)
	local grade = DragonStats.GetGrade(dragon)
	label(
		card,
		`Power {Format.Number(DragonStats.GetPower(dragon))} · {if trait then trait.Name else "No trait"} · {if grade then "Grade " .. grade.Id else "No grade"}`,
		Color3.fromRGB(170, 220, 255),
		false,
		66,
		16
	)

	-- Level buttons
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.new(0, 8, 0, 90)
	row.Size = UDim2.new(1, -16, 0, 30)
	row.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.Parent = row

	local atCap = dragon.Level >= cap
	local oneCost = DragonStats.GetLevelUpCost(dragon, data.Rebirths)
	local tenLevels, tenCost = DragonStats.GetBulkLevelCost(dragon, 10, cap, data.Rebirths)
	local plusOne = button(row, if atCap then "Max level" else `+1  {Format.Number(oneCost)}`, not atCap and data.Gold >= oneCost, function()
		levelUpDragon:FireServer(dragon.Id, 1)
	end)
	plusOne.Size = UDim2.new(0.4, -3, 1, 0)
	local plusTen = button(row, `+{math.max(tenLevels, 1)}  {Format.Number(tenCost)}`, tenLevels > 0 and data.Gold >= oneCost, function()
		levelUpDragon:FireServer(dragon.Id, 10) -- server buys as many of the 10 as the player can afford
	end)
	plusTen.Size = UDim2.new(0.35, -3, 1, 0)
	local max = button(row, "Max", not atCap and data.Gold >= oneCost, function()
		levelUpDragon:FireServer(dragon.Id, Leveling.MaxLevelsPerRequest)
	end)
	max.Size = UDim2.new(0.25, -2, 1, 0)

	-- Roost
	if inRoost then
		label(card, "In roost", Color3.fromRGB(130, 230, 140), true, 126, 20)
	else
		local place = button(card, "Place in roost", true, function()
			placeInRoost:FireServer(dragon.Id)
		end)
		place.Position = UDim2.new(0, 8, 0, 126)
		place.Size = UDim2.new(1, -16, 0, 26)
	end
end

local function redraw()
	local data = DataController:Get()
	if data == nil then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local cap = DragonStats.GetLevelCap(data)
	local entries = {}
	for _, dragon in data.Dragons do
		table.insert(entries, {
			Dragon = dragon,
			InRoost = table.find(data.RoostDragonIds, dragon.Id) ~= nil,
			Income = DragonStats.GetGoldPerSecond(dragon),
		})
	end
	-- Roost dragons first, then by income
	table.sort(entries, function(a, b)
		if a.InRoost ~= b.InRoost then
			return a.InRoost
		end
		return a.Income > b.Income
	end)
	for index, entry in entries do
		makeCard(entry.Dragon, data, cap, entry.InRoost, index)
	end

	header.Text = `Your dragons ({#entries})  ·  Roost {#data.RoostDragonIds}/{DragonStats.GetRoostSlots(data)}`
		.. `  ·  {data.WyrmRunes} Wyrm Runes  ·  {data.Dragonstones} Dragonstones`
		.. (if #entries == 0 then "  ·  Bind at a Star Altar at night!" else "")
end

function InventoryController:Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Inventory"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local open = Instance.new("TextButton")
	open.AnchorPoint = Vector2.new(0, 1)
	open.Position = UDim2.new(0, 16, 1, -160) -- above the Rebirth button
	open.Size = UDim2.new(0, 160, 0, 40)
	open.BackgroundColor3 = Color3.fromRGB(170, 220, 255)
	open.TextColor3 = DARK
	open.Font = Enum.Font.GothamBold
	open.TextScaled = true
	open.Text = "Dragons"
	round(open)
	local openPad = Instance.new("UIPadding")
	openPad.PaddingTop = UDim.new(0, 6)
	openPad.PaddingBottom = UDim.new(0, 6)
	openPad.Parent = open
	open.Parent = gui

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.92, 0, 0.75, 0)
	panel.BackgroundColor3 = DARK
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	round(panel)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(700, 520)
	limit.Parent = panel

	header = label(panel, "Your dragons", Color3.new(1, 1, 1), true, 10, 26)
	header.Size = UDim2.new(1, -70, 0, 26)
	header.Position = UDim2.new(0, 14, 0, 10)

	local close = button(panel, "X", true, function()
		panel.Visible = false
	end)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 8)
	close.Size = UDim2.new(0, 36, 0, 30)

	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.new(0, 10, 0, 46)
	list.Size = UDim2.new(1, -20, 1, -56)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 210, 0, 160)
	grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = list

	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
		dirty = true
	end)

	local function markDirty()
		dirty = true
	end
	for _, key in { "Dragons", "RoostDragonIds", "Gold", "Rebirths", "RoostSlotUpgrades", "WyrmRunes", "Dragonstones" } do
		DataController:OnChanged(key, markDirty)
	end
end

function InventoryController:Start()
	while true do
		if dirty and panel.Visible then
			dirty = false
			redraw()
		end
		task.wait(REFRESH_INTERVAL)
	end
end

return InventoryController
