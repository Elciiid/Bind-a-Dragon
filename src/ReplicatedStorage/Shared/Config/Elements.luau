--!strict
-- Dragon elements. Color is used for UI and for tinting the night sky when a constellation of that element is up.

export type Element = {
	Name: string,
	Color: Color3,
}

local Elements: { [string]: Element } = {
	Fire = { Name = "Fire", Color = Color3.fromRGB(255, 110, 40) },
	Ice = { Name = "Ice", Color = Color3.fromRGB(120, 210, 255) },
	Storm = { Name = "Storm", Color = Color3.fromRGB(255, 235, 90) },
	Shadow = { Name = "Shadow", Color = Color3.fromRGB(150, 90, 220) },
}

return Elements
