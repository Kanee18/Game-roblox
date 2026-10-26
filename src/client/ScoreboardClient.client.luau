--[[
	ScoreboardClient (LocalScript)
	Lokasi: StarterPlayer > StarterPlayerScripts > ScoreboardClient

	Papan Poin Kelas: semua siswa dengan Poin per tahap (✅ = tahap sudah selesai)
	dan total Poin.
	  * Tampil di layar SEMUA siswa saat Guru menekan "📊 Tampilkan ke Semua Siswa"
	    di Panel Guru (siswa boleh menutupnya sendiri dengan ✕)
	  * Guru bisa melihatnya sendiri dulu lewat "👁️ Lihat Papan Poin"
	  * Urutan peringkat mengikuti pilihan Guru: Total, atau Poin Tahap 1/2/3/4
	    (misalnya setelah semua siswa menyelesaikan Tahap 1, atau setelah Tahap 3)
	  * Di papan milik Guru ada tombol ✏️ untuk meminta siswa mengganti nama
	Data dari ProgressService (Attribute "Scoreboard" di ReplicatedStorage > GameState).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UiKit = require(Shared:WaitForChild("UiKit"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local Theme = GameConfig.Theme
local MEDALS = { "🥇", "🥈", "🥉" }
local LOCAL_VIEW_ATTRIBUTE = "LihatPapanPoin" -- diatur AdminPanelClient (hanya di layar Guru)

local player = Players.LocalPlayer
local state = Remotes.GetState()

type Entry = {
	UserId: number,
	Name: string,
	Points: number,
	Online: boolean,
	Stages: { { Points: number, Done: boolean } },
}

local gui = UiKit.new("ScreenGui", {
	Name = "PapanPoin",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 8,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local board = UiKit.new("Frame", {
	Name = "Papan",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = Theme.Cream,
	Active = true,
	Parent = gui,
}, {
	UiKit.corner(18),
	UiKit.stroke(Theme.Gold, 4),
	UiKit.new("UISizeConstraint", { MaxSize = Vector2.new(980, 760) }),
})

local title = UiKit.label({
	Position = UDim2.fromOffset(16, 8),
	Text = "📊 PAPAN POIN KELAS",
	TextColor3 = Theme.Ink,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = false,
	Parent = board,
})
local subtitle = UiKit.label({
	Font = Theme.FontBody,
	TextColor3 = Theme.InkSoft,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextScaled = true,
	Parent = board,
}, { UiKit.new("UITextSizeConstraint", { MaxTextSize = 15 }) })
local closeButton = UiKit.button({
	Text = "✕",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = Theme.CreamDark,
	TextSize = 22,
	Parent = board,
})
local headerRow = UiKit.new("Frame", {
	BackgroundTransparency = 1,
	Parent = board,
}, {
	UiKit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local list = UiKit.new("ScrollingFrame", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Theme.Gold,
	Parent = board,
}, {
	UiKit.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	UiKit.new("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8) }),
})

--------------------------------------------------------------------------------
-- Tata letak (HP lebih rapat)
--------------------------------------------------------------------------------
local layout = {
	RowHeight = 34,
	TextSize = 18,
	Rank = 44,
	Stage = 66,
	Total = 80,
	Edit = 38,
}

UiKit.OnLayout(function(compact)
	board.Size = if compact then UDim2.new(1, -16, 1, -12) else UDim2.fromScale(0.9, 0.86)
	title.TextSize = if compact then 22 else 30
	title.Size = UDim2.new(1, -80, 0, if compact then 28 else 38)
	subtitle.Position = UDim2.fromOffset(16, if compact then 36 else 48)
	subtitle.Size = UDim2.new(1, -70, 0, if compact then 30 else 38)
	local top = if compact then 70 else 92
	headerRow.Position = UDim2.fromOffset(12, top)
	headerRow.Size = UDim2.new(1, -34, 0, if compact then 24 else 30)
	list.Position = UDim2.fromOffset(12, top + (if compact then 28 else 34))
	list.Size = UDim2.new(1, -24, 1, -(top + (if compact then 34 else 44)))

	layout.RowHeight = if compact then 28 else 34
	layout.TextSize = if compact then 14 else 18
	layout.Rank = if compact then 32 else 44
	layout.Stage = if compact then 50 else 66
	layout.Total = if compact then 58 else 80
	layout.Edit = if compact then 32 else 38
end)

--------------------------------------------------------------------------------
-- Data
--------------------------------------------------------------------------------
local function isAdmin(): boolean
	return player:GetAttribute("IsAdmin") == true
end

local function getMode(): string
	local mode = state:GetAttribute("ScoreboardMode")
	return if typeof(mode) == "string" and (mode == "Total" or GameConfig.StageById[mode]) then mode else "Total"
end

local function stageIndex(mode: string): number?
	for index, stage in GameConfig.Stages do
		if stage.Id == mode then
			return index
		end
	end
	return nil
end

local function readEntries(): { Entry }
	local raw = state:GetAttribute("Scoreboard")
	if typeof(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and typeof(decoded) == "table" then decoded else {}
end

-- Urutkan sesuai mode: Total, atau Poin di satu tahap (lalu selesai lebih dulu, lalu total).
local function sortEntries(entries: { Entry }, index: number?)
	table.sort(entries, function(a, b)
		if index then
			local stageA, stageB = a.Stages[index], b.Stages[index]
			if stageA.Points ~= stageB.Points then
				return stageA.Points > stageB.Points
			end
			if stageA.Done ~= stageB.Done then
				return stageA.Done
			end
		end
		if a.Points ~= b.Points then
			return a.Points > b.Points
		end
		return string.lower(a.Name) < string.lower(b.Name)
	end)
end

--------------------------------------------------------------------------------
-- Gambar papan
--------------------------------------------------------------------------------
local function cell(parent: Instance, order: number, width: UDim, text: string, props: { [string]: any }?)
	local label = UiKit.label({
		Size = UDim2.new(width.Scale, width.Offset, 1, 0),
		Text = text,
		Font = Theme.FontBold,
		TextSize = layout.TextSize,
		TextColor3 = Theme.Ink,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = order,
		Parent = parent,
	}, { UiKit.corner(6) })
	if props then
		local target: any = label
		for key, value in props do
			target[key] = value
		end
	end
	return label
end

local function nameWidth(): UDim
	local stageCount = #GameConfig.Stages
	local fixed = layout.Rank + layout.Stage * stageCount + layout.Total
	local gaps = 4 * (stageCount + 2)
	if isAdmin() then
		fixed += layout.Edit
		gaps += 4
	end
	return UDim.new(1, -(fixed + gaps))
end

local function clearChildren(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function render()
	if not gui.Enabled then
		return
	end
	local mode = getMode()
	local index = stageIndex(mode)
	local entries = readEntries()
	sortEntries(entries, index)
	local admin = isAdmin()

	-- Ringkasan: urutan, jumlah siswa, berapa yang sudah menyelesaikan tiap tahap.
	local modeText = "Total semua tahap"
	if index then
		local stage = GameConfig.Stages[index]
		modeText = `{stage.ElementIcon} Tahap {stage.Number} · {stage.Title}`
	end
	local doneParts = {}
	for stageIndexNumber, stage in GameConfig.Stages do
		local done = 0
		for _, entry in entries do
			if entry.Stages[stageIndexNumber] and entry.Stages[stageIndexNumber].Done then
				done += 1
			end
		end
		table.insert(doneParts, `{stage.ElementIcon} {done}`)
	end
	local myRank = nil
	for rank, entry in entries do
		if entry.UserId == player.UserId then
			myRank = rank
		end
	end
	local summary = `Urutan: {modeText}   ·   👥 {#entries} siswa   ·   ✅ Selesai: {table.concat(doneParts, "  ")}`
	if myRank then
		summary ..= `   ·   Peringkatmu: #{myRank}`
	end
	if admin then
		summary ..= "   ·   ✏️ = minta siswa ganti nama"
	end
	subtitle.Text = summary

	-- Baris judul kolom
	clearChildren(headerRow)
	local nameColumn = nameWidth()
	local headerProps = { TextColor3 = Theme.White, BackgroundTransparency = 0, BackgroundColor3 = Theme.Ink }
	cell(headerRow, 1, UDim.new(0, layout.Rank), "#", headerProps)
	cell(headerRow, 2, nameColumn, "Nama", {
		TextColor3 = Theme.White,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	for stageIndexNumber, stage in GameConfig.Stages do
		local selected = stageIndexNumber == index
		cell(headerRow, 2 + stageIndexNumber, UDim.new(0, layout.Stage), `{stage.ElementIcon} {stage.Number}`, {
			TextColor3 = if selected then Theme.Ink else Theme.White,
			BackgroundTransparency = 0,
			BackgroundColor3 = if selected then stage.Color else Theme.Ink,
		})
	end
	cell(headerRow, 10, UDim.new(0, layout.Total), "Total", {
		TextColor3 = if index then Theme.White else Theme.Ink,
		BackgroundTransparency = 0,
		BackgroundColor3 = if index then Theme.Ink else Theme.GoldBright,
	})
	if admin then
		cell(headerRow, 11, UDim.new(0, layout.Edit), "", headerProps)
	end

	-- Baris siswa
	clearChildren(list)
	if #entries == 0 then
		UiKit.label({
			Size = UDim2.new(1, 0, 0, 40),
			Font = Theme.FontBody,
			TextSize = layout.TextSize,
			TextColor3 = Theme.InkSoft,
			Text = "Belum ada siswa di kelas ini.",
			Parent = list,
		})
		return
	end
	for rank, entry in entries do
		local isMe = entry.UserId == player.UserId
		local row = UiKit.new("Frame", {
			Size = UDim2.new(1, 0, 0, layout.RowHeight),
			BackgroundColor3 = if isMe then Theme.GoldBright elseif rank % 2 == 0 then Theme.CreamDark else Theme.White,
			BackgroundTransparency = if isMe then 0.1 else 0.3,
			LayoutOrder = rank,
			Parent = list,
		}, {
			UiKit.corner(8),
			UiKit.new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local textColor = if entry.Online then Theme.Ink else Theme.InkSoft
		cell(row, 1, UDim.new(0, layout.Rank), MEDALS[rank] or tostring(rank), { TextColor3 = textColor })
		cell(row, 2, nameColumn, if entry.Online then entry.Name else `{entry.Name} (keluar)`, {
			TextColor3 = textColor,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		for stageIndexNumber, stage in GameConfig.Stages do
			local stageEntry = entry.Stages[stageIndexNumber] or { Points = 0, Done = false }
			local text = if stageEntry.Done
				then `✅{UiKit.formatNumber(stageEntry.Points)}`
				elseif stageEntry.Points ~= 0 then UiKit.formatNumber(stageEntry.Points)
				else "–"
			local selected = stageIndexNumber == index
			cell(row, 2 + stageIndexNumber, UDim.new(0, layout.Stage), text, {
				Font = Theme.FontBody,
				TextColor3 = if stageEntry.Points < 0 then Theme.Danger else textColor,
				BackgroundTransparency = if selected then 0.55 else 1,
				BackgroundColor3 = stage.Color,
			})
		end
		cell(row, 10, UDim.new(0, layout.Total), UiKit.formatNumber(entry.Points), {
			TextColor3 = textColor,
			BackgroundTransparency = if index then 1 else 0.4,
			BackgroundColor3 = Theme.GoldBright,
		})
		if admin then
			local editButton = UiKit.button({
				Size = UDim2.new(0, layout.Edit, 1, -4),
				Text = "✏️",
				TextSize = layout.TextSize,
				BackgroundColor3 = Theme.CreamDark,
				Visible = entry.Online,
				LayoutOrder = 11,
				Parent = row,
			})
			editButton.Activated:Connect(function()
				Sfx.Play("Click")
				Remotes.Get("AdminAction"):FireServer("RequestRename", entry.UserId)
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- Tampil / sembunyi
--------------------------------------------------------------------------------
local dismissed = false -- siswa menutup papan yang sedang ditampilkan Guru

local function refreshVisibility()
	local shared = state:GetAttribute("ScoreboardVisible") == true and not dismissed
	local localView = player:GetAttribute(LOCAL_VIEW_ATTRIBUTE) == true
	local shouldShow = shared or localView
	if shouldShow and not gui.Enabled then
		gui.Enabled = true
		render()
	elseif not shouldShow then
		gui.Enabled = false
	end
end

closeButton.Activated:Connect(function()
	Sfx.Play("Click")
	dismissed = state:GetAttribute("ScoreboardVisible") == true
	player:SetAttribute(LOCAL_VIEW_ATTRIBUTE, false)
	refreshVisibility()
end)

state:GetAttributeChangedSignal("ScoreboardVisible"):Connect(function()
	if state:GetAttribute("ScoreboardVisible") == true then
		dismissed = false
		Sfx.Play("Fanfare")
	end
	refreshVisibility()
end)
state:GetAttributeChangedSignal("Scoreboard"):Connect(render)
state:GetAttributeChangedSignal("ScoreboardMode"):Connect(render)
player:GetAttributeChangedSignal(LOCAL_VIEW_ATTRIBUTE):Connect(refreshVisibility)
player:GetAttributeChangedSignal("IsAdmin"):Connect(render)
UiKit.OnLayout(function()
	render()
end)

refreshVisibility()
