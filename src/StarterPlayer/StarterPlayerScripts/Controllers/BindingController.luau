--!strict
-- Shows the result of a bind. The server decides everything; this only displays it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NotificationController = require(script.Parent.NotificationController)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

type BindResult = {
	Ok: boolean,
	Message: string?,
	SpeciesId: string?,
}

local BindingController = {}

function BindingController:Start()
	local bindResult = ReplicatedStorage.Remotes.BindResult :: RemoteEvent
	bindResult.OnClientEvent:Connect(function(result: BindResult)
		if not result.Ok then
			NotificationController:Show(result.Message or "Binding failed.", Color3.fromRGB(255, 120, 120))
			return
		end

		local species = Dragons[result.SpeciesId :: string]
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
