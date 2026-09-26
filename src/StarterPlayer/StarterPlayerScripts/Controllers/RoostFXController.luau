--!strict
-- Roost life (client only):
--  * Owner banners: each owned pen shows its owner's avatar and "Name's Roost" over the gate (world label rules),
--    replacing the plain server sign locally. Empty pens show nothing.
--  * Gold pops: now and then a "+gold" rises from one of YOUR roost dragons (their share of your roost income).
--  * Bursts: a sparkle burst on your roost dragon when it levels up, a bigger one with a sound when it evolves.
-- Settings: Config/WorldUI Roost.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local DataController = require(script.Parent.DataController)
local EffectsQuality = require(script.Parent.EffectsQuality)
local Style = require(script.Parent.UI.Style)
local Icon = require(script.Parent.UI.Icon)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local WorldUI = require(ReplicatedStorage.Shared.Config.WorldUI)

local RoostConfig = WorldUI.Roost

local RoostFXController = {}

local banners: { [Model]: BillboardGui } = {}
local thumbnails: { [number]: string } = {}
local lastLevels: { [string]: number } = {}

local function ownPlot(): Model?
	for _, plot in CollectionService:GetTagged("RoostPlot") do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
			return plot
		end
	end
	return nil
end

local function thumbnail(userId: number): string
	local cached = thumbnails[userId]
	if cached then
		return cached
	end
	local ok, image = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
	end)
	local result = if ok then image else ""
	thumbnails[userId] = result
	return result
end

local function updateBanner(plot: Model)
	local sign = plot:FindFirstChild("Sign")
	if sign == nil or not sign:IsA("BasePart") then
		return
	end
	-- the server's plain sign stays hidden on this client
	local serverSign = sign:FindFirstChild("OwnerGui")
	if serverSign and serverSign:IsA("BillboardGui") then
		serverSign.Enabled = false
	end
	local ownerId = plot:GetAttribute("OwnerUserId")
	local banner = banners[plot]
	if type(ownerId) ~= "number" then
		if banner then
			banner.Enabled = false
		end
		return
	end
	if banner == nil then
		local size = RoostConfig.BannerSize
		local gui = Instance.new("BillboardGui")
		gui.Name = "OwnerBanner"
		gui.Size = UDim2.fromOffset(size.X, size.Y)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.MaxDistance = UITheme.WorldLabels.MaxDistance
		gui.AlwaysOnTop = false
		gui.LightInfluence = 0
		gui.Parent = sign
		local panel = Instance.new("Frame")
		panel.Size = UDim2.fromScale(1, 1)
		panel.BackgroundColor3 = Color3.new(1, 1, 1)
		Style.Gradient(panel, UITheme.Colors.PanelTop, UITheme.Colors.PanelBottom)
		Style.Corner(panel, UITheme.SmallCorner)
		Style.Stroke(panel, UITheme.Colors.Trim, 2)
		panel.Parent = gui
		local avatar = Instance.new("ImageLabel")
		avatar.Name = "Avatar"
		avatar.AnchorPoint = Vector2.new(0, 0.5)
		avatar.Position = UDim2.new(0, 4, 0.5, 0)
		avatar.Size = UDim2.fromOffset(size.Y - 8, size.Y - 8)
		avatar.BackgroundColor3 = UITheme.Colors.TitleBar
		Style.Round(avatar)
		Style.Stroke(avatar, UITheme.Colors.Gold, 1.5)
		avatar.Parent = panel
		local label = Style.Label(panel, "", "Heavy", 16, UITheme.Colors.Gold)
		label.Name = "Name"
		label.Position = UDim2.fromOffset(size.Y + 2, 4)
		label.Size = UDim2.new(1, -(size.Y + 8), 1, -8)
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		banners[plot] = gui
		banner = gui
	end
	local gui = banner :: BillboardGui
	gui.Enabled = true
	local owner = Players:GetPlayerByUserId(ownerId)
	local name = if owner then owner.DisplayName else "?"
	local panel = gui:FindFirstChildOfClass("Frame") :: Frame
	(panel:FindFirstChild("Name") :: TextLabel).Text = `{name}'s Roost`
	task.spawn(function()
		(panel:FindFirstChild("Avatar") :: ImageLabel).Image = thumbnail(ownerId)
	end)
end

local function watchPlot(plot: Instance)
	if not plot:IsA("Model") then
		return
	end
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		updateBanner(plot)
	end)
	local sign = plot:FindFirstChild("Sign") or plot:WaitForChild("Sign", 10)
	if sign then
		sign.ChildAdded:Connect(function(child)
			if child.Name == "OwnerGui" and child:IsA("BillboardGui") then
				child.Enabled = false
				child:GetPropertyChangedSignal("Enabled"):Connect(function()
					child.Enabled = false
				end)
			end
		end)
		local existing = sign:FindFirstChild("OwnerGui")
		if existing and existing:IsA("BillboardGui") then
			existing:GetPropertyChangedSignal("Enabled"):Connect(function()
				existing.Enabled = false
			end)
		end
	end
	updateBanner(plot)
end

local function dragonModel(dragonId: string): Model?
	local plot = ownPlot()
	local model = plot and plot:FindFirstChild(`Dragon_{dragonId}`)
	return if model and model:IsA("Model") then model else nil
end

local function burst(model: Model, count: number, color: Color3)
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if part == nil then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(6, 14)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Size = NumberSequence.new(0.7, 0)
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Parent = part
	emitter:Emit(if EffectsQuality.IsLow() then math.ceil(count / 3) else count)
	task.delay(2, function()
		emitter:Destroy()
	end)
end

local function goldPop(model: Model, amount: number)
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if part == nil then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, model:GetExtentsSize().Y / 2 + 1, 0)
	gui.MaxDistance = UITheme.WorldLabels.MaxDistance
	gui.LightInfluence = 0
	gui.Parent = part
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 3)
	layout.Parent = row
	local icon = Icon.new(row, "Gold", UITheme.Colors.Gold)
	icon.Size = UDim2.fromOffset(22, 22)
	local label = Style.Label(row, `+{Format.Number(amount)}`, "Heavy", 20, UITheme.Colors.Gold)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 26)
	label.TextWrapped = false
	label.LayoutOrder = 2
	local start = os.clock()
	local base = gui.StudsOffsetWorldSpace
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - start) / RoostConfig.GoldPopSeconds
		if t >= 1 or gui.Parent == nil then
			connection:Disconnect()
			gui:Destroy()
			return
		end
		gui.StudsOffsetWorldSpace = base + Vector3.new(0, RoostConfig.GoldPopRise * t, 0)
		local fade = math.max(0, (t - 0.6) / 0.4)
		label.TextTransparency = fade
		label.TextStrokeTransparency = fade
		if icon:IsA("ImageLabel") then
			icon.ImageTransparency = fade
		end
	end)
end

local function onDragonsChanged()
	local data = DataController:Get()
	if data == nil then
		return
	end
	for id, dragon in data.Dragons do
		local before = lastLevels[id]
		lastLevels[id] = dragon.Level
		if before and dragon.Level > before and table.find(data.RoostDragonIds, id) then
			local evolved = DragonStats.GetStage(dragon.Level).Id ~= DragonStats.GetStage(before).Id
			-- the server rebuilds the roost model after a level-up; wait for the new one
			task.delay(0.4, function()
				local model = dragonModel(id)
				if model == nil then
					return
				end
				if evolved then
					burst(model, RoostConfig.EvolveParticles, UITheme.Colors.Gold)
					local sound = Instance.new("Sound")
					sound.SoundId = RoostConfig.EvolveSound
					local volume = Players.LocalPlayer:GetAttribute("SoundVolume")
					sound.Volume = 0.6 * (if type(volume) == "number" then volume else 1)
					sound.Parent = SoundService
					sound.Ended:Connect(function()
						sound:Destroy()
					end)
					sound:Play()
				else
					burst(model, RoostConfig.LevelUpParticles, UITheme.Colors.Gold)
				end
			end)
		end
	end
end

function RoostFXController:Start()
	CollectionService:GetInstanceAddedSignal("RoostPlot"):Connect(function(plot)
		task.spawn(watchPlot, plot)
	end)
	for _, plot in CollectionService:GetTagged("RoostPlot") do
		task.spawn(watchPlot, plot)
	end
	Players.PlayerAdded:Connect(function()
		for plot in banners do
			updateBanner(plot)
		end
	end)

	task.spawn(function()
		local data = DataController:WaitForData()
		for id, dragon in data.Dragons do
			lastLevels[id] = dragon.Level
		end
		DataController:OnChanged("Dragons", onDragonsChanged)
	end)

	-- Gold pops from your own roost dragons
	task.spawn(function()
		local rng = Random.new()
		while true do
			local interval = rng:NextNumber(RoostConfig.GoldPopEvery.Min, RoostConfig.GoldPopEvery.Max)
			task.wait(interval)
			local data = DataController:Get()
			local plot = ownPlot()
			if data and plot and #data.RoostDragonIds > 0 then
				local id = data.RoostDragonIds[rng:NextInteger(1, #data.RoostDragonIds)]
				local model = plot:FindFirstChild(`Dragon_{id}`)
				if model and model:IsA("Model") then
					local share = DragonStats.GetRoostIncome(data) / #data.RoostDragonIds
					goldPop(model, share * interval)
				end
			end
		end
	end)
end

return RoostFXController
