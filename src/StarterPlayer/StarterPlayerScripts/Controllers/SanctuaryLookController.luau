--!strict
-- Sanctuary looks, client side (Valley rework; Config/WorldUI.SanctuaryLooks). Each sanctuary shows one look: a kit of
-- set pieces (Wild Hollow, Crystal Garden, Celestial Sanctum) built in Studio by ValleyBuild.BuildSanctuaryLooks into
-- ReplicatedStorage.Assets.SanctuaryLooks.<LookId>.<PlotName>, in world position; every top-level child of a kit is a
-- Model (a piece). The server sets the plot attribute "SanctuaryLook" (RoostService). This controller clones in the kit
-- of sanctuaries near the camera only (CloneDistance / DropDistance) and drops it again when the camera goes away, so
-- far sanctuaries cost nothing. When a sanctuary's look changes while it is near, the old kit sinks away, the new one
-- grows in piece after piece from the gate outward with a sparkle burst and a sound, and its owner gets a reward pop-up.
-- Kit lights are on only close to the camera. A look with no kit built yet falls back to the default look's kit.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EffectsQuality = require(script.Parent.EffectsQuality)
local NotificationController = require(script.Parent.NotificationController)
local SanctuaryLooks = require(ReplicatedStorage.Shared.SanctuaryLooks)
local WorldUI = require(ReplicatedStorage.Shared.Config.WorldUI)

local Settings = WorldUI.SanctuaryLooks
local PLOT_TAG = "RoostPlot"
local SCAN_INTERVAL = 1
local UPDATE_INTERVAL = 0.5

type Move = { Piece: Model, Base: number, From: number, To: number, Start: number, Duration: number, Destroy: boolean, Kit: Folder? }

type Sanctuary = {
	Plot: Model,
	Look: string?, -- the look whose kit is shown (nil = nothing cloned in)
	Kit: Folder?,
	Center: Vector3,
	Lights: { PointLight },
	Spinners: { Model }, -- kit models with SpinAxis / SpinSpeed attributes (the armillary rings)
	Near: boolean, -- the camera is within SpinDistance
}

local SanctuaryLookController = {}

local sanctuaries: { [Model]: Sanctuary } = {}
local moves: { Move } = {}
local localFolder: Folder? = nil

local function easeOutBack(t: number): number
	local c1, c3 = 1.4, 2.4
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function kitFor(look: string, plotName: string): Instance?
	local root = ReplicatedStorage:FindFirstChild("Assets")
	root = root and root:FindFirstChild("SanctuaryLooks")
	if root == nil then
		return nil
	end
	local kit = root:FindFirstChild(look)
	kit = kit and kit:FindFirstChild(plotName)
	if kit == nil and look ~= Settings.Default then
		kit = root:FindFirstChild(Settings.Default)
		kit = kit and kit:FindFirstChild(plotName)
	end
	return kit
end

local function pieces(kit: Instance): { Model }
	local list = {}
	for _, child in kit:GetChildren() do
		if child:IsA("Model") then
			table.insert(list, child)
		end
	end
	return list
end

local function collectLights(sanctuary: Sanctuary)
	local lights, spinners = {}, {}
	if sanctuary.Kit then
		for _, d in sanctuary.Kit:GetDescendants() do
			if d:IsA("PointLight") then
				table.insert(lights, d)
			elseif d:IsA("Model") and type(d:GetAttribute("SpinSpeed")) == "number" and d:GetAttribute("SpinSpeed") ~= 0 then
				table.insert(spinners, d)
			end
		end
	end
	sanctuary.Lights = lights
	sanctuary.Spinners = spinners
end

-- Clones the kit in. Animated: every piece starts tiny and grows, gate first, then outward.
local function showKit(sanctuary: Sanctuary, look: string, animate: boolean)
	local source = kitFor(look, sanctuary.Plot.Name)
	sanctuary.Look = look
	if source == nil or localFolder == nil then
		sanctuary.Kit = nil
		collectLights(sanctuary)
		return
	end
	local kit = source:Clone() :: Folder
	kit.Name = `{sanctuary.Plot.Name}_{look}`
	if animate then
		local list = pieces(kit)
		local sign = sanctuary.Plot:FindFirstChild("Sign")
		local gate = if sign and sign:IsA("BasePart") then sign.Position else sanctuary.Center
		table.sort(list, function(a, b)
			return (a:GetPivot().Position - gate).Magnitude < (b:GetPivot().Position - gate).Magnitude
		end)
		local now = os.clock()
		local spread = math.max(0, Settings.InSeconds - Settings.PieceSeconds)
		for i, piece in list do
			local base = piece:GetScale()
			piece:ScaleTo(base * Settings.StartScale)
			table.insert(moves, {
				Piece = piece, Base = base, From = Settings.StartScale, To = 1,
				Start = now + spread * (i - 1) / math.max(1, #list - 1), Duration = Settings.PieceSeconds, Destroy = false,
			})
		end
	end
	kit.Parent = localFolder
	sanctuary.Kit = kit
	collectLights(sanctuary)
end

-- Removes the shown kit: sinking away (animated) or at once.
local function hideKit(sanctuary: Sanctuary, animate: boolean)
	local kit = sanctuary.Kit
	sanctuary.Kit = nil
	sanctuary.Look = nil
	sanctuary.Lights = {}
	sanctuary.Spinners = {}
	if kit == nil then
		return
	end
	if not animate then
		kit:Destroy()
		return
	end
	local list = pieces(kit)
	local now = os.clock()
	for i, piece in list do
		table.insert(moves, {
			Piece = piece, Base = piece:GetScale(), From = 1, To = Settings.StartScale,
			Start = now + (Settings.OutSeconds - 0.6) * (i - 1) / math.max(1, #list - 1), Duration = 0.6, Destroy = true, Kit = kit,
		})
	end
	task.delay(Settings.OutSeconds + 0.5, function()
		kit:Destroy()
	end)
end

local function burst(sanctuary: Sanctuary, look: string)
	local plot = sanctuary.Plot
	local sign = plot:FindFirstChild("Sign")
	local at = if sign and sign:IsA("BasePart") then sign.Position else sanctuary.Center
	if localFolder == nil then
		return
	end
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = CFrame.new(at + Vector3.new(0, 4, 0))
	part.Parent = localFolder
	if not EffectsQuality.IsLow() then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 226, 150), Color3.fromRGB(150, 230, 190))
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new(1.6, 0)
		emitter.Lifetime = NumberRange.new(1.4, 2.6)
		emitter.Speed = NumberRange.new(14, 30)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, -6, 0)
		emitter.Rate = 0
		emitter.Parent = part
		emitter:Emit(Settings.BurstParticles)
	end
	local sound = Instance.new("Sound")
	sound.SoundId = WorldUI.SanctuaryTiers.BurstSound
	local volume = Players.LocalPlayer:GetAttribute("SoundVolume")
	sound.Volume = WorldUI.SanctuaryTiers.BurstVolume * (if type(volume) == "number" then volume else 1)
	sound.RollOffMaxDistance = 300
	sound.Parent = part
	sound:Play()
	task.delay(4, function()
		part:Destroy()
	end)
	if plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
		NotificationController:Moment({ Moment = "Look", Name = SanctuaryLooks.NameOf(look) }, `New look: {SanctuaryLooks.NameOf(look)}`)
	end
end

local function wantedLook(plot: Model): string
	local look = plot:GetAttribute("SanctuaryLook")
	return if type(look) == "string" and look ~= "" then look else Settings.Default
end

-- The plot's look changed: while the sanctuary is near, transform it (with the burst); otherwise just remember.
local function onLookChanged(sanctuary: Sanctuary)
	local look = wantedLook(sanctuary.Plot)
	if sanctuary.Look == nil or sanctuary.Look == look then
		return -- nothing shown yet (the update loop shows it), or nothing changed
	end
	hideKit(sanctuary, true)
	showKit(sanctuary, look, true)
	burst(sanctuary, look)
end

local function register(plot: Model)
	local center = plot:GetAttribute("RoamCenter")
	if typeof(center) ~= "Vector3" then
		return
	end
	local sanctuary: Sanctuary = { Plot = plot, Look = nil, Kit = nil, Center = center, Lights = {}, Spinners = {}, Near = false }
	sanctuaries[plot] = sanctuary
	plot:GetAttributeChangedSignal("SanctuaryLook"):Connect(function()
		onLookChanged(sanctuary)
	end)
	plot.Destroying:Connect(function()
		hideKit(sanctuary, false)
		sanctuaries[plot] = nil
	end)
end

local function scan()
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		if plot:IsA("Model") and sanctuaries[plot] == nil then
			register(plot)
		end
	end
end

-- Clone kits in near the camera, drop them beyond DropDistance, switch the kit lights by distance.
local function update()
	local camera = workspace.CurrentCamera
	local from = if camera then camera.CFrame.Position else Vector3.zero
	for _, sanctuary in sanctuaries do
		local distance = (sanctuary.Center - from).Magnitude
		sanctuary.Near = distance < Settings.SpinDistance
		if sanctuary.Kit == nil and sanctuary.Look == nil and distance < Settings.CloneDistance then
			showKit(sanctuary, wantedLook(sanctuary.Plot), false)
		elseif sanctuary.Look ~= nil and distance > Settings.DropDistance then
			hideKit(sanctuary, false)
		end
		for _, light in sanctuary.Lights do
			local parent = light.Parent
			local on = parent ~= nil and parent:IsA("BasePart") and (parent.Position - from).Magnitude < Settings.LightDistance
			if light.Enabled ~= on then
				light.Enabled = on
			end
		end
	end
end

-- Turns the spinning kit models (armillary rings) of sanctuaries near the camera around their world axis.
local function stepSpin(dt: number)
	for _, sanctuary in sanctuaries do
		if sanctuary.Near then
			for _, model in sanctuary.Spinners do
				local axis = model:GetAttribute("SpinAxis")
				local speed = model:GetAttribute("SpinSpeed")
				if typeof(axis) == "Vector3" and type(speed) == "number" and model.Parent ~= nil then
					local pivot = model:GetPivot()
					model:PivotTo(CFrame.fromAxisAngle(axis, speed * dt) * pivot.Rotation + pivot.Position)
				end
			end
		end
	end
end

local function stepMoves()
	if #moves == 0 then
		return
	end
	local now = os.clock()
	for i = #moves, 1, -1 do
		local m = moves[i]
		if m.Piece.Parent == nil then
			table.remove(moves, i)
		elseif now >= m.Start then
			local t = math.clamp((now - m.Start) / m.Duration, 0, 1)
			local eased = if m.To > m.From then easeOutBack(t) else t * t
			m.Piece:ScaleTo(m.Base * (m.From + (m.To - m.From) * eased))
			if t >= 1 then
				table.remove(moves, i)
			end
		end
	end
end

function SanctuaryLookController:Start()
	local f = Instance.new("Folder")
	f.Name = "SanctuaryLooks"
	f.Parent = workspace
	localFolder = f
	local sinceScan, sinceUpdate = SCAN_INTERVAL, UPDATE_INTERVAL
	RunService.Heartbeat:Connect(function(dt)
		sinceScan += dt
		sinceUpdate += dt
		if sinceScan >= SCAN_INTERVAL then
			sinceScan = 0
			scan()
		end
		if sinceUpdate >= UPDATE_INTERVAL then
			sinceUpdate = 0
			update()
		end
		stepMoves()
		stepSpin(dt)
	end)
end

return SanctuaryLookController
