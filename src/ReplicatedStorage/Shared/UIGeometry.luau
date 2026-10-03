--!strict
-- Pure layout maths, shared with portable tests. Bounds use CoreUISafeInsets coordinates.
local Geometry = {}

-- Intersect a target with a clipping ancestor/safe rectangle. Empty targets have no visible bounds.
function Geometry.Intersection(left: number, top: number, right: number, bottom: number, clipLeft: number, clipTop: number, clipRight: number, clipBottom: number)
	left, top = math.max(left, clipLeft), math.max(top, clipTop)
	right, bottom = math.min(right, clipRight), math.min(bottom, clipBottom)
	if right <= left or bottom <= top then return nil end
	return { Left = left, Top = top, Right = right, Bottom = bottom }
end

function Geometry.Popup(width: number, height: number, wantedWidth: number, wantedHeight: number, top: number, bottom: number, margin: number, overhang: number, maxWidth: number, maxHeight: number)
	local space = math.max(1, height - top - bottom - margin * 2)
	local w = math.max(1, math.min(width - margin * 2, wantedWidth, maxWidth))
	local h = math.max(1, math.min(space - overhang, wantedHeight, maxHeight))
	return { Width = w, Height = h, X = width / 2, Y = top + margin + (space - h - overhang) / 2 + overhang + h / 2 }
end

-- Reflow complete physical cards; never shrink their text just to force another column.
function Geometry.Columns(width: number, minimum: number, gap: number): (number, number)
	local columns = math.max(1, math.floor((width + gap) / (minimum + gap)))
	return columns, math.max(1, math.floor((width - (columns - 1) * gap) / columns))
end

function Geometry.Hotbar(width: number, sideReserve: number, slots: number, baseSize: number, minimum: number, gap: number, leftReserve: number?): (number, number, number, number)
	local left = leftReserve or sideReserve
	local free = width - left - sideReserve
	local available = math.max(minimum * 2 + gap, free)
	local count = math.clamp(math.floor((available + gap) / (minimum + gap)) - 1, 1, slots)
	local size = math.clamp(math.floor((available - count * gap) / (count + 1)), minimum, baseSize)
	return count, size, count * size + count * gap + minimum, if free >= minimum * 2 + gap then left + free / 2 else width / 2
end

-- Center the vertical HUD column on the left, lifting it only when bottom-left currencies need
-- the space. Compress gaps/icon art before shrinking a target; very short viewports scroll.
function Geometry.SideColumn(height: number, count: number, currencyHeight: number, iconSize: number, labelSize: number, minimum: number, gap: number, top: number, bottom: number, separation: number)
	local available = math.max(1, height - top - currencyHeight - bottom - separation)
	local row = math.max(minimum, math.min(iconSize + labelSize + 2, available / math.max(1, count)))
	local spacing = if count > 1 then math.clamp((available - count * row) / (count - 1), 0, gap) else 0
	local content = count * row + math.max(0, count - 1) * spacing
	local visibleHeight = math.min(available, content)
	local lowestTop = math.max(top, height - currencyHeight - bottom - separation - visibleHeight)
	local y = math.clamp((height - visibleHeight) / 2, top, lowestTop)
	return { Row = row, Icon = math.max(1, row - labelSize - 2), Gap = spacing, Height = visibleHeight, Content = content, Y = y }
end

-- Navigation coordinates are local to its safe host. Reserve the app's settings controls on the
-- left of Roblox's unoccupied top bar. An explicit center keeps the group centered on the entire
-- display, not just the remaining space beside Roblox's controls. Report when that cannot fit.
function Geometry.TopRow(width: number, reserved: number, count: number, wantedSlot: number, minimum: number, gap: number, center: number?)
	local x = center or reserved + math.max(0, width - reserved) / 2
	local available = math.max(0, math.min(width - reserved, 2 * (x - reserved), 2 * (width - x)))
	local fits = available >= count * minimum + math.max(0, count - 1) * gap
	local slot = math.max(minimum, math.min(wantedSlot, (available - math.max(0, count - 1) * gap) / math.max(1, count)))
	return { Slot = slot, Width = count * slot + math.max(0, count - 1) * gap, X = x, Fits = fits }
end

-- A right-side tutorial card between the travel row and hotbar. Its instruction area may scroll
-- on exceptionally short viewports; the action row remains physical size and inside the safe area.
function Geometry.Tutorial(width: number, height: number, wantedWidth: number, minimumWidth: number, wantedHeight: number, textHeight: number, instructionHeight: number, top: number, bottom: number, padding: number)
	local w = math.max(1, math.min(wantedWidth, math.max(minimumWidth, width / 2 - padding), width - padding * 2))
	local h = math.max(1, math.min(math.max(wantedHeight, wantedHeight + textHeight - instructionHeight), height - top - bottom - padding))
	return { Width = w, Height = h, X = width - padding - w, Y = math.clamp(top, padding, math.max(padding, height - bottom - padding - h)) }
end

return Geometry
