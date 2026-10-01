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
		-- The Valley (Starter Meadow): each area's landmark stands 650-720 studs out behind its portal gate (gates on the
		-- portal terrace behind the Spire's foot, layout A-N, at bearings -28°, -19°, 19°, 28° from the altar; landmarks fanned
		-- a little wider at -35°, -18°, 18°, 35°, matching the ridge dips in ValleyTerrain SADDLES), seen through the dips in
		-- the mountain ridge. Unlock order west to east.
		-- Behind Portal_VolcanoPeak: the volcano with its lava streams and smoke plume.
		{
			Model = "ValleyVolcano",
			Position = Vector3.new(-413, 20, -590), -- 720 out at -35° (a little farther out so it doesn't crowd the ice spire)
			FaceTowards = MEADOW_CENTER,
			Scale = 1.1, -- ~350 tall: towers over the ridge like in the concept image
			ShowIn = { "StarterMeadow" },
		},
		-- Behind Portal_FrozenCliffs: the ice crystal spire on its cliff.
		{
			Model = "IceSpire",
			Position = Vector3.new(-204, 15, -628), -- 660 out at -18°
			FaceTowards = MEADOW_CENTER,
			Scale = 1.3,
			ShowIn = { "StarterMeadow" },
		},
		-- Behind Portal_StormCanyon: the lightning tower on its mesa.
		{
			Model = "StormTower",
			Position = Vector3.new(204, 15, -628),
			FaceTowards = MEADOW_CENTER,
			Scale = 1,
			ShowIn = { "StarterMeadow" },
			FlashEvery = NumberRange.new(2.5, 6),
		},
		-- Behind Portal_EclipseIsles: the floating island under the eclipse (its dark sun and gold corona spin slowly).
		-- Position = the island's grass top.
		{
			Model = "ValleyIsland",
			Position = Vector3.new(373, 200, -532), -- floats above the east ridge (650 out at 35°)
			FaceTowards = MEADOW_CENTER,
			Scale = 1.25,
			ShowIn = { "StarterMeadow" },
			SpinSpeed = 3,
		},
		-- Distant mountain ranges all around the valley, beyond the terrain (pieces ~830 studs out; pivot = valley center).
		{
			Model = "MeadowRanges",
			Position = MEADOW_CENTER,
			FaceTowards = Vector3.new(0, 0, -100),
			Scale = 1,
			ShowIn = { "StarterMeadow" },
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
