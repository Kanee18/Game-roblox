--[[
	Main (Script)
	Lokasi: ServerScriptService > Main

	Satu-satunya Script server:
	  1. Membangun dunia yang belum ada (World > BuildAll), sebelum pemain dimunculkan.
	  2. Menyalakan semua sistem inti secara berurutan.
	  3. Menyalakan setiap ModuleScript di folder Services > Stages.
]]

local Players = game:GetService("Players")

local Services = script.Parent:WaitForChild("Services")

--------------------------------------------------------------------------------
-- 1) Dunia: bangun otomatis jika belum ada (misalnya place baru dari `rojo build`).
--    Pemain ditahan dulu supaya tidak muncul di udara kosong lalu jatuh.
--------------------------------------------------------------------------------
local worldFolder = script.Parent:FindFirstChild("World")
local builder = worldFolder and worldFolder:FindFirstChild("BuildAll")
if builder and builder:IsA("ModuleScript") then
	local autoLoad = Players.CharacterAutoLoads
	Players.CharacterAutoLoads = false
	local builtCount = 0
	local ok, err = pcall(function()
		builtCount = require(builder).EnsureWorld()
	end)
	if not ok then
		warn(`[Main] ❌ Gagal membangun dunia: {err}`)
	end
	Players.CharacterAutoLoads = autoLoad
	if autoLoad then
		for _, player in Players:GetPlayers() do
			-- Munculkan di Lobby: yang belum punya karakter, atau yang sempat muncul
			-- sebelum dunianya selesai dibangun.
			if not player.Character or builtCount > 0 then
				task.spawn(player.LoadCharacter, player)
			end
		end
	end
else
	warn("[Main] ServerScriptService > World > BuildAll tidak ditemukan: dunia tidak dibangun otomatis.")
end

--------------------------------------------------------------------------------
-- 2) Sistem inti & 3) tahap
--------------------------------------------------------------------------------

-- Urutan penting: layanan di bawah boleh memakai layanan di atasnya.
local CORE_ORDER = {
	"NotifyService",
	"PointsService",
	"SpawnService",
	"NameService",
	"ProgressService",
	"PortalService",
	"AdminService",
	"VideotronService",
}

local function startModule(moduleScript: ModuleScript)
	local ok, err = pcall(function()
		local service = require(moduleScript)
		if type(service) == "table" and type(service.Start) == "function" then
			service.Start()
		end
	end)
	if ok then
		print(`[Main] ✅ {moduleScript.Name} aktif`)
	else
		warn(`[Main] ❌ {moduleScript.Name} gagal dimulai: {err}`)
	end
end

for _, serviceName in CORE_ORDER do
	local moduleScript = Services:FindFirstChild(serviceName)
	if moduleScript and moduleScript:IsA("ModuleScript") then
		startModule(moduleScript)
	else
		warn(`[Main] ModuleScript "{serviceName}" tidak ditemukan di ServerScriptService > Services`)
	end
end

local stagesFolder = Services:FindFirstChild("Stages")
if stagesFolder then
	for _, moduleScript in stagesFolder:GetChildren() do
		if moduleScript:IsA("ModuleScript") then
			startModule(moduleScript)
		end
	end
end
