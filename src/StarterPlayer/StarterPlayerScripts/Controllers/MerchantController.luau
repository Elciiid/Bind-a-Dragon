--!strict
-- Shows this player's own Stardust price on the Star Merchant's prompt (prices are per player and rise per
-- purchase, so the shared prompt text can't hold it). Local-only change; the server decides the real price.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local MERCHANT_TAG = "StarMerchant"
local UPDATE_INTERVAL = 0.5

local MerchantController = {}

function MerchantController:Start()
	while true do
		local data = DataController:Get()
		if data then
			local price = DragonStats.GetMerchantPrice(data, Cycle.GetState().NightIndex)
			for _, merchant in CollectionService:GetTagged(MERCHANT_TAG) do
				local prompt = merchant:FindFirstChild("BuyStardustPrompt", true)
				if prompt and prompt:IsA("ProximityPrompt") then
					prompt.ActionText = `Buy {Economy.Merchant.BundleSize} Stardust: {Format.Number(price)} gold`
				end
			end
		end
		task.wait(UPDATE_INTERVAL)
	end
end

return MerchantController
