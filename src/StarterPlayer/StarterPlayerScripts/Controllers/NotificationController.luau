--!strict
-- Toasts (UI/Toast) at the top of the screen, plus server-wide announcements. Each toast gets an icon picked from
-- its text (potion names, currencies, quests, Index, rebirth). Other controllers call NotificationController:Show.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(script.Parent.HudLayout)
local Toast = require(script.Parent.UI.Toast)
local Boosts = require(ReplicatedStorage.Shared.Config.Boosts)
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

-- kind: "success" | "error" | "info" | "reward" | "announce". color overrides the kind's accent.
function NotificationController:Show(text: string, color: Color3?, kind: string?)
	Toast.Show(text, kind or "info", iconFor(text), color)
end

function NotificationController:Init()
	local gui = HudLayout.MakeScreenGui("Notifications", "Notifications")
	local container = Instance.new("Frame")
	container.Name = "Toasts"
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Size = UDim2.new(0.9, 0, 0.5, 0)
	container.BackgroundTransparency = 1
	container.Parent = gui
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(480, math.huge)
	sizeLimit.Parent = container
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container
	Toast.SetContainer(container)
	HudLayout.OnLayoutChanged(function(isPhone)
		container.Position = UDim2.new(0.5, 0, 0, if isPhone then UITheme.Sizes.PhoneCardTop + 120 else 70)
	end)
end

function NotificationController:Start()
	local announcement = ReplicatedStorage.Remotes.Announcement :: RemoteEvent
	announcement.OnClientEvent:Connect(function(text: string)
		self:Show(text, nil, "announce")
	end)

	-- Messages for just this player: Notify:FireClient(player, text, kind) where kind is "error" | "success" | "info".
	local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent
	notify.OnClientEvent:Connect(function(text: string, kind: string?)
		self:Show(text, nil, kind)
	end)
end

return NotificationController
