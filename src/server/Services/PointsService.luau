--[[
	PointsService (ModuleScript)
	Lokasi: ServerScriptService > Services > PointsService

	Sistem Poin global. Membuat leaderstats "Poin" untuk setiap pemain.
	Poin HANYA diubah di server, jadi tidak bisa dicurangi dari client.

	Dipakai oleh tahap-tahap game:
		PointsService.Add(player, 10, "Jawaban benar!")
		PointsService.Add(player, -5, "Jawaban salah")
		PointsService.Get(player)
		PointsService.Changed:Connect(function(player, poinBaru, selisih) end)
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CONFIG = GameConfig.Points

local PointsService = {}

local changedEvent = Instance.new("BindableEvent")
-- Dipicu setiap Poin pemain berubah: (player, poinBaru, selisih)
PointsService.Changed = changedEvent.Event

local popupRemote = Remotes.Get("PointsPopup")

local sessionCache: { [number]: number } = {} -- UserId -> Poin terakhir (keluar-masuk server)
local lastChangedAt: { [Player]: number } = {} -- penentu urutan jika Poin seri
local isLoaded: { [Player]: boolean } = {} -- data aman untuk disimpan?

local dataStore: DataStore? = nil
if CONFIG.SaveToDataStore then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(CONFIG.DataStoreName)
	end)
	if ok then
		dataStore = result
	else
		warn("[PointsService] DataStore tidak tersedia, Poin tidak disimpan permanen:", result)
	end
end

local function getStat(player: Player): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(CONFIG.StatName)
	if stat and stat:IsA("IntValue") then
		return stat
	end
	return nil
end

local function clampPoints(value: number): number
	value = math.round(value)
	if not CONFIG.AllowNegative then
		value = math.max(0, value)
	end
	return value
end

local function dataKey(player: Player): string
	return "Poin_" .. player.UserId
end

-- Mengembalikan (berhasil, nilai). Berhasil + nil = pemain baru tanpa data.
local function loadSaved(player: Player): (boolean, number?)
	local store = dataStore
	if not store then
		return true, nil
	end
	for attempt = 1, 3 do
		local ok, result = pcall(store.GetAsync, store, dataKey(player))
		if ok then
			return true, if typeof(result) == "number" then result else nil
		end
		warn(`[PointsService] Gagal memuat Poin {player.Name} (percobaan {attempt}):`, result)
		task.wait(attempt)
	end
	return false, nil
end

local function save(player: Player)
	local store = dataStore
	local stat = getStat(player)
	-- Jangan menimpa data lama jika data pemain gagal dimuat.
	if not store or not stat or not isLoaded[player] then
		return
	end
	local value = stat.Value
	for attempt = 1, 3 do
		local ok, err = pcall(store.SetAsync, store, dataKey(player), value)
		if ok then
			return
		end
		warn(`[PointsService] Gagal menyimpan Poin {player.Name} (percobaan {attempt}):`, err)
		task.wait(attempt)
	end
end

local function setPoints(player: Player, newValue: number, reason: string?): number
	local stat = getStat(player)
	if not stat then
		return 0
	end
	local oldValue = stat.Value
	newValue = clampPoints(newValue)
	stat.Value = newValue

	local delta = newValue - oldValue
	if reason then
		popupRemote:FireClient(player, delta, reason)
	end
	if delta ~= 0 then
		lastChangedAt[player] = os.clock()
		changedEvent:Fire(player, newValue, delta)
	end
	return newValue
end

function PointsService.Get(player: Player): number
	local stat = getStat(player)
	return if stat then stat.Value else 0
end

-- amount boleh negatif. reason (opsional) tampil sebagai animasi di layar pemain.
function PointsService.Add(player: Player, amount: number, reason: string?): number
	return setPoints(player, PointsService.Get(player) + amount, reason)
end

function PointsService.Set(player: Player, value: number, reason: string?): number
	return setPoints(player, value, reason)
end

function PointsService.ResetAll()
	table.clear(sessionCache)
	for _, player in Players:GetPlayers() do
		setPoints(player, CONFIG.StartingPoints)
	end
end

-- Daftar pemain terurut dari Poin tertinggi. Jika seri, yang lebih dulu
-- mencapai Poin tersebut berada di atas.
function PointsService.GetLeaderboard(limit: number?)
	local entries = {}
	for _, player in Players:GetPlayers() do
		local stat = getStat(player)
		local hidden = GameConfig.Admin.ExcludeFromLeaderboard and player:GetAttribute("IsAdmin") == true
		if stat and not hidden then
			table.insert(entries, {
				Player = player,
				UserId = player.UserId,
				Name = player.Name,
				DisplayName = player.DisplayName,
				Points = stat.Value,
				ChangedAt = lastChangedAt[player] or math.huge,
			})
		end
	end
	table.sort(entries, function(a, b)
		if a.Points ~= b.Points then
			return a.Points > b.Points
		end
		if a.ChangedAt ~= b.ChangedAt then
			return a.ChangedAt < b.ChangedAt
		end
		return a.UserId < b.UserId
	end)
	if limit then
		for index = #entries, limit + 1, -1 do
			entries[index] = nil
		end
	end
	return entries
end

local function onPlayerAdded(player: Player)
	if player:FindFirstChild("leaderstats") then
		return
	end

	local cached = sessionCache[player.UserId]

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local stat = Instance.new("IntValue")
	stat.Name = CONFIG.StatName
	stat.Value = cached or CONFIG.StartingPoints
	stat.Parent = leaderstats
	leaderstats.Parent = player

	if cached ~= nil or not dataStore then
		isLoaded[player] = true
		return
	end

	local ok, saved = loadSaved(player)
	if player.Parent == nil then
		return
	end
	if ok then
		isLoaded[player] = true
		if saved then
			-- Tambahkan Poin yang mungkin sudah didapat selama proses memuat.
			setPoints(player, saved + (stat.Value - CONFIG.StartingPoints))
		end
	else
		warn(`[PointsService] Poin {player.Name} tidak akan disimpan sesi ini karena gagal dimuat.`)
	end
end

local function onPlayerRemoving(player: Player)
	local stat = getStat(player)
	if stat then
		sessionCache[player.UserId] = stat.Value
	end
	save(player)
	isLoaded[player] = nil
	lastChangedAt[player] = nil
end

function PointsService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	local store = dataStore
	if not store then
		return
	end

	task.spawn(function()
		while true do
			task.wait(CONFIG.AutoSaveInterval)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.5)
		end
	end)
end

return PointsService
