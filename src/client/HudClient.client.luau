--[[
	HudClient (LocalScript)
	Lokasi: StarterPlayer > StarterPlayerScripts > HudClient

	Menampilkan di layar setiap pemain:
	  * Jumlah Poin (atas tengah; di HP: kiri atas)
	  * Animasi "+10 Poin · Jawaban benar!"
	  * Notifikasi kecil (portal dibuka, dll; di HP: bawah tengah)
	  * Pengumuman besar dari Guru (ketuk untuk menutup)
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UiKit = require(Shared:WaitForChild("UiKit"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local Theme = GameConfig.Theme
local TOAST_DURATION = 4
local ANNOUNCEMENT_DURATION = 9

local KIND_COLORS = {
	info = Theme.Info,
	success = Theme.Success,
	error = Theme.Danger,
	portal = Theme.GoldBright,
}

local player = Players.LocalPlayer
local compact = false -- diatur oleh UiKit.OnLayout di bagian bawah

local gui = UiKit.new("ScreenGui", {
	Name = "HUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 5,
	Parent = player:WaitForChild("PlayerGui"),
})

--------------------------------------------------------------------------------
-- 1) Jumlah Poin
--------------------------------------------------------------------------------
local pointsPill = UiKit.new("Frame", {
	Name = "Poin",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(230, 52),
	BackgroundColor3 = Theme.Night,
	BackgroundTransparency = 0.2,
	Parent = gui,
}, {
	UiKit.corner(26),
	UiKit.stroke(Theme.Gold, 2),
})
local pillScale = UiKit.new("UIScale", { Parent = pointsPill })

local pointsLabel = UiKit.label({
	Size = UDim2.fromScale(1, 1),
	Text = "⭐ 0 Poin",
	TextScaled = true,
	TextColor3 = Theme.GoldBright,
	TextWrapped = false,
	Parent = pointsPill,
}, {
	UiKit.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	UiKit.new("UITextSizeConstraint", { MaxTextSize = 28 }),
})

local function pulse(scale: UIScale)
	scale.Scale = 1.18
	UiKit.tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
end

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats")
	local stat = leaderstats:WaitForChild(GameConfig.Points.StatName)
	local function update()
		pointsLabel.Text = `⭐ {UiKit.formatNumber(stat.Value)} Poin`
	end
	update()
	stat.Changed:Connect(update)
end)

--------------------------------------------------------------------------------
-- 2) Animasi perubahan Poin
--------------------------------------------------------------------------------
local function showPointsPopup(delta: number, reason: string?)
	local amountText = if delta > 0 then `+{delta} Poin` elseif delta < 0 then `{delta} Poin` else ""
	local text = amountText
	if reason and reason ~= "" then
		text = if amountText ~= "" then `{amountText}  ·  {reason}` else reason
	end
	if text == "" then
		return
	end
	-- Poin tidak pernah naik dari jawaban salah; delta 0 berarti pengurangan yang tertahan di 0.
	Sfx.Play(if delta > 0 then "Correct" else "Wrong")
	local color = if delta > 0 then Theme.Success elseif delta < 0 then Theme.Danger else Theme.Cream

	-- Di HP sedikit lebih rendah (panel tahap ada di kanan atas) dan lebih kecil.
	local y = if compact then 0.45 else 0.36
	local stroke = UiKit.textStroke(Theme.Night, 3)
	local popup = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, y),
		Size = UDim2.new(0.9, 0, 0, if compact then 44 else 60),
		Text = text,
		TextScaled = true,
		TextColor3 = color,
		Parent = gui,
	}, {
		stroke,
		UiKit.new("UITextSizeConstraint", { MaxTextSize = if compact then 30 else 40 }),
	})
	local scale = UiKit.new("UIScale", { Scale = 0.6, Parent = popup })
	UiKit.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)

	task.delay(1, function()
		UiKit.tween(popup, 0.8, { Position = UDim2.fromScale(0.5, y - 0.08), TextTransparency = 1 })
		UiKit.tween(stroke, 0.8, { Transparency = 1 }).Completed:Wait()
		popup:Destroy()
	end)

	if delta ~= 0 then
		pulse(pillScale)
	end
end

--------------------------------------------------------------------------------
-- 3) Notifikasi kecil (toast)
--------------------------------------------------------------------------------
local toastLayout = UiKit.new("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
})
local toastConstraint = UiKit.new("UISizeConstraint", {})
local toastHolder = UiKit.new("Frame", {
	Name = "Notifikasi",
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Parent = gui,
}, { toastLayout, toastConstraint })
local toastCount = 0

local TOAST_SOUNDS = { portal = "PortalOpen", error = "Error" }

local function showToast(text: string, kind: string?)
	Sfx.Play(TOAST_SOUNDS[kind or "info"] or "Notify")
	toastCount += 1
	local accent = KIND_COLORS[kind or "info"] or Theme.Info
	local stroke = UiKit.stroke(accent, 2, 1)
	local toast = UiKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Night,
		BackgroundTransparency = 1,
		LayoutOrder = toastCount,
		Parent = toastHolder,
	}, { UiKit.corner(12), stroke, UiKit.padding(10) })
	local label = UiKit.label({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = text,
		Font = Theme.FontBold,
		TextSize = if compact then 15 else 18,
		TextTransparency = 1,
		Parent = toast,
	})

	-- Hapus notifikasi paling lama jika terlalu banyak.
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	-- Di HP cukup 2 notifikasi supaya layar tidak penuh.
	for index = 1, #toasts - (if compact then 2 else 4) do
		toasts[index]:Destroy()
	end

	UiKit.tween(toast, 0.25, { BackgroundTransparency = if compact then 0.25 else 0.15 })
	UiKit.tween(stroke, 0.25, { Transparency = 0 })
	UiKit.tween(label, 0.25, { TextTransparency = 0 })

	task.delay(TOAST_DURATION, function()
		if not toast.Parent then
			return
		end
		UiKit.tween(toast, 0.4, { BackgroundTransparency = 1 })
		UiKit.tween(stroke, 0.4, { Transparency = 1 })
		UiKit.tween(label, 0.4, { TextTransparency = 1 }).Completed:Wait()
		toast:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- 4) Pengumuman dari Guru
--------------------------------------------------------------------------------
local announcement = UiKit.new("Frame", {
	Name = "Pengumuman",
	AnchorPoint = Vector2.new(0.5, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Theme.Cream,
	Active = true,
	Visible = false,
	Parent = gui,
}, {
	UiKit.corner(18),
	UiKit.stroke(Theme.Gold, 3),
	UiKit.padding(18),
	UiKit.new("UISizeConstraint", { MinSize = Vector2.new(300, 0), MaxSize = Vector2.new(760, math.huge) }),
	UiKit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local announcementScale = UiKit.new("UIScale", { Parent = announcement })
local announcementBaseScale = 1

UiKit.label({
	Text = "📢 Pengumuman dari Guru",
	Size = UDim2.new(1, 0, 0, 34),
	TextSize = 28,
	TextColor3 = Theme.Ink,
	LayoutOrder = 1,
	Parent = announcement,
})
local announcementBody = UiKit.label({
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Font = Theme.FontBody,
	TextSize = 22,
	TextColor3 = Theme.Ink,
	LayoutOrder = 2,
	Parent = announcement,
})
local announcementFrom = UiKit.label({
	Size = UDim2.new(1, 0, 0, 20),
	Font = Theme.FontBody,
	TextSize = 16,
	TextColor3 = Theme.InkSoft,
	TextXAlignment = Enum.TextXAlignment.Right,
	LayoutOrder = 3,
	Parent = announcement,
})
local announcementHint = UiKit.label({
	Size = UDim2.new(1, 0, 0, 16),
	Font = Theme.FontBody,
	TextSize = 13,
	TextColor3 = Theme.InkSoft,
	Text = "Ketuk untuk menutup",
	LayoutOrder = 4,
	Parent = announcement,
})
local announcementToken = 0

announcement.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		announcementToken += 1
		announcement.Visible = false
	end
end)

local function showAnnouncement(text: string, fromName: string?)
	Sfx.Play("Announcement")
	announcementToken += 1
	local token = announcementToken
	announcementBody.Text = text
	announcementFrom.Text = if fromName then `— {fromName}` else ""
	announcement.Visible = true
	announcementScale.Scale = announcementBaseScale * 0.85
	UiKit.tween(announcementScale, 0.35, { Scale = announcementBaseScale }, Enum.EasingStyle.Back)
	task.delay(ANNOUNCEMENT_DURATION, function()
		if token == announcementToken then
			announcement.Visible = false
		end
	end)
end

--------------------------------------------------------------------------------
-- 5) Tata letak HP / PC
--------------------------------------------------------------------------------
-- Efek blur jarak jauh (Depth of Field) berat untuk HP dan membuat label yang jauh
-- sulit dibaca di layar kecil. Hanya dimatikan di layar ini (lokal).
local function applyDepthOfField()
	local depthOfField = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if depthOfField then
		depthOfField.Enabled = not compact
	end
end

UiKit.OnLayout(function(isCompact)
	compact = isCompact
	if isCompact then
		-- HP: Poin di kiri atas (tengah atas dipakai panel tahap & tidak terhalang jempol),
		-- notifikasi di bawah tengah (di antara joystick dan tombol lompat).
		pointsPill.AnchorPoint = Vector2.new(0, 0)
		pointsPill.Position = UDim2.new(0, 8, 0, 4)
		pointsPill.Size = UDim2.fromOffset(150, 40)
		toastHolder.AnchorPoint = Vector2.new(0.5, 1)
		toastHolder.Position = UDim2.new(0.5, 0, 1, -84)
		toastHolder.Size = UDim2.new(0.44, 0, 0, 0)
		toastConstraint.MaxSize = Vector2.new(400, math.huge)
		toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		announcement.Position = UDim2.new(0.5, 0, 0, 6)
		announcement.Size = UDim2.new(0.8, 0, 0, 0)
		announcementBaseScale = 0.8
	else
		pointsPill.AnchorPoint = Vector2.new(0.5, 0)
		pointsPill.Position = UDim2.new(0.5, 0, 0, 8)
		pointsPill.Size = UDim2.fromOffset(230, 52)
		toastHolder.AnchorPoint = Vector2.new(0.5, 0)
		toastHolder.Position = UDim2.new(0.5, 0, 0, 70)
		toastHolder.Size = UDim2.new(0.9, 0, 0, 0)
		toastConstraint.MaxSize = Vector2.new(520, math.huge)
		toastLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		announcement.Position = UDim2.fromScale(0.5, 0.2)
		announcement.Size = UDim2.new(0.6, 0, 0, 0)
		announcementBaseScale = 1
	end
	announcementScale.Scale = announcementBaseScale
	announcementHint.Visible = isCompact
	applyDepthOfField()
end)
Lighting.ChildAdded:Connect(applyDepthOfField)

--------------------------------------------------------------------------------
Remotes.Get("Notify").OnClientEvent:Connect(showToast)
Remotes.Get("PointsPopup").OnClientEvent:Connect(showPointsPopup)
Remotes.Get("Announcement").OnClientEvent:Connect(showAnnouncement)

showToast(`👋 Selamat datang di {GameConfig.GameTitle}! Tunggu Guru membuka portal, ya.`, "portal")
