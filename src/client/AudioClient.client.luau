--[[
	AudioClient (LocalScript)
	Lokasi: StarterPlayer > StarterPlayerScripts > AudioClient

	Musik latar untuk siswa ini:
	  * Lagu berganti otomatis sesuai area (Lobby, Tahap 1–4) dengan crossfade
	  * Jika ID musik di GameConfig.Audio.Music kosong atau gagal dimuat, dimainkan
	    melodi kotak-musik dari suara bawaan Roblox (tanpa perlu ID)
	  * Tombol 🔊/🔇 di samping jumlah Poin untuk mematikan musik sendiri
	  * Guru bisa mematikan musik untuk semua siswa dari Panel Guru
	  * Suara "wus" saat berpindah area
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local UiKit = require(Shared:WaitForChild("UiKit"))

local CONFIG = GameConfig.Audio
local Theme = GameConfig.Theme

local player = Players.LocalPlayer
local state = Remotes.GetState()

-- Melodi kotak-musik per area. Angka = nada (setengah-langkah dari nada dasar),
-- false = jeda. Pitch = nada dasar, Tempo = detik per ketukan.
local CHIME_SONGS = {
	Lobby = { Pitch = 1, Tempo = 0.5, Notes = { 0, 4, 7, 9, 7, 4, 2, false, 0, 2, 4, 7, 4, false, false, false, 9, 7, 4, 2, 4, 2, 0, false, false, false } },
	Stage1 = { Pitch = 1.12, Tempo = 0.3, Notes = { 0, 7, 12, 7, 4, 7, 12, 14, 12, 7, 4, 2, 0, false, 0, false } },
	Stage2 = { Pitch = 0.9, Tempo = 0.26, Notes = { 0, 3, 7, 3, 10, 7, 3, 0, 0, 3, 5, 7, 5, 3, false, false } },
	Stage3 = { Pitch = 1, Tempo = 0.2, Notes = { 0, 7, 12, 7, 3, 7, 10, 7, 0, 7, 12, 15, 12, 10, 7, false } },
	Stage4 = { Pitch = 1.25, Tempo = 0.42, Notes = { 0, 4, 9, 12, 9, 4, 7, 11, 14, 11, 7, false, 12, 9, 4, false } },
}

local personalMusicOn = true
local currentTrack: Sound? = nil
local currentTrackId: string? = nil
local chimeToken = 0
local chimeArea: string? = nil
local failedIds: { [string]: boolean } = {} -- ID musik yang gagal dimuat (tidak dicoba ulang)

local function currentArea(): string
	local area = player:GetAttribute("CurrentStage")
	return if typeof(area) == "string" then area else "Lobby"
end

local function musicAllowed(): boolean
	return personalMusicOn and state:GetAttribute("MusicEnabled") ~= false
end

local function stopChime()
	chimeToken += 1
	chimeArea = nil
end

local function playChime(area: string)
	if chimeArea == area then
		return -- sudah berjalan
	end
	stopChime()
	chimeArea = area
	local token = chimeToken
	local song = CHIME_SONGS[area] or CHIME_SONGS.Lobby
	task.spawn(function()
		while token == chimeToken do
			for _, note in song.Notes do
				if token ~= chimeToken then
					return
				end
				if note then
					Sfx.Play("Chime", song.Pitch * 2 ^ (note / 12))
				end
				task.wait(song.Tempo)
			end
		end
	end)
end

local function fadeOutTrack()
	local old = currentTrack
	currentTrack = nil
	currentTrackId = nil
	if old then
		UiKit.tween(old, CONFIG.CrossfadeTime, { Volume = 0 }).Completed:Connect(function()
			old:Destroy()
		end)
	end
end

local function playTrack(area: string, id: string)
	if id == currentTrackId then
		return
	end
	fadeOutTrack()
	local sound = Instance.new("Sound")
	sound.Name = "Musik_" .. area
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	UiKit.tween(sound, CONFIG.CrossfadeTime, { Volume = CONFIG.MusicVolume })
	currentTrack = sound
	currentTrackId = id

	-- Jika lagu gagal dimuat (ID salah / bukan audio publik), beri tahu dan pakai melodi bawaan.
	task.spawn(function()
		ContentProvider:PreloadAsync({ sound }, function(_, status)
			if status ~= Enum.AssetFetchStatus.Success then
				warn(`[Audio] Musik area "{area}" gagal dimuat ({id}, {status.Name}). Periksa GameConfig.Audio.Music.{area}.`)
				failedIds[id] = true
				if currentTrack == sound then
					fadeOutTrack()
					if CONFIG.FallbackMusic and musicAllowed() then
						playChime(area)
					end
				end
			end
		end)
	end)
end

local function refreshMusic()
	local area = currentArea()
	if not musicAllowed() then
		fadeOutTrack()
		stopChime()
		return
	end
	local id = Sfx.NormalizeId(CONFIG.Music[area])
	if id ~= "" and not failedIds[id] then
		stopChime()
		playTrack(area, id)
	else
		fadeOutTrack()
		if CONFIG.FallbackMusic then
			playChime(area)
		else
			stopChime()
		end
	end
end

--------------------------------------------------------------------------------
-- Tombol musik (di samping jumlah Poin)
--------------------------------------------------------------------------------
local gui = UiKit.new("ScreenGui", {
	Name = "TombolMusik",
	ResetOnSpawn = false,
	DisplayOrder = 6,
	Parent = player:WaitForChild("PlayerGui"),
})
local musicButton = UiKit.button({
	Name = "Musik",
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0.5, 123, 0, 8),
	Size = UDim2.fromOffset(52, 52),
	BackgroundColor3 = Theme.Night,
	BackgroundTransparency = 0.2,
	TextColor3 = Theme.White,
	TextSize = 24,
	Parent = gui,
}, { UiKit.corner(UDim.new(0.5, 0)), UiKit.stroke(Theme.Gold, 2) })

local function renderButton()
	if state:GetAttribute("MusicEnabled") == false then
		musicButton.Text = "🔇"
		musicButton.TextTransparency = 0.4
	else
		musicButton.Text = if personalMusicOn then "🔊" else "🔇"
		musicButton.TextTransparency = 0
	end
end

musicButton.Activated:Connect(function()
	Sfx.Play("Click")
	if state:GetAttribute("MusicEnabled") == false then
		return -- Guru sedang mematikan musik untuk semua
	end
	personalMusicOn = not personalMusicOn
	renderButton()
	refreshMusic()
end)

--------------------------------------------------------------------------------
local lastArea = player:GetAttribute("CurrentStage")
player:GetAttributeChangedSignal("CurrentStage"):Connect(function()
	local area = player:GetAttribute("CurrentStage")
	if lastArea ~= nil and area ~= lastArea then
		Sfx.Play("Teleport") -- tidak berbunyi saat pertama kali masuk game
	end
	lastArea = area
	refreshMusic()
end)
state:GetAttributeChangedSignal("MusicEnabled"):Connect(function()
	renderButton()
	refreshMusic()
end)

renderButton()
refreshMusic()
task.spawn(Sfx.Preload)
