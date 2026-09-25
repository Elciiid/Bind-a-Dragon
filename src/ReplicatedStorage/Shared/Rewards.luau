--!strict
-- Item rewards (potions, Wyrm Runes, Dragonstones, Stardust) used by the Index, quests and later the Spire.
-- Describe is for UI text (client + server). Apply changes player data, so only the server calls it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

export type Reward = {
	Potions: { [string]: number }?, -- Config/Boosts potion Id -> count
	WyrmRunes: number?,
	Dragonstones: number?,
	Stardust: number?,
}

local Rewards = {}

-- "2 Gilded Draught, 1 Wyrm Rune, 30 Stardust"
function Rewards.Describe(reward: Reward): string
	local parts = {}
	for potionId, count in reward.Potions or {} do
		local potion = Boosts.ById[potionId]
		table.insert(parts, `{count} {if potion then potion.Name else potionId}`)
	end
	table.sort(parts)
	if reward.WyrmRunes then
		table.insert(parts, `{reward.WyrmRunes} Wyrm Rune{if reward.WyrmRunes == 1 then "" else "s"}`)
	end
	if reward.Dragonstones then
		table.insert(parts, `{reward.Dragonstones} Dragonstone{if reward.Dragonstones == 1 then "" else "s"}`)
	end
	if reward.Stardust then
		table.insert(parts, `{reward.Stardust} Stardust`)
	end
	return table.concat(parts, ", ")
end

-- Server only.
function Rewards.Apply(data: PlayerDataTypes.PlayerData, reward: Reward)
	for potionId, count in reward.Potions or {} do
		if Boosts.ById[potionId] and count > 0 then
			data.Potions[potionId] = (data.Potions[potionId] or 0) + count
		end
	end
	data.WyrmRunes += reward.WyrmRunes or 0
	data.Dragonstones += reward.Dragonstones or 0
	data.Stardust += reward.Stardust or 0
end

return Rewards
