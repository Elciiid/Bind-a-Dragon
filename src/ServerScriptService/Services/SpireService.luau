--!strict
-- Dragon Spire: server-run auto-battle climbs (numbers in Config/Spire).
--
-- A climb starts from the "Climb the Spire" prompt on any instance tagged "DragonSpire" (a BasePart, or a Model with
-- a PrimaryPart), or SpireAction("Start") while standing near one. Every run starts at stage 1.
-- SpireAction("AutoRepeat", boolean) controls repeat at the top; SpireAction("Stop") ends it. The player must
-- stay within EntranceRange; walking away ends the climb. SpireAction("Difficulty", id) picks the difficulty of the next climb (Easy, Medium,
-- Hard, Infinite: Config/Spire.Difficulties; one that is not unlocked is refused); SpireAction("Board") asks for the weekly Infinite leaderboard.
-- Records are per difficulty (data.SpireRecords). Far-below cleared floors resolve fast (FastFloors) and pay a share of the boss currency;
-- the Spire Haste pass halves every fight.
-- The server fights floor by floor with the player's most powerful dragon (x Wyrmblood Tonic) and sends each step
-- to the client (SpireUpdate) for display. Results and rewards are decided here only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoostService = require(script.Parent.BoostService)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local SpireLeaderboardService = require(script.Parent.SpireLeaderboardService)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local SpireConfig = require(ReplicatedStorage.Shared.Config.Spire)
local BindingConfig = require(ReplicatedStorage.Shared.Config.Binding)
local RebirthMilestones = require(ReplicatedStorage.Shared.RebirthMilestones)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

type Run = { Stop: boolean }

local SPIRE_TAG = "DragonSpire"

local spireAction = ReplicatedStorage.Remotes.SpireAction :: RemoteEvent
local spireUpdate = ReplicatedStorage.Remotes.SpireUpdate :: RemoteEvent
local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local rng = Random.new()
local runs: { [Player]: Run } = {}
local lastAction: { [Player]: number } = {}
local lastStop: { [Player]: number } = {}
local lastBoard: { [Player]: number } = {} -- own limiter: picking Infinite sends Difficulty and Board together
local autoRepeat: { [Player]: boolean } = {} -- session-only, OFF on join
local speciesIds: { string } = {}
for speciesId in Dragons do
	table.insert(speciesIds, speciesId)
end
table.sort(speciesIds)

local SpireService = {}

local function getSpirePosition(spire: Instance): Vector3?
	if spire:IsA("BasePart") then
		return spire.Position
	elseif spire:IsA("Model") then
		return spire:GetPivot().Position
	end
	return nil
end

local function isNearSpire(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	for _, spire in CollectionService:GetTagged(SPIRE_TAG) do
		local position = getSpirePosition(spire)
		if position and (root.Position - position).Magnitude <= SpireConfig.EntranceRange then
			return true
		end
	end
	return false
end

-- Waits up to seconds; returns false if the climb was stopped, the player walked away or left.
local function waitClimbing(player: Player, run: Run, seconds: number): boolean
	local waited = 0
	while waited < seconds do
		if run.Stop or player.Parent ~= Players or not isNearSpire(player) then
			return false
		end
		waited += task.wait(math.min(SpireConfig.CheckInterval, seconds - waited))
	end
	return not run.Stop and player.Parent == Players and isNearSpire(player)
end

local function matches(drop: SpireConfig.Drop, floor: number): boolean
	if drop.SkipBosses and DragonStats.IsBossFloor(floor) then
		return false
	end
	return floor % drop.Every == (drop.Offset or 0)
end

-- Whole units from a fractional amount (a fast floor pays a share of a rune): the fraction is the chance of one more, so the average is exact.
local function roundAmount(amount: number): number
	local whole = math.floor(amount)
	return whole + (if rng:NextNumber() < amount - whole then 1 else 0)
end

-- Rolls a drop table for a floor into a reward (potions are never doubled by Conqueror's Brew).
local function rollDrops(drops: { SpireConfig.Drop }, floor: number, rewardMultiplier: number): Rewards.Reward
	local potions: { [string]: number } = {}
	local reward: Rewards.Reward = { Potions = potions, WyrmRunes = 0, Dragonstones = 0, Stardust = 0 }
	for _, drop in drops do
		if not matches(drop, floor) or rng:NextNumber() >= (drop.Chance or 1) then
			continue
		end
		if drop.Potion then
			potions[drop.Potion] = (potions[drop.Potion] or 0) + 1
		end
		local runes, stones = drop.WyrmRunes or 0, drop.Dragonstones or 0
		if drop.RuneOrStone then
			if rng:NextNumber() < 0.5 then
				runes += 1
			else
				stones += 1
			end
		end
		reward.WyrmRunes = (reward.WyrmRunes or 0) + roundAmount(runes * rewardMultiplier)
		reward.Dragonstones = (reward.Dragonstones or 0) + roundAmount(stones * rewardMultiplier)
		reward.Stardust = (reward.Stardust or 0) + roundAmount((drop.Stardust or 0) * rewardMultiplier)
	end
	-- Drop empty fields so Rewards.Describe stays short.
	if next(potions) == nil then
		reward.Potions = nil
	end
	for _, key in { "WyrmRunes", "Dragonstones", "Stardust" } do
		if (reward :: any)[key] == 0 then
			(reward :: any)[key] = nil
		end
	end
	return reward
end

-- The floor's enemy: (name, species id). Display only; its power comes from DragonStats.GetEnemyPower.
local function getEnemy(floor: number): (string, string)
	local speciesId = speciesIds[(floor * 7) % #speciesIds + 1]
	local species = Dragons[speciesId]
	return if species then species.Name else "Wild Dragon", speciesId
end

-- The base drop table + a difficulty's extra entries (nil extras = the base table itself).
local function joinDrops(base: { SpireConfig.Drop }, extra: { SpireConfig.Drop }?): { SpireConfig.Drop }
	if extra == nil then
		return base
	end
	local joined = table.clone(base)
	for _, drop in extra do
		table.insert(joined, drop)
	end
	return joined
end

-- The difficulty a player's next climb uses: their saved pick, or Easy when that is not unlocked.
local function selectedDifficulty(data: PlayerDataTypes.PlayerData): string
	local id = data.SpireDifficulty
	if SpireConfig.Difficulties[id] ~= nil and id ~= "Order" and DragonStats.IsDifficultyUnlocked(data, id) then
		return id
	end
	return "Easy"
end

local function climb(player: Player, run: Run, difficulty: string)
	local data = DataService:GetData(player)
	if data == nil then
		runs[player] = nil
		return
	end
	local dragon = DragonStats.GetBestDragon(data)
	if dragon == nil then
		runs[player] = nil
		notify:FireClient(player, "You need a dragon to climb the Spire.", "error")
		return
	end
	local def = SpireConfig.Difficulties[difficulty]
	local maxFloors: number? = def.MaxFloors -- nil = Infinite: no top floor
	local haste = if MonetizationService:OwnsPass(player, "SpireHaste") then SpireConfig.Haste.FightSpeed else 1
	local floor = 1
	local result = "Stopped"

	while maxFloors == nil or floor <= maxFloors do
		local best, bestPower = DragonStats.GetBestDragon(data)
		if best == nil then
			break
		end
		local power = bestPower * BoostService:GetMultiplier(player, "SpirePower")
		local enemyPower = DragonStats.GetEnemyPower(floor, difficulty)
		local species = Dragons[best.SpeciesId]
		if run.Stop or not isNearSpire(player) then break end
		-- a floor you have already cleared, far below your power, resolves fast and pays a share of the boss currency (Config/Spire.FastFloors)
		local record = DragonStats.GetSpireRecord(data, difficulty)
		local baseSeconds, share = DragonStats.GetFloorTier(power, enemyPower, floor <= record)
		local seconds = baseSeconds / haste
		local enemyName, enemyId = getEnemy(floor)
		spireUpdate:FireClient(player, {
			Phase = "Fight",
			Difficulty = difficulty,
			Floor = floor,
			Boss = DragonStats.IsBossFloor(floor),
			Dragon = if species then species.Name else "Your dragon",
			SpeciesId = best.SpeciesId, -- for the HUD portraits
			MutationId = best.MutationId or "Normal",
			Level = best.Level,
			Power = power,
			Enemy = enemyName,
			EnemyId = enemyId,
			EnemyPower = enemyPower,
			Seconds = seconds,
			Fast = baseSeconds < SpireConfig.FightSeconds,
			Haste = haste > 1,
			AutoRepeat = autoRepeat[player] == true,
			Record = record,
		})
		if not waitClimbing(player, run, seconds) then
			break
		end
		if power < enemyPower then
			result = "Lost"
			break
		end

		-- Won: rewards. Boss currency = Easy's values x the difficulty's multiplier x the floor's share; a first clear adds that
		-- floor's guaranteed drops (Easy: the full table; the harder difficulties: their extras only) and 30 s of roost income.
		local boost = BoostService:GetMultiplier(player, "SpireRewards")
		local firstClear = floor > record
		local reward: Rewards.Reward
		if firstClear then
			local drops = if def.SkipBaseFirstClear then {} else SpireConfig.FirstClearDrops
			reward = rollDrops(joinDrops(drops, def.ExtraFirstClearDrops), floor, boost * def.FirstClearMultiplier)
		else
			reward = rollDrops(joinDrops(SpireConfig.ReclearDrops, def.ExtraReclearDrops), floor, boost * share)
		end
		local baseline = rollDrops(SpireConfig.VictoryDrops, floor, boost * DragonStats.GetSpireRewardMultiplier(difficulty, floor) * share)
		reward.WyrmRunes = (reward.WyrmRunes or 0) + (baseline.WyrmRunes or 0)
		reward.Dragonstones = (reward.Dragonstones or 0) + (baseline.Dragonstones or 0)
		reward.Stardust = (reward.Stardust or 0) + (baseline.Stardust or 0)
		if reward.WyrmRunes == 0 then reward.WyrmRunes = nil end
		if reward.Dragonstones == 0 then reward.Dragonstones = nil end
		if reward.Stardust == 0 then reward.Stardust = nil end
		local gold = 0
		if firstClear then
			data.SpireRecords[difficulty] = floor
			gold = math.floor(DragonStats.GetRoostIncome(data) * def.FirstClearIncomeSeconds * boost)
			local bankLimit = DragonStats.GetGoldBankLimit(data)
			if bankLimit then
				gold = math.max(0, math.min(gold, bankLimit - data.Gold))
			end
			data.Gold += gold
		end
		Rewards.Apply(data, reward)
		if difficulty == SpireConfig.Leaderboard.Difficulty then
			SpireLeaderboardService:Submit(player, floor)
		end
		do
			local day = os.time() // 86400
			if data.EchoSigilSpireProgressDay ~= day then
				data.EchoSigilSpireProgressDay = day
				data.EchoSigilSpireWins = 0
			end
			data.EchoSigilSpireWins += 1
			if data.EchoSigilSpireWins >= BindingConfig.EchoSigilSpireWins and data.EchoSigilSpireDay ~= day then
				data.EchoSigilSpireDay = day
				local sigilCap = RebirthMilestones.GetEchoSigilCap(data.Rebirths)
				if data.EchoSigils < sigilCap then
					data.EchoSigils += 1
					notify:FireClient(player, `Spire challenge complete: +1 Echo Sigil ({data.EchoSigils}/{sigilCap})`, "success")
				end
			end
		end
		local parts = {}
		if gold > 0 then
			table.insert(parts, `{Format.Number(gold)} gold`)
		end
		local items = Rewards.Describe(reward)
		if items ~= "" then
			table.insert(parts, items)
		end
		spireUpdate:FireClient(player, {
			Phase = "Won",
			Difficulty = difficulty,
			Floor = floor,
			FirstClear = firstClear,
			Rewards = table.concat(parts, ", "),
			Reward = reward, -- the items, so the HUD can fly their icons to the Inventory button
			Gold = gold,
			Record = DragonStats.GetSpireRecord(data, difficulty),
		})
		floor += 1
		if maxFloors and floor > maxFloors then
			result = "Top"
			spireUpdate:FireClient(player, { Phase = "Ended", Difficulty = difficulty, Result = result, Floor = maxFloors, Record = DragonStats.GetSpireRecord(data, difficulty), AutoRepeat = autoRepeat[player] == true })
			if not autoRepeat[player] or not waitClimbing(player, run, SpireConfig.RepeatPauseSeconds) or not autoRepeat[player] then
				break
			end
			floor = 1
			result = "Stopped"
		end
	end

	if maxFloors and floor > maxFloors then
		result = "Top"
	end
	runs[player] = nil
	if result ~= "Top" then
		spireUpdate:FireClient(player, { Phase = "Ended", Difficulty = difficulty, Result = result, Floor = floor, Record = DragonStats.GetSpireRecord(data, difficulty), AutoRepeat = autoRepeat[player] == true })
	end
end

local function tryStart(player: Player)
	if runs[player] then
		return
	end
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	if not isNearSpire(player) then
		notify:FireClient(player, "Go to the Dragon Spire to climb.", "error")
		return
	end
	local difficulty = selectedDifficulty(data)
	local run: Run = { Stop = false }
	runs[player] = run -- reserve synchronously before spawning; duplicate starts cannot race
	task.spawn(function()
		local ok, err = pcall(climb, player, run, difficulty)
		if not ok then
			runs[player] = nil
			warn(`[SpireService] {err}`)
			spireUpdate:FireClient(player, { Phase = "Ended", Result = "Stopped", AutoRepeat = autoRepeat[player] == true })
		end
	end)
end

-- The weekly Infinite leaderboard for the HUD.
local function sendBoard(player: Player)
	local board = SpireLeaderboardService:GetBoard(player)
	spireUpdate:FireClient(player, {
		Phase = "Board",
		Entries = board.Entries,
		MyBest = board.MyBest,
		MyRank = board.MyRank,
		SecondsLeft = board.SecondsLeft,
		Offline = board.Offline,
	})
end

-- SpireAction("Start" | "Stop" | "AutoRepeat" | "Difficulty" | "Board", value?)
local function onSpireAction(player: Player, action: unknown, value: unknown)
	if action ~= "Start" and action ~= "Stop" and action ~= "AutoRepeat" and action ~= "Difficulty" and action ~= "Board" then
		return
	end
	if action == "AutoRepeat" and typeof(value) ~= "boolean" then return end
	if action == "Difficulty" and (typeof(value) ~= "string" or SpireConfig.Difficulties[value] == nil or value == "Order") then return end
	local now = os.clock()
	if action == "Stop" then
		if now - (lastStop[player] or -math.huge) < SpireConfig.StopCooldown then return end
		lastStop[player] = now
	elseif action == "Board" then
		if now - (lastBoard[player] or -math.huge) < SpireConfig.ActionCooldown then return end
		lastBoard[player] = now
	else
		if now - (lastAction[player] or -math.huge) < SpireConfig.ActionCooldown then return end
		lastAction[player] = now
	end
	if action == "Start" then
		tryStart(player)
	elseif action == "AutoRepeat" then
		autoRepeat[player] = value == true
		spireUpdate:FireClient(player, { Phase = "State", AutoRepeat = autoRepeat[player] })
	elseif action == "Difficulty" then
		local data = DataService:GetData(player)
		if data == nil or runs[player] or not DragonStats.IsDifficultyUnlocked(data, value :: string) then
			return -- locked, or a climb is going: the pick cannot change mid-run
		end
		data.SpireDifficulty = value :: string
		spireUpdate:FireClient(player, { Phase = "State", Difficulty = value })
	elseif action == "Board" then
		task.spawn(sendBoard, player)
	elseif runs[player] then
		runs[player].Stop = true
	end
end

-- prompts already connected (a tagged model that is removed and re-added reuses its ClimbPrompt: connect only once)
local hookedPrompts: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function setupSpire(spire: Instance)
	local part = if spire:IsA("BasePart") then spire elseif spire:IsA("Model") then spire.PrimaryPart else nil
	if part == nil then
		warn(`[SpireService] DragonSpire {spire:GetFullName()} needs to be a BasePart or a Model with a PrimaryPart`)
		return
	end
	local existing = spire:FindFirstChild("ClimbPrompt", true)
	local prompt = if existing and existing:IsA("ProximityPrompt") then existing else Instance.new("ProximityPrompt")
	prompt.Name = "ClimbPrompt"
	prompt.ActionText = "Climb the Spire"
	prompt.ObjectText = "Dragon Spire"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = SpireConfig.PromptHoldSeconds
	prompt.MaxActivationDistance = SpireConfig.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	if hookedPrompts[prompt] then
		return
	end
	hookedPrompts[prompt] = true
	prompt.Triggered:Connect(function(player)
		tryStart(player)
	end)
end

-- The same handler the SpireAction remote runs (Studio tools call it through DevService).
SpireService.HandleAction = onSpireAction

function SpireService:IsClimbing(player: Player): boolean
	return runs[player] ~= nil
end

function SpireService:Start()
	spireAction.OnServerEvent:Connect(onSpireAction)
	Players.PlayerRemoving:Connect(function(player)
		if runs[player] then
			runs[player].Stop = true
		end
		lastAction[player] = nil
		lastStop[player] = nil
		lastBoard[player] = nil
		autoRepeat[player] = nil
	end)
	CollectionService:GetInstanceAddedSignal(SPIRE_TAG):Connect(setupSpire)
	for _, spire in CollectionService:GetTagged(SPIRE_TAG) do
		setupSpire(spire)
	end
end

return SpireService
