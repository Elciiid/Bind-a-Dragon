--!strict
-- Kid-friendly odds text: "Only 1 in 8,400 binds!", excitement tags (Config/Odds) and wording (Config/Text.Odds).
-- N comes from the server (BindResult) or Shared/BindingOdds; this only formats it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local OddsConfig = require(ReplicatedStorage.Shared.Config.Odds)
local Text = require(ReplicatedStorage.Shared.Config.Text)

local OddsText = {}

-- "1 in 8,400" (a whole number, at least 1): the pop-up line, Index and dragon tooltips.
function OddsText.OneIn(n: number): string
	if n == math.huge or n ~= n then
		return Text.Odds.Unknown
	end
	local shown = Format.Commas(math.max(1, n))
	return Text.Format(Text.Odds.OneIn, { n = shown })
end

-- "1 in 1.67": exact decimals, only for the tap-for-details breakdown (Config/Odds DenominatorDecimals).
function OddsText.OneInExact(n: number): string
	if n == math.huge or n ~= n or n < 1 then
		return Text.Odds.Unknown
	end
	local factor = 10 ^ OddsConfig.DenominatorDecimals
	local rounded = math.round(n * factor) / factor
	local whole = math.floor(rounded)
	local shown = Format.Commas(whole)
	local fraction = rounded - whole
	if fraction > 0 then
		local decimals = string.format(`%.{OddsConfig.DenominatorDecimals}f`, fraction):sub(2):gsub("0+$", "")
		shown ..= decimals
	end
	return Text.Format(Text.Odds.OneIn, { n = shown })
end

function OddsText.Probability(n: number): string
	if n < 1 or n == math.huge or n ~= n then
		return Text.Odds.Unknown
	end
	return string.format(`%.{OddsConfig.ProbabilityDecimals}f%%`, 100 / n)
end

-- The excitement tag for an N ("LEGENDARY LUCK!"), or nil for common binds.
function OddsText.Tag(n: number): string?
	for _, entry in OddsConfig.Tags do
		if n >= entry.MinOneIn then
			return Text.Odds.Tags[entry.Id]
		end
	end
	return nil
end

function OddsText.Color(n: number): Color3
	for _, entry in OddsConfig.Tags do
		if n >= entry.MinOneIn then
			return entry.Color
		end
	end
	return OddsConfig.CommonColor
end

-- The big line: "Only 1 in 8,400 binds!" (common binds: "1 in 3 binds").
function OddsText.Line(n: number): string
	return Text.Format(if OddsText.Tag(n) then Text.Odds.Only else Text.Odds.Plain, { oneIn = OddsText.OneIn(n) })
end

return OddsText
