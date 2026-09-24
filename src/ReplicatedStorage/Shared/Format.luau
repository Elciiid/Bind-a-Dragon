--!strict
-- Display formatting helpers shared by all UI.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 950 -> "950", 1234 -> "1.23K", 45600000 -> "45.6M"
function Format.Number(n: number): string
	if n < 1000 then
		return tostring(math.floor(n))
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	local text
	if scaled >= 100 then
		text = tostring(math.floor(scaled))
	else
		-- Round down (never show more than the player has), then drop trailing zeros: "1.50" -> "1.5"
		local decimals = if scaled >= 10 then 1 else 2
		local factor = 10 ^ decimals
		text = string.format(`%.{decimals}f`, math.floor(scaled * factor) / factor)
		text = (text:gsub("0+$", ""):gsub("%.$", ""))
	end
	return text .. SUFFIXES[tier + 1]
end

return Format
