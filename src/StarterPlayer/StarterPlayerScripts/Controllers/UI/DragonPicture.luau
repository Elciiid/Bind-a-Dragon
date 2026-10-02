--!strict
-- A picture of a dragon for cards and pop-ups: a ViewportFrame with its real art (ReplicatedStorage.Assets.Dragons.
-- <SpeciesId>.<StageId> or <SpeciesId>), seen from the front-side; species that only have the shared placeholder model
-- show their big rarity icon instead. Mutation identity is displayed by cards, labels, and world aura.
--
-- Usage: DragonPicture.new(frame, speciesId, level?) -> GuiObject (fills `frame`)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icon = require(script.Parent.Icon)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)

local DragonPicture = {}

local FILL = 0.94 -- share of the picture's half-size the dragon's bounding box may fill (a little padding)

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
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	-- the art faces -Z: look from its front-left, a little above. The distance is the smallest one that keeps every corner of the model's
	-- bounding box inside the (square) picture with a small padding, so the dragon fills its slot instead of floating small in it.
	local direction = Vector3.new(0.55, 0.18, -0.8).Unit
	local look = -direction
	local right = look:Cross(Vector3.yAxis).Unit
	local up = right:Cross(look).Unit
	local tangent = math.tan(math.rad(camera.FieldOfView / 2)) * FILL
	local distance = 1
	for sx = -1, 1, 2 do
		for sy = -1, 1, 2 do
			for sz = -1, 1, 2 do
				local offset = Vector3.new(size.X / 2 * sx, size.Y / 2 * sy, size.Z / 2 * sz)
				local across = math.max(math.abs(offset:Dot(right)), math.abs(offset:Dot(up)))
				distance = math.max(distance, across / tangent - offset:Dot(look))
			end
		end
	end
	camera.CFrame = CFrame.lookAt(box.Position + direction * distance, box.Position)
	camera.Parent = view
	view.CurrentCamera = camera
	return view
end

return DragonPicture
