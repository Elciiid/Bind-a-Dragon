--!strict
-- Rebirth menu tile (HudLayout) and a confirm window (UI/Window) that spells out the cost, what is kept, and what the
-- rebirth unlocks, with green Rebirth / red Cancel. The window scales with the screen (phones). The server decides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataController = require(script.Parent.DataController)
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Button = require(script.Parent.UI.Button)
local Window = require(script.Parent.UI.Window)
local DragonStats = require(ReplicatedStorage.Shared.DragonStats)
local Format = require(ReplicatedStorage.Shared.Format)
local Areas = require(ReplicatedStorage.Shared.Config.Areas)
local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)

local requestRebirth = ReplicatedStorage.Remotes.RequestRebirth :: RemoteEvent

local RebirthController = {}

local button: TextButton
local window: Window.Window
local body: TextLabel
local confirm: Button.Button

local function refresh()
	local data = DataController:Get()
	if data == nil then
		return
	end
	local cost = DragonStats.GetRebirthCost(data.Rebirths)
	local next = data.Rebirths + 1
	if data.Rebirths > 0 then
		HudLayout.SetMenuText("Rebirth", `Rebirth ★{data.Rebirths}`, `★{data.Rebirths}`)
	end

	if DragonStats.IsAtRebirthCap(data) then
		body.Text = table.concat({
			`Rebirth cap reached (★{data.Rebirths}).`,
			"",
			"More rebirths arrive in the next update.",
			"Your gold is saved up to the cost of one rebirth until then.",
		}, "\n")
		confirm:SetText("Cap reached")
		confirm:SetEnabled(false)
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
	confirm:SetText(if affordable then "Rebirth now" else "Not enough gold")
	confirm:SetEnabled(affordable)
end

function RebirthController:Init()
	button = HudLayout.AddMenuButton("Rebirth")
	window = Window.new({
		Name = "Rebirth",
		Title = "Rebirth",
		Icon = "Menu_Rebirth",
		Size = UDim2.new(0.9, 0, 0.9, 0), -- height scales with the screen, up to MaxSize
		MaxSize = Vector2.new(460, 360),
	})
	local content = window.Content

	body = Style.Label(content, "", "Bold", 18)
	body.Size = UDim2.new(1, 0, 1, -54)
	body.TextScaled = true -- shrinks on small screens, up to 18
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = 18
	textLimit.Parent = body

	confirm = Button.new(content, {
		Text = "Rebirth now",
		Kind = "Confirm",
		Icon = "Menu_Rebirth",
		Sound = "Confirm",
		OnClick = function()
			local data = DataController:Get()
			if data and data.Gold >= DragonStats.GetRebirthCost(data.Rebirths) then
				requestRebirth:FireServer()
				window:Close()
			end
		end,
	})
	confirm.Instance.AnchorPoint = Vector2.new(0, 1)
	confirm.Instance.Position = UDim2.new(0, 0, 1, 0)
	confirm.Instance.Size = UDim2.new(0.5, -6, 0, 46)

	local cancel = Button.new(content, {
		Text = "Cancel",
		Kind = "Cancel",
		OnClick = function()
			window:Close()
		end,
	})
	cancel.Instance.AnchorPoint = Vector2.new(1, 1)
	cancel.Instance.Position = UDim2.new(1, 0, 1, 0)
	cancel.Instance.Size = UDim2.new(0.5, -6, 0, 46)

	button.Activated:Connect(function()
		refresh()
		window:Toggle()
	end)

	DataController:OnChanged("Gold", refresh)
	DataController:OnChanged("Rebirths", refresh)
end

return RebirthController
