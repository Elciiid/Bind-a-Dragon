--!strict
-- Level-up prompts on the dragons in the local player's own roost (client-only prompts, so nobody else sees them).
-- The prompt shows the dragon, its level and the next level's cost; triggering it asks the server to level up.
-- Stopgap until the dragon inventory UI exists; the server does all the checking either way.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)

local PLOT_TAG = "RoostPlot"
local PROMPT_RANGE = 10
local UPDATE_INTERVAL = 0.3

local levelUpDragon = ReplicatedStorage.Remotes.LevelUpDragon :: RemoteEvent

local DragonPromptController = {}

local prompts: { [Model]: ProximityPrompt } = {}

local function getOwnPlot(): Model?
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
			return plot
		end
	end
	return nil
end

local function ensurePrompt(model: Model, dragonId: string): ProximityPrompt?
	local existing = prompts[model]
	if existing then
		return existing
	end
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if part == nil then
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LevelUpPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		levelUpDragon:FireServer(dragonId, 1)
	end)
	prompt.Parent = part
	prompts[model] = prompt
	return prompt
end

local function update()
	-- Forget prompts whose models were replaced (the server rebuilds a model when its dragon levels up).
	for model in prompts do
		if model.Parent == nil then
			prompts[model] = nil
		end
	end

	local data = DataController:Get()
	local plot = getOwnPlot()
	if data == nil or plot == nil then
		return
	end
	local cap = DragonStats.GetLevelCap(data)

	for _, child in plot:GetChildren() do
		local dragonId = child.Name:match("^Dragon_(.+)$")
		local dragon = dragonId and data.Dragons[dragonId]
		if not child:IsA("Model") or dragon == nil then
			continue
		end
		local prompt = ensurePrompt(child, dragon.Id)
		if prompt == nil then
			continue
		end
		local species = Dragons[dragon.SpeciesId]
		prompt.ObjectText = `{if species then species.Name else "Dragon"}  Lv {dragon.Level}`
		if dragon.Level >= cap then
			prompt.ActionText = "Max level"
		else
			prompt.ActionText = `Level up: {Format.Number(DragonStats.GetLevelUpCost(dragon))} gold`
		end
	end
end

function DragonPromptController:Start()
	while true do
		update()
		task.wait(UPDATE_INTERVAL)
	end
end

return DragonPromptController
