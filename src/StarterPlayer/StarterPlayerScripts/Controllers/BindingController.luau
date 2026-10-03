--!strict
-- One queue of confirmed server results. Ceremony/result cards are presentation only; skipping never rolls,
-- grants, rerolls, changes rewards or acknowledges a purchase. Odds are frozen from this BindResult, not live luck.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local NotificationController = require(script.Parent.NotificationController)
local CeremonyController = require(script.Parent.CeremonyController)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local OddsText = require(ReplicatedStorage.Shared.OddsText)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local RevealGate = require(script.Parent.UI.RevealGate)
local Ceremony = require(ReplicatedStorage.Shared.Config.Ceremony)
local OnboardingController = require(script.Parent.OnboardingController)

type BindResult = {
	DragonId: string, SpeciesId: string, ConstellationId: string, Luck: number, MutationId: string,
	BaseOneIn: number, EffectiveOneIn: number, SpeciesOneIn: number, MutationOneIn: number, Auto: boolean,
	TutorialFirstBind: boolean?,
}

local BindingController = {}
local results: { BindResult } = {}
local processing = false
local responseToken = 0

local function present(result: BindResult)
	local species = Dragons[result.SpeciesId]
	if not species then
		warn("[BindingController] Unknown confirmed species: " .. tostring(result.SpeciesId))
		RevealGate.ReleaseDragon(result.DragonId)
		return
	end
	local mutation = Mutations.Get(result.MutationId)
	-- Presentation snapshots only. Authoritative dragon stats continue to come from server/shared calculations.
	local payload = {
		Moment = "NewDragon", DragonId = result.DragonId, SpeciesId = result.SpeciesId, Level = 1,
		MutationId = mutation.Id, Auto = result.Auto, BaseOneIn = result.BaseOneIn,
		EffectiveOneIn = result.EffectiveOneIn, SpeciesOneIn = result.SpeciesOneIn,
		MutationOneIn = result.MutationOneIn, Luck = result.Luck, TutorialFirstBind = result.TutorialFirstBind,
		BaseGoldPerSecond = species.BaseGoldPerSecond, BasePower = species.BasePower,
		MutationIncomeMultiplier = mutation.IncomeMultiplier, MutationPowerMultiplier = mutation.PowerMultiplier,
	}
	local delivered = false
	local function resultCard()
		if delivered then return end
		delivered = true
		local odds = Text.Format(Text.Odds.Plain, { oneIn = OddsText.OneInExact(result.EffectiveOneIn) })
		NotificationController:Moment(payload, species.Name .. " · " .. odds)
	end
	local ok, err = xpcall(function()
		if result.TutorialFirstBind then OnboardingController.PlayFirstBind() end
		if result.Auto or CeremonyController.IsIdle() then
			RevealGate.Reveal()
			resultCard()
		else
			CeremonyController.Play({
				SpeciesId = result.SpeciesId, MutationId = mutation.Id,
				BaseOneIn = result.BaseOneIn, EffectiveOneIn = result.EffectiveOneIn,
				OnReveal = RevealGate.Reveal,
			}, resultCard)
		end
	end, debug.traceback)
	if not ok then
		warn("[BindingController] Confirmed result fallback: " .. tostring(err))
		RevealGate.Reveal()
		resultCard()
	end
	-- Exactly one card and one announcement release, including skips, missing art and ceremony errors.
	RevealGate.ReleaseDragon(result.DragonId)
end

function BindingController:Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name ~= "BindPrompt" or (player and player ~= Players.LocalPlayer) then return end
		RevealGate.Begin()
		responseToken += 1
		local token = responseToken
		task.delay(Ceremony.ResponseTimeout, function()
			if token == responseToken and not processing then RevealGate.Cancel() end
		end)
	end)
	local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent
	notify.OnClientEvent:Connect(function(_, kind)
		if kind == "error" and not processing then RevealGate.Cancel() end
	end)
	local bindResult = ReplicatedStorage.Remotes.BindResult :: RemoteEvent
	bindResult.OnClientEvent:Connect(function(result: BindResult)
		responseToken += 1 -- invalidate the unanswered-request timer
		table.insert(results, table.clone(result))
		RevealGate.Begin()
		if processing then return end
		processing = true
		task.spawn(function()
			local ok, err = xpcall(function()
				while #results > 0 do
					RevealGate.Begin()
					present(table.remove(results, 1) :: BindResult)
				end
			end, debug.traceback)
			if not ok then
				warn("[BindingController] Reveal queue cleanup: " .. tostring(err))
				for _, pending in results do RevealGate.ReleaseDragon(pending.DragonId) end
				table.clear(results)
			end
			processing = false
			RevealGate.Finish()
		end)
	end)
end

return BindingController
