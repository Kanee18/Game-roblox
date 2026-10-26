--[[
	Main (Script)
	Lokasi: ServerScriptService > Main

	Satu-satunya Script server. Menyalakan semua sistem inti secara berurutan,
	lalu menyalakan setiap ModuleScript di folder Services > Stages
	(diisi pada langkah Tahap 1-4).
]]

local Services = script.Parent:WaitForChild("Services")

-- Urutan penting: layanan di bawah boleh memakai layanan di atasnya.
local CORE_ORDER = {
	"NotifyService",
	"PointsService",
	"SpawnService",
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
