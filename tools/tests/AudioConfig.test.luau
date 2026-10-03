--!strict
-- CLI config-contract check; deliberately does not pretend to load Roblox assets outside Studio.
local audio = require("../../src/ReplicatedStorage/Shared/Config/Audio")
local expected = { "StarterMeadow", "VolcanoPeak", "FrozenCliffs", "StormCanyon", "EclipseIsles" }
local count = 0
for _, area in expected do
	local config = audio.Areas[area]
	assert(config, `Missing area {area}`)
	for _, key in { "DayMusic", "NightMusic", "DayAmbience", "NightAmbience" } do
		assert(string.match(config[key], "^rbxassetid://%d+$"), `Invalid {area}/{key}`)
		count += 1
	end
end
assert(audio.Areas[audio.DefaultArea], "Invalid fallback")
assert(audio.CrossfadeSmoothing > 0 and audio.AreaPollSeconds > 0)
for _, rarity in { "Common", "Rare", "Epic", "Legendary", "Mythic", "Primordial" } do
	local cue = audio.Bind[rarity]
	assert(cue and cue.Volume >= 0 and cue.Volume <= 1 and cue.Seconds > 0)
end
assert(audio.Bind.Common.Seconds < audio.Bind.Mythic.Seconds)
assert(audio.Dragon.MaxSimultaneous <= 3 and audio.Dragon.MaxDistance > audio.Dragon.MinDistance)
for _, kind in { "Wing", "Roar", "Chirp" } do
	local cue = audio.Dragon[kind]
	assert(cue.Cooldown >= cue.Seconds and cue.Volume > 0 and cue.Volume <= 1)
end
print(`PASS Audio config: {count} area slots, 6 bind cues, 3 bounded dragon cues. Asset loading NOT tested.`)
