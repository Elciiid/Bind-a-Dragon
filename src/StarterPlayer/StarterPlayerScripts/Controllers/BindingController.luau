--!strict
-- Shows the result of a successful bind. The server decides everything; this only displays it.
-- A bind at an altar plays the binding ceremony (CeremonyController) and then the toast. Auto-bind pass binds and
-- binds while the player is idle only show the toast. (Refusals arrive as Notify messages, NotificationController.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NotificationController = require(script.Parent.NotificationController)
local CeremonyController = require(script.Parent.CeremonyController)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local IndexConfig = require(ReplicatedStorage.Shared.Config.Index)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

type BindResult = {
	DragonId: string,
	SpeciesId: string,
	ConstellationId: string,
	Luck: number,
	Starborn: boolean,
	Auto: boolean, -- bound by the Auto-bind pass
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
		local prefix = if result.Auto then "Auto-bind: " else ""
		local function toast()
			if result.Starborn then
				NotificationController:Show(`{prefix}STARBORN! You bound a Starborn {species.Name}! ({species.Rarity} {species.Element})`, IndexConfig.StarbornColor)
			else
				NotificationController:Show(`{prefix}You bound {species.Name}! ({species.Rarity} {species.Element})`, color)
			end
		end
		if result.Auto or CeremonyController.IsIdle() then
			toast()
		else
			task.spawn(CeremonyController.Play, { SpeciesId = result.SpeciesId, Starborn = result.Starborn }, toast)
		end
	end)
end

return BindingController
