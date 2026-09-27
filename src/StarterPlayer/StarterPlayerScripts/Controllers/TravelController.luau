--!strict
-- Travel button + "Waystones" menu: one button per Config/Travel destination; picking one asks the server to
-- teleport (TravelService checks everything). The button shows only while the player is in the Valley
-- (Config/Travel Area). PC: top, left of the day/night card; phone: right edge. Wording in Config/Text (Travel).
-- Based on Kyle's TravelController (Hakai branch).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Button = require(script.Parent.UI.Button)
local Window = require(script.Parent.UI.Window)
local CurrentArea = require(ReplicatedStorage.Shared.CurrentArea)
local Travel = require(ReplicatedStorage.Shared.Config.Travel)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local AREA_CHECK_INTERVAL = 0.5 -- seconds between "am I in the Valley?" checks
local ARRIVAL_WAIT = 6 -- seconds to watch for the teleport after asking (the server may stream first)
local ARRIVAL_JUMP = 20 -- studs: a move this big in one step is the teleport

local travelTo = ReplicatedStorage.Remotes.TravelTo :: RemoteEvent
local words = Text.Travel

local TravelController = {}

local window: Window.Window
local travelButton: Button.Button

-- After the teleport, swing the camera behind the character so the player faces what they came for.
local function faceOnArrival()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local from = root.Position
	local started = os.clock()
	while os.clock() - started < ARRIVAL_WAIT do
		task.wait()
		if root.Parent == nil then
			return
		end
		if (root.Position - from).Magnitude > ARRIVAL_JUMP then
			local camera = workspace.CurrentCamera
			local look = root.CFrame.LookVector
			local distance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
			camera.CFrame = CFrame.lookAt(root.Position - look * distance + Vector3.new(0, distance * 0.35, 0), root.Position)
			return
		end
	end
end

local function inValley(): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and CurrentArea.At(root.Position) == Travel.Area
end

function TravelController:Init()
	local gui = HudLayout.MakeScreenGui("TravelHud", "Hud")
	travelButton = Button.new(gui, {
		Text = words.Button,
		Kind = "Primary",
		TextSize = 15,
		OnClick = function()
			window:Toggle()
		end,
	})
	travelButton.Instance.Name = "TravelButton"
	travelButton.Instance.Visible = false

	local rows = #Travel.Destinations
	window = Window.new({
		Name = "Waystones",
		Title = words.Title,
		Size = UDim2.fromOffset(320, 110 + rows * 54),
		MaxSize = Vector2.new(340, 110 + rows * 54),
	})
	local content = window.Content
	local hint = Style.Label(content, words.Hint, "Bold", 15, UITheme.Colors.TextMuted)
	hint.Size = UDim2.new(1, 0, 0, 24)
	for index, destination in Travel.Destinations do
		local button = Button.new(content, {
			Text = words.Places[destination.Id] or destination.Id,
			Kind = destination.Kind :: Button.Kind,
			TextSize = 16,
			OnClick = function()
				travelTo:FireServer(destination.Id)
				window:Close()
				task.spawn(faceOnArrival)
			end,
		})
		button.Instance.Name = destination.Id
		button.Instance.Position = UDim2.fromOffset(0, 32 + (index - 1) * 54)
		button.Instance.Size = UDim2.new(1, 0, 0, 46)
	end

	HudLayout.OnLayoutChanged(function(isPhone)
		local sizes = UITheme.Sizes
		local instance = travelButton.Instance
		if isPhone then
			local size = sizes.PhoneTravelButton
			instance.AnchorPoint = Vector2.new(1, 0.5)
			instance.Position = UDim2.new(1, -sizes.PhoneMargin, 0.55, 0)
			instance.Size = UDim2.fromOffset(size.X, size.Y)
			travelButton.Label.TextSize = 13
		else
			local size = sizes.TravelButton
			instance.AnchorPoint = Vector2.new(1, 0)
			instance.Position = UDim2.new(0.5, -(sizes.SkyCard.X / 2 + sizes.Gap * 2), 0, 12 + (sizes.SkyCard.Y - size.Y) / 2)
			instance.Size = UDim2.fromOffset(size.X, size.Y)
			travelButton.Label.TextSize = 15
		end
	end)
end

function TravelController:Start()
	task.spawn(function()
		while true do
			local show = inValley()
			if travelButton.Instance.Visible ~= show then
				travelButton.Instance.Visible = show
				if not show and window.IsOpen then
					window:Close()
				end
			end
			task.wait(AREA_CHECK_INTERVAL)
		end
	end)
end

return TravelController
