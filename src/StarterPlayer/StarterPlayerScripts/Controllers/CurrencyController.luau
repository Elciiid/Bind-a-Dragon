--!strict
-- Gold and Stardust pills (UI/CurrencyPill via HudLayout: bottom-left on PC, top-left on phones).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local CurrencyController = {}

function CurrencyController:Init()
	local gold = HudLayout.AddCurrency("Gold", UITheme.Colors.Gold, 1)
	local stardust = HudLayout.AddCurrency("Stardust", UITheme.Colors.Stardust, 2)
	gold:Set("...")
	stardust:Set("...")

	-- Gold shows the roost's income too, e.g. "1.2K  +25/s".
	local function updateGold()
		local data = DataController:Get()
		if data == nil then
			return
		end
		local income = DragonStats.GetRoostIncome(data)
		local incomeText = if income > 0 then `  +{Format.Number(income)}/s` else ""
		gold:Set(`{Format.Number(data.Gold)}{incomeText}`)
	end
	DataController:OnChanged("Gold", updateGold)
	DataController:OnChanged("Dragons", updateGold)
	DataController:OnChanged("RoostDragonIds", updateGold)
	DataController:OnChanged("Stardust", function(value: number)
		stardust:Set(Format.Number(value))
	end)
end

return CurrencyController
