--!strict
-- Game passes and developer products (MonetizationService). Paid features are convenience only.
-- Id = 0 means "not created yet": the item shows in the shop as unavailable and nobody owns it.
-- Create them in the Creator Dashboard, then paste the IDs here. Robux is display only (the price is set on Roblox).
-- In Studio, a server-side Player attribute "TestPass_<Key>" = true grants a pass for playtests.

export type Item = {
	Id: number,
	Name: string,
	Description: string,
	Robux: number,
}

return {
	Passes = {
		ElevatorPass = {
			Id = 0,
			Name = "Tower Elevator",
			Description = "Start Spire climbs above your record floor",
			Robux = 300,
		},
		AfkIncome2x = {
			Id = 0,
			Name = "2x AFK Income",
			Description = "Doubles roost income while offline or idle (20+ min without moving). Not active play.",
			Robux = 199,
		},
		AutoBind = {
			Id = 0,
			Name = "Auto-bind",
			Description = "Binds for you near the end of each night while you're in the game. Base luck only: no area, moon, offering, group or potion bonuses.",
			Robux = 149,
		},
	} :: { [string]: Item },

	Products = {
		ElevatorSkip = {
			Id = 0,
			Name = "Elevator Skip",
			Description = "One Spire climb starting above your record floor",
			Robux = 29,
		},
	} :: { [string]: Item },

	-- Display order in the shop.
	ShopOrder = { "ElevatorPass", "ElevatorSkip", "AfkIncome2x", "AutoBind" },

	AfkIncomeMultiplier = 2, -- 2x AFK Income: offline and idle roost income only
	AutoBindSecondsLeft = 60, -- Auto-bind binds for you when this many seconds of night are left (bind yourself earlier for better luck)
	AutoBindLuck = 1, -- base luck: no area, moon, constellation, offering, group or potion bonuses
	ReceiptSaveTimeout = 30, -- seconds to wait for the grant to be saved before Roblox retries the receipt
}
