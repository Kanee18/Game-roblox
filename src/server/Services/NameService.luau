--[[
	NameService (ModuleScript)
	Lokasi: ServerScriptService > Services > NameService

	Nama siswa yang diketik di awal game (layar "Tulis namamu" dari NameClient).
	  * Diperiksa server: panjang, huruf yang boleh, tidak kembar dengan teman, dan
	    filter teks Roblox (wajib, karena nama dilihat pemain lain)
	  * Disimpan di Attribute pemain "StudentName", lalu dipakai Videotron, Papan Poin,
	    kolom "Nama" di daftar pemain, dan nama di atas kepala karakter
	  * Attribute "NeedsName" = true membuat layar isi nama muncul di layar siswa
	  * Keluar lalu masuk lagi ke server yang sama: nama tetap diingat

		NameService.Get(player)            --> "Budi Santoso" (atau nama Roblox jika belum diisi)
		NameService.HasName(player)        --> sudah mengisi nama? (Guru selalu true)
		NameService.RequestRename(player)  --> minta siswa mengetik ulang namanya
		NameService.Changed:Connect(function(player, namaBaru) end)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local NotifyService = require(script.Parent.NotifyService)

local CONFIG = GameConfig.StudentNames
local SUBMIT_COOLDOWN = 1.5

local NameService = {}

local changedEvent = Instance.new("BindableEvent")
-- Dipicu setiap nama siswa disimpan: (player, namaBaru)
NameService.Changed = changedEvent.Event

local resultRemote = Remotes.Get("NameResult")

local sessionCache: { [number]: string } = {} -- UserId -> nama (keluar-masuk server)
local lastSubmitAt: { [Player]: number } = {}

function NameService.Get(player: Player): string
	local name = player:GetAttribute("StudentName")
	return if typeof(name) == "string" and name ~= "" then name else player.DisplayName
end

function NameService.HasName(player: Player): boolean
	if not CONFIG.Enabled or player:GetAttribute("IsAdmin") == true then
		return true
	end
	local name = player:GetAttribute("StudentName")
	return typeof(name) == "string" and name ~= ""
end

function NameService.RequestRename(player: Player)
	if CONFIG.Enabled and player:GetAttribute("IsAdmin") ~= true then
		player:SetAttribute("NeedsName", true)
	end
end

--------------------------------------------------------------------------------
-- Menampilkan nama
--------------------------------------------------------------------------------
local function applyToCharacter(player: Player, character: Model)
	if not CONFIG.ShowAboveHead or typeof(player:GetAttribute("StudentName")) ~= "string" then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") and player.Parent then
		humanoid.DisplayName = NameService.Get(player)
	end
end

-- Kolom "Nama" di daftar pemain Roblox (di samping kolom Poin).
local function applyToPlayerList(player: Player)
	if not CONFIG.ShowInPlayerList then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", 10)
	if not leaderstats or player.Parent == nil then
		return
	end
	local existing = leaderstats:FindFirstChild(CONFIG.StatName)
	local stat: StringValue
	if existing and existing:IsA("StringValue") then
		stat = existing
	else
		stat = Instance.new("StringValue")
		stat.Name = CONFIG.StatName
		stat.Parent = leaderstats
	end
	stat.Value = NameService.Get(player)
end

local function setName(player: Player, name: string)
	player:SetAttribute("StudentName", name)
	player:SetAttribute("NeedsName", false)
	sessionCache[player.UserId] = name
	task.spawn(applyToPlayerList, player)
	if player.Character then
		task.spawn(applyToCharacter, player, player.Character)
	end
	changedEvent:Fire(player, name)
end

--------------------------------------------------------------------------------
-- Memeriksa nama
--------------------------------------------------------------------------------
-- Merapikan nama (spasi ganda dibuang, huruf awal tiap kata kapital) lalu memeriksa
-- aturannya. Mengembalikan (nama, nil) atau (nil, pesanKesalahan).
local function normalize(raw: any): (string?, string?)
	if typeof(raw) ~= "string" then
		return nil, "Nama tidak valid."
	end
	local text = raw:gsub("%c", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
	local length = utf8.len(text)
	if not length then
		return nil, "Nama berisi huruf yang tidak dikenal."
	end
	if length < CONFIG.MinLength then
		return nil, `Nama terlalu pendek (minimal {CONFIG.MinLength} huruf).`
	end
	if length > CONFIG.MaxLength then
		return nil, `Nama terlalu panjang (maksimal {CONFIG.MaxLength} huruf).`
	end
	if not text:match("^[%a%d%.%-' ]+$") then
		return nil, "Pakai huruf, angka, spasi, titik, atau tanda hubung saja."
	end
	local _, letters = text:gsub("%a", "")
	if letters < 2 then
		return nil, "Nama harus berisi huruf."
	end
	return (text:gsub("%f[%w]%a", string.upper)), nil
end

-- Nama yang sama (tanpa membedakan huruf besar/kecil) sudah dipakai siswa lain di sesi ini?
local function isTaken(name: string, player: Player): boolean
	local lower = string.lower(name)
	for userId, other in sessionCache do
		if userId ~= player.UserId and string.lower(other) == lower then
			return true
		end
	end
	return false
end

-- Aturan Roblox: teks dari pemain yang dilihat pemain lain WAJIB difilter.
-- Nama yang tersensor (berisi ###) ditolak supaya siswa memilih nama lain.
local function passesFilter(name: string, player: Player): (boolean, string?)
	if RunService:IsStudio() then
		return true, nil -- filter tidak berjalan di Studio
	end
	local ok, result = pcall(function()
		local filterResult = TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PublicChat)
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		warn("[NameService] Gagal memfilter nama:", result)
		return false, "Nama belum bisa diperiksa. Coba lagi sebentar, ya."
	end
	if result ~= name then
		return false, "Nama itu tidak bisa dipakai. Coba nama lain, ya."
	end
	return true, nil
end

local function onSubmit(player: Player, raw: any)
	-- Nama hanya bisa diisi saat diminta (awal game, atau diminta Guru), jadi siswa
	-- tidak bisa diam-diam mengganti nama menjadi nama temannya.
	if not CONFIG.Enabled or player:GetAttribute("NeedsName") ~= true then
		return
	end
	local now = os.clock()
	if (lastSubmitAt[player] or 0) + SUBMIT_COOLDOWN > now then
		resultRemote:FireClient(player, { Ok = false, Error = "Tunggu sebentar, lalu coba lagi." })
		return
	end
	lastSubmitAt[player] = now

	local name, problem = normalize(raw)
	if name then
		local ok, filterProblem = passesFilter(name, player)
		if not ok then
			name, problem = nil, filterProblem
		end
	end
	if name and isTaken(name, player) then
		problem = `Nama "{name}" sudah dipakai temanmu. Tambahkan inisial, misalnya "{name} A".`
		name = nil
	end
	if player.Parent == nil then
		return
	end
	if not name then
		resultRemote:FireClient(player, { Ok = false, Error = problem or "Nama tidak valid." })
		return
	end

	local isRename = typeof(player:GetAttribute("StudentName")) == "string"
	setName(player, name)
	resultRemote:FireClient(player, { Ok = true, Name = name })
	NotifyService.ToPlayer(
		player,
		if isRename then `✏️ Namamu sekarang: {name}` else `👋 Halo, {name}! Selamat bermain.`,
		"success"
	)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		applyToCharacter(player, character)
	end)
	if not CONFIG.Enabled then
		return
	end

	local cached = sessionCache[player.UserId]
	if cached then
		setName(player, cached)
		return
	end

	-- Guru tidak perlu mengisi nama. Status Guru bisa butuh sesaat (cek Group).
	local deadline = os.clock() + 15
	while player.Parent and player:GetAttribute("IsAdmin") == nil and os.clock() < deadline do
		task.wait(0.2)
	end
	if player.Parent and player:GetAttribute("IsAdmin") ~= true and not NameService.HasName(player) then
		player:SetAttribute("NeedsName", true)
	end
end

function NameService.Start()
	Remotes.Get("NameSubmit").OnServerEvent:Connect(onSubmit)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSubmitAt[player] = nil
	end)
end

return NameService
