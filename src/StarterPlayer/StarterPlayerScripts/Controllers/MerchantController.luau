--!strict
-- The Star Merchant, client side. A speech bubble ("Welcome, binder!") pops up over the NPC when you walk up; talking to it (the E prompt,
-- EconomyService) starts a dialog like popular Roblox shops: no window, the merchant's line in the speech bubble over its head and the
-- choices as big numbered lines on the screen (yellow "1.)" + white outlined text). Pick by clicking / tapping a line or pressing 1-5.
--   1.) I want to buy Stardust!            Kyle's live price + a yes / no (EconomyService validates the purchase)
--   2.) I want to sell this!               sells the dragon you are CARRYING from the hotbar (name + gold, confirm; Epic+/mutated = 2nd confirm)
--   3.) I want to sell my inventory!       sells every backpack dragon (not in the sanctuary) that is not a favorite (count + gold, confirm)
--   4.) Edit auto sell settings!           a small panel: per-rarity switches + keep mutated / keep new species (SellService, data.AutoSell)
--   5.) Goodbye!                           closes. The dialog also closes when you walk away or the merchant's tag goes away.
-- While talking the camera eases toward the merchant (not with Reduced Motion) and the merchant NPC waves goodbye / hops after a sale (MerchantIdleController).
-- Prices come from the same shared functions the server uses (DragonStats.GetSellValue, Config/Economy.Selling).

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local MerchantIdle = require(script.Parent.MerchantIdleController)
local Window = require(script.Parent.UI.Window)
local Style = require(script.Parent.UI.Style)
local Cycle = require(ReplicatedStorage.Shared.Cycle)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Mutations = require(ReplicatedStorage.Shared.Config.Mutations)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerData)

local words = Text.Merchant
local Dialog = Economy.Merchant.Dialog

local MerchantController = {}

type Choice = { Text: string, OnPick: () -> (), Dim: boolean? }

local player = Players.LocalPlayer
local gui: ScreenGui
local choiceFrame: Frame
local bubbleLabels: { [BillboardGui]: TextLabel } = {}
local bubbles: { [Instance]: BillboardGui } = {}
local activePrompt: ProximityPrompt? = nil
local activeMerchant: Instance? = nil
local isOpen = false
local currentLine = ""
local choices: { Choice } = {}
local choiceButtons: { TextButton } = {}
local refreshPage: (() -> ())? = nil -- re-runs the current page (live prices, a dragon that changed)
local autoWindow: Window.Window
local autoRows: { [string]: { Set: (boolean) -> () } } = {}
local inAutoPanel = false

local YELLOW = "rgb(255,226,102)"

local function carriedId(): string
	local id = player:GetAttribute("CarryDragonId")
	return if type(id) == "string" then id else ""
end

local function validPrompt(prompt: ProximityPrompt): boolean
	if prompt.Name ~= "BuyStardustPrompt" then
		return false
	end
	for _, merchant in CollectionService:GetTagged("StarMerchant") do
		if prompt:IsDescendantOf(merchant) then
			return true
		end
	end
	return false
end

local function rewardText(runes: number, stones: number): string
	local parts = {}
	if runes > 0 then
		table.insert(parts, `+{runes} Rune{if runes == 1 then "" else "s"}`)
	end
	if stones > 0 then
		table.insert(parts, `+{stones} Stone{if stones == 1 then "" else "s"}`)
	end
	return if #parts > 0 then " (" .. table.concat(parts, ", ") .. ")" else ""
end

local function describeDragon(dragon: PlayerDataTypes.Dragon): string
	local species = Dragons[dragon.SpeciesId]
	local mutation = Mutations.Get(dragon.MutationId)
	local mutated = mutation.Id ~= Mutations.NormalId
	local rarity = if species then species.Rarity else "Common"
	return `a {if mutated then mutation.Name .. " " else ""}{rarity} {if species then species.Name else "dragon"}`
end

---------------------------------------------------------------------------------------------------------------
-- The merchant's speech bubble (also carries the dialog line while talking)

local function merchantAnchor(merchant: Instance): BasePart?
	if merchant:IsA("BasePart") then
		return merchant
	end
	local anchor = merchant:FindFirstChild("InteractionAnchor", true)
	if anchor and anchor:IsA("BasePart") then
		return anchor
	end
	if merchant:IsA("Model") and merchant.PrimaryPart then
		return merchant.PrimaryPart
	end
	return merchant:FindFirstChildWhichIsA("BasePart", true)
end

local function makeBubble(merchant: Instance): BillboardGui?
	local anchor = merchantAnchor(merchant)
	if anchor == nil then
		return nil
	end
	local top = anchor.Position.Y
	if merchant:IsA("Model") then
		local box, size = merchant:GetBoundingBox()
		top = box.Position.Y + size.Y / 2
	end
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "MerchantBubble"
	bubble.Adornee = anchor
	bubble.Size = UDim2.fromOffset(Dialog.BubbleWidth, Dialog.BubbleHeight)
	bubble.StudsOffsetWorldSpace = Vector3.new(0, top - anchor.Position.Y + 2.2, 0)
	bubble.SizeOffset = Vector2.new(0, Economy.Merchant.BubbleRaise) -- in bubble heights: clears the price board under it at any distance
	bubble.AlwaysOnTop = false
	bubble.MaxDistance = 80
	bubble.Enabled = false
	bubble.ResetOnSpawn = false
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(1, 1)
	Style.WorldPanel(panel, nil, true)
	panel.Parent = bubble
	local label = Style.Label(panel, words.Greeting, "Title", 22, UITheme.Colors.Text)
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 22
	limit.MinTextSize = 10
	limit.Parent = label
	Style.Pad(label, 12, 6)
	Style.Outline(label, 2)
	bubble.Parent = anchor
	bubbleLabels[bubble] = label
	return bubble
end

local function setBubbleText(text: string)
	for bubble, label in bubbleLabels do
		label.Text = text
		if not bubble.Parent then
			bubbleLabels[bubble] = nil
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Camera: eases toward the merchant while talking (Reduced Motion: stays put)

local cameraWeight = 0
local cameraTarget = 0

local function frameMerchant()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local anchor = activeMerchant and merchantAnchor(activeMerchant)
	if camera == nil or root == nil or not root:IsA("BasePart") or anchor == nil then
		return
	end
	local from = root.Position
	local flat = Vector3.new(anchor.Position.X - from.X, 0, anchor.Position.Z - from.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	local forward = flat.Unit
	local right = forward:Cross(Vector3.yAxis)
	local position = from - forward * Dialog.CameraBack + right * Dialog.CameraSide + Vector3.new(0, Dialog.CameraUp, 0)
	local look = from:Lerp(anchor.Position, Dialog.CameraLookBlend) + Vector3.new(0, Dialog.CameraLookUp, 0)
	local target = CFrame.lookAt(position, look)
	camera.CFrame = camera.CFrame:Lerp(target, cameraWeight)
end

local function cameraStep(dt: number)
	local rate = if cameraTarget > cameraWeight then Dialog.CameraEaseIn else Dialog.CameraEaseOut
	cameraWeight += (cameraTarget - cameraWeight) * (1 - math.exp(-rate * dt))
	if cameraTarget == 0 and cameraWeight < 0.01 then
		cameraWeight = 0
		RunService:UnbindFromRenderStep("MerchantCamera")
		return
	end
	frameMerchant()
end

local function easeCamera(on: boolean)
	if player:GetAttribute("ReducedMotion") == true then
		return
	end
	cameraTarget = if on then Dialog.CameraStrength else 0
	if on or cameraWeight > 0 then
		RunService:UnbindFromRenderStep("MerchantCamera")
		RunService:BindToRenderStep("MerchantCamera", Enum.RenderPriority.Camera.Value + 1, cameraStep)
	end
end

---------------------------------------------------------------------------------------------------------------
-- The numbered choice lines

local function clearChoices()
	for _, button in choiceButtons do
		button:Destroy()
	end
	table.clear(choiceButtons)
end

local function pick(index: number)
	local choice = choices[index]
	if choice and isOpen and not inAutoPanel then
		choice.OnPick()
	end
end

local function drawChoices()
	clearChoices()
	local phone = HudLayout.IsPhone()
	local lineHeight = if phone then Dialog.PhoneLineHeight else Dialog.LineHeight
	local x = if phone then Dialog.PhoneScreenX else Dialog.ScreenX
	choiceFrame.Position = UDim2.fromScale(x, if phone then Dialog.PhoneScreenY else Dialog.ScreenY)
	choiceFrame.Size = UDim2.fromScale(1 - x - 0.03 - (if phone then 0.2 else 0), 0)
	local textSize = if phone then Dialog.PhoneTextSize else Dialog.TextSize
	for index, choice in choices do
		local button = Instance.new("TextButton")
		button.Name = `Choice{index}`
		button.LayoutOrder = index
		button.AutoButtonColor = false
		button.BackgroundTransparency = 1
		button.RichText = true
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.TextWrapped = true
		button.Size = UDim2.new(1, 0, 0, lineHeight)
		button.Text = `<font color="{YELLOW}">{index}.)</font> {choice.Text}`
		Style.Text(button, "Heavy", textSize, if choice.Dim then Color3.fromRGB(170, 170, 185) else UITheme.Colors.Text)
		Style.Outline(button, 2.5)
		button.Parent = choiceFrame
		local rest = UDim2.new(1, 0, 0, lineHeight)
		button.MouseEnter:Connect(function()
			button.TextColor3 = Color3.fromRGB(255, 244, 190)
			TweenService:Create(button, TweenInfo.new(0.1), { Position = UDim2.fromOffset(Dialog.HoverShift, 0) }):Play()
		end)
		button.MouseLeave:Connect(function()
			button.TextColor3 = if choice.Dim then Color3.fromRGB(170, 170, 185) else UITheme.Colors.Text
			TweenService:Create(button, TweenInfo.new(0.1), { Position = UDim2.fromOffset(0, 0) }):Play()
		end)
		button.Activated:Connect(function()
			Style.Play("Click")
			pick(index)
		end)
		table.insert(choiceButtons, button)
		button.Size = rest
	end
end

-- Shows a page: the merchant's line in the bubble, the choices on the screen.
local function setPage(line: string, newChoices: { Choice }, refresh: (() -> ())?)
	currentLine = line
	choices = newChoices
	refreshPage = refresh
	setBubbleText(line)
	drawChoices()
end

local closeDialog: (reaction: string?) -> ()
local showMain: (line: string?) -> ()

---------------------------------------------------------------------------------------------------------------
-- Pages

local function showBuy()
	local function build()
		local data = DataController:Get()
		if data == nil then
			return
		end
		local price = DragonStats.GetMerchantPrice(data, Cycle.GetState().NightIndex)
		local affordable = data.Gold >= price
		local line = Text.Format(if affordable then words.BuyLine else words.BuyLineBroke, {
			amount = Economy.Merchant.BundleSize,
			price = Format.Number(price),
		})
		setPage(line, {
			{
				Text = words.BuyYes,
				Dim = not affordable,
				OnPick = function()
					if affordable then
						ReplicatedStorage.Remotes.BuyStardust:FireServer("Bundle")
					end
				end,
			},
			{ Text = words.MaybeLater, OnPick = function() showMain() end },
		}, build)
	end
	build()
end

local function showSellThis()
	local data = DataController:Get()
	if data == nil then
		return
	end
	local function back()
		showMain()
	end
	local id = carriedId()
	local dragon = if id ~= "" then data.Dragons[id] else nil
	if dragon == nil or Dragons[dragon.SpeciesId] == nil then
		setPage(words.NoCarry, { { Text = words.Okay, OnPick = back } })
		return
	end
	local species = Dragons[dragon.SpeciesId]
	local why = DragonStats.GetSellProtection(dragon, data)
	if why ~= nil then
		local line = if why == "Favorite" then words.CarryFavorite else words.CarryProtected
		setPage(Text.Format(line, { name = species.Name }), { { Text = words.Okay, OnPick = back } })
		return
	end
	local gold, rewards = DragonStats.GetSellValue(dragon, data)
	local risky = DragonStats.IsRiskySale(dragon)
	local function sell()
		ReplicatedStorage.Remotes.SellDragons:FireServer({ dragon.Id }, risky)
		showMain(words.Done)
	end
	setPage(Text.Format(words.SellThisLine, {
		name = species.Name,
		rarity = species.Rarity,
		level = dragon.Level,
		gold = Format.Number(gold),
		extra = rewardText(rewards.WyrmRunes, rewards.Dragonstones),
	}), {
		{
			Text = words.Deal,
			OnPick = function()
				if risky then
					setPage(Text.Format(words.RiskyLine, { desc = describeDragon(dragon) }), {
						{ Text = words.RiskyYes, OnPick = sell },
						{ Text = words.RiskyNo, OnPick = back },
					})
				else
					sell()
				end
			end,
		},
		{ Text = words.NoWait, OnPick = back },
	})
end

local function showSellInventory()
	local data = DataController:Get()
	if data == nil then
		return
	end
	local function back()
		showMain()
	end
	local list = DragonStats.GetSellableInventory(data)
	if #list == 0 then
		setPage(words.InventoryEmpty, { { Text = words.Okay, OnPick = back } })
		return
	end
	local gold, runes, stones = 0, 0, 0
	local risky: { PlayerDataTypes.Dragon } = {}
	for _, dragon in list do
		local value, rewards = DragonStats.GetSellValue(dragon, data)
		gold += value
		runes += rewards.WyrmRunes
		stones += rewards.Dragonstones
		if DragonStats.IsRiskySale(dragon) then
			table.insert(risky, dragon)
		end
	end
	local function sell()
		ReplicatedStorage.Remotes.SellInventory:FireServer(#risky > 0, #list)
		showMain(words.Done)
	end
	setPage(Text.Format(words.InventoryLine, {
		count = #list,
		s = if #list == 1 then "" else "s",
		gold = Format.Number(gold),
		extra = rewardText(runes, stones),
	}), {
		{
			Text = words.InventoryYes,
			OnPick = function()
				if #risky == 0 then
					sell()
					return
				end
				local names = {}
				for index, dragon in risky do
					if index > 4 then
						table.insert(names, `and {#risky - 4} more`)
						break
					end
					local species = Dragons[dragon.SpeciesId]
					local mutation = Mutations.Get(dragon.MutationId)
					table.insert(names, `{if mutation.Id ~= Mutations.NormalId then mutation.Name .. " " else ""}{if species then species.Name else "dragon"}`)
				end
				setPage(Text.Format(words.InventoryRiskyLine, { names = table.concat(names, ", ") }), {
					{ Text = words.RiskyYes, OnPick = sell },
					{ Text = words.RiskyNo, OnPick = back },
				})
			end,
		},
		{ Text = words.InventoryNo, OnPick = back },
	})
end

local function openAutoPanel()
	inAutoPanel = true
	clearChoices()
	autoWindow:Open()
end

showMain = function(line: string?)
	setPage(line or words.MenuLine, {
		{ Text = words.ChoiceBuy, OnPick = showBuy },
		{ Text = words.ChoiceSellThis, OnPick = showSellThis },
		{ Text = words.ChoiceSellInventory, OnPick = showSellInventory },
		{ Text = words.ChoiceAutoSell, OnPick = openAutoPanel },
		{ Text = words.ChoiceBye, OnPick = function() closeDialog("Bye") end },
	})
end

---------------------------------------------------------------------------------------------------------------
-- Auto sell panel (the one small window)

local RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

local function sendAutoSell()
	local data = DataController:Get()
	if data and data.AutoSell then
		ReplicatedStorage.Remotes.SetAutoSell:FireServer(table.clone(data.AutoSell))
	end
end

local function makeSwitch(parent: Frame, get: () -> boolean, set: (boolean) -> ()): () -> ()
	local colors = UITheme.Colors
	local switch = Instance.new("TextButton")
	switch.Name = "Switch"
	switch.Text = ""
	switch.AutoButtonColor = false
	switch.AnchorPoint = Vector2.new(1, 0.5)
	switch.Position = UDim2.new(1, -8, 0.5, 0)
	switch.Size = UDim2.fromOffset(84, 38)
	switch.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.Round(switch)
	Style.GoldBorder(switch, 2.5)
	local gradient = Style.Gradient(switch, colors.Neutral, colors.Neutral)
	switch.Parent = parent
	local word = Style.Label(switch, "", "Title", 15)
	word.Size = UDim2.new(0.6, 0, 1, 0)
	word.ZIndex = 2
	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(28, 28)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.ZIndex = 3
	Style.Gradient(knob, colors.TrimLight, colors.TrimDark)
	Style.Round(knob)
	Style.Stroke(knob, colors.TextStroke, 1.5)
	knob.Parent = switch
	Style.AttachPress(switch)
	switch.Activated:Connect(function()
		set(not get())
	end)
	return function()
		local on = get()
		local base = if on then colors.Confirm else colors.Neutral
		gradient.Color = ColorSequence.new(Style.Shade(base, 0.16), Style.Shade(base, -0.2))
		word.Text = if on then "ON" else "OFF"
		word.Position = if on then UDim2.fromScale(0.04, 0) else UDim2.fromScale(0.38, 0)
		TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Back), {
			Position = if on then UDim2.new(1, -18, 0.5, 0) else UDim2.new(0, 18, 0.5, 0),
		}):Play()
	end
end

local function buildAutoPanel()
	autoWindow = Window.new({
		Name = "AutoSell",
		Title = words.AutoTitle,
		Icon = "Gold",
		Size = UDim2.new(0.9, 0, 0.8, 0),
		MaxSize = Vector2.new(480, 440),
	})
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = UITheme.Colors.Trim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = autoWindow.Content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local info = Style.Label(list, words.AutoLine, "Bold", 14, UITheme.Colors.TextMuted)
	info.LayoutOrder = 0
	info.Size = UDim2.new(1, -8, 0, 40)

	local refreshers: { () -> () } = {}
	local function row(order: number, text: string, color: Color3, key: string)
		local frame = Instance.new("Frame")
		frame.Name = key
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, -8, 0, 48)
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		Style.CardLook(frame, color)
		frame.Parent = list
		local label = Style.Label(frame, text, "Title", 18, color)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Position = UDim2.fromOffset(14, 0)
		label.Size = UDim2.new(1, -110, 1, 0)
		Style.Outline(label, 1.5)
		table.insert(refreshers, makeSwitch(frame, function()
			local data = DataController:Get()
			return data ~= nil and data.AutoSell ~= nil and (data.AutoSell :: any)[key] == true
		end, function(value: boolean)
			local data = DataController:Get()
			if data and data.AutoSell then
				-- optimistic: the server's reply (a changed AutoSell table) confirms it
				local copy = table.clone(data.AutoSell)
				;(copy :: any)[key] = value
				data.AutoSell = copy
				for _, refresh in refreshers do
					refresh()
				end
				ReplicatedStorage.Remotes.SetAutoSell:FireServer(copy)
			end
		end))
	end
	for order, rarityId in RARITY_ORDER do
		local rarity = (UITheme.Rarity :: any)[rarityId]
		row(order, `Sell new {rarityId} dragons`, if rarity then rarity.Color else UITheme.Colors.Gold, rarityId)
	end
	row(10, words.KeepMutated, UITheme.Colors.Confirm, "KeepMutated")
	row(11, words.KeepNewSpecies, UITheme.Colors.Confirm, "KeepNewSpecies")
	local function refreshAll()
		for _, refresh in refreshers do
			refresh()
		end
	end
	DataController:OnChanged("AutoSell", refreshAll)
	autoWindow:OnOpen(refreshAll)
	autoWindow:OnClose(function()
		inAutoPanel = false
		if isOpen then
			showMain()
		end
	end)
end

---------------------------------------------------------------------------------------------------------------
-- Opening / closing

local function openDialog(prompt: ProximityPrompt)
	activePrompt = prompt
	local merchant: Instance? = nil
	for _, tagged in CollectionService:GetTagged("StarMerchant") do
		if prompt:IsDescendantOf(tagged) then
			merchant = tagged
		end
	end
	activeMerchant = merchant
	isOpen = true
	inAutoPanel = false
	player:SetAttribute("MerchantDialog", true)
	gui.Enabled = true
	if merchant then
		local bubble = bubbles[merchant]
		if bubble then
			bubble.Enabled = true
		end
	end
	showMain()
	easeCamera(true)
	-- 1-5 pick a line (the key is sunk so the hotbar doesn't also react)
	ContextActionService:BindActionAtPriority("MerchantChoice", function(_, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end
		local number = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
		if number >= 1 and number <= 5 then
			pick(number)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 10,
		Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five)
end

closeDialog = function(reaction: string?)
	if not isOpen then
		return
	end
	isOpen = false
	inAutoPanel = false
	player:SetAttribute("MerchantDialog", nil)
	ContextActionService:UnbindAction("MerchantChoice")
	if autoWindow.IsOpen then
		autoWindow:Close()
	end
	clearChoices()
	gui.Enabled = false
	easeCamera(false)
	local merchant = activeMerchant
	if merchant then
		if reaction then
			MerchantIdle:Play(merchant, "Bye")
		end
	end
	setBubbleText(words.Greeting)
	activePrompt = nil
	activeMerchant = nil
end

function MerchantController:Init()
	gui = HudLayout.MakeScreenGui("MerchantDialog", "Popups")
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Enabled = false
	choiceFrame = Instance.new("Frame")
	choiceFrame.Name = "Choices"
	choiceFrame.BackgroundTransparency = 1
	choiceFrame.AnchorPoint = Vector2.new(0, 0.5)
	choiceFrame.Position = UDim2.fromScale(Dialog.ScreenX, Dialog.ScreenY)
	choiceFrame.Size = UDim2.fromScale(1 - Dialog.ScreenX - 0.03, 0)
	choiceFrame.AutomaticSize = Enum.AutomaticSize.Y
	choiceFrame.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = choiceFrame

	buildAutoPanel()

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player or not validPrompt(prompt) then
			return
		end
		openDialog(prompt)
	end)
	DataController:OnChanged("Gold", function()
		if isOpen and refreshPage then
			refreshPage()
		end
	end)
	DataController:OnChanged("MerchantPurchases", function()
		if isOpen and refreshPage then
			refreshPage()
		end
	end)
	player:GetAttributeChangedSignal("CarryDragonId"):Connect(function()
		if isOpen and currentLine == words.NoCarry then
			showSellThis()
		end
	end)
end

function MerchantController:Start()
	local BUBBLE_RANGE = 28 -- studs: the bubble shows while you're this close
	task.spawn(function()
		while true do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			for _, merchant in CollectionService:GetTagged("StarMerchant") do
				local bubble = bubbles[merchant]
				if bubble == nil or bubble.Parent == nil then
					bubble = makeBubble(merchant)
					if bubble then
						bubbles[merchant] = bubble
					end
				end
				if bubble and root and root:IsA("BasePart") then
					local anchor = merchantAnchor(merchant)
					local near = anchor ~= nil and (root.Position - anchor.Position).Magnitude <= BUBBLE_RANGE
					bubble.Enabled = near or (isOpen and activeMerchant == merchant)
				end
			end
			-- the open dialog: close when walking away, or when its merchant / prompt is gone
			if isOpen then
				local anchor = activePrompt and activePrompt.Parent
				local position = if anchor and anchor:IsA("BasePart") then anchor.Position elseif anchor and anchor:IsA("Attachment") then anchor.WorldPosition else nil
				if not activePrompt or not activePrompt:IsDescendantOf(workspace) or not validPrompt(activePrompt)
					or not root or not root:IsA("BasePart") or not position
					or (root.Position - position).Magnitude > Economy.Merchant.PurchaseRange then
					closeDialog("Bye")
				elseif refreshPage then
					refreshPage()
				end
			end
			task.wait(Economy.Merchant.MenuUpdateInterval)
		end
	end)
end

return MerchantController
