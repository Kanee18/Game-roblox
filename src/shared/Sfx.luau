--[[
	Sfx (ModuleScript)
	Lokasi: ReplicatedStorage > Shared > Sfx

	Pemutar efek suara untuk LocalScript (suara hanya terdengar oleh pemain itu).
	Daftar suara ada di GameConfig.Audio.Sfx.

		Sfx.Play("Correct")              -- sekali
		Sfx.Play("Chime", 1.5)           -- dengan nada (PlaybackSpeed) lain
		local wind = Sfx.Loop("WindLoop") -- berulang; hentikan dengan wind:Destroy()
]]

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local GameConfig = require(script.Parent.GameConfig)

local CONFIG = GameConfig.Audio

local Sfx = {}

local folder = SoundService:FindFirstChild("EfekSuara")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "EfekSuara"
	folder.Parent = SoundService
end

local templates: { [string]: Sound } = {}

local function normalizeId(id: any): string
	if typeof(id) == "number" then
		return "rbxassetid://" .. id
	end
	if typeof(id) == "string" and string.match(id, "^%d+$") then
		return "rbxassetid://" .. id
	end
	return if typeof(id) == "string" then id else ""
end
Sfx.NormalizeId = normalizeId

local function getTemplate(name: string): Sound?
	local cached = templates[name]
	if cached then
		return cached
	end
	local definition = CONFIG.Sfx[name]
	local id = definition and normalizeId(definition.Id) or ""
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = (definition.Volume or 1) * CONFIG.SfxVolume
	sound.PlaybackSpeed = definition.Speed or 1
	sound.Parent = folder
	templates[name] = sound
	return sound
end

-- Mainkan suara sekali. speed/volumeScale opsional.
function Sfx.Play(name: string, speed: number?, volumeScale: number?)
	local template = getTemplate(name)
	if not template then
		return
	end
	local sound = template:Clone()
	if speed then
		sound.PlaybackSpeed = speed
	end
	if volumeScale then
		sound.Volume *= volumeScale
	end
	sound.Parent = folder
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	-- Jaga-jaga jika suara gagal dimuat dan Ended tidak pernah terpicu.
	task.delay(15, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Suara berulang (mis. angin saat terbang). Hentikan dengan :Destroy().
function Sfx.Loop(name: string): Sound?
	local template = getTemplate(name)
	if not template then
		return nil
	end
	local sound = template:Clone()
	sound.Looped = true
	sound.Parent = folder
	sound:Play()
	return sound
end

-- Muat semua efek suara lebih awal dan laporkan yang gagal di jendela Output.
function Sfx.Preload()
	local sounds = {}
	for name in CONFIG.Sfx do
		local template = getTemplate(name)
		if template then
			table.insert(sounds, template)
		end
	end
	ContentProvider:PreloadAsync(sounds, function(contentId, status)
		if status ~= Enum.AssetFetchStatus.Success then
			warn(`[Audio] Efek suara gagal dimuat: {contentId} ({status.Name}). Ganti ID-nya di GameConfig.Audio.Sfx.`)
		end
	end)
end

return Sfx
