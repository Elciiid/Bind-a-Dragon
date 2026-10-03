--!strict
-- Queued, mobile-first reward/result cards. Facts reflow and scroll at physical text sizes rather than shrinking
-- the entire card. The primary Continue button stays outside the scroll area, including on short phones.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)
local Button = require(script.Parent.Button)
local EffectsQuality = require(script.Parent.Parent.EffectsQuality)
local Text = require(ReplicatedStorage.Shared.Config.Text)

export type Props = {
	Title: string, Name: string, Tag: string?, Color: Color3?, Icon: string?,
	Picture: ((parent: Frame) -> ())?, Button: string?, Sound: string?,
	Line: string?, LineColor: Color3?, Chips: { { Text: string, Color: Color3 } }?,
	Details: { Title: string, Rows: { { string } } }?, Hint: string?, Seconds: number?,
	Stats: { { Label: string, Value: string, Icon: string?, Color: Color3? } }?,
}

local RewardPopup = {}
local queue: { Props } = {}
local showing = false
local gui: ScreenGui? = nil
local function hud(): any
	return require(script.Parent.Parent.HudLayout)
end
local function reduced(): boolean
	return Players.LocalPlayer:GetAttribute("ReducedMotion") == true or EffectsQuality.IsLow()
end
local function screen(): ScreenGui
	if gui == nil then
		local layer = hud().MakeScreenGui("RewardPopup", "Popups")
		layer.DisplayOrder = Style.Theme.Layers.Notifications + 1
		layer.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		layer.ResetOnSpawn = false
		layer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		layer.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		gui = layer
	end
	return gui :: ScreenGui
end
local function scroll(parent: Instance, name: string): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = Style.Theme.MobileUI.Scrollbar
	frame.ScrollBarImageColor3 = Style.Theme.Colors.TextMuted
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.Active, frame.Selectable = true, true
	frame.ZIndex = 3
	frame.Parent = parent
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, Style.Theme.MobileUI.Gap)
	list.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingRight = UDim.new(0, Style.Theme.MobileUI.Padding)
	padding.PaddingBottom = UDim.new(0, Style.Theme.MobileUI.Padding)
	padding.Parent = frame
	return frame
end
local function textHeight(label: TextLabel, width: number, minimum: number): number
	local measureHeight = math.max(Style.Theme.RewardPresentation.PreferredHeight, #label.Text * (label.TextSize + Style.Theme.MobileUI.Gap))
	return math.max(minimum, math.ceil(TextService:GetTextSize(label.Text, label.TextSize, label.Font, Vector2.new(math.max(1, width), measureHeight)).Y))
end

-- Retains the existing Build API for callers; UIScale is fixed at one. The root's Size drives responsive reflow.
function RewardPopup.Build(parent: Instance, props: Props): (Frame, UIScale, Button.Button)
	local theme, mobile, appearance = Style.Theme, Style.Theme.MobileUI, Style.Theme.RewardPresentation
	local color = props.Color or theme.Colors.Gold
	local root = Instance.new("Frame")
	root.Name = "Reward"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(appearance.MaxWidth, appearance.PreferredHeight)
	root.BackgroundTransparency = 1
	root.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = root
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.Parent = root
	Style.PanelLook(panel, theme.SmallCorner)
	local heading = Style.Label(panel, props.Title, "Title", mobile.Title, color)
	heading.Name = "Title"
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Position = UDim2.fromOffset(mobile.Padding, mobile.Padding)
	heading.Size = UDim2.new(1, -mobile.Padding * 2, 0, mobile.Touch)
	heading.ZIndex = 3

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.ZIndex = 3
	body.Parent = panel
	local facts = scroll(body, "Facts")
	local picture = Instance.new("Frame")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.LayoutOrder = 1
	picture.ZIndex = 3
	picture.Parent = body
	local rays = Instance.new("ImageLabel")
	rays.Name = "Rays"
	rays.BackgroundTransparency = 1
	rays.Image = theme.Art.Rays
	rays.ImageColor3 = color
	rays.ImageTransparency = appearance.RaysTransparency
	rays.Size = UDim2.fromScale(1, 1)
	rays.ZIndex = 1
	rays.Parent = picture
	local turn: Tween? = nil
	if not reduced() then
		turn = TweenService:Create(rays, TweenInfo.new(theme.Motion.RewardSpin, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
		turn:Play()
	end
	local motionWatch = RunService.Heartbeat:Connect(function()
		if turn and reduced() then turn:Cancel(); turn = nil end
	end)
	root.Destroying:Connect(function()
		motionWatch:Disconnect()
		if turn then turn:Cancel() end
	end)
	local pictureContent = Instance.new("Frame")
	pictureContent.Name = "Art"
	pictureContent.BackgroundTransparency = 1
	pictureContent.Size = UDim2.fromScale(1, 1)
	pictureContent.ZIndex = 3
	pictureContent.Parent = picture
	local pictureOk = false
	if props.Picture then pictureOk = pcall(props.Picture, pictureContent) end
	if not pictureOk then
		for _, child in pictureContent:GetChildren() do child:Destroy() end
		-- Missing/unavailable art never prevents a complete text result or an accessible Continue action.
		local fallback = Icon.new(pictureContent, props.Icon or "Menu_Dragons", color)
		fallback.Size = UDim2.fromScale(1, 1)
		fallback.ZIndex = 4
	end

	local name = Style.Label(facts, props.Name, "Title", appearance.NameText, theme.Colors.Text)
	name.Name = "Name"
	name.LayoutOrder = 2
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextYAlignment = Enum.TextYAlignment.Top
	name.Size = UDim2.new(1, 0, 0, mobile.Touch)
	name.ZIndex = 3
	local line: TextLabel? = nil
	if props.Line then
		local odds = Style.Label(facts, props.Line, "Heavy", appearance.OddsText, props.LineColor or color)
		odds.Name = "OddsLine"
		odds.LayoutOrder = 3
		odds.TextXAlignment = Enum.TextXAlignment.Left
		odds.Size = UDim2.new(1, 0, 0, appearance.OddsHeight)
		odds.ZIndex = 3
		line = odds
	end
	local chips = Instance.new("Frame")
	chips.Name = "Chips"
	chips.BackgroundTransparency = 1
	chips.LayoutOrder = 4
	chips.ZIndex = 3
	chips.Visible = props.Chips ~= nil or (props.Tag ~= nil and props.Tag ~= "")
	chips.Parent = facts
	local chipLabels: { TextLabel } = {}
	local entries = props.Chips or (if props.Tag then { { Text = props.Tag, Color = color } } else {})
	for _, chip in entries do
		local label = Style.Label(chips, chip.Text, "Bold", mobile.Small, theme.Colors.Text)
		label.BackgroundTransparency = 0
		label.BackgroundColor3 = Style.Shade(chip.Color, -0.72)
		label.ZIndex = 3
		Style.Corner(label, theme.SmallCorner)
		Style.Stroke(label, chip.Color, mobile.CardBorder)
		table.insert(chipLabels, label)
	end
	local statRows: { { Frame: Frame, Label: TextLabel, Value: TextLabel, IconWidth: number } } = {}
	for index, stat in props.Stats or {} do
		local row = Instance.new("Frame")
		row.Name = "Stat" .. tostring(index)
		row.BackgroundColor3 = theme.Colors.GlassBottom
		row.BackgroundTransparency = 0.1
		row.Size = UDim2.new(1, 0, 0, appearance.StatHeight)
		row.LayoutOrder = 4 + index
		row.ZIndex = 3
		row.Parent = facts
		Style.Corner(row, theme.SmallCorner)
		local iconWidth = if stat.Icon then mobile.ButtonIcon + mobile.Gap else 0
		if stat.Icon then
			local icon = Icon.new(row, stat.Icon, stat.Color or color)
			icon.Position = UDim2.fromOffset(mobile.Padding, (appearance.StatHeight - mobile.ButtonIcon) / 2)
			icon.Size = UDim2.fromOffset(mobile.ButtonIcon, mobile.ButtonIcon)
			icon.ZIndex = 3
		end
		local label = Style.Label(row, stat.Label, "Body", mobile.Small, theme.Colors.TextMuted)
		label.Position = UDim2.fromOffset(mobile.Padding + iconWidth, 0)
		label.Size = UDim2.new(0.55, -mobile.Padding - iconWidth, 1, 0)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 3
		local value = Style.Label(row, stat.Value, "Heavy", mobile.Title, stat.Color or theme.Colors.Text)
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.new(1, -mobile.Padding, 0, 0)
		value.Size = UDim2.new(0.45, -mobile.Padding, 1, 0)
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.ZIndex = 3
		table.insert(statRows, { Frame = row, Label = label, Value = value, IconWidth = iconWidth })
	end

	local footer = Instance.new("Frame")
	footer.Name = "Actions"
	footer.BackgroundTransparency = 1
	footer.ZIndex = 3
	footer.Parent = panel
	local button = Button.new(footer, { Text = props.Button or Text.Reveal.Continue, Kind = "Confirm", TextSize = mobile.Body, Sound = "Confirm" })
	button.Instance.ZIndex = 3
	local details: ScrollingFrame? = nil
	local toggle: Button.Button? = nil
	local detailRows: { { Frame: Frame, Label: TextLabel, Value: TextLabel } } = {}
	if props.Details then
		local rows = scroll(body, "Details")
		rows.Visible = false
		rows.Size = UDim2.fromScale(1, 1)
		rows.ZIndex = 4
		details = rows
		local detailTitle = Style.Label(rows, props.Details.Title, "Title", mobile.Title, color)
		detailTitle.Size = UDim2.new(1, 0, 0, mobile.Touch)
		detailTitle.ZIndex = 4
		for index, pair in props.Details.Rows do
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, appearance.StatHeight)
			row.LayoutOrder = index
			row.ZIndex = 4
			row.Parent = rows
			local left = Style.Label(row, pair[1], "Body", mobile.Body, theme.Colors.TextMuted)
			left.Size = UDim2.new(0.5, -mobile.Gap / 2, 1, 0)
			left.TextXAlignment = Enum.TextXAlignment.Left
			left.ZIndex = 4
			local right = Style.Label(row, pair[2], "Bold", mobile.Body, theme.Colors.Text)
			right.AnchorPoint = Vector2.new(1, 0)
			right.Position = UDim2.fromScale(1, 0)
			right.Size = UDim2.new(0.5, -mobile.Gap / 2, 1, 0)
			right.TextXAlignment = Enum.TextXAlignment.Right
			right.ZIndex = 4
			table.insert(detailRows, { Frame = row, Label = left, Value = right })
		end
		toggle = Button.new(footer, { Text = Text.Reveal.Details, Kind = "Neutral", TextSize = mobile.Body })
		toggle.Instance.ZIndex = 3
		button.Instance.NextSelectionLeft = toggle.Instance
		toggle.Instance.NextSelectionRight = button.Instance
		toggle.Instance.Activated:Connect(function()
			rows.Visible = not rows.Visible
			facts.Visible, picture.Visible = not rows.Visible, not rows.Visible
			root:SetAttribute("ReadingDetails", rows.Visible)
			root:SetAttribute("Interacted", true)
			local detailButton = toggle :: Button.Button
			detailButton:SetText(if rows.Visible then Text.Reveal.HideDetails else Text.Reveal.Details)
		end)
	end
	local function interacted(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseWheel or input.UserInputType == Enum.UserInputType.Gamepad1 then root:SetAttribute("Interacted", true) end
	end
	facts.InputBegan:Connect(interacted)
	if details then details.InputBegan:Connect(interacted) end
	facts:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if facts.CanvasPosition.Y > 0 then root:SetAttribute("Interacted", true) end
	end)

	local function reflow()
		local width, height = root.AbsoluteSize.X, root.AbsoluteSize.Y
		if width <= 0 or height <= 0 then return end
		local contentWidth = width - mobile.Padding * 2
		local bodyTop = mobile.Padding + mobile.Touch + mobile.Gap
		-- Even a very short viewport must not let the scrolling body overlap the fixed action row.
		local bodyHeight = math.max(1, height - bodyTop - mobile.Touch - mobile.Padding * 2 - mobile.Gap)
		body.Position = UDim2.fromOffset(mobile.Padding, bodyTop)
		body.Size = UDim2.fromOffset(contentWidth, bodyHeight)
		footer.Position = UDim2.fromOffset(mobile.Padding, height - mobile.Padding - mobile.Touch)
		footer.Size = UDim2.fromOffset(contentWidth, mobile.Touch)
		local split = width >= appearance.SplitWidth
		local side = math.clamp(if split then contentWidth * appearance.PictureFraction else bodyHeight * appearance.PictureFraction, appearance.PictureMin, appearance.PictureMax)
		side = math.min(side, bodyHeight)
		picture.Parent = if split then body else facts
		picture.AnchorPoint = Vector2.zero
		picture.Position = if split then UDim2.fromOffset(0, (bodyHeight - side) / 2) else UDim2.new()
		picture.Size = UDim2.fromOffset(side, side)
		facts.Position = if split then UDim2.fromOffset(side + mobile.Gap, 0) else UDim2.new()
		facts.Size = if split then UDim2.new(1, -side - mobile.Gap, 1, 0) else UDim2.fromScale(1, 1)
		local textWidth = math.max(1, contentWidth - (if split then side + mobile.Gap else 0) - mobile.Padding)
		name.Size = UDim2.new(1, 0, 0, textHeight(name, textWidth, mobile.Touch))
		if line then line.Size = UDim2.new(1, 0, 0, textHeight(line, textWidth, appearance.OddsHeight)) end
		local x, y, rowHeight = 0, 0, appearance.ChipHeight
		for _, label in chipLabels do
			local natural = TextService:GetTextSize(label.Text, label.TextSize, label.Font, Vector2.new(textWidth, appearance.PreferredHeight)).X + mobile.Padding * 2
			local chipWidth = math.min(textWidth, natural)
			if x > 0 and x + chipWidth > textWidth then x, y = 0, y + rowHeight + mobile.Gap; rowHeight = appearance.ChipHeight end
			local chipHeight = textHeight(label, math.max(1, chipWidth - mobile.Padding), appearance.ChipHeight)
			label.Position = UDim2.fromOffset(x, y)
			label.Size = UDim2.fromOffset(chipWidth, chipHeight)
			x += chipWidth + mobile.Gap
			rowHeight = math.max(rowHeight, chipHeight)
		end
		chips.Size = UDim2.new(1, 0, 0, if #chipLabels > 0 then y + rowHeight else 0)
		for _, row in statRows do
			-- Measure each actual column after icon/padding deductions. A generic fraction can underestimate
			-- wrapped label height on portrait phones or with localized-length text.
			local labelWidth = math.max(1, textWidth * 0.55 - mobile.Padding - row.IconWidth)
			local valueWidth = math.max(1, textWidth * 0.45 - mobile.Padding)
			row.Frame.Size = UDim2.new(1, 0, 0, math.max(appearance.StatHeight, textHeight(row.Label, labelWidth, appearance.StatHeight), textHeight(row.Value, valueWidth, appearance.StatHeight)))
		end
		for _, row in detailRows do
			local half = math.max(1, (contentWidth - mobile.Padding - mobile.Gap) / 2)
			row.Frame.Size = UDim2.new(1, 0, 0, math.max(appearance.StatHeight, textHeight(row.Label, half, appearance.StatHeight), textHeight(row.Value, half, appearance.StatHeight)))
		end
		button.Instance.Position = if toggle then UDim2.new(0.5, mobile.Gap / 2, 0, 0) else UDim2.new()
		button.Instance.Size = if toggle then UDim2.new(0.5, -mobile.Gap / 2, 1, 0) else UDim2.fromScale(1, 1)
		if toggle then toggle.Instance.Size = UDim2.new(0.5, -mobile.Gap / 2, 1, 0) end
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(reflow)
	reflow()
	return root, scale, button
end

local function showNext()
	local props = table.remove(queue, 1)
	if not props then
		showing = false
		Players.LocalPlayer:SetAttribute("RewardPopupOpen", false)
		return
	end
	showing = true
	Players.LocalPlayer:SetAttribute("RewardPopupOpen", true)
	local layer, theme = screen(), Style.Theme
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BorderSizePixel = 0
	dim.BackgroundColor3 = theme.Colors.GlassBottom
	dim.BackgroundTransparency = theme.RewardPresentation.DimTransparency
	dim.Active = true
	dim.Parent = layer
	local ok, builtRoot, _, builtButton = pcall(RewardPopup.Build, dim, props)
	if not ok then
		warn("[RewardPopup] Card fallback: " .. tostring(builtRoot))
		dim:Destroy()
		showNext()
		return
	end
	local root, button = builtRoot :: Frame, builtButton :: Button.Button
	local closed = false
	local previousSelection = GuiService.SelectedObject
	local elapsed = 0
	local function relayout()
		if closed or not root.Parent then return end
		-- Core-safe parent and core-relative usable rectangle; do not add the Roblox top-bar inset twice.
		local safe = hud().GetUsableRect()
		local gap = theme.MobileUI.Padding
		root.Size = UDim2.fromOffset(math.min(theme.RewardPresentation.MaxWidth, math.max(1, safe.Width - gap * 2)), math.min(theme.RewardPresentation.PreferredHeight, math.max(theme.MobileUI.Touch * 3, safe.Height - gap * 2)))
		root.Position = UDim2.fromOffset(safe.Width / 2, safe.Height / 2)
	end
	relayout()
	local disconnectLayout = hud().OnLayoutChanged(relayout)
	local timer: RBXScriptConnection? = nil
	local backConnection: RBXScriptConnection? = nil
	local function close()
		if closed then return end
		closed = true
		disconnectLayout()
		if timer then timer:Disconnect() end
		if backConnection then backConnection:Disconnect() end
		local restoreSelection = GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(root)
		if restoreSelection then GuiService.SelectedObject = nil end
		dim:Destroy()
		showNext()
		if restoreSelection and not showing and previousSelection and hud().GetVisibleRect(previousSelection) then GuiService.SelectedObject = previousSelection end
	end
	button.Instance.Activated:Connect(close)
	if UserInputService:GetLastInputType().Name:find("Gamepad") then GuiService.SelectedObject = button.Instance end
	backConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if layer.Enabled and (input.KeyCode == Enum.KeyCode.ButtonB or (input.KeyCode == Enum.KeyCode.Escape and not processed)) then close() end
	end)
	timer = RunService.Heartbeat:Connect(function(dt)
		if not dim.Parent then close(); return end
		-- Never close while the player is reading details, scrolling, or the spoiler gate masks this layer.
		if layer.Enabled and root:GetAttribute("ReadingDetails") ~= true and root:GetAttribute("Interacted") ~= true then
			elapsed += dt
			if elapsed >= (props.Seconds or theme.RewardPresentation.DefaultSeconds) then close() end
		end
	end)
	Style.Play(props.Sound or "Confirm")
end

function RewardPopup.Show(props: Props)
	table.insert(queue, props)
	if not showing then showNext() end
end

return RewardPopup
