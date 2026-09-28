--!strict
-- Travel buttons: three big HUD icons in a row at the very top-center (in the middle of Roblox's top bar) (Portals | Home | Market; Home in the middle, a bit
-- bigger), in UITheme.Travel. Tapping one asks the server to teleport (TravelService checks everything; works from
-- any area and brings the player back to the Valley), then the camera swings to face the destination.
-- The day/night pill (DayNightController) sits under the row. Destinations in Config/Travel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(script.Parent.HudLayout)
local HudIcon = require(script.Parent.UI.HudIcon)
local Travel = require(ReplicatedStorage.Shared.Config.Travel)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local ARRIVAL_WAIT = 6 -- seconds to watch for the teleport after asking (the server may stream first)
local ARRIVAL_JUMP = 20 -- studs: a move this big in one step is the teleport

local travelTo = ReplicatedStorage.Remotes.TravelTo :: RemoteEvent

local TravelController = {}

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

function TravelController:Init()
	local gui = HudLayout.MakeScreenGui("TravelHud", "Hud")
	gui.ScreenInsets = Enum.ScreenInsets.None -- the row sits at the very top, in the middle of Roblox's top bar
	local row = Instance.new("Frame")
	row.Name = "TravelRow"
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.BackgroundTransparency = 1
	row.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row

	local icons: { [string]: HudIcon.HudIcon } = {}
	for _, destination in Travel.Destinations do
		local look = UITheme.Travel[destination.Id]
		local icon = HudIcon.new(row, { Image = look.Icon, Glyph = look.Glyph, Label = look.Label, Color = look.Color })
		icon.Instance.Name = destination.Id
		icon.Instance.LayoutOrder = look.Order
		icon.Instance.Activated:Connect(function()
			travelTo:FireServer(destination.Id) -- the server checks the id, cooldown and landing spot
			task.spawn(faceOnArrival)
		end)
		icons[destination.Id] = icon
	end

	HudLayout.OnLayoutChanged(function(phone)
		local sizes = UITheme.Sizes
		local small = if phone then sizes.PhoneTravelIcon else sizes.TravelIcon
		local home = if phone then sizes.PhoneTravelHomeIcon else sizes.TravelHomeIcon
		local label = if phone then sizes.PhoneHudLabel else sizes.HudLabel - 2
		list.Padding = UDim.new(0, if phone then 10 else 18)
		for id, icon in icons do
			icon:Resize(if id == "Home" then home else small, label)
		end
		row.Position = UDim2.new(0.5, 0, 0, if phone then sizes.PhoneTravelTop else sizes.TravelTop)
		row.Size = UDim2.fromOffset(0, home + label + 2)
	end)
end

return TravelController
