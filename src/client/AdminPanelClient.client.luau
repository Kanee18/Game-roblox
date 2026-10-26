--[[
	AdminPanelClient (LocalScript)
	Lokasi: StarterPlayer > StarterPlayerScripts > AdminPanelClient

	Panel Guru: hanya dibuat untuk pemain dengan Attribute "IsAdmin" = true.
	Keamanan tetap dijaga di server (AdminService memeriksa ulang setiap
	perintah), jadi siswa tidak bisa memakai panel ini walaupun melihat kodenya.

	Fitur:
	  * Buka/Tutup 4 portal elemen
	  * Tutup semua portal, panggil semua siswa ke Lobby, reset semua Poin
	  * Kirim pengumuman ke semua siswa
	Tombol "🛠️ Panel Guru" di kiri layar, atau tekan G.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UiKit = require(Shared:WaitForChild("UiKit"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local Theme = GameConfig.Theme
local TOGGLE_KEY = Enum.KeyCode.G
local RESET_CONFIRM_SECONDS = 3

local player = Players.LocalPlayer

local function buildPanel()
	local adminAction = Remotes.Get("AdminAction")
	local state = Remotes.GetState()

	local gui = UiKit.new("ScreenGui", {
		Name = "PanelGuru",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local toggleButton = UiKit.button({
		Name = "TombolPanel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(160, 48),
		BackgroundColor3 = Theme.Cream,
		Text = "🛠️ Panel Guru",
		TextSize = 20,
		Parent = gui,
	}, { UiKit.stroke(Theme.Gold, 2) })

	local panel = UiKit.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 184, 0.5, 0),
		Size = UDim2.new(0, 440, 0.85, 0),
		BackgroundColor3 = Theme.Cream,
		Visible = false,
		Parent = gui,
	}, {
		UiKit.corner(18),
		UiKit.stroke(Theme.Gold, 3),
		UiKit.new("UISizeConstraint", { MaxSize = Vector2.new(440, 700) }),
	})

	-- Judul
	UiKit.label({
		Text = "PANEL GURU",
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(1, -80, 0, 34),
		TextSize = 30,
		TextColor3 = Theme.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	UiKit.label({
		Text = "Kontrol portal & kelas · tekan G untuk buka/tutup",
		Position = UDim2.fromOffset(20, 46),
		Size = UDim2.new(1, -80, 0, 18),
		Font = Theme.FontBody,
		TextSize = 14,
		TextColor3 = Theme.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	local closeButton = UiKit.button({
		Text = "✕",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Theme.CreamDark,
		TextSize = 22,
		Parent = panel,
	})

	local body = UiKit.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 1, -86),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Gold,
		Parent = panel,
	}, {
		UiKit.new("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UiKit.new("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 22),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 14),
		}),
	})

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local function sectionTitle(text: string)
		UiKit.label({
			Text = text,
			Size = UDim2.new(1, 0, 0, 26),
			TextSize = 20,
			TextColor3 = Theme.Ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = nextOrder(),
			Parent = body,
		})
	end

	local function actionButton(text: string, color: Color3, onClick: (TextButton) -> ()): TextButton
		local button = UiKit.button({
			Text = text,
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = color,
			LayoutOrder = nextOrder(),
			Parent = body,
		})
		button.Activated:Connect(function()
			Sfx.Play("Click")
			onClick(button)
		end)
		return button
	end

	----------------------------------------------------------------------------
	-- Portal elemen
	----------------------------------------------------------------------------
	sectionTitle("🌀 Portal Elemen")

	local portalRows = {}

	local function isPortalOpen(stageId: string): boolean
		return state:GetAttribute(GameConfig.PortalStatePrefix .. stageId) == true
	end

	local function refreshRow(stageId: string)
		local row = portalRows[stageId]
		if not row then
			return
		end
		local isOpen = isPortalOpen(stageId)
		row.Status.Text = if isOpen then "● TERBUKA — siswa bisa masuk" else "● TERTUTUP"
		row.Status.TextColor3 = if isOpen then Theme.SuccessDark else Theme.Danger
		row.Button.Text = if isOpen then "Tutup" else "Buka"
		row.Button.BackgroundColor3 = if isOpen then Theme.Danger else Theme.Success
	end

	for _, stage in GameConfig.Stages do
		local row = UiKit.new("Frame", {
			Size = UDim2.new(1, 0, 0, 82),
			BackgroundColor3 = Theme.White,
			LayoutOrder = nextOrder(),
			Parent = body,
		}, { UiKit.corner(12), UiKit.stroke(Theme.CreamDark, 1) })

		UiKit.new("Frame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(0, 8, 1, -16),
			BackgroundColor3 = stage.Color,
			Parent = row,
		}, { UiKit.corner(4) })

		UiKit.label({
			Text = `{stage.ElementIcon} Tahap {stage.Number} · {stage.Title}`,
			Position = UDim2.fromOffset(26, 8),
			Size = UDim2.new(1, -150, 0, 24),
			TextSize = 18,
			TextColor3 = Theme.Ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		UiKit.label({
			Text = `Portal {stage.Element} · {stage.Materi}`,
			Position = UDim2.fromOffset(26, 34),
			Size = UDim2.new(1, -150, 0, 18),
			Font = Theme.FontBody,
			TextSize = 13,
			TextColor3 = Theme.InkSoft,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local status = UiKit.label({
			Position = UDim2.fromOffset(26, 56),
			Size = UDim2.new(1, -150, 0, 18),
			Font = Theme.FontBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = false,
			Parent = row,
		})
		local button = UiKit.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(110, 44),
			TextColor3 = Theme.White,
			TextSize = 20,
			Parent = row,
		}, { UiKit.textStroke(Theme.Ink, 1) })

		portalRows[stage.Id] = { Status = status, Button = button }

		button.Activated:Connect(function()
			Sfx.Play("Click")
			adminAction:FireServer("SetPortal", stage.Id, not isPortalOpen(stage.Id))
		end)
		state:GetAttributeChangedSignal(GameConfig.PortalStatePrefix .. stage.Id):Connect(function()
			refreshRow(stage.Id)
		end)
		refreshRow(stage.Id)
	end

	----------------------------------------------------------------------------
	-- Kontrol kelas
	----------------------------------------------------------------------------
	sectionTitle("🏫 Kontrol Kelas")

	actionButton("🔒 Tutup Semua Portal", Theme.CreamDark, function()
		adminAction:FireServer("CloseAllPortals")
	end)

	actionButton("🏠 Panggil Semua ke Lobby", Theme.Info, function()
		adminAction:FireServer("RecallAll")
	end)

	local RESET_TEXT = "♻️ Reset Semua Poin"
	local resetArmedUntil = 0
	actionButton(RESET_TEXT, Theme.Gold, function(button)
		if os.clock() < resetArmedUntil then
			resetArmedUntil = 0
			button.Text = RESET_TEXT
			adminAction:FireServer("ResetPoints")
			return
		end
		-- Klik pertama hanya meminta konfirmasi agar tidak terhapus tanpa sengaja.
		resetArmedUntil = os.clock() + RESET_CONFIRM_SECONDS
		button.Text = "⚠️ Yakin? Klik sekali lagi"
		task.delay(RESET_CONFIRM_SECONDS, function()
			if os.clock() >= resetArmedUntil then
				button.Text = RESET_TEXT
			end
		end)
	end)

	-- Musik latar untuk semua siswa (efek suara tetap menyala)
	local musicButton = actionButton("", Theme.CreamDark, function()
		adminAction:FireServer("SetMusic", state:GetAttribute("MusicEnabled") == false)
	end)
	local function refreshMusicButton()
		local enabled = state:GetAttribute("MusicEnabled") ~= false
		musicButton.Text = if enabled then "🎵 Musik semua siswa: NYALA" else "🔇 Musik semua siswa: MATI"
		musicButton.BackgroundColor3 = if enabled then Theme.CreamDark else Theme.Danger
	end
	state:GetAttributeChangedSignal("MusicEnabled"):Connect(refreshMusicButton)
	refreshMusicButton()

	----------------------------------------------------------------------------
	-- Pengumuman
	----------------------------------------------------------------------------
	sectionTitle("📢 Pengumuman")

	local textBox = UiKit.new("TextBox", {
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Theme.White,
		ClearTextOnFocus = false,
		PlaceholderText = "Tulis pengumuman untuk semua siswa… (Enter untuk kirim)",
		PlaceholderColor3 = Theme.InkSoft,
		Text = "",
		TextColor3 = Theme.Ink,
		Font = Theme.FontBody,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = nextOrder(),
		Parent = body,
	}, { UiKit.corner(10), UiKit.stroke(Theme.CreamDark, 1), UiKit.padding(8) })

	local function sendAnnouncement()
		local text = textBox.Text
		if text:match("^%s*$") then
			return
		end
		adminAction:FireServer("Announce", text)
		textBox.Text = ""
	end

	actionButton("📢 Kirim Pengumuman", Theme.GoldBright, sendAnnouncement)
	textBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			sendAnnouncement()
		end
	end)

	----------------------------------------------------------------------------
	-- Buka / tutup panel
	----------------------------------------------------------------------------
	local function setVisible(visible: boolean)
		panel.Visible = visible
		toggleButton.Text = if visible then "✖ Tutup Panel" else "🛠️ Panel Guru"
	end

	toggleButton.Activated:Connect(function()
		Sfx.Play("Click")
		setVisible(not panel.Visible)
	end)
	closeButton.Activated:Connect(function()
		setVisible(false)
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == TOGGLE_KEY then
			setVisible(not panel.Visible)
		end
	end)
end

-- Server menentukan status admin (bisa butuh sesaat jika memeriksa Group).
if player:GetAttribute("IsAdmin") == true then
	buildPanel()
else
	local connection
	connection = player:GetAttributeChangedSignal("IsAdmin"):Connect(function()
		if player:GetAttribute("IsAdmin") == true then
			connection:Disconnect()
			buildPanel()
		end
	end)
end
