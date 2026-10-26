--[[
	NameClient (LocalScript)
	Lokasi: StarterPlayer > StarterPlayerScripts > NameClient

	Layar "Tulis namamu" di awal game, dan saat Guru meminta siswa mengganti nama.
	Muncul selama Attribute pemain "NeedsName" = true (diatur NameService di server).
	Nama yang diterima server dipakai di Videotron, Papan Poin, daftar pemain, dan
	di atas kepala karakter. Guru tidak diminta mengisi nama.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UiKit = require(Shared:WaitForChild("UiKit"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local Theme = GameConfig.Theme
local CONFIG = GameConfig.StudentNames
local RESPONSE_TIMEOUT = 10

if not CONFIG.Enabled then
	return
end

local player = Players.LocalPlayer
local submitRemote = Remotes.Get("NameSubmit")
local resultRemote = Remotes.Get("NameResult")

local gui = UiKit.new("ScreenGui", {
	Name = "IsiNama",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 20, -- di atas semua UI lain
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Latar gelap yang menahan klik/ketukan: isi nama dulu sebelum bermain.
local backdrop = UiKit.new("Frame", {
	Position = UDim2.new(0, 0, 0, -80),
	Size = UDim2.new(1, 0, 1, 80),
	BackgroundColor3 = Theme.Night,
	BackgroundTransparency = 0.35,
	Active = true,
	Parent = gui,
})

local cardConstraint = UiKit.new("UISizeConstraint", { MinSize = Vector2.new(280, 0), MaxSize = Vector2.new(520, math.huge) })
local card = UiKit.new("Frame", {
	Name = "Kartu",
	AnchorPoint = Vector2.new(0.5, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Theme.Cream,
	Parent = gui,
}, {
	UiKit.corner(18),
	UiKit.stroke(Theme.Gold, 4),
	UiKit.padding(18),
	cardConstraint,
	UiKit.new("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
})
local cardScale = UiKit.new("UIScale", { Parent = card })
local baseScale = 1

local title = UiKit.label({
	Size = UDim2.new(1, 0, 0, 36),
	TextSize = 30,
	TextColor3 = Theme.Ink,
	LayoutOrder = 1,
	Parent = card,
})
local body = UiKit.label({
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Font = Theme.FontBody,
	TextSize = 17,
	TextColor3 = Theme.InkSoft,
	LayoutOrder = 2,
	Parent = card,
})
local textBox = UiKit.new("TextBox", {
	Size = UDim2.new(1, 0, 0, 50),
	BackgroundColor3 = Theme.White,
	ClearTextOnFocus = false,
	PlaceholderText = "Contoh: Budi Santoso",
	PlaceholderColor3 = Theme.InkSoft,
	Text = "",
	TextColor3 = Theme.Ink,
	Font = Theme.FontBold,
	TextSize = 22,
	LayoutOrder = 3,
	Parent = card,
}, { UiKit.corner(12), UiKit.stroke(Theme.Gold, 2), UiKit.padding(8) })
local errorLabel = UiKit.label({
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Font = Theme.FontBold,
	TextSize = 16,
	TextColor3 = Theme.Danger,
	Visible = false,
	LayoutOrder = 4,
	Parent = card,
})
local button = UiKit.button({
	Size = UDim2.new(1, 0, 0, 50),
	BackgroundColor3 = Theme.GoldBright,
	TextSize = 22,
	LayoutOrder = 5,
	Parent = card,
}, { UiKit.stroke(Theme.Gold, 2) })
UiKit.label({
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Font = Theme.FontBody,
	TextSize = 14,
	TextColor3 = Theme.InkSoft,
	Text = `Nama ini dilihat Guru dan teman-teman. Pakai nama asli atau nama panggilanmu ({CONFIG.MinLength}–{CONFIG.MaxLength} huruf).`,
	LayoutOrder = 6,
	Parent = card,
})

local BUTTON_TEXT = "✅ Mulai Bermain"
local waitToken = 0
local waiting = false

local function setWaiting(isWaiting: boolean)
	waiting = isWaiting
	button.Text = if isWaiting then "⏳ Memeriksa nama…" else BUTTON_TEXT
	button.AutoButtonColor = not isWaiting
	button.BackgroundColor3 = if isWaiting then Theme.CreamDark else Theme.GoldBright
end

local function showError(text: string)
	errorLabel.Text = `⚠️ {text}`
	errorLabel.Visible = true
	Sfx.Play("Error")
end

local function submit()
	if waiting then
		return
	end
	local text = textBox.Text
	if text:match("^%s*$") then
		showError("Tulis namamu dulu, ya.")
		return
	end
	errorLabel.Visible = false
	Sfx.Play("Click")
	setWaiting(true)
	waitToken += 1
	local token = waitToken
	submitRemote:FireServer(text)
	-- Jika jawaban server tidak datang (jaringan putus sebentar), tombol aktif lagi.
	task.delay(RESPONSE_TIMEOUT, function()
		if waiting and token == waitToken then
			setWaiting(false)
			showError("Koneksi lambat. Coba tekan tombolnya lagi.")
		end
	end)
end

-- Batasi panjang ketikan (server tetap memeriksa ulang).
textBox:GetPropertyChangedSignal("Text"):Connect(function()
	local text = textBox.Text
	local length = utf8.len(text)
	if length and length > CONFIG.MaxLength then
		local cutAt = utf8.offset(text, CONFIG.MaxLength + 1)
		if cutAt then
			textBox.Text = text:sub(1, cutAt - 1)
		end
	end
end)
textBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		submit()
	end
end)
button.Activated:Connect(submit)

resultRemote.OnClientEvent:Connect(function(result)
	waitToken += 1
	setWaiting(false)
	if typeof(result) ~= "table" then
		return
	end
	if result.Ok then
		Sfx.Play("Success")
		gui.Enabled = false
	else
		showError(if typeof(result.Error) == "string" then result.Error else "Nama tidak valid.")
	end
end)

--------------------------------------------------------------------------------
-- Buka / tutup
--------------------------------------------------------------------------------
local function open()
	local current = player:GetAttribute("StudentName")
	if typeof(current) == "string" then
		title.Text = "✏️ Ganti Nama"
		body.Text = "Guru memintamu menulis ulang namamu. Periksa ejaannya, ya."
		textBox.Text = current
	else
		title.Text = "👋 Selamat Datang!"
		body.Text = "Sebelum bermain, tulis namamu supaya Guru dan teman-teman mengenalimu di Papan Poin dan Videotron."
	end
	errorLabel.Visible = false
	setWaiting(false)
	gui.Enabled = true
	cardScale.Scale = baseScale * 0.85
	UiKit.tween(cardScale, 0.35, { Scale = baseScale }, Enum.EasingStyle.Back)
	Sfx.Play("Notify")
	if not UiKit.IsTouch() then
		textBox:CaptureFocus() -- di PC langsung bisa mengetik
	end
end

local function refresh()
	local needsName = player:GetAttribute("NeedsName") == true
	if needsName and not gui.Enabled then
		open()
	elseif not needsName then
		gui.Enabled = false
	end
end

UiKit.OnLayout(function(compact)
	-- HP: kartu di bagian atas (bagian bawah layar tertutup keyboard saat mengetik).
	baseScale = if compact then 0.85 else 1
	cardScale.Scale = baseScale
	card.Position = if compact then UDim2.new(0.5, 0, 0, 6) else UDim2.fromScale(0.5, 0.16)
	card.Size = UDim2.new(if compact then 0.6 else 0.45, 0, 0, 0)
end)

player:GetAttributeChangedSignal("NeedsName"):Connect(refresh)
refresh()
