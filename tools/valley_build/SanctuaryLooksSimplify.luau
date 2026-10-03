-- Simplify 2026-10-04 (kid-friendly Roblox look, KISS): trims the Celestial Sanctum and Crystal Garden kits in
-- ReplicatedStorage.Assets.SanctuaryLooks to about 250 parts per sanctuary. Studio build helper, not used by the game.
-- Prunes by rule (piece name + part/model name), so it is safe to run twice; the slots, piece names and the kit structure
-- stay the same. If BuildCelestial / BuildCrystalGarden is ever re-run, run Simplify() right after it.
-- Usage: require(ServerStorage.RemasterTools.SanctuaryLooksSimplify:Clone()).Simplify()
-- The live copy is ServerStorage.RemasterTools.SanctuaryLooksSimplify; this file is the reference copy.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local S = {}

-- [look] = { { piece name pattern, names to remove inside it (parts or models, matched exactly) } }
S.Rules = {
	CelestialSanctum = {
		{ "^Dome$", { "RingA", "RingB", "RingC", "Bead" } }, -- the three spinning gold armillary rings (+ their beads)
		{ "^Inlay$", "*" }, -- the constellation floor inlay (the whole piece)
		{ "^Float%d+$", { "HoldRing", "Bead", "Crystal", "CrystalTip" } }, -- gold rings around the perch rocks, small crystals
		{ "^Wall%d+$", { "NicheFrame", "NicheGlass", "NicheTop", "WallCap" } }, -- glass niches and caps (marble wall + posts stay)
	},
	CrystalGarden = {
		{ "^Pool$", { "Crystal", "CrystalTip" } }, -- the 12 small crystals around the rim (fountain + gold rim stay)
		{ "^Gate$", { "Glyph" } },
		{ "^Wall%d+$", { "WallBand" } },
	},
}

function S.Simplify(): string
	local looks = ReplicatedStorage.Assets.SanctuaryLooks
	local report = {}
	for lookName, rules in S.Rules do
		local look = looks:FindFirstChild(lookName)
		local before, after = 0, 0
		for _, plot in (if look then look:GetChildren() else {}) do
			for _, d in plot:GetDescendants() do
				if d:IsA("BasePart") then
					before += 1
				end
			end
			for _, piece in plot:GetChildren() do
				for _, rule in rules do
					if string.match(piece.Name, rule[1]) then
						if rule[2] == "*" then
							piece:Destroy()
						else
							for _, d in piece:GetDescendants() do
								if d.Parent and table.find(rule[2], d.Name) then
									d:Destroy()
								end
							end
						end
						break
					end
				end
			end
			for _, d in plot:GetDescendants() do
				if d:IsA("BasePart") then
					after += 1
				end
			end
		end
		local plots = if look then #look:GetChildren() else 0
		table.insert(report, string.format("%s: %d -> %d parts (%d plots, %d per plot)", lookName, before, after, plots, if plots > 0 then after // plots else 0))
	end
	return table.concat(report, "; ")
end

return S
