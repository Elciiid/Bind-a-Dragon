--!strict
-- Shows the result of a successful bind. The server decides everything; this only displays it.
-- (Refusals arrive as Notify messages, handled by NotificationController.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NotificationController = require(script.Parent.NotificationController)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

type BindResult = {
	DragonId: string,
	SpeciesId: string,
	ConstellationId: string,
	Luck: number,
}

local BindingController = {}

function BindingController:Start()
	local bindResult = ReplicatedStorage.Remotes.BindResult :: RemoteEvent
	bindResult.OnClientEvent:Connect(function(result: BindResult)
		local species = Dragons[result.SpeciesId]
		if species == nil then
			return
		end
		local color = Color3.new(1, 1, 1)
		for _, rarity in Rarities do
			if rarity.Id == species.Rarity then
				color = rarity.Color
			end
		end
		NotificationController:Show(`You bound {species.Name}! ({species.Rarity} {species.Element})`, color)
	end)
end

return BindingController
