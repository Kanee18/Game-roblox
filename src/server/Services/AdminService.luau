--[[
	AdminService (ModuleScript)
	Lokasi: ServerScriptService > Services > AdminService

	Menentukan siapa Guru (admin) dan menjalankan perintah dari Panel Guru.
	Setiap perintah diperiksa ulang di server, jadi siswa tidak bisa
	membuka portal walaupun mencoba mengirim RemoteEvent sendiri.

	Pemain admin mendapat Attribute "IsAdmin" = true (dibaca AdminPanelClient).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(ReplicatedStorage.Shared.UiKit)
local NameService = require(script.Parent.NameService)
local NotifyService = require(script.Parent.NotifyService)
local PointsService = require(script.Parent.PointsService)
local PortalService = require(script.Parent.PortalService)
local ProgressService = require(script.Parent.ProgressService)
local SpawnService = require(script.Parent.SpawnService)

local CONFIG = GameConfig.Admin
local Theme = GameConfig.Theme
local MAX_ANNOUNCEMENT_LENGTH = 150
local ACTION_COOLDOWN = 0.4

local AdminService = {}

local lastActionAt: { [Player]: number } = {}
local initializedPlayers: { [Player]: boolean } = {}

local function checkAdmin(player: Player): boolean
	if table.find(CONFIG.UserIds, player.UserId) then
		return true
	end
	if CONFIG.CreatorIsAdmin and game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	if RunService:IsStudio() and (player.UserId > 0 or table.find(CONFIG.StudioTestAdminIds, player.UserId)) then
		return true
	end
	if (CONFIG.GroupId or 0) > 0 then
		local ok, rank = pcall(player.GetRankInGroup, player, CONFIG.GroupId)
		if ok and rank >= CONFIG.GroupMinRank then
			return true
		end
	end
	return false
end

function AdminService.IsAdmin(player: Player): boolean
	return player:GetAttribute("IsAdmin") == true
end

-- Label "⭐ GURU" di atas kepala Guru agar mudah dikenali siswa.
local function addTeacherTag(character: Model)
	local head = character:WaitForChild("Head", 5)
	if not head or head:FindFirstChild("GuruTag") then
		return
	end
	local billboard = UiKit.new("BillboardGui", {
		Name = "GuruTag",
		Size = UDim2.fromOffset(110, 32),
		StudsOffset = Vector3.new(0, 2.8, 0),
		AlwaysOnTop = true,
		MaxDistance = 90,
		LightInfluence = 0,
		Parent = head,
	})
	UiKit.label({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.GoldBright,
		Text = "⭐ GURU",
		TextSize = 20,
		TextColor3 = Theme.Ink,
		Parent = billboard,
	}, { UiKit.corner(16), UiKit.stroke(Theme.Night, 2) })
end

-- Membersihkan teks pengumuman: buang karakter kontrol, rapikan spasi, batasi panjang.
local function cleanText(raw: any): string?
	if typeof(raw) ~= "string" then
		return nil
	end
	local text = raw:gsub("%c", " ")
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	local length = utf8.len(text)
	if not length or length == 0 then
		return nil
	end
	if length > MAX_ANNOUNCEMENT_LENGTH then
		local cutAt = utf8.offset(text, MAX_ANNOUNCEMENT_LENGTH + 1)
		if cutAt then
			text = text:sub(1, cutAt - 1)
		end
	end
	return text
end

-- Aturan Roblox: teks dari pemain yang ditampilkan ke pemain lain WAJIB difilter.
local function filterForBroadcast(text: string, fromUserId: number): string?
	if RunService:IsStudio() then
		return text -- filter tidak berjalan di Studio
	end
	local ok, result = pcall(function()
		local filterResult = TextService:FilterStringAsync(text, fromUserId)
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)
	if ok then
		return result
	end
	warn("[AdminService] Gagal memfilter pengumuman:", result)
	return nil
end

local ACTIONS = {
	SetPortal = function(_admin: Player, stageId: any, isOpen: any)
		if typeof(stageId) ~= "string" or typeof(isOpen) ~= "boolean" then
			return
		end
		PortalService.SetOpen(stageId, isOpen)
	end,

	CloseAllPortals = function(_admin: Player)
		PortalService.CloseAll()
	end,

	RecallAll = function(_admin: Player)
		SpawnService.RecallAllToLobby()
		NotifyService.ToAll("🏠 Guru memanggil semua siswa kembali ke Lobby.", "info")
	end,

	ResetPoints = function(_admin: Player)
		PointsService.ResetAll()
		NotifyService.ToAll("♻️ Semua Poin direset oleh Guru. Ayo mulai lagi!", "info")
	end,

	SetMusic = function(_admin: Player, enabled: any)
		if typeof(enabled) ~= "boolean" then
			return
		end
		Remotes.GetState():SetAttribute("MusicEnabled", enabled)
		NotifyService.ToAll(if enabled then "🎵 Musik dinyalakan oleh Guru." else "🔇 Musik dimatikan oleh Guru.", "info")
	end,

	-- Papan Poin Kelas di layar semua siswa
	SetScoreboardVisible = function(_admin: Player, visible: any)
		if typeof(visible) ~= "boolean" then
			return
		end
		ProgressService.SetVisible(visible)
		if visible then
			NotifyService.ToAll("📊 Guru menampilkan Papan Poin Kelas!", "portal")
		end
	end,

	-- Dasar urutan papan: "Total" atau "Stage1".."Stage4"
	SetScoreboardMode = function(_admin: Player, mode: any)
		if typeof(mode) == "string" then
			ProgressService.SetMode(mode)
		end
	end,

	-- Minta seorang siswa mengetik ulang namanya (salah ketik / nama tidak pantas).
	RequestRename = function(admin: Player, userId: any)
		local student = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
		if not student then
			NotifyService.ToPlayer(admin, "⚠️ Siswa itu sudah keluar dari game.", "error")
			return
		end
		NameService.RequestRename(student)
		NotifyService.ToPlayer(admin, `✏️ {NameService.Get(student)} diminta mengganti nama.`, "info")
		NotifyService.ToPlayer(student, "✏️ Guru memintamu menulis ulang namamu.", "info")
	end,

	Announce = function(admin: Player, rawText: any)
		local text = cleanText(rawText)
		if not text then
			return
		end
		local filtered = filterForBroadcast(text, admin.UserId)
		if not filtered then
			NotifyService.ToPlayer(admin, "⚠️ Pengumuman gagal dikirim. Coba lagi.", "error")
			return
		end
		NotifyService.Announce(filtered, admin.DisplayName)
	end,
}

local function onAdminAction(player: Player, action: any, ...)
	if not AdminService.IsAdmin(player) then
		warn(`[AdminService] {player.Name} mencoba memakai Panel Guru tanpa izin.`)
		return
	end
	local now = os.clock()
	if (lastActionAt[player] or 0) + ACTION_COOLDOWN > now then
		return
	end
	lastActionAt[player] = now

	local handler = if typeof(action) == "string" then ACTIONS[action] else nil
	if handler then
		handler(player, ...)
	end
end

local function onPlayerAdded(player: Player)
	if initializedPlayers[player] then
		return
	end
	initializedPlayers[player] = true

	local isAdmin = checkAdmin(player)
	if player.Parent == nil then
		return
	end
	player:SetAttribute("IsAdmin", isAdmin)
	if not isAdmin then
		return
	end

	print(`[AdminService] {player.Name} masuk sebagai Guru (admin).`)
	if player.Character then
		task.spawn(addTeacherTag, player.Character)
	end
	player.CharacterAdded:Connect(addTeacherTag)
end

function AdminService.Start()
	Remotes.GetState():SetAttribute("MusicEnabled", true)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastActionAt[player] = nil
		initializedPlayers[player] = nil
	end)

	Remotes.Get("AdminAction").OnServerEvent:Connect(onAdminAction)
end

return AdminService
