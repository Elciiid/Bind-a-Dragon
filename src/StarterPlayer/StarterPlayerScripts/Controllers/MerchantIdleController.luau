--!strict
-- Idle motion for every instance tagged "StarMerchant" that is skinned art (the Star Merchant dragon NPC): breathing, a slow
-- sway, and a turn toward the local player when they come close. Client-only (the art is never moved on the server).
-- The imported model keeps one working bone (the root, first Bone under the PrimaryPart), so the whole body moves with it:
-- Transform = bob * yaw (turn) * pitch/roll (breath, sway). Numbers: Config/Economy.Merchant.Idle.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Idle = Economy.Merchant.Idle

type Rig = {
	Model: Model,
	Body: BasePart,
	Root: Bone,
	Turn: number,
	Seed: number,
}

local rigs: { [Instance]: Rig } = {}

local MerchantIdleController = {}

local function findRig(merchant: Instance): Rig?
	local model = if merchant:IsA("Model") then merchant else nil
	local body = model and model.PrimaryPart
	if model == nil or body == nil then
		return nil
	end
	local root = body:FindFirstChildWhichIsA("Bone")
	if root == nil then
		return nil
	end
	-- a different phase per merchant so two of them never move in step
	return { Model = model, Body = body, Root = root, Turn = 0, Seed = (model:GetPivot().Position.X * 7.3) % 10 }
end

local function register(merchant: Instance)
	if rigs[merchant] then
		return
	end
	if merchant:IsA("Model") and merchant.PrimaryPart == nil then
		merchant:GetPropertyChangedSignal("PrimaryPart"):Wait()
	end
	local rig = findRig(merchant)
	if rig == nil then
		return -- a plain part/tent: nothing to animate
	end
	rigs[merchant] = rig
	merchant.Destroying:Connect(function()
		rigs[merchant] = nil
	end)
end

local function step(dt: number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local playerPosition = if root and root:IsA("BasePart") then root.Position else nil
	local now = os.clock()
	for merchant, rig in rigs do
		if rig.Body.Parent == nil then
			rigs[merchant] = nil
			continue
		end
		local frame = rig.Body.CFrame
		if playerPosition and (playerPosition - frame.Position).Magnitude > Idle.AnimateDistance then
			continue
		end
		local t = now + rig.Seed

		-- which way to face: toward the player when close (+ turns to the model's right), else an occasional glance
		local target = math.sin(t / Idle.LookAwayPeriod * math.pi * 2) * Idle.LookAwayTurn
		if playerPosition then
			local local_ = frame:PointToObjectSpace(playerPosition)
			if local_.Magnitude <= Idle.NoticeRange then
				-- the art faces -Z in its own frame: the player on the right (+X) is a positive turn
				target = math.clamp(math.atan2(local_.X, -local_.Z), -Idle.MaxTurn, Idle.MaxTurn)
			end
		end
		rig.Turn += (target - rig.Turn) * (1 - math.exp(-Idle.TurnSpeed * dt))

		local breath = math.sin(t / Idle.BreathPeriod * math.pi * 2)
		local sway = math.sin(t / Idle.SwayPeriod * math.pi * 2)
		rig.Root.Transform = CFrame.new(0, breath * Idle.BreathBob, 0)
			* CFrame.Angles(0, rig.Turn, 0)
			* CFrame.Angles(breath * Idle.BreathPitch, 0, sway * Idle.SwayRoll)
	end
end

function MerchantIdleController:Start()
	CollectionService:GetInstanceAddedSignal("StarMerchant"):Connect(function(merchant)
		task.spawn(register, merchant)
	end)
	for _, merchant in CollectionService:GetTagged("StarMerchant") do
		task.spawn(register, merchant)
	end
	RunService.Heartbeat:Connect(step)
end

return MerchantIdleController
