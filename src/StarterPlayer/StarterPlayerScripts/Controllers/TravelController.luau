--!strict
-- Top navigation shortcut for the player's Roost, Star Merchant and Dragon Spire.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HudLayout = require(script.Parent.HudLayout)
local Style = require(script.Parent.UI.Style)
local Button = require(script.Parent.UI.Button)
local Window = require(script.Parent.UI.Window)

local travelTo = ReplicatedStorage.Remotes.TravelTo :: RemoteEvent
local TravelController = {}

local window: Window.Window
local navButton: Button.Button

function TravelController:Init()
	local gui = HudLayout.MakeScreenGui("TravelHud", "Hud")
	navButton = Button.new(gui, {
		Text = "✦ Travel",
		Kind = "Primary",
		TextSize = 15,
		OnClick = function()
			window:Toggle()
		end,
	})
	navButton.Instance.Name = "TopTravelButton"
	navButton.Instance.Size = UDim2.fromOffset(116, 38)

	window = Window.new({
		Name = "TravelDestinations",
		Title = "Waystones",
		Size = UDim2.fromOffset(300, 258),
		MaxSize = Vector2.new(320, 280),
	})
	local content = window.Content
	local note = Style.Label(content, "Choose a place to visit", "Bold", 15)
	note.Position = UDim2.fromOffset(0, 0)
	note.Size = UDim2.new(1, 0, 0, 24)

	local function destinationButton(text: string, id: string, y: number, kind: Button.Kind)
		local button = Button.new(content, {
			Text = text,
			Kind = kind,
			TextSize = 16,
			OnClick = function()
				travelTo:FireServer(id)
				window:Close()
			end,
		})
		button.Instance.Position = UDim2.fromOffset(0, y)
		button.Instance.Size = UDim2.new(1, 0, 0, 46)
	end

	destinationButton("Home · Your Roost", "Home", 34, "Neutral")
	destinationButton("Shop · Star Merchant", "Shop", 90, "Primary")
	destinationButton("DragonSpire · Climb & Forge", "DragonSpire", 146, "Confirm")

	HudLayout.OnLayoutChanged(function(isPhone)
		local camera = workspace.CurrentCamera
		local width = if camera then camera.ViewportSize.X else 1920
		if isPhone or width < 1200 then
			navButton.Instance.Position = UDim2.fromOffset(8, 60)
		else
			navButton.Instance.Position = UDim2.new(0.5, -360, 0, 12)
		end
	end)
end

return TravelController
