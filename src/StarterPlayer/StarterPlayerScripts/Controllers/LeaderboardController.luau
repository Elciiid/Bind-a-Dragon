--!strict
-- Boards are authored in Studio: tag a BasePart Leaderboard; set Board to Rebirths, Gold or Rarest.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Style = require(script.Parent.UI.Style)
local Theme = Style.Theme.Leaderboards
local Config = require(ReplicatedStorage.Shared.Config.Leaderboards)
local TextConfig = require(ReplicatedStorage.Shared.Config.Text)
local Text = TextConfig.Leaderboards
local Format = require(ReplicatedStorage.Shared.Format)
local Dragons = require(ReplicatedStorage.Shared.Config.Dragons)
local remote = ReplicatedStorage.Remotes.GetLeaderboards :: RemoteFunction
local player = Players.LocalPlayer
local boards: {[BasePart]: any} = {}
local thumbnails: {[number]: string} = {}
local latest: any = nil
local Controller = {}

local function valueText(board: string, value: number): string
	local n = Format.Number(value)
	if board == "Gold" then return TextConfig.Format(Text.GoldApprox, {value = n}) end
	if board == "Rarest" then return TextConfig.Format(Text.Odds, {value = n}) end
	return tostring(value)
end
local function render(part: BasePart)
	local state = boards[part]
	if not state then return end
	local board = part:GetAttribute("Board")
	state.Gui.Enabled = Text.Titles[board] ~= nil
	if not state.Gui.Enabled then return end
	state.Title.Text = Text.Titles[board]
	local data = latest and latest[board]
	for i, row in state.Rows do
		local entry = data and data.Top[i]
		row.Frame.Visible = entry ~= nil
		if entry then
			row.Label.Text = `#{entry.Rank}  {entry.Name}   {valueText(board, entry.Value)}`
			local rare = entry.Rare
			local species = rare and Dragons[rare.Species]
			row.Detail.Text = if species then `{species.Name} · {rare.Mutation}` else ""
			row.Avatar.Image = thumbnails[entry.UserId] or ""
			if entry.UserId > 0 and not thumbnails[entry.UserId] then
				task.spawn(function()
					local ok, image = pcall(Players.GetUserThumbnailAsync, Players, entry.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
					if ok then thumbnails[entry.UserId] = image; if row.Frame.Parent and row.Label.Text:find(entry.Name, 1, true) then row.Avatar.Image = image end end
				end)
			end
		end
	end
	state.Status.Text = if not data or data.UpdatedAt == 0 then Text.Loading elseif #data.Top == 0 then Text.Empty else Text.RankNote
	local own = data and data.Own
	state.Own.Text = if own then TextConfig.Format(if own.Rank then Text.Own else Text.OwnUnranked,
		{rank = own.Rank, value = valueText(board, own.Value)}) else Text.Loading
end
local function remove(instance: Instance)
	local state = boards[instance :: BasePart]
	if state then state.Connection:Disconnect(); state.Gui:Destroy(); boards[instance :: BasePart] = nil end
end
local function add(instance: Instance)
	if not instance:IsA("BasePart") or boards[instance] then return end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardDisplay"; gui.Adornee = instance; gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Theme.CanvasSize; gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.AlwaysOnTop = false; gui.LightInfluence = 0; gui.MaxDistance = Theme.MaxDistance
	gui.Parent = player:WaitForChild("PlayerGui")
	local panel = Instance.new("Frame"); panel.Size = UDim2.new(1, -Theme.Margin * 2, 1, -Theme.Margin * 2)
	panel.Position = UDim2.fromOffset(Theme.Margin, Theme.Margin); Style.WorldPanel(panel, nil, true); panel.Parent = gui
	local title = Style.Label(panel, "", "Title", Theme.TitleSize, Style.Theme.Colors.Gold)
	title.Size = UDim2.new(1, 0, 0, Theme.HeaderHeight)
	local rows = {}
	for i = 1, Config.TopCount do
		local frame = Instance.new("Frame"); frame.BackgroundTransparency = 1
		frame.Position = UDim2.fromOffset(Theme.Margin, Theme.HeaderHeight + (i - 1) * Theme.RowHeight)
		frame.Size = UDim2.new(1, -Theme.Margin * 2, 0, Theme.RowHeight); frame.Parent = panel
		local avatar = Instance.new("ImageLabel"); avatar.BackgroundTransparency = 1
		avatar.Size = UDim2.fromOffset(Theme.AvatarSize, Theme.AvatarSize); avatar.Parent = frame; Style.Round(avatar)
		local label = Style.Label(frame, "", "Bold", Theme.RowSize, Theme.Medals[i] or Style.Theme.Colors.Text)
		label.Position = UDim2.fromOffset(Theme.AvatarSize + Theme.Margin, 0)
		label.Size = UDim2.new(1, -(Theme.AvatarSize + Theme.Margin), 0.6, 0); label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		local detail = Style.Label(frame, "", "Body", Theme.DetailSize)
		detail.Position = UDim2.new(0, Theme.AvatarSize + Theme.Margin, 0.6, 0)
		detail.Size = UDim2.new(1, -(Theme.AvatarSize + Theme.Margin), 0.4, 0); detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.TextTruncate = Enum.TextTruncate.AtEnd
		rows[i] = {Frame = frame, Label = label, Detail = detail, Avatar = avatar}
	end
	local own = Style.Label(panel, "", "Bold", Theme.FooterSize, Style.Theme.Colors.Gold)
	own.Position = UDim2.fromOffset(0, Theme.HeaderHeight + Config.TopCount * Theme.RowHeight); own.Size = UDim2.new(1, 0, 0, Theme.RowHeight / 2)
	local status = Style.Label(panel, "", "Body", Theme.DetailSize)
	status.Position = own.Position + UDim2.fromOffset(0, Theme.RowHeight / 2); status.Size = own.Size
	boards[instance] = {Gui = gui, Title = title, Rows = rows, Own = own, Status = status,
		Connection = instance:GetAttributeChangedSignal("Board"):Connect(function() render(instance) end)}
	render(instance)
end
function Controller:Start()
	CollectionService:GetInstanceAddedSignal("Leaderboard"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("Leaderboard"):Connect(remove)
	for _, instance in CollectionService:GetTagged("Leaderboard") do add(instance) end
	while true do
		if next(boards) then
			local ok, result = pcall(remote.InvokeServer, remote)
			if ok and result then latest = result; for part in boards do render(part) end end
		end
		task.wait(Config.ClientPollInterval)
	end
end
return Controller
