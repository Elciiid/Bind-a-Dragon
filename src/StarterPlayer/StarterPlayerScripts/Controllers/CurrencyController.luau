--!strict
-- Gold and Stardust counters. HudLayout places them (bottom-left on PC, top-left on phones). Placeholder UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local CurrencyController = {}

function CurrencyController:Init()
	local gold = HudLayout.AddCurrencyLabel("Gold", Theme.Colors.Gold, 1)
	local stardust = HudLayout.AddCurrencyLabel("Stardust", Theme.Colors.Stardust, 2)
	gold.Text = "Gold: ..."
	stardust.Text = "Stardust: ..."

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
