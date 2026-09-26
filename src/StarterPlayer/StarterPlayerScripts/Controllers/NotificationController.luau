--!strict
-- Toast messages at the top of the screen, plus server-wide announcements. Placeholder UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local HudLayout = require(script.Parent.HudLayout)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local TOAST_SECONDS = 4

local NotificationController = {}

local container: Frame

function NotificationController:Show(text: string, color: Color3?)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 36)
	label.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	Instance.new("UICorner").Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = label
	label.Parent = container

	task.delay(TOAST_SECONDS, function()
		local fade = TweenInfo.new(0.5)
		TweenService:Create(label, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.wait(0.5)
		label:Destroy()
	end)
end

function NotificationController:Init()
	local gui = HudLayout.MakeScreenGui("Notifications", "Notifications")

	container = Instance.new("Frame")
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Position = UDim2.new(0.5, 0, 0, 70)
	container.Size = UDim2.new(0.9, 0, 0.5, 0)
	container.BackgroundTransparency = 1
	container.Parent = gui
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(520, math.huge)
	sizeLimit.Parent = container
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = container
	HudLayout.OnLayoutChanged(function(isPhone)
		container.Position = UDim2.new(0.5, 0, 0, if isPhone then Theme.Sizes.PhoneCardTop + 120 else 70)
	end)
end

local KIND_COLORS: { [string]: Color3 } = {
	error = Color3.fromRGB(255, 120, 120),
	success = Color3.fromRGB(130, 230, 140),
	info = Color3.new(1, 1, 1),
}

function NotificationController:Start()
	local announcement = ReplicatedStorage.Remotes.Announcement :: RemoteEvent
	announcement.OnClientEvent:Connect(function(text: string)
		self:Show(text, Color3.fromRGB(255, 220, 120))
	end)

	-- Messages for just this player: Notify:FireClient(player, text, kind) where kind is "error" | "success" | "info".
	local notify = ReplicatedStorage.Remotes.Notify :: RemoteEvent
	notify.OnClientEvent:Connect(function(text: string, kind: string?)
		self:Show(text, KIND_COLORS[kind or "info"])
	end)
end

return NotificationController
