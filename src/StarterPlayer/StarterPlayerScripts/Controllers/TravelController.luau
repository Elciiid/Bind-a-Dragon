--!strict
-- Travel buttons: three big HUD icons in a row at the very top-center (in the middle of Roblox's top bar) (Portals | Home | Market; Home in the middle, a bit
-- bigger), in UITheme.Travel. Tapping one asks the server to teleport (TravelService checks everything; works from
-- any area and brings the player back to the Valley), then the camera swings to face the destination.
-- The day/night pill (DayNightController) sits under the row. Destinations in Config/Travel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(script.Parent.HudLayout)
local HudIcon = require(script.Parent.UI.HudIcon)
local Button = require(script.Parent.UI.Button)
local Window = require(script.Parent.UI.Window)
local DataController = require(script.Parent.DataController)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local RebirthMilestones = require(ReplicatedStorage.Shared.RebirthMilestones)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local Travel = require(ReplicatedStorage.Shared.Config.Travel)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Geometry = require(ReplicatedStorage.Shared.UIGeometry)

local ARRIVAL_WAIT = 6 -- seconds to watch for the teleport after asking (the server may stream first)
local ARRIVAL_JUMP = 20 -- studs: a move this big in one step is the teleport

local travelTo = ReplicatedStorage.Remotes.TravelTo :: RemoteEvent
local travelToAltar = ReplicatedStorage.Remotes.TravelToAltar :: RemoteEvent

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
	HudLayout.HideWithPopups(gui)
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
		HudLayout.RegisterTutorialTarget(destination.Id, icon.Instance)
	end

	-- Altars (R18 milestone, Altar Travel): a fourth icon that opens a short list of the areas whose altar you can go to.
	local altarLook = UITheme.Travel.Altars
	local altarIcon = HudIcon.new(row, { Image = altarLook.Icon, Glyph = altarLook.Glyph, Label = Text.Milestones.Altars.Button, Color = altarLook.Color })
	altarIcon.Instance.Name = "Altars"
	altarIcon.Instance.LayoutOrder = altarLook.Order
	altarIcon.Instance.Visible = false
	icons.Altars = altarIcon
	local altarWindow = Window.new({
		Name = "Altars",
		Title = Text.Milestones.Altars.Heading,
		Icon = "Travel_Portals",
		Size = UDim2.new(0.8, 0, 0.8, 0),
		MaxSize = Vector2.new(360, 400),
	})
	local altarScroll = Instance.new("ScrollingFrame")
	altarScroll.Size = UDim2.fromScale(1, 1)
	altarScroll.BackgroundTransparency = 1
	altarScroll.BorderSizePixel = 0
	altarScroll.CanvasSize = UDim2.new()
	altarScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	altarScroll.ScrollBarThickness = UITheme.MobileUI.Scrollbar
	altarScroll.Parent = altarWindow.Content
	local altarList = Instance.new("UIListLayout")
	altarList.Padding = UDim.new(0, 8)
	altarList.SortOrder = Enum.SortOrder.LayoutOrder
	altarList.Parent = altarScroll
	local function fillAltars()
		for _, child in altarScroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local data = DataController:Get()
		local ordered = {}
		for id, area in Areas do
			table.insert(ordered, { Id = id, Area = area })
		end
		table.sort(ordered, function(a, b)
			return a.Area.Order < b.Area.Order
		end)
		for index, entry in ordered do
			local unlocked = data ~= nil and DragonStats.IsAreaUnlocked(data, entry.Id)
			local altarButton = Button.new(altarScroll, {
				Text = if unlocked then entry.Area.Name else Text.Format(Text.Milestones.Altars.Locked, { n = entry.Area.RebirthsRequired }),
				Kind = if unlocked then "Confirm" else "Cancel",
				TextSize = 20,
				OnClick = function()
					if unlocked then
						travelToAltar:FireServer(entry.Id) -- the server checks the milestone, the area and the altar
						altarWindow:Close()
						task.spawn(faceOnArrival)
					end
				end,
			})
			altarButton.Instance.LayoutOrder = index
			altarButton.Instance.Size = UDim2.new(1, 0, 0, 46)
			altarButton:SetEnabled(unlocked)
		end
	end
	altarIcon.Instance.Activated:Connect(function()
		fillAltars()
		altarWindow:Toggle()
	end)
	local function layoutTravel(phone: boolean)
		local sizes = UITheme.Sizes
		local small = if phone then UITheme.MobileUI.TravelIcon else sizes.TravelIcon
		local home = if phone then UITheme.MobileUI.TravelIcon else sizes.TravelHomeIcon
		local label = if phone then UITheme.MobileUI.TravelText else sizes.HudLabel - 2
		local count = if altarIcon.Instance.Visible then 4 else 3
		local safe, insets, reserved = HudLayout.GetTravelHost()
		local wanted = if phone then UITheme.MobileUI.TravelSlot else sizes.TravelSlot
		local gap = UITheme.MobileUI.TravelGap
		local usable = HudLayout.GetUsableRect()
		local center = usable.Min.X + usable.Width / 2 - safe.Min.X
		local box = Geometry.TopRow(safe.Width, reserved, count, wanted, UITheme.MobileUI.Touch, gap, center)
		-- If a genuinely centered row cannot fit beside native controls, use the core-safe top
		-- edge with the same small margin. Never push it off-center or overlap Roblox's menu/cutout.
		if not box.Fits then
			safe, insets = usable, Enum.ScreenInsets.CoreUISafeInsets
			box = Geometry.TopRow(safe.Width, 0, count, wanted, UITheme.MobileUI.Touch, gap, safe.Width / 2)
		end
		gui.ScreenInsets = insets
		list.Padding = UDim.new(0, gap)
		local height = math.max(UITheme.MobileUI.Touch, home + label + 2)
		for id, icon in icons do
			icon:Resize(if id == "Home" then home else small, label)
			icon.Instance.Size = UDim2.fromOffset(box.Slot, height)
			icon.Label.Size = UDim2.new(1, 0, 0, label)
		end
		row.Position = UDim2.fromOffset(box.X, UITheme.MobileUI.TravelTop)
		row.Size = UDim2.fromOffset(0, height)
		HudLayout.SetTravelBottom(safe.Min.Y + UITheme.MobileUI.TravelTop + height)
	end
	local function refreshAltars()
		local data = DataController:Get()
		altarIcon.Instance.Visible = data ~= nil and RebirthMilestones.Has(data.Rebirths, "AltarTravel")
		layoutTravel(HudLayout.IsPhone())
	end
	DataController:OnChanged("Rebirths", refreshAltars)
	task.defer(refreshAltars)

	HudLayout.OnLayoutChanged(layoutTravel)
end

return TravelController
