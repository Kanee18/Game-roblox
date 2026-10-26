--[[
	NotifyService (ModuleScript)
	Lokasi: ServerScriptService > Services > NotifyService

	Mengirim notifikasi ke layar pemain (ditampilkan oleh HudClient).
		NotifyService.ToPlayer(player, "Halo!", "success")
		NotifyService.ToAll("Portal dibuka!", "portal")
	Jenis (kind): "info" | "success" | "error" | "portal"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local NotifyService = {}

local notifyRemote = Remotes.Get("Notify")
local announcementRemote = Remotes.Get("Announcement")

function NotifyService.ToPlayer(player: Player, text: string, kind: string?)
	notifyRemote:FireClient(player, text, kind or "info")
end

function NotifyService.ToAll(text: string, kind: string?)
	notifyRemote:FireAllClients(text, kind or "info")
end

-- Pengumuman besar di tengah layar. Teks HARUS sudah difilter (lihat AdminService).
function NotifyService.Announce(text: string, fromName: string)
	announcementRemote:FireAllClients(text, fromName)
end

function NotifyService.Start() end

return NotifyService
