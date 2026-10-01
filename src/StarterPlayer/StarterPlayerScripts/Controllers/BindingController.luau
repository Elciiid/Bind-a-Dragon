--!strict
-- Shows the result of a successful bind. The server decides everything; this only displays it.
-- A bind at an altar plays the binding ceremony (CeremonyController) and then the "New dragon!" reward pop-up
-- (NotificationController:Moment). Auto-bind pass binds and binds while the player is idle only show the pop-up. (Refusals arrive as Notify messages, NotificationController.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NotificationController = require(script.Parent.NotificationController)
local CeremonyController = require(script.Parent.CeremonyController)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local OddsText = require(ReplicatedStorage.Shared.OddsText)

type BindResult = {
	DragonId: string,
	SpeciesId: string,
	ConstellationId: string,
	Luck: number,
	MutationId: string,
	BaseOneIn: number,
	EffectiveOneIn: number,
	SpeciesOneIn: number,
	MutationOneIn: number,
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
		-- a reward pop-up for the new dragon (after the ceremony, or right away for Auto-bind / idle binds)
		local function toast()
			NotificationController:Moment({
				Moment = "NewDragon",
				SpeciesId = result.SpeciesId,
				Level = 1,
				MutationId = result.MutationId,
				Auto = result.Auto,
				BaseOneIn = result.BaseOneIn,
				EffectiveOneIn = result.EffectiveOneIn,
				SpeciesOneIn = result.SpeciesOneIn,
				MutationOneIn = result.MutationOneIn,
				Luck = result.Luck,
			}, `You bound {species.Name}! {OddsText.Line(result.EffectiveOneIn)}`)
		end
		if result.Auto or CeremonyController.IsIdle() then
			toast()
		else
			task.spawn(CeremonyController.Play, {
				SpeciesId = result.SpeciesId,
				MutationId = result.MutationId,
				BaseOneIn = result.BaseOneIn,
				EffectiveOneIn = result.EffectiveOneIn,
			}, toast)
		end
	end)
end

return BindingController
