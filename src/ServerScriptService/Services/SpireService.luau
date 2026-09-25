--!strict
-- Dragon Spire: server-run auto-battle climbs (numbers in Config/Spire).
--
-- A climb starts from the "Climb the Spire" prompt on any instance tagged "DragonSpire" (a BasePart, or a Model with
-- a PrimaryPart), or SpireAction("Start", useElevator) while standing near one. The Tower Elevator (pass or
-- Elevator Skip product, MonetizationService) starts the climb above the record. SpireAction("Stop") ends it. The player must
-- stay within EntranceRange; walking away ends the climb.
-- The server fights floor by floor with the player's most powerful dragon (x Wyrmblood Tonic) and sends each step
-- to the client (SpireUpdate) for display. Results and rewards are decided here only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoostService = require(script.Parent.BoostService)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local SpireConfig = require(ReplicatedStorage.Shared.Config.Spire)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

type PlayerData = PlayerDataTypes.PlayerData
type Run = { Stop: boolean }

local SPIRE_TAG = "DragonSpire"
local CHECK_INTERVAL = 0.25
local ACTION_COOLDOWN = 0.5

local spireAction = ReplicatedStorage.Remotes.SpireAction :: RemoteEvent
local spireUpdate = ReplicatedStorage.Remotes.SpireUpdate :: RemoteEvent
local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local rng = Random.new()
local runs: { [Player]: Run } = {}
local lastAction: { [Player]: number } = {}
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
	if root == nil or not root:IsA("BasePart") then
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
		waited += task.wait(math.min(CHECK_INTERVAL, seconds - waited))
	end
	return not run.Stop and player.Parent == Players
end

local function matches(drop: SpireConfig.Drop, floor: number): boolean
	if drop.SkipBosses and DragonStats.IsBossFloor(floor) then
		return false
	end
	return floor % drop.Every == (drop.Offset or 0)
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
		reward.WyrmRunes = (reward.WyrmRunes or 0) + runes * rewardMultiplier
		reward.Dragonstones = (reward.Dragonstones or 0) + stones * rewardMultiplier
		reward.Stardust = (reward.Stardust or 0) + (drop.Stardust or 0) * rewardMultiplier
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

local function getEnemy(floor: number): string
	local speciesId = speciesIds[(floor * 7) % #speciesIds + 1]
	local species = Dragons[speciesId]
	return if species then species.Name else "Wild Dragon"
end

-- The Tower Elevator (pass, or one Elevator Skip) starts above the record: no fast floors and no re-clears.
local function getStartFloor(player: Player, data: PlayerData, useElevator: boolean): number?
	if not useElevator then
		return 1
	end
	if data.SpireRecord <= 0 or data.SpireRecord >= SpireConfig.MaxFloors then
		notify:FireClient(player, "The elevator opens once you've cleared a floor, and stops below the top.", "error")
		return nil
	end
	if not MonetizationService:UseElevator(player, data) then
		notify:FireClient(player, "You need the Tower Elevator pass or an Elevator Skip.", "error")
		return nil
	end
	return data.SpireRecord + 1
end

local function climb(player: Player, useElevator: boolean)
	local data = DataService:GetData(player)
	if data == nil or runs[player] then
		return
	end
	local dragon = DragonStats.GetBestDragon(data)
	if dragon == nil then
		notify:FireClient(player, "You need a dragon to climb the Spire.", "error")
		return
	end
	local run: Run = { Stop = false }
	runs[player] = run

	local record = data.SpireRecord
	local startFloor = getStartFloor(player, data, useElevator)
	if startFloor == nil then
		runs[player] = nil
		return
	end
	local floor = startFloor
	local fastUntil = math.max(floor - 1, record - SpireConfig.TopWindow)
	local result = "Stopped"

	-- Floors far below the record: fast, no drops.
	if fastUntil >= floor then
		local seconds = (fastUntil - floor + 1) * SpireConfig.FastFloorSeconds
		spireUpdate:FireClient(player, { Phase = "Fast", From = floor, To = fastUntil, Seconds = seconds, Record = record })
		if not waitClimbing(player, run, seconds) then
			runs[player] = nil
			spireUpdate:FireClient(player, { Phase = "Ended", Result = result, Floor = floor, Record = data.SpireRecord })
			return
		end
		floor = fastUntil + 1
	end

	while floor <= SpireConfig.MaxFloors do
		local best, bestPower = DragonStats.GetBestDragon(data)
		if best == nil then
			break
		end
		local power = bestPower * BoostService:GetMultiplier(player, "SpirePower")
		local enemyPower = DragonStats.GetEnemyPower(floor)
		local species = Dragons[best.SpeciesId]
		spireUpdate:FireClient(player, {
			Phase = "Fight",
			Floor = floor,
			Boss = DragonStats.IsBossFloor(floor),
			Dragon = if species then species.Name else "Your dragon",
			Power = power,
			Enemy = getEnemy(floor),
			EnemyPower = enemyPower,
			Seconds = SpireConfig.FightSeconds,
			Record = data.SpireRecord,
		})
		if not waitClimbing(player, run, SpireConfig.FightSeconds) then
			break
		end
		if power < enemyPower then
			result = "Lost"
			break
		end

		-- Won: rewards.
		local rewardMultiplier = BoostService:GetMultiplier(player, "SpireRewards")
		local firstClear = floor > data.SpireRecord
		local reward = rollDrops(if firstClear then SpireConfig.FirstClearDrops else SpireConfig.ReclearDrops, floor, rewardMultiplier)
		local gold = 0
		if firstClear then
			data.SpireRecord = floor
			gold = math.floor(DragonStats.GetRoostIncome(data) * SpireConfig.FirstClearIncomeSeconds * rewardMultiplier)
			data.Gold += gold
		end
		Rewards.Apply(data, reward)
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
			Floor = floor,
			FirstClear = firstClear,
			Rewards = table.concat(parts, ", "),
			Record = data.SpireRecord,
		})
		floor += 1
	end

	if floor > SpireConfig.MaxFloors then
		result = "Top"
	end
	runs[player] = nil
	spireUpdate:FireClient(player, { Phase = "Ended", Result = result, Floor = floor, Record = data.SpireRecord })
end

local function tryStart(player: Player, useElevator: boolean)
	if runs[player] then
		return
	end
	if not isNearSpire(player) then
		notify:FireClient(player, "Go to the Dragon Spire to climb.", "error")
		return
	end
	task.spawn(climb, player, useElevator)
end

-- SpireAction(action, useElevator?)
local function onSpireAction(player: Player, action: unknown, useElevator: unknown)
	if action ~= "Start" and action ~= "Stop" then
		return
	end
	local now = os.clock()
	if now - (lastAction[player] or 0) < ACTION_COOLDOWN then
		return
	end
	lastAction[player] = now
	if action == "Start" then
		tryStart(player, useElevator == true)
	elseif runs[player] then
		runs[player].Stop = true
	end
end

local function setupSpire(spire: Instance)
	local part = if spire:IsA("BasePart") then spire elseif spire:IsA("Model") then spire.PrimaryPart else nil
	if part == nil then
		warn(`[SpireService] DragonSpire {spire:GetFullName()} needs to be a BasePart or a Model with a PrimaryPart`)
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ClimbPrompt"
	prompt.ActionText = "Climb the Spire"
	prompt.ObjectText = "Dragon Spire"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = SpireConfig.PromptHoldSeconds
	prompt.MaxActivationDistance = 15
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		tryStart(player, false)
	end)
end

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
	end)
	CollectionService:GetInstanceAddedSignal(SPIRE_TAG):Connect(setupSpire)
	for _, spire in CollectionService:GetTagged(SPIRE_TAG) do
		setupSpire(spire)
	end
end

return SpireService
