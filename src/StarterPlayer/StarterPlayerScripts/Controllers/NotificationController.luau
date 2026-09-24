--!strict
-- Toast messages at the top of the screen, plus server-wide announcements. Placeholder UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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
	local gui = Instance.new("ScreenGui")
	gui.Name = "Notifications"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

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
end

function NotificationController:Start()
	local announcement = ReplicatedStorage.Remotes.Announcement :: RemoteEvent
	announcement.OnClientEvent:Connect(function(text: string)
		self:Show(text, Color3.fromRGB(255, 220, 120))
	end)
end

return NotificationController
