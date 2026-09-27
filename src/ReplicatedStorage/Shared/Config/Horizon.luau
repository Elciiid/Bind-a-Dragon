--!strict
-- Horizon landmarks (client only, HorizonController): big silhouettes of the other areas' landmarks, shown
-- on the horizon behind each Meadow portal so the world feels connected. They are cloned on the client from
-- ReplicatedStorage.Assets.Horizon.<Model> (built in Studio, lives in the place file), have no collision and are not
-- streamed. Positions are the model's base (its pivot), in studs; the model turns to face FaceTowards.
-- Optional pieces inside a model: a part/model named "Spinner" turns slowly (SpinSpeed), and parts named "Flash"
-- flash like lightning (FlashEvery). Particles, beams, lights and flashes are off with Low effects.

export type Landmark = {
	Model: string, -- child of ReplicatedStorage.Assets.Horizon
	Position: Vector3, -- base of the model
	FaceTowards: Vector3, -- the model's front (-Z) turns toward this point (usually the Meadow center)
	Scale: number, -- Model:ScaleTo
	ShowIn: { string }, -- area ids where it is visible
	SpinSpeed: number?, -- degrees per second for the "Spinner" piece
	FlashEvery: NumberRange?, -- seconds between lightning flashes on "Flash" parts
}

local MEADOW_CENTER = Vector3.new(0, 0, 0)

return {
	-- How long a lightning flash stays lit (seconds) and how bright the "Flash" parts get (0 = hidden, 1 = solid).
	FlashSeconds = 0.18,
	FlashOpacity = 0.9,

	Landmarks = {
		-- Behind Portal_VolcanoPeak (north-north-east, -67.5°): the volcano with its lava streaks and plume.
		{
			Model = "Volcano",
			Position = Vector3.new(260, -20, -628),
			FaceTowards = MEADOW_CENTER,
			Scale = 1,
			ShowIn = { "StarterMeadow" },
		},
		-- Behind Portal_FrozenCliffs (east-north-east, -22.5°): the ice crystal spire on its cliff.
		{
			Model = "IceSpire",
			Position = Vector3.new(628, -20, -260),
			FaceTowards = MEADOW_CENTER,
			Scale = 1,
			ShowIn = { "StarterMeadow" },
		},
		-- Behind Portal_StormCanyon (west-north-west, -157.5°): the lightning tower on its mesa.
		{
			Model = "StormTower",
			Position = Vector3.new(-628, -20, -260),
			FaceTowards = MEADOW_CENTER,
			Scale = 1,
			ShowIn = { "StarterMeadow" },
			FlashEvery = NumberRange.new(2.5, 6),
		},
		-- Behind Portal_EclipseIsles (north-north-west, -112.5°): the eclipse ring over the floating temple island.
		{
			Model = "EclipseRing",
			Position = Vector3.new(-260, -20, -628),
			FaceTowards = MEADOW_CENTER,
			Scale = 1,
			ShowIn = { "StarterMeadow" },
			SpinSpeed = 3,
		},

		-- In-area sky landmarks (client-side so they never stream out, even far away on phones).
		-- Eclipse Isles: the dark sun with its golden corona, high above the temple island, seen from the arrival.
		{
			Model = "EclipseSun",
			Position = Vector3.new(-1150, 0, -1370),
			FaceTowards = Vector3.new(-1150, 0, 0),
			Scale = 1,
			ShowIn = { "EclipseIsles" },
			SpinSpeed = 3,
		},
		-- Frozen Cliffs: the ice crystal spire on top of the north cliff.
		{
			Model = "IceCrystals",
			Position = Vector3.new(1600, 27, -205),
			FaceTowards = Vector3.new(1600, 27, 400),
			Scale = 1,
			ShowIn = { "FrozenCliffs" },
		},
		-- Storm Canyon: the lightning tower on the north mesa.
		{
			Model = "StormTowerLocal",
			Position = Vector3.new(-1600, 10, -210),
			FaceTowards = Vector3.new(-1600, 10, 400),
			Scale = 1,
			ShowIn = { "StormCanyon" },
			FlashEvery = NumberRange.new(2.5, 6),
		},
		-- Volcano Peak: smoke plume and embers rising from the crater.
		{
			Model = "VolcanoPlume",
			Position = Vector3.new(0, 116, -1790),
			FaceTowards = Vector3.new(0, 116, 0),
			Scale = 1.4,
			ShowIn = { "VolcanoPeak" },
		},
	} :: { Landmark },
}
