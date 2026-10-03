--!strict
-- Join loading step (Simplify 2026-10-04; settings Config/Loading, wording Text.Loading). Right after joining, a bright
-- sky-blue screen ("Waking up the dragons...", a tip, a progress bar) covers the world while the area around the player
-- streams in (the spawn, the plaza, the player's own sanctuary, a first ring of terrain), the key art is preloaded and the
-- sanctuary looks are cloned in (SanctuaryLookController.IsReady); then it fades out. It never waits longer than
-- Loading.MaxSeconds. It sits under pop-ups, toasts and the binding ceremony (UITheme.Layers.Popups - 1), takes no input,
-- and closes at once when any ProximityPrompt shows (e.g. the altar's Bind). Low effects: shorter fade, no sparkles.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local EffectsQuality = require(script.Parent.EffectsQuality)
local HudLayout = require(script.Parent.HudLayout)
local SanctuaryLookController = require(script.Parent.SanctuaryLookController)
local Style = require(script.Parent.UI.Style)
local ProgressBar = require(script.Parent.UI.ProgressBar)
local Loading = require(ReplicatedStorage.Shared.Config.Loading)
local Text = require(ReplicatedStorage.Shared.Config.Text)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local LoadingController = {}

local player = Players.LocalPlayer
local screen: ScreenGui? = nil
local closed = false
local bar: ProgressBar.ProgressBar? = nil

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Loading"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = UITheme.Layers.Popups - 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Active = false -- never takes input
	back.Size = UDim2.fromScale(1, 1)
	back.BorderSizePixel = 0
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.Parent = gui
	Style.Gradient(back, Loading.Top, Loading.Bottom)
	if not EffectsQuality.IsLow() then
		Style.Sparkles(back, 24)
	end

	local phone = HudLayout.IsPhone()
	local title = Style.Label(back, Text.Loading.Title, "Title", if phone then Loading.PhoneTitleSize else Loading.TitleSize)
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.42)
	title.Size = UDim2.new(0.9, 0, 0, (if phone then Loading.PhoneTitleSize else Loading.TitleSize) + 12)
	Style.Outline(title)

	local tips = Text.Loading.Tips
	local tip = Style.Label(back, tips[math.random(1, #tips)], "Body", if phone then 18 else 26, Color3.fromRGB(40, 70, 120))
	tip.Name = "Tip"
	tip.AnchorPoint = Vector2.new(0.5, 0)
	tip.Position = UDim2.fromScale(0.5, 0.52)
	tip.Size = UDim2.new(0.8, 0, 0, 30)

	local holder = Instance.new("Frame")
	holder.Name = "Bar"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.fromScale(0.5, 0.6)
	holder.Size = UDim2.new(if phone then 0.6 else 0.35, 0, 0, if phone then 18 else 24)
	holder.Parent = back
	local progress = ProgressBar.new(holder, Loading.BarColor)
	progress.Instance.Size = UDim2.fromScale(1, 1)
	progress:Set(0.05, "")
	bar = progress

	-- "Waking up the dragons..." with the dots counting up
	task.spawn(function()
		local dots = 0
		while not closed and gui.Parent do
			dots = dots % 3 + 1
			title.Text = Text.Loading.Title .. string.rep(".", dots)
			task.wait(0.45)
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	screen = gui
end

local function close()
	if closed then
		return
	end
	closed = true
	local gui = screen
	if gui == nil then
		return
	end
	local seconds = if EffectsQuality.IsLow() then Loading.FadeSeconds / 2 else Loading.FadeSeconds
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, d in gui:GetDescendants() do
		if d:IsA("Frame") then
			TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
		elseif d:IsA("TextLabel") then
			TweenService:Create(d, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		elseif d:IsA("ImageLabel") then
			TweenService:Create(d, info, { ImageTransparency = 1 }):Play()
		end
	end
	task.delay(seconds + 0.1, function()
		gui:Destroy()
	end)
end

local function setProgress(done: number, total: number)
	if bar and not closed then
		bar:Set(0.05 + 0.95 * done / math.max(1, total), "", true)
	end
end

local function ownSanctuaryCenter(): Vector3?
	local started = os.clock()
	while os.clock() - started < Loading.OwnSanctuaryWait do
		for _, plot in game:GetService("CollectionService"):GetTagged("RoostPlot") do
			if plot:GetAttribute("OwnerUserId") == player.UserId then
				local center = plot:GetAttribute("RoamCenter")
				if typeof(center) == "Vector3" then
					return center
				end
			end
		end
		task.wait(0.25)
	end
	return nil
end

local function preloadList(): { Instance }
	local list = {}
	for _, path in Loading.Preload do
		local node: Instance? = game
		for _, name in path do
			node = node and (if node == game then game:GetService(name) else node:FindFirstChild(name))
		end
		if node then
			table.insert(list, node)
		end
	end
	return list
end

-- Runs every wait step in parallel; returns when all are done.
local function load()
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", Loading.MaxSeconds) :: BasePart?
	local spawnAt = if root then root.Position else Vector3.zero
	local steps: { () -> () } = {
		function()
			player:RequestStreamAroundAsync(spawnAt)
		end,
		function()
			player:RequestStreamAroundAsync(Loading.Plaza)
		end,
		function()
			local center = ownSanctuaryCenter()
			if center then
				player:RequestStreamAroundAsync(center)
			end
		end,
		function()
			ContentProvider:PreloadAsync(preloadList())
		end,
	}
	for i = 1, Loading.RingPoints do
		local angle = (i - 1) / Loading.RingPoints * math.pi * 2
		local point = spawnAt + Vector3.new(math.cos(angle), 0, math.sin(angle)) * Loading.RingRadius
		table.insert(steps, function()
			player:RequestStreamAroundAsync(point)
		end)
	end
	if Loading.WaitForSanctuaryLooks then
		table.insert(steps, function()
			local started = os.clock()
			while not SanctuaryLookController.IsReady() and os.clock() - started < Loading.MaxSeconds do
				task.wait(0.2)
			end
		end)
	end
	local done = 0
	local finished = Instance.new("BindableEvent")
	for _, step in steps do
		task.spawn(function()
			pcall(step) -- a failed request (e.g. a point outside the world) must not hold the screen
			done += 1
			setProgress(done, #steps)
			if done == #steps then
				finished:Fire()
			end
		end)
	end
	if done < #steps then
		finished.Event:Wait()
	end
	finished:Destroy()
end

function LoadingController:Init()
	build()
end

function LoadingController:Start()
	local started = os.clock()
	ProximityPromptService.PromptShown:Connect(close) -- never cover a prompt (e.g. the altar's Bind)
	task.delay(Loading.MaxSeconds, close)
	load()
	local shown = os.clock() - started
	if shown < Loading.MinSeconds then
		task.wait(Loading.MinSeconds - shown)
	end
	close()
end

return LoadingController
