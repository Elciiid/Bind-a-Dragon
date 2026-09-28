--!strict
-- Brings the roost upgrade stands to life for everyone (the art is built in Studio by ValleyBuild.BuildUpgradeStands,
-- in each plot's "UpgradeStandArt" folder; the owner's levels come from the plot's "RoostSlots" / "RoostIncomeLevel"
-- attributes, set by RoostService):
--   * the star egg and the star coin ("Floater") bob and spin, the crystals ("Orbit") circle the egg
--   * gems ("Pip1"...) light up: one per roost slot, one per GemLevels income levels (the next one glows part-way);
--     a maxed upgrade turns its glow gold and sparkles more
--   * sparkles and a glow light near the camera (no sparkles with Low effects), a burst on every upgrade bought
--   * a board over each stand with the owner's level (hidden while the plot has no owner, and while the stand's
--     own buy prompt is showing, so the board never covers the E prompt)
-- The owner's buy prompts stay in RoostUpgradeController. Numbers in Config/WorldUI.UpgradeStands, words in
-- Config/Text.UpgradeStands.

local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EffectsQuality = require(script.Parent.EffectsQuality)
local WorldBoard = require(script.Parent.UI.WorldBoard)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local RoostConfig = require(ReplicatedStorage.Shared.Config.Roost)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local Settings = require(ReplicatedStorage.Shared.Config.WorldUI).UpgradeStands

local PLOT_TAG = "RoostPlot"
local SCAN_INTERVAL = 1

type Stand = {
	Kind: string, -- "Slots" | "Income"
	Plot: Model,
	Model: Model,
	Parts: { BasePart }, -- floater + orbit parts, moved together
	Base: { CFrame }, -- their built CFrames
	Orbiting: { boolean },
	Center: Vector3, -- the floater's center (bob/spin/orbit around it)
	Pips: { BasePart },
	PipColor: Color3,
	Glow: BasePart, -- egg core / star coin
	GlowColor: Color3,
	Light: PointLight,
	Emitter: ParticleEmitter,
	Board: WorldBoard.WorldBoard,
	BoardPart: BasePart, -- the part the board (and the owner's buy prompt) hang on
	PromptOpen: boolean, -- the buy prompt on BoardPart is showing: the board steps aside
	Scale: number,
	Phase: number,
	Level: number?, -- last shown level (for the burst)
	Rate: number, -- sparkle rate for the current level
}

local UpgradeStandController = {}

local stands: { [Model]: Stand } = {}

local function level(stand: Stand): number?
	if stand.Plot:GetAttribute("OwnerUserId") == nil then
		return nil
	end
	local value = stand.Plot:GetAttribute(if stand.Kind == "Slots" then "RoostSlots" else "RoostIncomeLevel")
	return if type(value) == "number" then value else nil
end

-- Gems, glow color, sparkle rate and board text for the owner's current level; a burst when it went up.
local function refresh(stand: Stand)
	local value = level(stand)
	local maxLevel = if stand.Kind == "Slots" then RoostConfig.MaxSlots else Economy.RoostUpgrades.MaxIncomeLevel
	local progress
	if stand.Kind == "Slots" then
		local slots = value or 0
		for i, pip in stand.Pips do
			local lit = i <= slots
			pip.Material = if lit then Enum.Material.Neon else Enum.Material.Glass
			pip.Color = if lit then Settings.SlotGemColor else stand.PipColor
		end
		progress = math.clamp((slots - RoostConfig.BaseSlots) / (maxLevel - RoostConfig.BaseSlots), 0, 1)
	else
		local levels = value or 0
		local full = math.floor(levels / Settings.GemLevels)
		local partial = (levels % Settings.GemLevels) / Settings.GemLevels
		for i, pip in stand.Pips do
			local lit = i <= full
			pip.Material = if lit then Enum.Material.Neon else Enum.Material.Glass
			pip.Color = if lit then Settings.IncomeGemColor
				elseif i == full + 1 then stand.PipColor:Lerp(Settings.IncomeGemColor, partial * 0.7)
				else stand.PipColor
		end
		progress = levels / maxLevel
	end
	local maxed = value ~= nil and value >= maxLevel
	stand.Glow.Color = if maxed then Settings.MaxedColor else stand.GlowColor
	stand.Emitter.Color = ColorSequence.new(if maxed then Settings.MaxedColor
		elseif stand.Kind == "Slots" then Settings.SlotGemColor
		else Settings.IncomeGemColor)
	stand.Rate = if value == nil then 0 else Settings.SparkleRate * (0.3 + 0.7 * progress) * (if maxed then 2 else 1)

	stand.Board:SetEnabled(value ~= nil and not stand.PromptOpen)
	if value ~= nil then
		local words = Text.UpgradeStands
		if stand.Kind == "Slots" then
			stand.Board:Set(words.SlotsTitle, if maxed then words.MaxedLine else Text.Format(words.SlotsLine, { slots = value, max = maxLevel }))
		else
			local bonus = math.round(Economy.RoostUpgrades.IncomeBonusPerLevel * value * 100)
			stand.Board:Set(words.IncomeTitle, if maxed then Text.Format(words.IncomeLine, { bonus = bonus }) .. " · " .. words.MaxedLine
				else Text.Format(words.IncomeLine, { bonus = bonus }))
		end
	end
	if value and stand.Level and value > stand.Level and not EffectsQuality.IsLow() then
		stand.Emitter:Emit(Settings.BurstParticles)
	end
	stand.Level = value
end

local function register(plot: Model, model: Model)
	local kind = if model.Name == "SlotsStand" then "Slots" elseif model.Name == "IncomeStand" then "Income" else nil
	local floater = model:FindFirstChild("Floater")
	local plinth = model:FindFirstChild("Plinth")
	if kind == nil or floater == nil or plinth == nil or not plinth:IsA("BasePart") then
		return
	end
	local glow = floater:FindFirstChild(if kind == "Slots" then "EggCore" else "StarCoin")
	if glow == nil or not glow:IsA("BasePart") then
		return
	end
	local parts, base, orbiting = {}, {}, {}
	for _, d in floater:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(base, d.CFrame)
			table.insert(orbiting, false)
		end
	end
	local orbit = model:FindFirstChild("Orbit")
	if orbit then
		for _, d in orbit:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
				table.insert(base, d.CFrame)
				table.insert(orbiting, true)
			end
		end
	end
	local pips = {}
	for i = 1, 8 do
		local pip = model:FindFirstChild("Pip" .. i)
		if pip and pip:IsA("BasePart") then
			table.insert(pips, pip)
		end
	end
	local center = (floater :: Model):GetBoundingBox().Position

	local light = Instance.new("PointLight")
	light.Color = glow.Color
	light.Range = Settings.LightRange
	light.Brightness = Settings.LightBrightness
	light.Shadows = false
	light.Enabled = false
	light.Parent = glow

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(1, 3)
	emitter.Lifetime = NumberRange.new(1.2, 2.2)
	emitter.Size = NumberSequence.new(0.6, 0)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 1.5, 0)
	emitter.Parent = glow

	-- the board hangs over the stand's anchor part (upright; the plinth is a rotated cylinder, which would turn the
	-- board's offset sideways)
	local anchor = plot:FindFirstChild("Upgrade" .. kind)
	local boardPart = if anchor and anchor:IsA("BasePart") then anchor else plinth
	local floor = plinth.Position.Y - plinth.Size.X / 2 -- the plinth is a flat cylinder: its X is its height
	local board = WorldBoard.new(boardPart, {
		Size = Settings.BoardSize,
		Icon = if kind == "Slots" then "Menu_Dragons" else "Gold",
		OffsetY = floor + Settings.BoardHeight - boardPart.Position.Y,
		Color = if kind == "Slots" then Settings.SlotGemColor else Settings.IncomeGemColor,
	})
	-- nudge it outward, away from the gate's center line (clear of the owner banner over the path)
	local other = plot:FindFirstChild(if kind == "Slots" then "UpgradeIncome" else "UpgradeSlots")
	if other and other:IsA("BasePart") then
		local away = boardPart.Position - other.Position
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude > 0.1 then
			board.Gui.StudsOffsetWorldSpace += away.Unit * Settings.BoardSideOffset
		end
	end

	local stand: Stand = {
		Kind = kind,
		Plot = plot,
		Model = model,
		Parts = parts,
		Base = base,
		Orbiting = orbiting,
		Center = center,
		Pips = pips,
		PipColor = if pips[1] then pips[1].Color else Color3.new(0.25, 0.25, 0.35),
		Glow = glow,
		GlowColor = glow.Color,
		Light = light,
		Emitter = emitter,
		Board = board,
		BoardPart = boardPart,
		PromptOpen = false,
		Scale = model:GetScale(),
		Phase = math.random() * 10,
		Level = nil,
		Rate = 0,
	}
	stands[model] = stand
	refresh(stand)
	local function changed()
		refresh(stand)
	end
	plot:GetAttributeChangedSignal("RoostSlots"):Connect(changed)
	plot:GetAttributeChangedSignal("RoostIncomeLevel"):Connect(changed)
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(changed)
end

local function scan()
	for model, stand in stands do
		if model.Parent == nil then
			stand.Board.Gui:Destroy()
			stands[model] = nil
		end
	end
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		local art = plot:IsA("Model") and plot:FindFirstChild("UpgradeStandArt")
		if art then
			for _, model in art:GetChildren() do
				if model:IsA("Model") and stands[model] == nil then
					register(plot :: Model, model)
				end
			end
		end
	end
end

local function animate(stand: Stand, t: number)
	local bob = math.sin(t * Settings.BobSpeed + stand.Phase) * Settings.BobHeight * stand.Scale
	local spin = t * (if stand.Kind == "Slots" then Settings.EggSpin else Settings.CoinSpin)
	local center = stand.Center
	local float = CFrame.new(center + Vector3.new(0, bob, 0)) * CFrame.Angles(0, spin, 0) * CFrame.new(-center)
	local around = CFrame.new(center + Vector3.new(0, bob * 0.5, 0)) * CFrame.Angles(0, t * Settings.OrbitSpeed, 0) * CFrame.new(-center)
	local cframes = table.create(#stand.Parts)
	for i, cf in stand.Base do
		cframes[i] = (if stand.Orbiting[i] then around else float) * cf
	end
	workspace:BulkMoveTo(stand.Parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- The owner's buy prompt hangs on the same part as the board: hide the board while the prompt shows.
local function onPrompt(prompt: ProximityPrompt, open: boolean)
	for _, stand in stands do
		if prompt.Parent == stand.BoardPart then
			stand.PromptOpen = open
			stand.Board:SetEnabled(level(stand) ~= nil and not open)
		end
	end
end

function UpgradeStandController:Start()
	ProximityPromptService.PromptShown:Connect(function(prompt)
		onPrompt(prompt, true)
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		onPrompt(prompt, false)
	end)
	local sinceScan = SCAN_INTERVAL
	RunService.Heartbeat:Connect(function(dt)
		sinceScan += dt
		if sinceScan >= SCAN_INTERVAL then
			sinceScan = 0
			scan()
		end
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		local from = camera.CFrame.Position
		local low = EffectsQuality.IsLow()
		local t = os.clock()
		for _, stand in stands do
			local distance = (stand.Center - from).Magnitude
			local near = distance < Settings.AnimateDistance
			if near then
				animate(stand, t)
			end
			local lit = stand.Level ~= nil and distance < Settings.LightDistance
			if stand.Light.Enabled ~= lit then
				stand.Light.Enabled = lit
			end
			local rate = if near and not low then stand.Rate else 0
			if stand.Emitter.Rate ~= rate then
				stand.Emitter.Rate = rate
			end
		end
	end)
end

return UpgradeStandController
