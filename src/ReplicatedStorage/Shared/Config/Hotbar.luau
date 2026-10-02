--!strict
-- Dragon Hotbar (HotbarController) and carried companions (CompanionController, HotbarService). Tunable numbers only.
return {
	Slots = 10, -- keys 1-9 then 0
	SetCooldown = 0.1, -- seconds between SetHotbarSlot requests per player (server)
	CarryCooldown = 0.4, -- seconds between CarryDragon requests per player (server)
	StageRefreshSeconds = 2, -- the server re-checks the carried dragon's evolution stage this often
	AutoFillSeconds = 1, -- the server looks for new backpack dragons (bound, taken out of the roost) this often and slots them into the first empty slot

	-- Hotbar look (pixels)
	SlotSize = 58,
	PhoneSlotSize = 46, -- phones show PhoneSlotsPerPage slots at a time (big enough to tap) and a page arrow for the rest
	PhoneMinSlotSize = 44, -- never smaller than this on phones (the page arrow takes the squeeze instead)
	PhoneSlotsPerPage = 5,
	MinSlotSize = 26,
	SlotGap = 6,
	PhoneSlotGap = 4,
	BottomMargin = 14,
	PhoneBottomMargin = 8,
	PhoneSideReserve = 232, -- phones: free width kept on each side (the thumbstick zone is ~220 wide on the left; 5 slots + arrow fit between)
	CarriedColor = Color3.fromRGB(255, 214, 96), -- outline of the slot whose dragon is being carried
	EmptyTransparency = 0.55,

	-- Companion (the carried dragon, seen by everyone)
	-- Size by stage: CompanionLengthFraction x the stage's Length in Config/Evolution (10 / 15 / 21 / 28 studs), never below
	-- CompanionMinLength: Hatchling ~5, Drake ~6, Dragon ~8.5, Elder ~11 studs (nose to tail tip, the wider of width/length).
	CompanionLengthFraction = 0.4,
	CompanionMinLength = 5,
	-- Where it hovers, from the player's root: right, up, back (the player faces -Z; +Z is behind). Bigger companions sit farther
	-- out, higher and further back so they never block the camera: offset = base + perStud x the companion's size.
	FollowSide = 2.4, FollowSidePerStud = 0.4,
	FollowUp = 2.6, FollowUpPerStud = 0.22,
	FollowBack = 1.6, FollowBackPerStud = 0.5,
	FollowResponse = 5, -- how fast the companion catches up (higher = tighter)
	BobHeight = 0.5, -- studs of hover bob
	BobSpeed = 1.6,
	FlapRate = 1.2, -- wing beat clock speed (DragonRig Pose.Flap seconds per second)
	MaxBank = math.rad(22),
	TeleportDistance = 40, -- farther than this from the player: snap beside them (respawn, teleport)
	RenderDistance = 160, -- companions farther than this from the camera aren't drawn
	FullRigDistance = 60, -- bone animation: full detail inside this, simple up to RenderDistance
}
