--[[
	HudClient (LocalScript)
	Lokasi: StarterPlayer > StarterPlayerScripts > HudClient

	Menampilkan di layar setiap pemain:
	  * Jumlah Poin (atas tengah)
	  * Animasi "+10 Poin · Jawaban benar!"
	  * Notifikasi kecil (portal dibuka, dll)
	  * Pengumuman besar dari Guru
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UiKit = require(Shared:WaitForChild("UiKit"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local Theme = GameConfig.Theme
local TOAST_DURATION = 4
local MAX_TOASTS = 4
local ANNOUNCEMENT_DURATION = 9

local KIND_COLORS = {
	info = Theme.Info,
	success = Theme.Success,
	error = Theme.Danger,
	portal = Theme.GoldBright,
}

local player = Players.LocalPlayer

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
	TextSize = 28,
	TextColor3 = Theme.GoldBright,
	TextWrapped = false,
	Parent = pointsPill,
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

	local stroke = UiKit.textStroke(Theme.Night, 3)
	local popup = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.new(0.9, 0, 0, 60),
		Text = text,
		TextScaled = true,
		TextColor3 = color,
		Parent = gui,
	}, {
		stroke,
		UiKit.new("UITextSizeConstraint", { MaxTextSize = 40 }),
	})
	local scale = UiKit.new("UIScale", { Scale = 0.6, Parent = popup })
	UiKit.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)

	task.delay(1, function()
		UiKit.tween(popup, 0.8, { Position = UDim2.fromScale(0.5, 0.28), TextTransparency = 1 })
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
local toastHolder = UiKit.new("Frame", {
	Name = "Notifikasi",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.new(0.9, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	UiKit.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
	UiKit.new("UISizeConstraint", { MaxSize = Vector2.new(520, math.huge) }),
})
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
		TextSize = 18,
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
	for index = 1, #toasts - MAX_TOASTS do
		toasts[index]:Destroy()
	end

	UiKit.tween(toast, 0.25, { BackgroundTransparency = 0.15 })
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
	Position = UDim2.fromScale(0.5, 0.2),
	Size = UDim2.new(0.6, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Theme.Cream,
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
local announcementToken = 0

local function showAnnouncement(text: string, fromName: string?)
	Sfx.Play("Announcement")
	announcementToken += 1
	local token = announcementToken
	announcementBody.Text = text
	announcementFrom.Text = if fromName then `— {fromName}` else ""
	announcement.Visible = true
	announcementScale.Scale = 0.85
	UiKit.tween(announcementScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(ANNOUNCEMENT_DURATION, function()
		if token == announcementToken then
			announcement.Visible = false
		end
	end)
end

--------------------------------------------------------------------------------
Remotes.Get("Notify").OnClientEvent:Connect(showToast)
Remotes.Get("PointsPopup").OnClientEvent:Connect(showPointsPopup)
Remotes.Get("Announcement").OnClientEvent:Connect(showAnnouncement)

showToast(`👋 Selamat datang di {GameConfig.GameTitle}! Tunggu Guru membuka portal, ya.`, "portal")
