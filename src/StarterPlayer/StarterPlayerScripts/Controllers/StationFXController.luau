--!strict
-- Station boards and glows (client only), all within the world label distance:
--  * Rune Shrine: a small board with your Wyrm Runes; the shrine glows and sparkles while you have any.
--  * Dragonstone Forge: a board with your Dragonstones; the forge's fire flares while you have any.
--  * Star Merchant: tonight's Stardust price for you and when it resets.
--  * Dragon Spire door: your record floor and "Climb!".
-- One thing at a time: while a station's own prompt shows (e.g. the Spire's "Climb" E prompt), its board hides, and so
-- does your own ★ rebirth badge (so it never covers the prompt).
-- Settings: Config/WorldUI Stations.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local EffectsQuality = require(script.Parent.EffectsQuality)
local WorldBoard = require(script.Parent.UI.WorldBoard)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local WorldUI = require(ReplicatedStorage.Shared.Config.WorldUI)

local Stations = WorldUI.Stations

type Glowing = { Board: WorldBoard.WorldBoard, Light: PointLight, Emitter: ParticleEmitter, Rate: number, Kind: string }

local StationFXController = {}

local glowing: { [Instance]: Glowing } = {}
local merchants: { [Instance]: WorldBoard.WorldBoard } = {}
local spires: { [Instance]: WorldBoard.WorldBoard } = {}
local openPrompts: { [ProximityPrompt]: boolean } = {}

local function modelTop(model: Instance): (BasePart?, number)
	local part = if model:IsA("Model") then model.PrimaryPart elseif model:IsA("BasePart") then model else nil
	if part == nil then
		return nil, 0
	end
	local height = 4
	if model:IsA("Model") then
		local cf, size = model:GetBoundingBox()
		height = (cf.Position.Y + size.Y / 2) - part.Position.Y + 1.5
	end
	return part, height
end

local function refresh()
	local data = DataController:Get()
	if data == nil then
		return
	end
	local low = EffectsQuality.IsLow()
	for _, station in glowing do
		local count = if station.Kind == "Rune" then data.WyrmRunes else data.Dragonstones
		station.Board:Set(`x{count}`, if station.Kind == "Rune" then "Wyrm Runes" else "Dragonstones")
		local on = count > 0
		station.Light.Enabled = on
		station.Emitter.Rate = if on then station.Rate * (if low then 0.4 else 1) else 0
	end
	local price = DragonStats.GetMerchantPrice(data, Cycle.GetState().NightIndex)
	for _, board in merchants do
		board:Set(`{Economy.Merchant.BundleSize} Stardust`, `{Format.Number(price)} gold · {Stations.MerchantResetText}`)
	end
	for _, board in spires do
		board:Set(`Best floor {DragonStats.GetSpireRecord(data, data.SpireDifficulty)}`, Stations.SpireClimbText)
	end
end

local function setupGlow(instance: Instance, kind: string)
	if glowing[instance] then
		return
	end
	if instance:IsA("Model") and instance.PrimaryPart == nil then
		instance:GetPropertyChangedSignal("PrimaryPart"):Wait()
	end
	local part, height = modelTop(instance)
	if part == nil then
		return
	end
	local color = if kind == "Rune" then Stations.ShrineColor else Stations.ForgeColor
	local board = WorldBoard.new(part, {
		Size = Stations.BoardSize,
		Icon = if kind == "Rune" then "WyrmRune" else "Dragonstone",
		OffsetY = height,
		Color = color,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = Stations.GlowRange
	light.Brightness = Stations.GlowBrightness
	light.Shadows = false
	light.Enabled = false
	light.Parent = part
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	if kind == "Rune" then
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(color)
		emitter.Speed = NumberRange.new(1, 3)
		emitter.Lifetime = NumberRange.new(1.5, 2.5)
		emitter.Size = NumberSequence.new(0.5, 0)
		emitter.SpreadAngle = Vector2.new(40, 40)
		emitter.Acceleration = Vector3.new(0, 2, 0)
	else
		emitter.Texture = "rbxasset://textures/particles/fire_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), color)
		emitter.Speed = NumberRange.new(3, 6)
		emitter.Lifetime = NumberRange.new(0.5, 0.9)
		emitter.Size = NumberSequence.new(1.6, 0.2)
		emitter.Transparency = NumberSequence.new(0.2, 1)
		emitter.SpreadAngle = Vector2.new(20, 20)
		emitter.Acceleration = Vector3.new(0, 6, 0)
	end
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = part
	glowing[instance] = {
		Board = board,
		Light = light,
		Emitter = emitter,
		Rate = if kind == "Rune" then Stations.ShrineSparkleRate else Stations.ForgeFireRate,
		Kind = kind,
	}
	instance.Destroying:Connect(function()
		glowing[instance] = nil
	end)
	refresh()
end

local function setupBoard(instance: Instance, list: { [Instance]: WorldBoard.WorldBoard }, size: Vector2, icon: string)
	if list[instance] then
		return
	end
	if instance:IsA("Model") and instance.PrimaryPart == nil then
		instance:GetPropertyChangedSignal("PrimaryPart"):Wait()
	end
	local part, height = modelTop(instance)
	if part == nil then
		return
	end
	-- the Spire's PrimaryPart is at its door: keep the board just above the door, not at the tower's top
	local offset = if list == spires then 6 else height
	list[instance] = WorldBoard.new(part, { Size = size, Icon = icon, OffsetY = offset })
	instance.Destroying:Connect(function()
		list[instance] = nil
	end)
	refresh()
end

local function watch(tag: string, fn: (Instance) -> ())
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		task.spawn(fn, instance)
	end)
	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(fn, instance)
	end
end

-- Hides a station's board while one of its own prompts shows, and your own ★ badge while any prompt shows.
local function updatePromptHiding()
	local anyOpen = next(openPrompts) ~= nil
	for _, list in { merchants, spires } do
		for station, board in list do
			local covered = false
			for prompt in openPrompts do
				if prompt:IsDescendantOf(station) then
					covered = true
				end
			end
			board:SetEnabled(not covered)
		end
	end
	for station, glow in glowing do
		local covered = false
		for prompt in openPrompts do
			if prompt:IsDescendantOf(station) then
				covered = true
			end
		end
		glow.Board:SetEnabled(not covered)
	end
	local character = Players.LocalPlayer.Character
	local head = character and character:FindFirstChild("Head")
	local badge = head and head:FindFirstChild("RebirthBadge")
	if badge and badge:IsA("BillboardGui") then
		-- your own badge also hides near a station board, where it would sit right in front of it
		local nearBoard = false
		if head and head:IsA("BasePart") then
			for _, list in { merchants, spires } do
				for _, board in list do
					local adornee = board.Gui.Adornee
					if adornee and adornee:IsA("BasePart") and (adornee.Position - head.Position).Magnitude <= Stations.BadgeHideRange then
						nearBoard = true
					end
				end
			end
		end
		badge.Enabled = not anyOpen and not nearBoard
	end
end

function StationFXController:Start()
	if Stations.HideBoardWithPrompt then
		ProximityPromptService.PromptShown:Connect(function(prompt)
			openPrompts[prompt] = true
			updatePromptHiding()
		end)
		ProximityPromptService.PromptHidden:Connect(function(prompt)
			openPrompts[prompt] = nil
			updatePromptHiding()
		end)
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			updatePromptHiding() -- the ★ badge check follows the player around
		end
	end)
	watch("RuneShrine", function(instance)
		setupGlow(instance, "Rune")
	end)
	watch("DragonstoneForge", function(instance)
		setupGlow(instance, "Stone")
	end)
	watch("StarMerchant", function(instance)
		setupBoard(instance, merchants, Stations.MerchantBoardSize, "Stardust")
	end)
	watch("DragonSpire", function(instance)
		setupBoard(instance, spires, Stations.SpireBoardSize, "Menu_Rebirth")
	end)
	for _, key in { "WyrmRunes", "Dragonstones", "Gold", "Rebirths", "SpireRecords", "SpireDifficulty", "MerchantPurchases", "MerchantDay" } do
		DataController:OnChanged(key, refresh)
	end
	EffectsQuality.OnChanged(function()
		refresh()
	end)
	task.spawn(function()
		DataController:WaitForData()
		while true do
			refresh() -- the merchant price also changes at dawn
			task.wait(5)
		end
	end)
end

return StationFXController
