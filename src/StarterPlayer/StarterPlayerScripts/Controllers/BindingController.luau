--!strict
-- Shows the result of a successful bind. The server decides everything; this only displays it.
-- A bind at an altar plays the binding ceremony (CeremonyController) and then the "New dragon!" reward pop-up
-- (NotificationController:Moment). Auto-bind pass binds and binds while the player is idle only show the pop-up. (Refusals arrive as Notify messages, NotificationController.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local NotificationController = require(script.Parent.NotificationController)
local CeremonyController = require(script.Parent.CeremonyController)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local OddsText = require(ReplicatedStorage.Shared.OddsText)
local RevealGate = require(script.Parent.UI.RevealGate)
local Ceremony = require(ReplicatedStorage.Shared.Config.Ceremony)

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
	AutoSoldGold: number?, -- auto sell sold the new dragon for this much gold (shown inside the reveal pop-up)
}

local BindingController = {}
local results: { BindResult } = {}
local processing = false
local responseToken = 0

function BindingController:Start()
	-- Begin before the server grants/syncs the dragon, avoiding an inventory or nameplate spoiler.
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name ~= "BindPrompt" or (player and player ~= Players.LocalPlayer) then return end
		RevealGate.Begin()
		responseToken += 1
		local token = responseToken
		task.delay(Ceremony.ResponseTimeout, function()
			if token == responseToken and not processing then RevealGate.Finish() end
		end)
	end)
	local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent
	notify.OnClientEvent:Connect(function(_, kind)
		if kind == "error" and not processing then RevealGate.Finish() end
	end)
	local bindResult = ReplicatedStorage.Remotes.BindResult :: RemoteEvent
	bindResult.OnClientEvent:Connect(function(result: BindResult)
		table.insert(results, result)
		RevealGate.Begin()
		if processing then return end
		processing = true
		task.spawn(function()
		local ok, err = xpcall(function()
		while #results > 0 do
		RevealGate.Begin()
		local result = table.remove(results, 1) :: BindResult
		local species = Dragons[result.SpeciesId]
		if species == nil then
			continue
		end
		-- a reward pop-up for the new dragon (after the ceremony, or right away for Auto-bind / idle binds)
		local function toast()
			NotificationController:Moment({
				Moment = "NewDragon",
				SpeciesId = result.SpeciesId,
				Level = 1,
				MutationId = result.MutationId,
				Auto = result.Auto,
				AutoSoldGold = result.AutoSoldGold,
				BaseOneIn = result.BaseOneIn,
				EffectiveOneIn = result.EffectiveOneIn,
				SpeciesOneIn = result.SpeciesOneIn,
				MutationOneIn = result.MutationOneIn,
				Luck = result.Luck,
			}, `You bound {species.Name}! {OddsText.Line(result.EffectiveOneIn)}`)
		end
		if result.Auto or CeremonyController.IsIdle() then
			RevealGate.Reveal()
			toast()
		else
			CeremonyController.Play({
				SpeciesId = result.SpeciesId,
				MutationId = result.MutationId,
				BaseOneIn = result.BaseOneIn,
				EffectiveOneIn = result.EffectiveOneIn,
				OnReveal = RevealGate.Reveal,
			}, toast)
		end
		RevealGate.ReleaseDragon(result.DragonId)
		end
		end, debug.traceback)
		if not ok then warn(`[BindingController] Reveal queue failed: {err}`); table.clear(results) end
		processing = false
		RevealGate.Finish()
		end)
	end)
end

return BindingController
