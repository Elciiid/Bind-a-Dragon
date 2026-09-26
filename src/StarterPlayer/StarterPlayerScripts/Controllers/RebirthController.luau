--!strict
-- Rebirth menu button (HudLayout) and a confirm panel that spells out the cost, what is kept, and what the rebirth
-- unlocks. The panel scales with the screen (phones). The server decides; this only asks. Placeholder UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)

local requestRebirth = ReplicatedStorage.Remotes.RequestRebirth :: RemoteEvent

local DARK = Color3.fromRGB(15, 15, 30)
local GOLD = Color3.fromRGB(255, 210, 70)

local RebirthController = {}

local button: TextButton
local panel: Frame
local body: TextLabel
local confirm: TextButton

local function style(instance: GuiObject, padding: number)
	Instance.new("UICorner").Parent = instance
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, padding)
	pad.PaddingBottom = UDim.new(0, padding)
	pad.PaddingLeft = UDim.new(0, padding + 4)
	pad.PaddingRight = UDim.new(0, padding + 4)
	pad.Parent = instance
end

local function makeButton(parent: Instance, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.TextColor3 = DARK
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.Text = text
	b.AutoButtonColor = true
	style(b, 6)
	b.Parent = parent
	return b
end

local function refresh()
	local data = DataController:Get()
	if data == nil then
		return
	end
	local cost = DragonStats.GetRebirthCost(data.Rebirths)
	local next = data.Rebirths + 1
	if data.Rebirths > 0 then
		HudLayout.SetMenuText("Rebirth", `Rebirth  ★{data.Rebirths}`, `Rebirth\n★{data.Rebirths}`)
	end

	if DragonStats.IsAtRebirthCap(data) then
		body.Text = table.concat({
			`Rebirth cap reached (★{data.Rebirths}).`,
			"",
			"More rebirths arrive in the next update.",
			"Your gold is saved up to the cost of one rebirth until then.",
		}, "\n")
		confirm.Text = "Cap reached"
		confirm.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
		return
	end

	local capNow = DragonStats.GetLevelCap(data)
	local capNext = capNow + Leveling.CapPerRebirth
	local unlocks = {}
	for _, area in Areas do
		if area.RebirthsRequired == next then
			table.insert(unlocks, area.Name)
		end
	end

	local lines = {
		`Rebirth {next}`,
		`Cost: {Format.Number(cost)} gold  (you have {Format.Number(data.Gold)})`,
		"",
		"Resets: your gold.",
		"Keeps: dragons, levels, evolutions, traits, grades, Stardust, roost upgrades.",
		"",
		`Income bonus {Format.Multiplier(DragonStats.GetRebirthBonus(data.Rebirths))} → {Format.Multiplier(DragonStats.GetRebirthBonus(next))}`,
		`Level cap {capNow} → {capNext}`,
		if #unlocks > 0 then `Unlocks: {table.concat(unlocks, ", ")}` else "No new area at this rebirth",
	}
	body.Text = table.concat(lines, "\n")

	local affordable = data.Gold >= cost
	confirm.Text = if affordable then "Rebirth now" else "Not enough gold"
	confirm.BackgroundColor3 = if affordable then GOLD else Color3.fromRGB(120, 120, 130)
end

function RebirthController:Init()
	local gui = HudLayout.MakeScreenGui("Rebirth", "Popups")
	button = HudLayout.AddMenuButton("Rebirth")

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.9, 0, 0.9, 0) -- height scales with the screen, up to MaxSize
	panel.BackgroundColor3 = DARK
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.Parent = gui
	style(panel, 14)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(420, 300)
	limit.Parent = panel

	body = Instance.new("TextLabel")
	body.Size = UDim2.new(1, 0, 1, -56)
	body.BackgroundTransparency = 1
	body.TextColor3 = Color3.new(1, 1, 1)
	body.Font = Enum.Font.Gotham
	body.TextScaled = true -- shrinks on small screens, up to 18
	body.TextWrapped = true
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = 18
	textLimit.Parent = body
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Parent = panel

	HudLayout.RegisterPopup(panel, UDim2.new(0.9, 0, 0.9, 0))

	confirm = makeButton(panel, "Rebirth now", GOLD)
	confirm.AnchorPoint = Vector2.new(0, 1)
	confirm.Position = UDim2.new(0, 0, 1, 0)
	confirm.Size = UDim2.new(0.5, -6, 0, 44)

	local cancel = makeButton(panel, "Cancel", Color3.fromRGB(200, 200, 210))
	cancel.AnchorPoint = Vector2.new(1, 1)
	cancel.Position = UDim2.new(1, 0, 1, 0)
	cancel.Size = UDim2.new(0.5, -6, 0, 44)

	button.Activated:Connect(function()
		refresh()
		panel.Visible = not panel.Visible
	end)
	cancel.Activated:Connect(function()
		panel.Visible = false
	end)
	confirm.Activated:Connect(function()
		local data = DataController:Get()
		if data and data.Gold >= DragonStats.GetRebirthCost(data.Rebirths) then
			requestRebirth:FireServer()
			panel.Visible = false
		end
	end)

	DataController:OnChanged("Gold", refresh)
	DataController:OnChanged("Rebirths", refresh)
end

return RebirthController
