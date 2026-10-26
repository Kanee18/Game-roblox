--[[
	ProgressService (ModuleScript)
	Lokasi: ServerScriptService > Services > ProgressService

	Mencatat Poin setiap siswa PER TAHAP dan tahap mana yang sudah selesai, lalu
	menyiapkan Papan Poin Kelas yang bisa ditampilkan Guru (lihat ScoreboardClient).
	  * Poin dihitung ke tahap tempat siswa berada saat Poin berubah
	  * Tahap dianggap selesai saat: Tahap 1 = sampai finish, Tahap 2 = sudah menjawab
	    sejumlah gelombang (GameConfig.Stage2.WavesToComplete), Tahap 3 = misi selesai,
	    Tahap 4 = mendarat di pulau
	  * Data untuk client di ReplicatedStorage > GameState:
	      Attribute "Scoreboard"        JSON daftar siswa (nama, Poin per tahap, selesai)
	      Attribute "ScoreboardVisible" true = papan tampil di layar semua siswa
	      Attribute "ScoreboardMode"    "Total" atau "Stage1".."Stage4" (dasar urutan papan)

		ProgressService.MarkComplete(player, "Stage1")  --> true jika baru saja selesai
		ProgressService.CountAnswer(player, "Stage2")   --> jumlah jawaban di tahap itu
		ProgressService.SetVisible(true)
		ProgressService.SetMode("Stage1")
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local NameService = require(script.Parent.NameService)
local PointsService = require(script.Parent.PointsService)
local SpawnService = require(script.Parent.SpawnService)

local CONFIG = GameConfig.Scoreboard

type StageRecord = { Points: number, Done: boolean, Answers: number }
type Record = {
	UserId: number,
	Name: string,
	Points: number,
	IsAdmin: boolean,
	JoinOrder: number,
	Stages: { [string]: StageRecord },
}

local ProgressService = {}

local state = Remotes.GetState()
local records: { [number]: Record } = {} -- UserId -> catatan (tetap ada saat siswa keluar)
local joinCounter = 0
local dirty = true

local function markDirty()
	dirty = true
end

local function newStages(): { [string]: StageRecord }
	local stages = {}
	for _, stage in GameConfig.Stages do
		stages[stage.Id] = { Points = 0, Done = false, Answers = 0 }
	end
	return stages
end

local function getRecord(player: Player): Record
	local record = records[player.UserId]
	if not record then
		joinCounter += 1
		record = {
			UserId = player.UserId,
			Name = NameService.Get(player),
			Points = 0,
			IsAdmin = false,
			JoinOrder = joinCounter,
			Stages = newStages(),
		}
		records[player.UserId] = record
	end
	return record
end

-- Tandai tahap selesai. Mengembalikan true hanya saat pertama kali selesai.
function ProgressService.MarkComplete(player: Player, stageId: string): boolean
	local stageRecord = getRecord(player).Stages[stageId]
	if not stageRecord or stageRecord.Done then
		return false
	end
	stageRecord.Done = true
	markDirty()
	return true
end

function ProgressService.IsComplete(player: Player, stageId: string): boolean
	local stageRecord = getRecord(player).Stages[stageId]
	return stageRecord ~= nil and stageRecord.Done
end

-- Menambah hitungan jawaban siswa di sebuah tahap, mengembalikan jumlah terbaru.
function ProgressService.CountAnswer(player: Player, stageId: string): number
	local stageRecord = getRecord(player).Stages[stageId]
	if not stageRecord then
		return 0
	end
	stageRecord.Answers += 1
	return stageRecord.Answers
end

function ProgressService.SetVisible(visible: boolean)
	state:SetAttribute("ScoreboardVisible", visible)
end

function ProgressService.SetMode(mode: string)
	if mode == "Total" or GameConfig.StageById[mode] then
		state:SetAttribute("ScoreboardMode", mode)
	end
end

local function publish()
	local list = {}
	for _, record in records do
		local player = Players:GetPlayerByUserId(record.UserId)
		if player then
			record.Name = NameService.Get(player)
			record.Points = PointsService.Get(player)
			record.IsAdmin = player:GetAttribute("IsAdmin") == true
		end
		local online = player ~= nil
		local hidden = record.IsAdmin and GameConfig.Admin.ExcludeFromLeaderboard
		if not hidden and (online or CONFIG.KeepLeftPlayers) then
			local stages = {}
			for index, stage in GameConfig.Stages do
				local stageRecord = record.Stages[stage.Id]
				stages[index] = { Points = stageRecord.Points, Done = stageRecord.Done }
			end
			table.insert(list, {
				UserId = record.UserId,
				Name = record.Name,
				Points = record.Points,
				Online = online,
				Order = record.JoinOrder,
				Stages = stages,
			})
		end
	end
	-- Urutan peringkat dihitung di client (sesuai mode Total / Tahap N).
	table.sort(list, function(a, b)
		return a.Order < b.Order
	end)
	state:SetAttribute("Scoreboard", HttpService:JSONEncode(list))
end

local function onPlayerAdded(player: Player)
	getRecord(player)
	player:GetAttributeChangedSignal("IsAdmin"):Connect(markDirty)
	markDirty()
end

function ProgressService.Start()
	state:SetAttribute("Scoreboard", "[]")
	state:SetAttribute("ScoreboardVisible", false)
	state:SetAttribute("ScoreboardMode", "Total")

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		-- Simpan Poin terakhir selagi leaderstats masih ada.
		getRecord(player).Points = PointsService.Get(player)
		markDirty()
	end)

	-- Poin masuk ke tahap tempat siswa berada (Poin dari Lobby hanya masuk Total).
	PointsService.Changed:Connect(function(player: Player, _newPoints: number, delta: number)
		local stageRecord = getRecord(player).Stages[SpawnService.GetArea(player)]
		if stageRecord then
			stageRecord.Points += delta
		end
		markDirty()
	end)

	-- Reset Semua Poin: catatan tahap ikut kosong, siswa yang sudah keluar dihapus.
	PointsService.AllReset:Connect(function()
		for userId, record in records do
			if Players:GetPlayerByUserId(userId) then
				record.Stages = newStages()
			else
				records[userId] = nil
			end
		end
		markDirty()
	end)

	NameService.Changed:Connect(markDirty)

	task.spawn(function()
		while true do
			task.wait(CONFIG.RefreshInterval)
			if dirty then
				dirty = false
				local ok, err = pcall(publish)
				if not ok then
					warn("[ProgressService] Gagal memperbarui Papan Poin:", err)
				end
			end
		end
	end)
end

return ProgressService
