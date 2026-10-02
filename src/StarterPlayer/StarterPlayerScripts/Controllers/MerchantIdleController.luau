--!strict
-- Animates every instance tagged "StarMerchant" that is skinned art (the Star Merchant dragon NPC) by moving its bones from code
-- (like DragonRig; bones and numbers in Config/MerchantRig):
--   idle        breathing, a slow lean, the tail sways down its chain, the head bobs and tilts, ears flick, and a turn toward the
--               local player when they come close
--   Greet       a wave hello when a player walks up (once per GreetCooldown)
--   Bye         a goodbye wave + nod (MerchantController calls Play when the dialog closes)
--   Hop         after any sale (player attribute MerchantSales, set by SellService): a happy hop with both arms up and a coin tossed
--               from the hand
-- Client-only: the art is never moved on the server. If the imported model kept fewer bones, missing ones are skipped; with only the
-- root bone the whole body breathes, leans, turns and hops.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Rig = require(ReplicatedStorage.Shared.Config.MerchantRig)

type Reaction = { Name: string, Start: number }
type Merchant = {
	Model: Model,
	Body: BasePart,
	Root: Bone,
	Bones: { [string]: Bone },
	Roles: { [string]: { Bone } },
	Full: boolean, -- more than the root bone is available
	Turn: number,
	Seed: number,
	Reaction: Reaction?,
	LastGreet: number,
}

local merchants: { [Instance]: Merchant } = {}
local TAU = math.pi * 2

local MerchantIdleController = {}

local function collectBones(body: BasePart): { [string]: Bone }
	local found: { [string]: Bone } = {}
	for _, descendant in body:GetDescendants() do
		if descendant:IsA("Bone") then
			found[descendant.Name] = descendant
		end
	end
	return found
end

local function build(merchant: Instance): Merchant?
	local model = if merchant:IsA("Model") then merchant else nil
	local body = model and model.PrimaryPart
	if model == nil or body == nil then
		return nil
	end
	local bones = collectBones(body)
	local root = bones[Rig.Root] or body:FindFirstChildWhichIsA("Bone")
	if root == nil then
		return nil
	end
	local roles: { [string]: { Bone } } = {}
	local count = 0
	for role, names in Rig.Roles do
		local list: { Bone } = {}
		for _, name in names do
			local bone = bones[name]
			if bone then
				table.insert(list, bone)
				count += 1
			end
		end
		roles[role] = list
	end
	return {
		Model = model,
		Body = body,
		Root = root,
		Bones = bones,
		Roles = roles,
		Full = count >= 8,
		Turn = 0,
		Seed = (model:GetPivot().Position.X * 7.3) % 10,
		Reaction = nil,
		LastGreet = -1e9,
	}
end

local function register(merchant: Instance)
	if merchants[merchant] then
		return
	end
	if merchant:IsA("Model") and merchant.PrimaryPart == nil then
		merchant:GetPropertyChangedSignal("PrimaryPart"):Wait()
	end
	local state = build(merchant)
	if state == nil then
		return -- a plain part/tent: nothing to animate
	end
	merchants[merchant] = state
	merchant.Destroying:Connect(function()
		merchants[merchant] = nil
	end)
end

-- Rotation for a channel at time t (seconds); `weight` fades reactions in and out.
local function angleOf(channel: any, t: number, boneIndex: number, weight: number): number
	if channel.Static then
		return channel.Amount * weight
	end
	return channel.Amount * math.sin(TAU * t / channel.Period + (channel.Phase or 0) + (channel.PhasePerBone or 0) * (boneIndex - 1)) * weight
end

local function addRotation(rotations: { [Bone]: CFrame }, bone: Bone, axis: Vector3, angle: number)
	local current = rotations[bone] or CFrame.identity
	rotations[bone] = current * CFrame.fromAxisAngle(axis, angle)
end

local function spawnCoin(state: Merchant, start: Vector3)
	local settings = Rig.Reactions.Hop.Coin
	local coin = Instance.new("Part")
	coin.Name = "MerchantCoin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.12, settings.Size, settings.Size)
	coin.Material = Enum.Material.Neon
	coin.Color = settings.Color
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CanTouch = false
	coin.CastShadow = false
	coin.Position = start
	coin.Parent = workspace
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local u = (os.clock() - started) / settings.Seconds
		if u >= 1 or coin.Parent == nil then
			connection:Disconnect()
			coin:Destroy()
			return
		end
		-- up and back down in an arc (a little drift toward the front of the merchant)
		local height = settings.Rise * 4 * u * (1 - u)
		local forward = state.Body.CFrame.LookVector * (u * 1.5)
		coin.CFrame = CFrame.new(start + Vector3.new(0, height, 0) + forward) * CFrame.Angles(u * 14, 0, math.rad(90))
	end)
end

local function step(dt: number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local playerPosition = if root and root:IsA("BasePart") then root.Position else nil
	local now = os.clock()
	for merchant, state in merchants do
		if state.Body.Parent == nil then
			merchants[merchant] = nil
			continue
		end
		local frame = state.Body.CFrame
		if playerPosition and (playerPosition - frame.Position).Magnitude > Rig.AnimateDistance then
			continue
		end
		local t = now + state.Seed
		local rotations: { [Bone]: CFrame } = {}
		local lift = 0 -- studs the whole body is raised (the hop)

		-- who the merchant faces: the player when close (positive turn = toward the model's right), else an occasional glance
		local target = math.sin(TAU * t / Rig.LookAwayPeriod) * Rig.LookAwayTurn
		local near = false
		if playerPosition then
			local local_ = frame:PointToObjectSpace(playerPosition)
			if local_.Magnitude <= Rig.TurnRange then
				near = true
				target = math.clamp(math.atan2(local_.X, -local_.Z), -Rig.MaxTurn, Rig.MaxTurn)
			end
			-- a wave hello when someone walks up
			if local_.Magnitude <= Rig.GreetRange and now - state.LastGreet > Rig.GreetCooldown and state.Reaction == nil then
				state.LastGreet = now
				state.Reaction = { Name = "Greet", Start = now }
			end
		end
		state.Turn += (target - state.Turn) * (1 - math.exp(-Rig.TurnSpeed * dt))

		if state.Full then
			-- idle layers
			for _, channel in Rig.Idle do
				local bones = state.Roles[channel.Role]
				if bones then
					for index, bone in bones do
						addRotation(rotations, bone, channel.Axis, angleOf(channel, t, index, 1))
					end
				end
			end
			-- the turn, shared along the spine, neck and head
			for role, share in Rig.TurnShare do
				for _, bone in state.Roles[role] or {} do
					addRotation(rotations, bone, Rig.TurnAxis, state.Turn * share / math.max(1, #state.Roles[role]))
				end
			end
		else
			-- root only: the whole body breathes, leans, turns
			local breath = math.sin(TAU * t / 3.4)
			local sway = math.sin(TAU * t / 7.5)
			rotations[state.Root] = CFrame.Angles(0, state.Turn, 0) * CFrame.Angles(breath * 0.028, 0, sway * 0.045)
		end

		-- the current reaction
		local reaction = state.Reaction
		if reaction then
			local definition = Rig.Reactions[reaction.Name]
			local elapsed = now - reaction.Start
			if definition == nil or elapsed >= definition.Duration then
				state.Reaction = nil
			else
				local weight = math.clamp(math.min(elapsed / definition.Fade, (definition.Duration - elapsed) / definition.Fade), 0, 1)
				weight = weight * weight * (3 - 2 * weight) -- eased
				if state.Full then
					for _, channel in definition.Channels do
						local bones = state.Roles[channel.Role]
						if bones then
							if channel.Index then
								local bone = bones[channel.Index]
								if bone then
									addRotation(rotations, bone, channel.Axis, angleOf(channel, elapsed, channel.Index, weight))
								end
							else
								for index, bone in bones do
									addRotation(rotations, bone, channel.Axis, angleOf(channel, elapsed, index, weight))
								end
							end
						end
					end
				end
				if definition.HopHeight then
					local u = elapsed / definition.Duration
					lift = definition.HopHeight * 4 * u * (1 - u)
				end
			end
		end

		-- apply: rotations on every bone we drive, the hop as a lift of the root (bone space is unscaled: divide by the model's scale)
		for _, bone in state.Bones do
			local rotation = rotations[bone]
			if bone == state.Root then
				bone.Transform = CFrame.new(0, lift / state.Model:GetScale(), 0) * (rotation or CFrame.identity)
			else
				bone.Transform = rotation or CFrame.identity
			end
		end
	end
end

-- Starts a reaction on a merchant ("Greet", "Bye" or "Hop"). A hop is not cut short by another reaction.
function MerchantIdleController:Play(merchant: Instance, name: string)
	local state = merchants[merchant]
	if state == nil or Rig.Reactions[name] == nil then
		return
	end
	local current = state.Reaction
	if current and current.Name == "Hop" and name ~= "Hop" then
		return
	end
	state.Reaction = { Name = name, Start = os.clock() }
	if name == "Hop" then
		local settings = Rig.Reactions.Hop.Coin
		local hand = (state.Roles.ArmL and state.Roles.ArmL[#state.Roles.ArmL]) or state.Root
		task.delay(settings.Delay, function()
			if state.Body.Parent then
				spawnCoin(state, hand.WorldPosition + Vector3.new(0, 0.5, 0))
			end
		end)
	end
end

local function watchSales(player: Player)
	player:GetAttributeChangedSignal("MerchantSales"):Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			return
		end
		for merchant, state in merchants do
			if (state.Body.Position - root.Position).Magnitude <= Rig.SaleRange then
				MerchantIdleController:Play(merchant, "Hop")
			end
		end
	end)
end

function MerchantIdleController:Start()
	CollectionService:GetInstanceAddedSignal("StarMerchant"):Connect(function(merchant)
		task.spawn(register, merchant)
	end)
	for _, merchant in CollectionService:GetTagged("StarMerchant") do
		task.spawn(register, merchant)
	end
	Players.PlayerAdded:Connect(watchSales)
	for _, player in Players:GetPlayers() do
		watchSales(player)
	end
	RunService.Heartbeat:Connect(step)
end

return MerchantIdleController
