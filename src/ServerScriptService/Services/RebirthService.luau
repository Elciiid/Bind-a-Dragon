--!strict
-- Rebirth: the client asks (RequestRebirth, no arguments); the server checks gold against the cost,
-- resets gold, and adds a rebirth. Everything else is kept. Level caps and areas follow from data.Rebirths.
-- Also shows a rebirth badge above each player's character.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local MilestoneService = require(script.Parent.MilestoneService)
local RebirthMilestones = require(ReplicatedStorage.Shared.RebirthMilestones)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local DataConfig = require(ReplicatedStorage.Shared.Config.Data)
local WorldLabels = require(ReplicatedStorage.Shared.Config.UITheme).WorldLabels

local requestRebirth = ReplicatedStorage.Remotes.RequestRebirth :: RemoteEvent
local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent
local announcement = ReplicatedStorage.Remotes.Announcement :: RemoteEvent

local MIN_REQUEST_INTERVAL = 1 -- seconds between rebirth requests per player
local BADGE_COLOR = Color3.fromRGB(255, 220, 120)
local TITLE_COLOR = Color3.fromRGB(190, 200, 255) -- rank titles; the Champion title is gold (BADGE_COLOR)

local lastRequest: { [Player]: number } = {}

local RebirthService = {}

local function updateBadge(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local data = DataService:GetData(player)
	if head == nil or data == nil then
		return
	end
	local badge = head:FindFirstChild("RebirthBadge") :: BillboardGui?
	if data.Rebirths <= 0 then
		if badge then
			badge:Destroy()
		end
		return
	end
	if badge == nil then
		local newBadge = Instance.new("BillboardGui")
		newBadge.Name = "RebirthBadge"
		newBadge.Size = UDim2.fromOffset(WorldLabels.RebirthBadge.X, math.floor(WorldLabels.RebirthBadge.Y * 1.8))
		newBadge.StudsOffset = Vector3.new(0, 2.8, 0)
		newBadge.MaxDistance = WorldLabels.BadgeMaxDistance
		newBadge.AlwaysOnTop = false
		local title = Instance.new("TextLabel") -- the rank title (RebirthMilestones.GetTitle) above the ★ count
		title.Name = "Title"
		title.Size = UDim2.fromScale(1, 0.42)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.LuckiestGuy
		title.TextScaled = true
		title.TextStrokeTransparency = 1
		title.Parent = newBadge
		local titleOutline = Instance.new("UIStroke")
		titleOutline.Color = Color3.fromRGB(24, 16, 48)
		titleOutline.Thickness = 1.2
		titleOutline.Parent = title
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Position = UDim2.fromScale(0, 0.45)
		label.Size = UDim2.fromScale(1, 0.55)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.LuckiestGuy -- UITheme.Fonts.Title
		label.TextScaled = true
		label.TextColor3 = BADGE_COLOR
		label.TextStrokeTransparency = 1
		label.Parent = newBadge
		local outline = Instance.new("UIStroke")
		outline.Color = Color3.fromRGB(24, 16, 48) -- UITheme.Colors.IconLabelStroke
		outline.Thickness = 1.5
		outline.Parent = label
		newBadge.Parent = head
		badge = newBadge
	end
	((badge :: BillboardGui):FindFirstChild("Label") :: TextLabel).Text = `★ {data.Rebirths}`
	local titleLabel = (badge :: BillboardGui):FindFirstChild("Title") :: TextLabel
	local titleText, gold = RebirthMilestones.GetTitle(data.Rebirths)
	titleLabel.Text = titleText or ""
	titleLabel.TextColor3 = if gold then BADGE_COLOR else TITLE_COLOR
end

-- Areas unlocked by exactly this many rebirths, for the celebration message.
-- An area is built once its AreaSpawn (tag "AreaSpawn" + AreaId attribute) exists in the world.
local function isBuilt(areaId: string): boolean
	for _, spawn in CollectionService:GetTagged("AreaSpawn") do
		if spawn:GetAttribute("AreaId") == areaId then
			return true
		end
	end
	return false
end

-- "Volcano Peak unlocked!" / "Frozen Cliffs unlocked, coming soon!" for areas this rebirth unlocks.
local function newlyUnlocked(rebirths: number): { string }
	local lines = {}
	for areaId, area in Areas do
		if area.RebirthsRequired == rebirths then
			table.insert(lines, if isBuilt(areaId) then `{area.Name} unlocked!` else `{area.Name} unlocked, coming soon!`)
		end
	end
	table.sort(lines)
	return lines
end

local function onRequestRebirth(player: Player)
	local now = os.clock()
	if now - (lastRequest[player] or 0) < MIN_REQUEST_INTERVAL then
		return
	end
	lastRequest[player] = now

	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	if DragonStats.IsAtRebirthCap(data) then
		notify:FireClient(player, "Rebirth cap reached. More rebirths in the next update!", "info")
		return
	end
	local cost = DragonStats.GetRebirthCost(data.Rebirths)
	if data.Gold < cost then
		notify:FireClient(player, `You need {Format.Number(cost)} gold to rebirth.`, "error")
		return
	end

	local capBefore = DragonStats.GetLevelCap(data)
	data.Gold = DataConfig.StartingGold
	data.Rebirths += 1
	local capAfter = DragonStats.GetLevelCap(data)

	local parts = { `Rebirth {data.Rebirths} complete! Income {Format.Multiplier(DragonStats.GetRebirthBonus(data.Rebirths))}.` }
	if capAfter > capBefore then
		table.insert(parts, `Level cap {capBefore} → {capAfter}.`)
	end
	local unlocked = newlyUnlocked(data.Rebirths)
	if #unlocked > 0 then
		table.insert(parts, table.concat(unlocked, " "))
	end
	notify:FireClient(player, table.concat(parts, " "), "moment", {
		Moment = "Rebirth",
		Rebirths = data.Rebirths,
		Income = Format.Multiplier(DragonStats.GetRebirthBonus(data.Rebirths)),
		CapFrom = capBefore,
		CapTo = capAfter,
		Unlocked = unlocked,
	})
	announcement:FireAllClients(`{player.DisplayName} reached Rebirth {data.Rebirths}!`)
	updateBadge(player)
	MilestoneService:OnRebirth(player, data)
end

function RebirthService:Start()
	requestRebirth.OnServerEvent:Connect(onRequestRebirth)

	DataService:OnDataLoaded(function(player)
		updateBadge(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			updateBadge(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return RebirthService
