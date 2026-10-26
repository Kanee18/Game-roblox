--[[
	BuildAll (ModuleScript)
	Lokasi: ServerScriptService > World > BuildAll

	Membangun bagian dunia yang BELUM ADA: pencahayaan, Lobby, dan Tahap 1–4.
	Dipanggil otomatis oleh Main saat server mulai, jadi place baru (misalnya hasil
	`rojo build`, atau Baseplate kosong) langsung bisa dimainkan tanpa langkah manual.

	Bagian yang sudah ada TIDAK diubah, jadi hiasan buatan Guru tetap aman.
	Untuk membangun ulang satu tahap: hapus Workspace > Stages > StageN, lalu Play lagi
	(atau jalankan tools/BuildWorld.luau di mode edit dan simpan dengan Ctrl+S).
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local BuildAll = {}

-- Tahap dianggap sudah dibangun jika folder-nya punya objek penanda ini.
local STAGES = {
	{ Id = "Stage1", Marker = "Sections", Builder = "BuildStage1" },
	{ Id = "Stage2", Marker = "Lanes", Builder = "BuildStage2" },
	{ Id = "Stage3", Marker = "Machine", Builder = "BuildStage3" },
	{ Id = "Stage4", Marker = "Gates", Builder = "BuildStage4" },
}

local function run(builderName: string, ...): boolean
	local args = table.pack(...)
	local ok, result = pcall(function()
		return require(script.Parent:WaitForChild(builderName)).Build(table.unpack(args, 1, args.n))
	end)
	if not ok then
		warn(`[World] {builderName} gagal: {result}`)
		return false
	end
	return result == true
end

-- Baseplate & SpawnLocation bawaan template Studio menutupi pulau Lobby dan
-- membuat pemain muncul di tempat yang salah, jadi dibuang saat Lobby dibangun.
local function removeTemplateDefaults()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
		print("[World] Baseplate bawaan template dihapus (digantikan pulau Lobby).")
	end
	local spawnLocation = workspace:FindFirstChild("SpawnLocation")
	if spawnLocation and spawnLocation:IsA("SpawnLocation") then
		spawnLocation:Destroy()
		print("[World] SpawnLocation bawaan template dihapus (pemain muncul di Lobby).")
	end
end

-- Mengembalikan jumlah bagian yang baru dibangun.
function BuildAll.EnsureWorld(): number
	local built = 0
	local running = RunService:IsRunning()

	if Lighting:GetAttribute("JarkomLighting") ~= true and run("SetupLighting", running) then
		built += 1
	end

	if not workspace:FindFirstChild("Lobby") then
		removeTemplateDefaults()
		if run("BuildLobby") then
			built += 1
		end
	end

	for _, stage in STAGES do
		local stages = workspace:FindFirstChild("Stages")
		local folder = stages and stages:FindFirstChild(stage.Id)
		if not (folder and folder:FindFirstChild(stage.Marker)) and run(stage.Builder) then
			built += 1
		end
	end

	if built > 0 and running then
		print(`🌍 [World] {built} bagian dunia dibangun otomatis untuk sesi ini. Ingin menghias & menyimpannya? Jalankan tools/BuildWorld.luau di mode edit.`)
	end
	return built
end

return BuildAll
