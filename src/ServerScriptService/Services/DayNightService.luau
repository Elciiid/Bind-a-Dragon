--!strict
-- Watches the shared day/night cycle and announces rare constellations to the server when their night begins.
-- The cycle itself needs no server state: see Shared/Cycle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cycle = require(ReplicatedStorage.Shared.Cycle)

local announcement = ReplicatedStorage.Remotes.Announcement :: RemoteEvent

local DayNightService = {}

function DayNightService:Start()
	local lastAnnouncedNight: number? = nil
	while true do
		local state = Cycle.GetState()
		if state.IsNight and state.Constellation.Rare and lastAnnouncedNight ~= state.NightIndex then
			lastAnnouncedNight = state.NightIndex
			local luckText = if state.Constellation.Luck > 1 then ` Bind luck x{state.Constellation.Luck} tonight!` else ""
			announcement:FireAllClients(`A rare constellation rises: {state.Constellation.Name}!{luckText}`)
		end
		task.wait(1)
	end
end

return DayNightService
