--!strict
-- Notifications (UI renewal part 2).
--   * Toasts (UI/Toast): ONE queue, top-center under the sky pill (HudLayout.TopReserved). At most
--     UITheme.Toasts.MaxVisible on screen; the rest wait. The same message again merges into the one showing or
--     waiting ("... x5") and restarts its time; rare things (announcements, rewards) jump the queue. Each toast gets an
--     icon picked from its text (potions, currencies, quests, Index, rebirth).
--   * Big moments (a new dragon, an evolution, a rebirth, a sanctuary tier, a rare constellation) show a centered
--     reward pop-up (UI/RewardPopup, one at a time) instead of a toast: the server sends them as Notify kind "moment"
--     (or an Announcement) with a payload table; controllers call NotificationController:Moment. Wording Text.Moments.
-- Spire floor clears and "+gold" pops never use the toast queue (they have their own UI).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local HudLayout = require(script.Parent.HudLayout)
local Toast = require(script.Parent.UI.Toast)
local RewardPopup = require(script.Parent.UI.RewardPopup)
local RevealGate = require(script.Parent.UI.RevealGate)
local DragonPicture = require(script.Parent.UI.DragonPicture)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local OddsConfig = require(ReplicatedStorage.Shared.Config.Odds)
local OddsText = require(ReplicatedStorage.Shared.OddsText)
local Format = require(ReplicatedStorage.Shared.Format)
local RebirthMilestones = require(ReplicatedStorage.Shared.RebirthMilestones)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local NotificationController = {}

-- Text -> icon key, most specific first.
local ICON_WORDS: { { string } } = {}
for _, potion in Boosts.Potions do
	table.insert(ICON_WORDS, { potion.Name, `Potion_{potion.Id}` })
end
for _, pair in {
	{ "Wyrm Rune", "WyrmRune" },
	{ "Dragonstone", "Dragonstone" },
	{ "Stardust", "Stardust" },
	{ "quest", "Menu_Quests" },
	{ "Index", "Menu_Index" },
	{ "Rebirth", "Menu_Rebirth" },
	{ "gold", "Gold" },
} do
	table.insert(ICON_WORDS, pair)
end

local function iconFor(text: string): string?
	local lower = string.lower(text)
	for _, pair in ICON_WORDS do
		if string.find(lower, string.lower(pair[1]), 1, true) then
			return pair[2]
		end
	end
	return nil
end

---------------------------------------------------------------------------------------------------------------
-- Toast queue

type Entry = {
	Key: string,
	Text: string,
	Kind: string,
	Icon: string?,
	Color: Color3?,
	Count: number,
	Priority: number,
	Handle: Toast.Handle?,
}

local visible: { Entry } = {}
local waiting: { Entry } = {}

local PRIORITY: { [string]: number } = { announce = 3, reward = 2, error = 1 }

local function label(entry: Entry): string
	return if entry.Count > 1 then `{entry.Text} x{entry.Count}` else entry.Text
end

local pump: () -> ()

local function show(entry: Entry)
	table.insert(visible, entry)
	entry.Handle = Toast.Spawn(label(entry), entry.Kind, entry.Icon, entry.Color, function()
		local index = table.find(visible, entry)
		if index then
			table.remove(visible, index)
		end
		pump()
	end)
end

pump = function()
	while #visible < UITheme.Toasts.MaxVisible and #waiting > 0 do
		show(table.remove(waiting, 1) :: Entry)
	end
end

local function push(entry: Entry)
	for _, other in visible do
		if other.Key == entry.Key then
			other.Count += 1
			local handle = other.Handle
			if handle then
				handle:SetText(label(other))
				handle:Extend()
			end
			return
		end
	end
	for _, other in waiting do
		if other.Key == entry.Key then
			other.Count += 1
			return
		end
	end
	-- higher priority waits in front of lower (same priority: first come, first shown)
	local at = #waiting + 1
	for index, other in waiting do
		if entry.Priority > other.Priority then
			at = index
			break
		end
	end
	table.insert(waiting, at, entry)
	pump()
end

-- kind: "success" | "error" | "info" | "reward" | "announce". color overrides the kind's accent; icon overrides the
-- icon picked from the text.
function NotificationController:Show(text: string, color: Color3?, kind: string?, icon: string?)
	if RevealGate.IsActive() then
		RevealGate.Defer(function() self:Show(text, color, kind, icon) end)
		return
	end
	local k = kind or "info"
	push({
		Key = text,
		Text = text,
		Kind = k,
		Icon = icon or iconFor(text),
		Color = color,
		Count = 1,
		Priority = PRIORITY[k] or 0,
		Handle = nil,
	})
end

---------------------------------------------------------------------------------------------------------------
-- Big moments

local function rarityColor(rarityId: string): Color3
	local rarity = UITheme.Rarity[rarityId]
	return if rarity then rarity.Color else UITheme.Colors.Gold
end

-- payload.Moment: "NewDragon" { SpeciesId, Level?, MutationId?, Auto?, BaseOneIn?, EffectiveOneIn?, SpeciesOneIn?, MutationOneIn?, Luck? } | "Milestone" { Id, Name, Info, Rebirths } | "Evolve" { SpeciesId, Level, Stage, Under? }
-- | "Rebirth" { Rebirths, Income, CapTo, Unlocked? } | "Tier" { Tier, Name } | "Look" { Name } | "Constellation" { Name, Luck }.
-- fallback = the toast text if the payload can't be shown.
function NotificationController:Moment(payload: any, fallback: string?)
	if RevealGate.IsActive() then
		RevealGate.Defer(function() self:Moment(payload, fallback) end)
		return
	end
	local words = Text.Moments
	local moment = if type(payload) == "table" then payload.Moment else nil
	if moment == "NewDragon" or moment == "Evolve" then
		local species = Dragons[payload.SpeciesId]
		if species == nil then
			if fallback then
				self:Show(fallback, nil, "success")
			end
			return
		end
		local mutation = Mutations.Get(payload.MutationId)
		local tag
		local odds = Text.Odds
		local hasOdds = moment == "NewDragon" and type(payload.EffectiveOneIn) == "number"
		local line, lineColor, chips, details, hint, excitement
		if moment == "Evolve" then
			local under = if payload.Under then Text.Format(words.EvolveUnder, { constellation = payload.Under }) else ""
			tag = Text.Format(words.EvolveTag, { stage = payload.Stage or "", under = under })
		elseif hasOdds then
			-- kid-friendly odds: an excitement banner, "Only 1 in N binds!", rarity / element / mutation chips, tap for details
			local n = payload.EffectiveOneIn :: number
			excitement = OddsText.Tag(n)
			line, lineColor = OddsText.Line(n), OddsText.Color(n)
			chips = {
				{ Text = species.Rarity, Color = rarityColor(species.Rarity) },
				{ Text = species.Element, Color = (Elements[species.Element] or Elements.Fire).Color },
			}
			if mutation.Id ~= Mutations.NormalId then
				table.insert(chips, { Text = mutation.Name, Color = mutation.Color })
			end
			if payload.Auto then
				table.insert(chips, { Text = "Auto-bind", Color = UITheme.Colors.TextMuted })
			end
			local rows = { { odds.RowSpecies, OddsText.OneIn(payload.SpeciesOneIn or n) } }
			if mutation.Id ~= Mutations.NormalId then
				table.insert(rows, { odds.RowMutation, OddsText.OneIn(payload.MutationOneIn or 1) })
			end
			table.insert(rows, { odds.RowTogether, OddsText.OneIn(n) })
			table.insert(rows, { odds.RowProbability, OddsText.Probability(n) })
			if type(payload.BaseOneIn) == "number" and math.abs(payload.BaseOneIn - n) > 0.01 then
				table.insert(rows, { odds.RowBase, OddsText.OneIn(payload.BaseOneIn) })
			end
			if type(payload.Luck) == "number" then
				table.insert(rows, { odds.RowLuck, Format.Multiplier(payload.Luck) })
			end
			details = { Title = odds.DetailsTitle, Rows = rows }
			hint = odds.Details
		else
			tag = Text.Format(if payload.Auto then words.AutoTag else words.NewDragonTag, { rarity = species.Rarity, element = species.Element })
		end
		RewardPopup.Show({
			Title = if moment == "Evolve" then words.Evolve elseif excitement then excitement elseif mutation.Id ~= Mutations.NormalId then words.Mutation else words.NewDragon,
			Name = if mutation.Id ~= Mutations.NormalId then `{mutation.Name} {species.Name}` else species.Name,
			Tag = tag,
			Line = line,
			LineColor = lineColor,
			Chips = chips,
			Details = details,
			Hint = hint,
			Seconds = if details then OddsConfig.PopupDetailSeconds else nil,
			Color = if mutation.Id ~= Mutations.NormalId then mutation.Color else rarityColor(species.Rarity),
			Picture = function(frame)
				DragonPicture.new(frame, payload.SpeciesId, payload.Level)
			end,
			Button = words.Button,
		})
	elseif moment == "Milestone" then
		RewardPopup.Show({
			Title = Text.Milestones.PopupTitle,
			Name = payload.Name,
			Chips = if type(payload.Rebirths) == "number" then { { Text = Text.Format(Text.Milestones.PopupTag, { n = payload.Rebirths }), Color = UITheme.Colors.Gold } } else nil,
			Line = payload.Info,
			LineColor = UITheme.Colors.Text,
			Color = UITheme.Colors.Gold,
			Icon = if payload.Champion then "Rarity_Mythic" else "Menu_Rebirth",
			Button = words.Button,
		})
	elseif moment == "Rebirth" then
		local unlocked = if type(payload.Unlocked) == "table" then payload.Unlocked else {}
		RewardPopup.Show({
			Title = words.Rebirth,
			Name = Text.Format(words.RebirthName, { n = payload.Rebirths }),
			Tag = if #unlocked > 0 then unlocked[1] else Text.Format(words.RebirthTag, { income = payload.Income, cap = payload.CapTo }),
			Color = UITheme.Colors.Gold,
			Icon = "Menu_Rebirth",
			Button = words.Button,
		})
	elseif moment == "Tier" then
		RewardPopup.Show({
			Title = words.Tier,
			Name = payload.Name,
			Tag = Text.Format(words.TierTag, { tier = payload.Tier }),
			Color = UITheme.Colors.Gold,
			Icon = "Travel_Home",
			Button = words.Button,
		})
	elseif moment == "Look" then
		RewardPopup.Show({
			Title = words.Look,
			Name = payload.Name,
			Tag = words.LookTag,
			Color = UITheme.Colors.Gold,
			Icon = "Travel_Home",
			Button = words.Button,
		})
	elseif moment == "Constellation" then
		RewardPopup.Show({
			Title = words.Constellation,
			Name = payload.Name,
			Tag = if (payload.Luck or 1) > 1 then Text.Format(words.ConstellationTag, { luck = `x{payload.Luck}` }) else words.ConstellationPlain,
			Color = Color3.fromRGB(170, 140, 255),
			Icon = "Sky_Moon",
			Button = words.Button,
		})
	elseif fallback then
		self:Show(fallback, nil, "success")
	end
end

function NotificationController:Init()
	local gui = HudLayout.MakeScreenGui("Notifications", "Notifications")
	gui.ScreenInsets = Enum.ScreenInsets.None -- measured from the very top, like the top bar
	local container = Instance.new("Frame")
	container.Name = "Toasts"
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Size = UDim2.new(0.9, 0, 0.5, 0)
	container.BackgroundTransparency = 1
	container.Parent = gui
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(560, math.huge)
	sizeLimit.Parent = container
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container
	Toast.SetContainer(container)
	HudLayout.OnLayoutChanged(function(isPhone)
		Toast.SetPhone(isPhone)
		-- top-center, under the sky pill
		container.Position = UDim2.new(0.5, 0, 0, HudLayout.TopReserved() + UITheme.Toasts.Gap)
	end)
end

function NotificationController:Start()
	-- Server-wide: Announcement:FireAllClients(text, payload?) (a payload with .Moment shows a reward pop-up).
	local announcement = ReplicatedStorage.Remotes.Announcement :: RemoteEvent
	announcement.OnClientEvent:Connect(function(text: string, payload: any?)
		if type(payload) == "table" and payload.Kind == "DragonBind"
			and payload.PlayerId == Players.LocalPlayer.UserId and type(payload.DragonId) == "string" then
			RevealGate.AfterDragon(payload.DragonId, function() self:Show(text, nil, "announce") end)
			return
		end
		if type(payload) == "table" and payload.Moment then
			self:Moment(payload, text)
		else
			self:Show(text, nil, "announce")
		end
	end)

	-- Messages for just this player: Notify:FireClient(player, text, kind, payload?) where kind is "error" | "success" |
	-- "info", or "moment" with a payload table (reward pop-up).
	local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent
	notify.OnClientEvent:Connect(function(text: string, kind: string?, payload: any?)
		if kind == "moment" then
			self:Moment(payload, text)
		else
			self:Show(text, nil, kind)
		end
	end)
end

return NotificationController
