--!strict
-- Actual shared config/maths contracts. This is NOT a Roblox renderer or an input/playtest substitute.
local shared = game:GetService("ReplicatedStorage").Shared
local Geometry = require(shared.UIGeometry)
local Theme = require(shared.Config.UITheme)
local Text = require(shared.Config.Text)
local Ceremony = require(shared.Config.Ceremony)
local OddsText = require(shared.OddsText)
return function(clientSources: { [string]: string }?)
	local mobile = Theme.MobileUI
	local references = 0
	for file, source in clientSources or {} do
		-- Direct text paths and MobileUI aliases only: this is a config typo guard, not a type checker.
		if source:find("local%s+Text%s*=%s*require%([^)]*Config%.Text%)") then
			for path in source:gmatch("%f[%w_]Text%.([%a_][%w_%.]*)") do
				local value: any = Text
				for key in path:gmatch("[%a_][%w_]*") do
					assert(type(value) == "table" and value[key] ~= nil, `Unknown Text.{path} in {file}`)
					value = value[key]
				end
				references += 1
			end
		end
		local aliases = { "UITheme.MobileUI", "Theme.MobileUI", "Style.Theme.MobileUI" }
		for alias in source:gmatch("local%s+([%a_][%w_]*)%s*=%s*[%w_%.]+%.MobileUI") do table.insert(aliases, alias) end
		for _, alias in aliases do
			local pattern = "%f[%w_]" .. alias:gsub("%.", "%%.") .. "%.([%a_][%w_]*)"
			for key in source:gmatch(pattern) do
				assert((mobile :: any)[key] ~= nil, `Unknown MobileUI.{key} in {file}`)
				references += 1
			end
		end
	end
	assert(mobile.Touch >= 44 and mobile.Body >= 16 and mobile.Small >= 14)
	assert(Theme.Sizes.PhoneCardScale == 1 and Theme.Sizes.PhoneSpireScale == 1)
	assert(Theme.Sizes.PhoneCloseButton >= mobile.Touch)
	assert(Text.Format(Text.Items.EchoSigils.Info, { cap = 7 }):find("Holds up to 7.", 1, true))
	assert(OddsText.OneInExact(158.73015873015873) == "1 in 158.73")
	assert(OddsText.OneInExact(49999.99999999999) == "1 in 50,000")
	local viewports = { {320, 520}, {452, 252}, {584, 252}, {667, 292}, {733, 313}, {720, 270}, {768, 952}, {1024, 700}, {1280, 680}, {1440, 820} }
	local envelopes, grids, pages, tutorials, sideColumns, topRows = 0, 0, 0, 0, 0, 0
	for _, viewport in viewports do
		local width, height = viewport[1], viewport[2]
		local currencyHeight = Theme.Sizes.PhoneCurrency.Y * 2 + Theme.Sizes.Gap
		local currencyTop = height - mobile.CurrencyBottom - currencyHeight
		local column = Geometry.SideColumn(height, 4, currencyHeight, mobile.SideIcon, mobile.Small,
			mobile.Touch, mobile.SideGap, mobile.SideTop, mobile.CurrencyBottom, mobile.SideCurrencyGap)
		assert(column.Row >= mobile.Touch and column.Icon + mobile.Small + 2 == column.Row)
		assert(column.Y >= mobile.SideTop and column.Y + column.Height <= currencyTop - mobile.SideCurrencyGap + 1e-9)
		local centeredY = (height - column.Height) / 2
		local lastSafeY = currencyTop - mobile.SideCurrencyGap - column.Height
		assert(math.abs(column.Y - math.clamp(centeredY, mobile.SideTop, math.max(mobile.SideTop, lastSafeY))) < 1e-9,
			"Vertical group stays centered unless currency clearance requires lifting it")
		assert(column.Content >= column.Height, "Overflow scrolls instead of reducing touch targets")
		sideColumns += 1
		local navigationBottom = 0
		for _, buttons in { 3, 4 } do
			-- Official GetInsetArea example: native top controls end at x=164, y=-58 in core coordinates.
			local nativeLeft, nativeHeight = 164, 58
			local reserved = math.floor(nativeHeight * 0.8) + Theme.Sizes.TopbarGap + mobile.TravelGap
			local nav = Geometry.TopRow(width - nativeLeft, reserved, buttons, mobile.TravelSlot,
				mobile.Touch, mobile.TravelGap, width / 2 - nativeLeft)
			local origin = nativeLeft
			local top = -nativeHeight
			if nav.Fits then
				assert(nav.X - nav.Width / 2 >= reserved - 1e-9, "Centered navigation avoids native/settings controls")
			else
				origin, top = 0, 0
				nav = Geometry.TopRow(width, 0, buttons, mobile.TravelSlot, mobile.Touch, mobile.TravelGap, width / 2)
			end
			assert(nav.Fits and nav.Slot >= mobile.Touch)
			assert(math.abs(origin + nav.X - width / 2) < 1e-9, "Navigation centers on the whole display, not remaining topbar space")
			assert(origin + nav.X - nav.Width / 2 >= -1e-9 and origin + nav.X + nav.Width / 2 <= width + 1e-9)
			assert(nav.Width == buttons * nav.Slot + (buttons - 1) * mobile.TravelGap)
			local navHeight = math.max(mobile.Touch, mobile.TravelIcon + mobile.TravelText + 2)
			assert(mobile.TravelTop > 0 and mobile.TravelTop <= 8, "Only a small top margin")
			if origin > 0 then
				assert(mobile.TravelTop + navHeight / 2 == nativeHeight / 2, "Phone navigation aligns with native top-bar controls")
			end
			if buttons == 3 then navigationBottom = math.max(0, top + mobile.TravelTop + navHeight) end
			topRows += 1
		end
		local overhang = Theme.Sizes.PhoneBanner / 2 + Theme.Sizes.PhoneBannerStar * 0.62
		local box = Geometry.Popup(width, height, width, height, mobile.WindowTop, 0, mobile.WindowMargin, overhang, 740, 580)
		local left, right = box.X - box.Width / 2, box.X + box.Width / 2
		local upper, lower = box.Y - box.Height / 2 - overhang, box.Y + box.Height / 2
		assert(left >= mobile.WindowMargin - 1e-9 and right <= width - mobile.WindowMargin + 1e-9)
		assert(upper >= mobile.WindowTop + mobile.WindowMargin - 1e-9 and lower <= height - mobile.WindowMargin + 1e-9)
		local expectedCenter = (mobile.WindowTop + mobile.WindowMargin + height - mobile.WindowMargin) / 2
		assert(math.abs((upper + lower) / 2 - expectedCenter) < 1e-9, "Center includes banner overhang")
		envelopes += 1
		for _, minimum in { mobile.DragonCard.X, mobile.PotionCard.X, mobile.CollectionCard.X } do
			local count, size = Geometry.Columns(box.Width - mobile.Padding * 2, minimum, mobile.Gap)
			assert(count >= 1 and size > 0)
			assert(count * size + (count - 1) * mobile.Gap <= box.Width - mobile.Padding * 2)
			assert(count == 1 or size >= minimum)
			grids += 1
		end
		local count, size, total = Geometry.Hotbar(width, mobile.HotbarTouchSideReserve, 5, 46, mobile.Touch, mobile.HotbarGap)
		assert(size >= mobile.Touch and count >= 1 and count <= 5 and total <= width)
		local visited = {}
		for page = 1, math.ceil(10 / count) do
			for slot = (page - 1) * count + 1, math.min(10, page * count) do assert(not visited[slot]); visited[slot] = true end
		end
		for slot = 1, 10 do assert(visited[slot]) end
		pages += 1
		local leftReserve = mobile.CurrencyLeft + Theme.Sizes.PhoneCurrency.X + mobile.Gap
		local center
		count, size, total, center = Geometry.Hotbar(width, mobile.HotbarTouchSideReserve, 5, 46,
			mobile.Touch, mobile.HotbarGap, leftReserve)
		local bottom = mobile.HotbarBottom
		if width - leftReserve - mobile.HotbarTouchSideReserve >= mobile.Touch * 2 + mobile.HotbarGap then
			assert(center - total / 2 >= leftReserve - 1e-9 and center + total / 2 <= width - mobile.HotbarTouchSideReserve + 1e-9,
				"Bottom-left money and right jump area cannot overlap the hotbar")
		else
			bottom = mobile.CurrencyBottom + currencyHeight + mobile.Gap
			assert(height - bottom <= currencyTop - mobile.Gap, "Narrow layouts lift the hotbar above money")
		end
		assert(size >= mobile.Touch and total <= width)
		visited = {}
		for page = 1, math.ceil(10 / count) do
			for slot = (page - 1) * count + 1, math.min(10, page * count) do assert(not visited[slot]); visited[slot] = true end
		end
		for slot = 1, 10 do assert(visited[slot]) end
		pages += 1
		for _, textHeight in { mobile.Body, mobile.Body * 3, mobile.Body * 10 } do
			local compact = height < mobile.TutorialCompactBelow
			local padding = if compact then mobile.TutorialCompactPadding else mobile.Padding
			local gap = if compact then mobile.TutorialCompactGap else mobile.TutorialActionGap
			local titleHeight = if compact then mobile.TutorialCompactTitleHeight else mobile.TutorialTitleHeight
			local top = navigationBottom + mobile.Gap + (if compact then 0 else mobile.Gap)
			local bottom = mobile.HotbarBottom + mobile.Touch
			local card = Geometry.Tutorial(width, height, mobile.TutorialWidth, mobile.TutorialMinWidth,
				if compact then mobile.TutorialCompactHeight else mobile.TutorialHeight,
				textHeight, mobile.TutorialInstructionHeight, top, bottom, padding)
			assert(card.X >= padding and card.X + card.Width <= width - padding)
			assert(card.Y >= navigationBottom, "Tutorial never covers the navigation row")
			assert(card.Y + card.Height <= height - bottom - padding)
			local footer = card.Height - padding - mobile.Touch
			assert(footer - (padding + titleHeight + gap) - gap - mobile.TutorialProgressHeight > 0, "Instruction viewport fits above fixed 44px actions")
			assert((card.Width - padding * 2 - gap) / 2 >= mobile.Touch)
			tutorials += 1
		end
	end
	local rect = Geometry.Intersection(10, 20, 90, 80, 0, 0, 100, 100)
	assert(rect and rect.Left == 10 and rect.Bottom == 80)
	rect = Geometry.Intersection(10, -20, 90, 80, 20, 10, 75, 60)
	assert(rect and rect.Left == 20 and rect.Top == 10 and rect.Right == 75 and rect.Bottom == 60)
	assert(Geometry.Intersection(10, -100, 90, -5, 0, 0, 100, 100) == nil, "Scrolled above viewport")
	assert(Geometry.Intersection(110, 20, 190, 80, 0, 0, 100, 100) == nil, "Outside safe area")
	assert(Geometry.Intersection(10, 20, 10, 80, 0, 0, 100, 100) == nil, "Zero-size target")
	rect = Geometry.Intersection(240, -58, 310, -12, 0, -58, 733, 313)
	assert(rect and rect.Top == -58 and rect.Bottom == -12, "Topbar Home target remains visible for tutorial outlines")
	local duration, previous = {}, 0
	for _, rarity in { "Common", "Rare", "Epic", "Legendary", "Mythic", "Prestige" } do
		local p = Ceremony.Profiles[rarity]
		local seconds = p.Anticipation + p.Gather + p.Silhouette + p.Entrance + p.Hold
		assert(seconds > previous and seconds < 4 and p.Stars <= 9)
		previous = seconds; duration[rarity] = seconds
	end
	local p = Ceremony.Profiles.Quick
	assert(p.Anticipation + p.Gather + p.Silhouette + p.Entrance + p.Hold < duration.Common)
	assert(Ceremony.SkipButtonSize.Y >= mobile.Touch and Ceremony.ReducedHoldSeconds <= 0.3)
	for step = 1, 5 do assert(Text.Onboarding.Titles[step] and Text.Onboarding.Steps[step] and Text.Onboarding.Icons[step]) end
	print(`PASS mobile UI: {envelopes} safe popup envelopes, {grids} card grids, {pages} complete hotbar paginations, {sideColumns} centered side columns, {topRows} centered/gapped top rows, {tutorials} tutorial envelopes, 6 clipping intersections, text/touch/odds/reveal contracts. Runtime rendering/input NOT tested.`)
	print(`PASS: {references} direct text and MobileUI source references resolve in the actual shared configuration.`)
end
