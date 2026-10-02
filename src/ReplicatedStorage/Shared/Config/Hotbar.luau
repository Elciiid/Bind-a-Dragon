--!strict
-- Dragon Hotbar (HotbarController) and carried companions (CompanionController, HotbarService). Tunable numbers only.
return {
	Slots = 10, -- keys 1-9 then 0
	SetCooldown = 0.1, -- seconds between SetHotbarSlot requests per player (server)
	CarryCooldown = 0.4, -- seconds between CarryDragon requests per player (server)
	StageRefreshSeconds = 2, -- the server re-checks the carried dragon's evolution stage this often

	-- Hotbar look (pixels)
	SlotSize = 58,
	PhoneSlotSize = 34, -- phones: also shrunk to fit between the thumbstick and the jump button (PhoneSideReserve)
	MinSlotSize = 26,
	SlotGap = 6,
	PhoneSlotGap = 3,
	BottomMargin = 14,
	PhoneBottomMargin = 8,
	PhoneSideReserve = 232, -- phones: free width kept on each side (the thumbstick zone is ~220 wide on the left)
	CarriedColor = Color3.fromRGB(255, 214, 96), -- outline of the slot whose dragon is being carried
	EmptyTransparency = 0.55,

	-- Companion (the carried dragon, seen by everyone)
	CompanionSpan = 4.5, -- studs across at its widest (wings spread or tail: whichever is larger); the roost sizes are 10-28
	FollowOffset = Vector3.new(3.6, 3.4, 1.2), -- from the player's root: right, up, back (the player faces -Z; +Z is behind)
	FollowResponse = 5, -- how fast the companion catches up (higher = tighter)
	BobHeight = 0.5, -- studs of hover bob
	BobSpeed = 1.6,
	FlapRate = 1.2, -- wing beat clock speed (DragonRig Pose.Flap seconds per second)
	MaxBank = math.rad(22),
	TeleportDistance = 40, -- farther than this from the player: snap beside them (respawn, teleport)
	RenderDistance = 160, -- companions farther than this from the camera aren't drawn
	FullRigDistance = 60, -- bone animation: full detail inside this, simple up to RenderDistance
}
