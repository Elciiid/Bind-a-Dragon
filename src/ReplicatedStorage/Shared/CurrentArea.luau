--!strict
-- Which area a position is in: the AreaId of the nearest AreaSpawn (areas are >= 1,200 studs apart, so the nearest
-- spawn is always the area's own). Same answer on server and client.

local CollectionService = game:GetService("CollectionService")

local CurrentArea = {}

function CurrentArea.At(position: Vector3): string?
	local best, bestDistance = nil, math.huge
	for _, spawnPart in CollectionService:GetTagged("AreaSpawn") do
		local areaId = spawnPart:GetAttribute("AreaId")
		if spawnPart:IsA("BasePart") and type(areaId) == "string" then
			local distance = (spawnPart.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = areaId, distance
			end
		end
	end
	return best
end

return CurrentArea
