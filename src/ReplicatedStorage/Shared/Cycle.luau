--!strict
-- Day/night cycle math, shared by server and client. Everything is derived from the synced server clock
-- (workspace:GetServerTimeNow(), unix seconds), so all servers and clients agree without any replication.
--
-- Each cycle is one day followed by one night. NightIndex identifies a cycle; during the day it refers to
-- the upcoming night. Binding uses it to allow one bind per player per night, across all servers.

--
-- Testing in Studio: set a number attribute "CycleTimeOffset" (seconds) on Workspace to shift the clock,
-- e.g. to jump straight to night. Ignored in live servers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DayNight = require(ReplicatedStorage.Shared.Config.DayNight)
local Constellations = require(ReplicatedStorage.Shared.Config.Constellations)

export type State = {
	NightIndex: number,
	IsNight: boolean,
	ClockTime: number, -- value for Lighting.ClockTime: day runs 6 -> 18, night runs 18 -> 6
	SecondsLeft: number, -- until the current phase ends
	Constellation: Constellations.Constellation, -- tonight's (or during the day, the upcoming night's)
}

local CYCLE_SECONDS = DayNight.DaySeconds + DayNight.NightSeconds

local totalWeight = 0
for _, constellation in Constellations do
	totalWeight += constellation.Weight
end

local Cycle = {}

-- Deterministic weighted pick, so every server and client lands on the same constellation for a night.
function Cycle.GetConstellation(nightIndex: number): Constellations.Constellation
	local rng = Random.new(nightIndex * 7919 + DayNight.ConstellationSeed)
	local roll = rng:NextNumber() * totalWeight
	for _, constellation in Constellations do
		roll -= constellation.Weight
		if roll < 0 then
			return constellation
		end
	end
	return Constellations[#Constellations]
end

function Cycle.GetState(now: number?): State
	local time = now or workspace:GetServerTimeNow()
	if now == nil and RunService:IsStudio() then
		local offset = workspace:GetAttribute("CycleTimeOffset")
		if type(offset) == "number" then
			time += offset
		end
	end
	local nightIndex = math.floor(time / CYCLE_SECONDS)
	local intoCycle = time - nightIndex * CYCLE_SECONDS
	local isNight = intoCycle >= DayNight.DaySeconds

	local clockTime, secondsLeft
	if isNight then
		local progress = (intoCycle - DayNight.DaySeconds) / DayNight.NightSeconds
		clockTime = (18 + 12 * progress) % 24
		secondsLeft = CYCLE_SECONDS - intoCycle
	else
		clockTime = 6 + 12 * (intoCycle / DayNight.DaySeconds)
		secondsLeft = DayNight.DaySeconds - intoCycle
	end

	return {
		NightIndex = nightIndex,
		IsNight = isNight,
		ClockTime = clockTime,
		SecondsLeft = secondsLeft,
		Constellation = Cycle.GetConstellation(nightIndex),
	}
end

-- 0 in the day, 1 at night, easing between them over the last `seconds` of the day (dusk) and the last `seconds`
-- of the night (dawn). For visuals and sound only; binding still uses IsNight.
function Cycle.GetNightBlend(state: State, seconds: number): number
	local t
	if state.IsNight then
		t = math.clamp(state.SecondsLeft / seconds, 0, 1)
	else
		t = 1 - math.clamp(state.SecondsLeft / seconds, 0, 1)
	end
	return t * t * (3 - 2 * t)
end

return Cycle
