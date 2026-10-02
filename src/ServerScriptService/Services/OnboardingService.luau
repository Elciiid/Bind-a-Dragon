--!strict
-- Saved tutorial progress and rewards. Clients can only opt out, never advance/grant.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)
local RoostService = require(script.Parent.RoostService)
local Config = require(ReplicatedStorage.Shared.Config.Onboarding)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local BindingOdds = require(ReplicatedStorage.Shared.BindingOdds)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Types = require(ReplicatedStorage.Shared.Types.PlayerData)
local skip = ReplicatedStorage.Remotes.SkipTutorial :: RemoteEvent
local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent
local lastRequest: { [Player]: number } = {}
local afterBindNight: { [Player]: number } = {}
local OnboardingService = {}

function OnboardingService:Ensure(data: Types.PlayerData)
	if data.OnboardingStep ~= 0 then return end
	local count = 0
	for _ in data.Dragons do count += 1 end
	if data.Rebirths > 0 or count > 1 or data.LastBindNight >= 0 then
		data.OnboardingStep = Config.Steps.Skipped
		data.OnboardingFirstBindUsed = true
		data.OnboardingFreeLevelUsed = true
	else
		data.OnboardingStep = Config.Steps.Start
	end
end

function OnboardingService:CanFirstBind(data: Types.PlayerData, areaId: string): boolean
	self:Ensure(data)
	return data.OnboardingStep == Config.Steps.Start and not data.OnboardingFirstBindUsed
		and data.Rebirths == 0 and areaId == Config.StarterArea
end

function OnboardingService:DidFirstBind(player: Player, data: Types.PlayerData, bindState: Cycle.State?): number
	data.OnboardingFirstBindUsed = true
	data.OnboardingStep = Config.Steps.Home
	local state = bindState or Cycle.GetState() -- Keep the grant and tutorial threshold on the same clock snapshot.
	-- By day NightIndex already identifies the upcoming night, not the previous one.
	afterBindNight[player] = state.NightIndex - (if state.IsNight then 0 else 1)
	return afterBindNight[player]
end

-- Conditional eligible pool: keeps area/element restrictions and mutation shares.
-- Its normalized odds, not normal home-altar odds, accompany the guaranteed Rare result.
function OnboardingService:GetFirstBindPool(element: string?): { BindingOdds.Outcome }
	local ranks: { [string]: number } = {}
	for index, rarity in Rarities do ranks[rarity.Id] = index end
	local pool: { BindingOdds.Outcome } = {}
	local total = 0
	for _, outcome in BindingOdds.GetPool(Config.StarterArea, element, Config.BindLuck) do
		if (ranks[Dragons[outcome.SpeciesId].Rarity] or 0) >= (ranks[Config.MinimumRarity] or math.huge) then
			total += outcome.BaseWeight
			table.insert(pool, outcome)
		end
	end
	for _, outcome in pool do
		outcome.BaseProbability = outcome.BaseWeight / total
		outcome.EffectiveProbability = outcome.BaseProbability
		outcome.BaseOneIn = 1 / outcome.BaseProbability
		outcome.EffectiveOneIn = outcome.BaseOneIn
	end
	return pool
end

function OnboardingService:RollFirstBind(rng: Random, element: string?): (BindingOdds.Outcome?, number?, number?)
	local pool = self:GetFirstBindPool(element)
	local selected: BindingOdds.Outcome? = nil
	local roll = rng:NextNumber()
	for _, outcome in pool do
		roll -= outcome.EffectiveProbability
		if roll < 0 then selected = outcome; break end
	end
	selected = selected or pool[#pool]
	if selected == nil then return nil, nil, nil end
	local speciesProbability = 0
	for _, outcome in pool do
		if outcome.SpeciesId == selected.SpeciesId then speciesProbability += outcome.EffectiveProbability end
	end
	return selected, 1 / speciesProbability, speciesProbability / selected.EffectiveProbability
end

-- Called only from a manual, ownership/cap-validated request; never Auto-Upgrade.
function OnboardingService:UseFreeLevel(data: Types.PlayerData): boolean
	self:Ensure(data)
	if data.OnboardingStep ~= Config.Steps.Upgrade or data.OnboardingFreeLevelUsed then return false end
	data.OnboardingFreeLevelUsed = true
	data.OnboardingStep = Config.Steps.Night
	return true
end

local function hint(player: Player, data: Types.PlayerData, key: string)
	if data.OnboardingHints[key] then return end
	data.OnboardingHints[key] = true
	-- RevealGate defers notifications until the new dragon has actually been revealed.
	notify:FireClient(player, Text.Onboarding[key], "info")
end

function OnboardingService:Start()
	DataService:OnDataLoaded(function(player, data)
		self:Ensure(data)
		if data.OnboardingStep > 0 and data.OnboardingStep < Config.Steps.Complete then
			local state = Cycle.GetState()
			afterBindNight[player] = if data.LastBindNight >= 0 then data.LastBindNight else state.NightIndex - 1
		end
	end)
	skip.OnServerEvent:Connect(function(player, value: unknown)
		if value ~= true then return end
		local now = os.clock()
		if now - (lastRequest[player] or -math.huge) < Config.RequestInterval then return end
		lastRequest[player] = now
		local data = DataService:GetData(player)
		if data == nil then return end
		data.OnboardingStep = Config.Steps.Skipped
		data.OnboardingFirstBindUsed = true
		data.OnboardingFreeLevelUsed = true
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player], afterBindNight[player] = nil, nil
	end)
	while true do
		local state = Cycle.GetState()
		for _, player in Players:GetPlayers() do
			local data = DataService:GetData(player)
			if data == nil then continue end
			self:Ensure(data)
			if data.OnboardingStep <= 0 then continue end
			if data.OnboardingStep == Config.Steps.Home then
				local plot = RoostService:GetPlot(player)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if plot and root and root:IsA("BasePart")
					and (root.Position - plot:GetPivot().Position).Magnitude <= Config.HomeArrivalRange then
					data.OnboardingStep = Config.Steps.Upgrade
				end
			elseif data.OnboardingStep == Config.Steps.Night and state.IsNight
				and data.LastBindNight ~= state.NightIndex
				and state.NightIndex > (afterBindNight[player] or state.NightIndex - 1) then
				data.OnboardingStep = Config.Steps.Complete
				hint(player, data, "Night")
			end
			if data.OnboardingFirstBindUsed then hint(player, data, "Quests") end
			if data.Gold >= DragonStats.GetRebirthCost(data.Rebirths) * Config.RebirthHintFraction then
				hint(player, data, "Rebirth")
			end
			for _, dragon in data.Dragons do
				if dragon.Level >= Config.SpireHintLevel then hint(player, data, "Spire"); break end
			end
		end
		task.wait(Config.PollSeconds)
	end
end

return OnboardingService
