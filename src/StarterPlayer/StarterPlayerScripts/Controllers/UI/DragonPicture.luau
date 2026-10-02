--!strict
-- A picture of a dragon for cards and pop-ups: a ViewportFrame with its real art (ReplicatedStorage.Assets.Dragons.
-- <SpeciesId>.<StageId> or <SpeciesId>), seen from the front-side; species that only have the shared placeholder model
-- show their big rarity icon instead. Mutation identity is displayed by cards, labels, and world aura.
-- Dragons with a bone map (Config/DragonRigs) are shown in the perched pose with the wings FOLDED (the same pose the roost uses on the
-- ground), and the picture is framed on that posed body (the bones' screen extent + a margin), so wide-winged dragons are not shrunk by their
-- spread wings. Every card, hotbar slot and pop-up uses this one component.
--
-- Usage: DragonPicture.new(frame, speciesId, level?) -> GuiObject (fills `frame`)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icon = require(script.Parent.Icon)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local RigConfig = require(ReplicatedStorage.Shared.Config.DragonRigs)
local DragonRig = require(script.Parent.Parent.DragonRig)

local DragonPicture = {}

local FILL = 0.94 -- share of the picture's half-size the dragon's bounding box may fill (a little padding)
local BONE_PADDING = 0.11 -- margin around every posed bone, as a share of the model's longest side (the mesh reaches past its bones)
local FOLDED: DragonRig.Pose = {
	Air = 0, Flap = 0, Gait = 0, Walk = 0, Clock = 0, Rest = 0, Hover = 0, Turn = 0, Pitch = 0,
	LookYaw = 0, LookPitch = 0, Action = nil, ActionT = 0, Seed = 0,
}

-- Poses the clone's bones to the folded perched pose; returns the posed bones' world positions (nil with no bones).
local function poseFolded(clone: Model, speciesId: string, stageId: string): { Vector3 }?
	local config = RigConfig.Rigs[`{speciesId}/{stageId}`]
	if config == nil then
		return nil
	end
	local rig = DragonRig.Build(clone, config)
	if rig == nil then
		return nil
	end
	DragonRig.Apply(rig, FOLDED, "Full")
	local points: { Vector3 } = {}
	for _, bone in rig.Bones do
		table.insert(points, bone.TransformedWorldCFrame.Position)
	end
	return points
end

local function artFor(speciesId: string, stageId: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Dragons")
	local species = folder and folder:FindFirstChild(speciesId)
	if species == nil then
		return nil
	end
	local model = species:FindFirstChild(stageId)
	if model and model:IsA("Model") then
		return model
	end
	return if species:IsA("Model") then species else nil
end

function DragonPicture.new(parent: GuiObject, speciesId: string, level: number?): GuiObject
	local stage = DragonStats.GetStage(level or 1)
	local model = artFor(speciesId, stage.Id)
	if model == nil then
		local species = Dragons[speciesId]
		local rarity = if species then species.Rarity else "Common"
		local icon = Icon.new(parent, `Rarity_{rarity}`)
		icon.Name = "Picture"
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Size = UDim2.fromScale(0.85, 0.85)
		icon.ZIndex = 4
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.Parent = icon
		return icon
	end

	local view = Instance.new("ViewportFrame")
	view.Name = "Picture"
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromScale(1, 1)
	view.LightDirection = Vector3.new(-1, -1, -0.6)
	view.Ambient = Color3.fromRGB(170, 160, 200)
	view.LightColor = Color3.fromRGB(255, 246, 230)
	view.ZIndex = 4 -- above a glow behind it
	view.Parent = parent
	local clone = model:Clone()
	for _, item in clone:GetDescendants() do
		if item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		end
	end
	clone:PivotTo(CFrame.new())
	clone.Parent = view
	local box, size = clone:GetBoundingBox()
	-- the points the picture must contain: the posed (folded) bones with a margin for the mesh around them, or the 8 corners of the
	-- bounding box for art without a bone map
	local points = poseFolded(clone, speciesId, stage.Id)
	local margin = math.max(size.X, size.Y, size.Z) * BONE_PADDING
	if points == nil then
		points = {}
		margin = 0
		for sx = -1, 1, 2 do
			for sy = -1, 1, 2 do
				for sz = -1, 1, 2 do
					table.insert(points, box.Position + Vector3.new(size.X / 2 * sx, size.Y / 2 * sy, size.Z / 2 * sz))
				end
			end
		end
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	-- the art faces -Z: look from its front-left, a little above. The camera is centered on what the points cover on screen and as
	-- close as keeps every point (plus the margin) inside the square picture: the dragon fills its slot instead of floating small in it.
	local direction = Vector3.new(0.55, 0.18, -0.8).Unit
	local look = -direction
	local right = look:Cross(Vector3.yAxis).Unit
	local up = right:Cross(look).Unit
	local tangent = math.tan(math.rad(camera.FieldOfView / 2)) * FILL
	local minRight, maxRight, minUp, maxUp, depthSum = math.huge, -math.huge, math.huge, -math.huge, 0
	for _, point in points do
		minRight, maxRight = math.min(minRight, point:Dot(right)), math.max(maxRight, point:Dot(right))
		minUp, maxUp = math.min(minUp, point:Dot(up)), math.max(maxUp, point:Dot(up))
		depthSum += point:Dot(look)
	end
	local midRight, midUp = (minRight + maxRight) / 2, (minUp + maxUp) / 2
	local targetDepth = depthSum / #points
	local target = right * midRight + up * midUp + look * targetDepth
	local distance = 1
	for _, point in points do
		local across = math.max(math.abs(point:Dot(right) - midRight), math.abs(point:Dot(up) - midUp)) + margin
		distance = math.max(distance, across / tangent - (point:Dot(look) - targetDepth))
	end
	camera.CFrame = CFrame.lookAt(target + direction * distance, target)
	camera.Parent = view
	view.CurrentCamera = camera
	return view
end

return DragonPicture
