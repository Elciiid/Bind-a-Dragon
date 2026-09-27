--!strict
-- Zones inside a roost plot (a Dragon Sanctuary): invisible flat disc parts in the plot's "Zones" folder, named
-- "<Zone>Zone" ("NestZone", "MeadowZone"). Each evolution stage's Zone (Config/Evolution) says where its dragons appear
-- (RoostService) and where walkers roam (RoostAnimationController); fliers use the whole pen. Plots without zones
-- fall back to the whole pen. A zone part is a Cylinder lying flat; its radius is half its diameter.

local RoostZones = {}

-- The zone's center (disc center, at the pen floor height floorY) and radius, or nil if the plot has no such zone.
function RoostZones.Get(plot: Model, zone: string?, floorY: number): (Vector3?, number)
	if zone == nil then
		return nil, 0
	end
	local folder = plot:FindFirstChild("Zones")
	local part = folder and folder:FindFirstChild(zone .. "Zone")
	if part == nil or not part:IsA("BasePart") then
		return nil, 0
	end
	return Vector3.new(part.Position.X, floorY, part.Position.Z), math.min(part.Size.Y, part.Size.Z) / 2
end

-- A random spot spread evenly over a disc, at least `margin` studs inside its edge.
function RoostZones.RandomSpot(center: Vector3, radius: number, margin: number, rng: Random): Vector3
	local usable = math.max(0, radius - margin)
	local angle = rng:NextNumber(0, 2 * math.pi)
	local distance = math.sqrt(rng:NextNumber()) * usable
	return center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

return RoostZones
