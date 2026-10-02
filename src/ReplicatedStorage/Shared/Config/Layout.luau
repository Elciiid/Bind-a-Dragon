--!strict
-- Geometry shared by HUD, windows and details; safe-area bounds come from Roblox, never guessed device models.
return {
	SafeMargin = 16, -- includes the window close-button overhang inside Roblox's safe bounds
	TooltipWidth = 340, -- maximum wrapped details width
	TooltipPadding = 10, -- inner details padding
	TooltipOffset = Vector2.new(14, 10), -- cursor clearance
	TooltipRefreshSeconds = 0.25, -- refresh changing dragon stats while details remain visible
	DetailsSize = Vector2.new(64, 44), -- physical touch target, unaffected by inventory card scaling
	PhoneDragonCardMinScale = 0.8, -- retain readable labels and room for a 44px Details target
	PhoneDragonCardHeight = 320, -- room for two independent 44px controls beneath the dragon statistics
	TouchTarget = 44, -- minimum physical height for inventory touch actions
}
