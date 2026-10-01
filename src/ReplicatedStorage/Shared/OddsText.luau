--!strict
-- Kid-friendly odds text: "Only 1 in 8,400 binds!", excitement tags (Config/Odds) and wording (Config/Text.Odds).
-- N comes from the server (BindResult) or Shared/BindingOdds; this only formats it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local OddsConfig = require(ReplicatedStorage.Shared.Config.Odds)
local Text = require(ReplicatedStorage.Shared.Config.Text)

local OddsText = {}

-- "1 in 8,400" (a whole number, at least 1).
function OddsText.OneIn(n: number): string
	if n == math.huge or n ~= n then
		return Text.Odds.Unknown
	end
	local shown = Format.Commas(math.max(1, n))
	return Text.Format(Text.Odds.OneIn, { n = shown })
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
