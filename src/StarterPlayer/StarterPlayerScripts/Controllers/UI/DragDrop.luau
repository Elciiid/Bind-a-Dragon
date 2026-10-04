--!strict
-- Drag and drop between Inventory cards and hotbar slots. Sources call DragDrop.Attach(button, getPayload, buildGhost): a mouse press that
-- moves more than DragThreshold pixels (or a touch that is held HoldSeconds without moving, then dragged) starts a drag: a ghost
-- follows the pointer; on release the topmost target under the pointer gets onDrop(payload), or DragDrop.OnDropOutside runs when
-- none is. A drag swallows the click that would follow it (button.Activated still fires, so sources check DragDrop.JustDragged()).
-- Targets are registered with DragDrop.AddTarget(frame, onDrop).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local DragDrop = {}

export type Payload = { DragonId: string, Slot: number?, Source: string }
type Target = { Frame: GuiObject, OnDrop: (Payload) -> () }

local DRAG_THRESHOLD = 8 -- pixels a mouse press must move before it is a drag
local HOLD_SECONDS = 0.32 -- a touch must be held this long (without moving) before it can drag
local TOUCH_SLOP = 12 -- the finger may wander this far during the hold

local targets: { Target } = {}
local ghostGui: ScreenGui? = nil
local dragging = false
local lastDragEnd = -1
local stateListeners: { (boolean) -> () } = {}

DragDrop.OnDropOutside = nil :: ((Payload, Vector2) -> ())?

local function ensureGui(): ScreenGui
	if ghostGui and ghostGui.Parent then
		return ghostGui
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "DragGhost"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	ghostGui = gui
	return gui
end

function DragDrop.AddTarget(frame: GuiObject, onDrop: (Payload) -> ())
	table.insert(targets, { Frame = frame, OnDrop = onDrop })
	frame.Destroying:Connect(function()
		for index, target in targets do
			if target.Frame == frame then
				table.remove(targets, index)
				break
			end
		end
	end)
end

-- Listens for the drag starting / ending (scroll lists turn their scrolling off while one is going).
function DragDrop.OnDragState(listener: (boolean) -> ())
	table.insert(stateListeners, listener)
end

function DragDrop.IsDragging(): boolean
	return dragging
end

-- True right after a drag ended: the click that follows must be ignored.
function DragDrop.JustDragged(): boolean
	return dragging or os.clock() - lastDragEnd < 0.25
end

local function isVisible(frame: GuiObject): boolean
	local current: Instance? = frame
	while current and current ~= game do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		if current:IsA("ScreenGui") and not current.Enabled then
			return false
		end
		current = current.Parent
	end
	return true
end

-- Input positions and all GuiObject.AbsolutePosition values share the core-safe coordinate origin.
local function pointerPosition(input: InputObject): Vector2
	return Vector2.new(input.Position.X, input.Position.Y)
end

local function targetAt(point: Vector2): Target?
	for index = #targets, 1, -1 do
		local target = targets[index]
		local frame = target.Frame
		if isVisible(frame) then
			local position, size = frame.AbsolutePosition, frame.AbsoluteSize
			local top = position
			if point.X >= top.X and point.X <= top.X + size.X and point.Y >= top.Y and point.Y <= top.Y + size.Y then
				return target
			end
		end
	end
	return nil
end

local function setDragging(value: boolean)
	dragging = value
	for _, listener in stateListeners do
		task.spawn(listener, value)
	end
end

-- Attach to a source button. getPayload returns what is dragged (nil = nothing to drag here); buildGhost fills the ghost frame.
function DragDrop.Attach(button: GuiObject, getPayload: () -> Payload?, buildGhost: (Frame, Payload) -> ())
	button.InputBegan:Connect(function(input: InputObject)
		local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
		local isTouch = input.UserInputType == Enum.UserInputType.Touch
		if not isMouse and not isTouch then
			return
		end
		local payload = getPayload()
		if payload == nil or dragging or Players.LocalPlayer:GetAttribute("BindRevealActive") == true then
			return
		end
		local startPoint = pointerPosition(input)
		local armedAt = os.clock()
		local started = false
		local ghost: Frame? = nil
		local moveConnection: RBXScriptConnection? = nil
		local endConnection: RBXScriptConnection? = nil
		local heartbeat: RBXScriptConnection? = nil
		local destroyConnection: RBXScriptConnection? = nil
		local finished = false
		local lastPoint = startPoint

		local function finish(drop: boolean)
			if finished then return end
			finished = true
			if destroyConnection then destroyConnection:Disconnect() end
			if moveConnection then
				moveConnection:Disconnect()
			end
			if endConnection then
				endConnection:Disconnect()
			end
			if heartbeat then
				heartbeat:Disconnect()
			end
			if ghost then
				ghost:Destroy()
			end
			if started then
				lastDragEnd = os.clock()
				setDragging(false)
				if drop then
					local target = targetAt(lastPoint)
					if target then
						target.OnDrop(payload)
					elseif DragDrop.OnDropOutside then
						DragDrop.OnDropOutside(payload, lastPoint)
					end
				end
			end
		end

		local function begin()
			if finished or not isVisible(button) then finish(false); return end
			started = true
			setDragging(true)
			local frame = Instance.new("Frame")
			frame.Name = "Ghost"
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.BackgroundTransparency = 1
			frame.Size = UDim2.fromOffset(64, 64)
			frame.Position = UDim2.fromOffset(lastPoint.X, lastPoint.Y)
			frame.Parent = ensureGui()
			ghost = frame
			local ok, err = pcall(buildGhost, frame, payload)
			if not ok then finish(false); warn(`[DragDrop] Preview failed: {err}`) end
		end
		destroyConnection = button.Destroying:Connect(function() finish(false) end)

		-- touch: begin after the hold if the finger stayed put
		heartbeat = RunService.Heartbeat:Connect(function()
			if not isVisible(button) or Players.LocalPlayer:GetAttribute("BindRevealActive") == true then finish(false); return end
			if isTouch and not started and os.clock() - armedAt >= HOLD_SECONDS and (lastPoint - startPoint).Magnitude <= TOUCH_SLOP then
					begin()
				end
			end)

		moveConnection = UserInputService.InputChanged:Connect(function(changed: InputObject)
			if not isVisible(button) or Players.LocalPlayer:GetAttribute("BindRevealActive") == true then finish(false); return end
			if changed.UserInputType ~= Enum.UserInputType.MouseMovement and changed.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			if isTouch and changed ~= input then
				return
			end
			lastPoint = pointerPosition(changed)
			if not started then
				if isMouse and (lastPoint - startPoint).Magnitude >= DRAG_THRESHOLD then
					begin()
				elseif isTouch and (lastPoint - startPoint).Magnitude > TOUCH_SLOP and os.clock() - armedAt < HOLD_SECONDS then
					finish(false) -- the finger moved before the hold: this is a scroll, not a drag
					return
				end
			end
			if ghost then
				ghost.Position = UDim2.fromOffset(lastPoint.X, lastPoint.Y)
			end
		end)
		endConnection = UserInputService.InputEnded:Connect(function(ended: InputObject)
			if ended == input or (isMouse and ended.UserInputType == Enum.UserInputType.MouseButton1) then
				finish(true)
			end
		end)
	end)
end

return DragDrop
