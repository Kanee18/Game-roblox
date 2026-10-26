--[[
	Remotes (ModuleScript)
	Lokasi: ReplicatedStorage > Shared > Remotes

	Server membuat semua RemoteEvent secara otomatis saat game berjalan;
	client cukup menunggu. Kamu TIDAK perlu membuat RemoteEvent manual.

	Saat game berjalan, akan muncul:
		ReplicatedStorage > RemoteEvents (Folder berisi RemoteEvent)
		ReplicatedStorage > GameState    (Folder berisi Attribute status game)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

-- Remote inti. Tahap 1-4 nanti cukup memanggil Remotes.Get("NamaBaru")
-- dari server; remote baru otomatis dibuat.
local CORE_REMOTES = {
	"Notify", -- server -> client: notifikasi kecil (toast)
	"PointsPopup", -- server -> client: animasi "+10 Poin"
	"Announcement", -- server -> semua client: pengumuman dari Guru
	"AdminAction", -- client (Guru) -> server: perintah dari Panel Guru
}

local Remotes = {}

local function getOrCreate(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local remoteFolder: Instance
local stateFolder: Instance

if IS_SERVER then
	remoteFolder = getOrCreate(ReplicatedStorage, "Folder", "RemoteEvents")
	stateFolder = getOrCreate(ReplicatedStorage, "Folder", "GameState")
	for _, name in CORE_REMOTES do
		getOrCreate(remoteFolder, "RemoteEvent", name)
	end
else
	remoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
	stateFolder = ReplicatedStorage:WaitForChild("GameState")
end

function Remotes.Get(name: string): RemoteEvent
	if IS_SERVER then
		return getOrCreate(remoteFolder, "RemoteEvent", name) :: RemoteEvent
	end
	return remoteFolder:WaitForChild(name) :: RemoteEvent
end

-- Folder berisi Attribute status game (portal terbuka, papan peringkat, dll).
function Remotes.GetState(): Folder
	return stateFolder :: Folder
end

return Remotes
