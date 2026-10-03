--!strict
-- Reusable, non-blocking guidance: card + real target outline + safe edge pointer.
-- Presentation never completes a step or grants a reward; the owner supplies server-synced state.
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HudLayout = require(script.Parent.Parent.HudLayout)
local EffectsQuality = require(script.Parent.Parent.EffectsQuality)
local Style = require(script.Parent.Style)
local Button = require(script.Parent.Button)
local Icon = require(script.Parent.Icon)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local Geometry = require(ReplicatedStorage.Shared.UIGeometry)
local Theme = Style.Theme
local mobile = Theme.MobileUI

export type Step = {
	Number: number, Total: number, Title: string, Instruction: string, Icon: string,
	Visible: boolean, Glyph: string?, ActionText: string?, Action: (() -> ())?,
	GuiTarget: GuiObject?, WorldTarget: Instance?, WorldPosition: Vector3?, Complete: boolean?,
}
local Card = {}
Card.__index = Card

function Card.new(onSkip: () -> ())
	local gui = HudLayout.MakeScreenGui("TutorialGuide", "Notifications")
	local panel = Instance.new("Frame")
	panel.Name = "TutorialCard"
	panel.BorderSizePixel = 0
	Style.CardLook(panel, Theme.Colors.Gold)
	panel.Parent = gui
	local heading = Style.Label(panel, "", "Bold", mobile.TutorialTitle, Theme.Colors.Gold)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextScaled = true
	local titleLimit = Instance.new("UITextSizeConstraint")
	titleLimit.MinTextSize, titleLimit.MaxTextSize = mobile.Small, mobile.TutorialTitle
	titleLimit.Parent = heading
	local counter = Style.Label(panel, "", "Bold", mobile.TutorialStep, Theme.Colors.TextMuted)
	counter.TextXAlignment = Enum.TextXAlignment.Right
	local description = Instance.new("ScrollingFrame")
	description.BackgroundTransparency = 1
	description.BorderSizePixel = 0
	description.CanvasSize = UDim2.new()
	description.ScrollBarThickness = mobile.Scrollbar
	description.ScrollBarImageColor3 = Theme.Colors.Trim
	description.ScrollingDirection = Enum.ScrollingDirection.Y
	description.Parent = panel
	local instruction = Style.Label(description, "", "Body", mobile.TutorialInstruction, Theme.Colors.Text)
	instruction.TextWrapped = true
	instruction.TextXAlignment = Enum.TextXAlignment.Left
	instruction.TextYAlignment = Enum.TextYAlignment.Top
	local glyph = Style.Label(panel, "", "Bold", mobile.Small, Theme.Colors.TextMuted)
	glyph.TextWrapped = true
	glyph.TextXAlignment = Enum.TextXAlignment.Left
	local progress = Instance.new("Frame")
	progress.BackgroundColor3 = Theme.Colors.GlassBottom
	progress.BorderSizePixel = 0
	Style.Round(progress)
	progress.Parent = panel
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Theme.Colors.Gold
	fill.Size = UDim2.fromScale(0, 1)
	Style.Round(fill)
	fill.Parent = progress
	local actionCallback: (() -> ())? = nil
	local action = Button.new(panel, { Text = "", Kind = "Primary", TextSize = mobile.Body, OnClick = function()
		if actionCallback then actionCallback() end
	end })
	local skip = Button.new(panel, { Text = Text.Onboarding.Skip, Kind = "Neutral", TextSize = mobile.Small, OnClick = onSkip })
	local outline = Instance.new("Frame")
	outline.Name = "TargetOutline"
	outline.BackgroundTransparency = 1
	outline.Active = false
	outline.Visible = false
	Style.Corner(outline, mobile.Padding)
	local edge = Style.Stroke(outline, Theme.Colors.Gold, mobile.TutorialOutline)
	outline.Parent = gui
	local arrow = Style.Label(gui, Text.Onboarding.GuideArrow, "Heavy", mobile.TutorialEdgeArrow, Theme.Colors.Gold)
	arrow.Name = "TargetArrow"
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(mobile.Touch, mobile.Touch)
	arrow.Visible = false
	local highlight = Instance.new("Highlight")
	highlight.Name = "LocalTutorialTarget"
	highlight.FillTransparency = 1
	highlight.OutlineColor = Theme.Colors.Gold
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = workspace
	local image: GuiObject? = nil
	local imageKey: string? = nil
	local measuredText, measuredWidth, measuredHeight = "", 0, 0
	local self = setmetatable({ Gui = gui, ActionButton = action.Instance }, Card)

	function self:Present(step: Step)
		local busy = HudLayout.HasFocus() or Players.LocalPlayer:GetAttribute("BindRevealActive") == true
			or Players.LocalPlayer:GetAttribute("RewardPopupOpen") == true
		panel.Visible = step.Visible and not busy
		if Players.LocalPlayer:GetAttribute("TutorialGuideOpen") ~= panel.Visible then
			Players.LocalPlayer:SetAttribute("TutorialGuideOpen", panel.Visible)
		end
		outline.Visible, arrow.Visible, highlight.Enabled = false, false, false
		if not step.Visible then return end
		local bounds = HudLayout.GetUsableRect()
		local compact = bounds.Height < mobile.TutorialCompactBelow
		local padding = if compact then mobile.TutorialCompactPadding else mobile.Padding
		local gap = if compact then mobile.TutorialCompactGap else mobile.TutorialActionGap
		local titleHeight = if compact then mobile.TutorialCompactTitleHeight else mobile.TutorialTitleHeight
		local width = math.min(mobile.TutorialWidth, math.max(mobile.TutorialMinWidth, bounds.Width / 2 - padding), bounds.Width - padding * 2)
		local textWidth = math.max(1, width - padding * 2 - mobile.Scrollbar)
		instruction.Text = step.Instruction
		if measuredText ~= step.Instruction or measuredWidth ~= textWidth then
			measuredText, measuredWidth = step.Instruction, textWidth
			measuredHeight = TextService:GetTextSize(step.Instruction, mobile.TutorialInstruction, instruction.Font, Vector2.new(textWidth, 100000)).Y
		end
		local measured = measuredHeight
		local box = Geometry.Tutorial(bounds.Width, bounds.Height, mobile.TutorialWidth, mobile.TutorialMinWidth,
			if compact then mobile.TutorialCompactHeight else mobile.TutorialHeight, measured, mobile.TutorialInstructionHeight,
			HudLayout.TopReserved() + (if compact then 0 else mobile.Gap), mobile.HotbarBottom + mobile.Touch, padding)
		local height = box.Height
		local x, y = bounds.Min.X + box.X, bounds.Min.Y + box.Y
		local point: Vector2? = nil
		local onScreen = false
		if step.WorldPosition and workspace.CurrentCamera then
			local projected, visible = workspace.CurrentCamera:WorldToViewportPoint(step.WorldPosition)
			point = HudLayout.ViewportToGui(Vector2.new(projected.X, projected.Y))
			onScreen = visible and projected.Z > 0
			if projected.Z <= 0 then point = bounds.Min + bounds.Max - point end
		end
		-- Prefer the other side if the card would cover the world target.
		if point and point.X >= x and point.Y >= y and point.Y <= y + height then x = bounds.Min.X + padding end
		panel.Position = UDim2.fromOffset(x, y)
		panel.Size = UDim2.fromOffset(width, height)
		if imageKey ~= step.Icon then
			if image then image:Destroy() end
			image = Icon.new(panel, step.Icon)
			imageKey = step.Icon
		end
		if image then image.Position = UDim2.fromOffset(padding, padding); image.Size = UDim2.fromOffset(mobile.ButtonIcon, mobile.ButtonIcon) end
		local titleLeft = padding * 2 + mobile.ButtonIcon
		heading.Position = UDim2.fromOffset(titleLeft, padding)
		heading.Size = UDim2.new(1, -(titleLeft + padding * 5), 0, titleHeight)
		heading.Text = if step.Complete then Text.Onboarding.Completed else step.Title
		counter.Position = UDim2.new(1, -padding * 5, 0, padding)
		counter.Size = UDim2.fromOffset(padding * 4, titleHeight)
		counter.Text = Text.Format(Text.Onboarding.StepCount, { step = step.Number, total = step.Total })
		local descY = padding + titleHeight + gap
		local footerY = height - padding - mobile.Touch
		local descHeight = math.max(1, footerY - descY - gap - mobile.TutorialProgressHeight)
		description.Position = UDim2.fromOffset(padding, descY)
		description.Size = UDim2.new(1, -padding * 2, 0, descHeight)
		description.ScrollBarThickness = if measured > descHeight then mobile.Scrollbar else 0
		instruction.Size = UDim2.new(1, -mobile.Scrollbar, 0, measured + 2)
		description.CanvasSize = UDim2.fromOffset(0, measured + 2)
		progress.Position = UDim2.fromOffset(padding, footerY - gap)
		progress.Size = UDim2.new(1, -padding * 2, 0, mobile.TutorialProgressHeight)
		fill.Size = UDim2.fromScale(math.clamp((step.Number - 1) / math.max(1, step.Total - 1), 0, 1), 1)
		local actionWidth = (width - padding * 2 - gap) / 2
		action.Instance.Position = UDim2.fromOffset(padding, footerY)
		action.Instance.Size = UDim2.fromOffset(actionWidth, mobile.Touch)
		action.Instance.Visible = step.ActionText ~= nil
		action:SetText(step.ActionText or "")
		actionCallback = step.Action
		skip.Instance.Position = UDim2.fromOffset(padding + actionWidth + gap, footerY)
		skip.Instance.Size = UDim2.fromOffset(actionWidth, mobile.Touch)
		glyph.Position = action.Instance.Position
		glyph.Size = action.Instance.Size
		glyph.Text = step.Glyph or ""
		glyph.Visible = not action.Instance.Visible
		-- A relevant control can still be outlined while its Inventory modal owns focus;
		-- the card itself stays out of the way. Other modal/reveal content suppresses world guidance.
		local targetBox = HudLayout.GetVisibleRect(step.GuiTarget)
		if targetBox and targetBox.Width >= mobile.Touch / 2 and targetBox.Height >= mobile.Touch / 2
			and Players.LocalPlayer:GetAttribute("BindRevealActive") ~= true and Players.LocalPlayer:GetAttribute("RewardPopupOpen") ~= true then
			local pad = mobile.TutorialTargetPadding
			local targetBounds = HudLayout.GetTargetSafeRect(step.GuiTarget)
			local left = math.max(targetBounds.Min.X, targetBox.Min.X - pad)
			local upper = math.max(targetBounds.Min.Y, targetBox.Min.Y - pad)
			local right = math.min(targetBounds.Max.X, targetBox.Max.X + pad)
			local bottom = math.min(targetBounds.Max.Y, targetBox.Max.Y + pad)
			outline.Position = UDim2.fromOffset(left, upper)
			outline.Size = UDim2.fromOffset(math.max(1, right - left), math.max(1, bottom - upper))
			outline.Visible = right > left and bottom > upper
		elseif not busy and step.WorldTarget and step.WorldTarget:IsDescendantOf(workspace) then
			highlight.Adornee = step.WorldTarget
			highlight.Enabled = true
			if point then
				local half = mobile.Touch / 2 + mobile.Padding
				local targetPoint = if onScreen then point - Vector2.new(0, mobile.Touch) else point
				arrow.Position = UDim2.fromOffset(math.clamp(targetPoint.X, bounds.Min.X + half, bounds.Max.X - half), math.clamp(targetPoint.Y, bounds.Min.Y + half, bounds.Max.Y - half))
				local direction = point - (bounds.Min + bounds.Max) / 2
				arrow.Rotation = if onScreen then 90 else math.deg(math.atan2(direction.Y, direction.X))
				arrow.Visible = true
			end
		end
		local transparency = if EffectsQuality.IsLow() then 0 else (math.sin(os.clock() * math.pi * 2 / mobile.TutorialPulseSeconds) + 1) * 0.15
		edge.Transparency = transparency
		highlight.OutlineTransparency = transparency
	end
	gui.Destroying:Connect(function()
		Players.LocalPlayer:SetAttribute("TutorialGuideOpen", false)
		highlight:Destroy()
	end)
	function self:Destroy() gui:Destroy() end
	return self
end
return Card
