--[[
	BuildWorld.luau — OPSIONAL: bangun dunia di MODE EDIT lewat Command Bar.

	Dunia game (pencahayaan, Lobby, 4 portal, Videotron, Tahap 1–4) sekarang
	DIBANGUN OTOMATIS setiap kali game dimulai jika belum ada. Jadi file ini
	tidak wajib dijalankan.

	Pakai file ini jika ingin MELIHAT dan MENGHIAS dunia di Studio, lalu
	MENYIMPANNYA ke place (setelah disimpan, pembangun otomatis tidak
	menyentuhnya lagi).

	Syarat : skrip proyek sudah terpasang (ServerScriptService > World).
	Cara   : pastikan TIDAK sedang Play (tekan Stop dulu), buka View > Command Bar,
	         tempel SELURUH isi file ini, tekan Enter, lalu simpan dengan Ctrl+S.
	Ulang  : untuk membangun ulang satu tahap, hapus Workspace > Stages > StageN
	         lalu jalankan file ini lagi.
]]

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

if RunService:IsRunning() then
	warn("[BuildWorld] Game sedang berjalan. Tekan Stop dulu, lalu jalankan lagi di mode edit — bangunan yang dibuat saat Play akan hilang.")
	return
end

local world = ServerScriptService:FindFirstChild("World")
local buildAll = world and world:FindFirstChild("BuildAll")
if not buildAll then
	warn("[BuildWorld] ServerScriptService > World > BuildAll belum ada. Pasang skrip proyek dulu (lihat README).")
	return
end

local count = require(buildAll).EnsureWorld()
if count > 0 then
	print(`✅ [BuildWorld] {count} bagian dunia dibangun. Simpan place dengan Ctrl+S!`)
else
	print("✅ [BuildWorld] Semua bagian dunia sudah ada, tidak ada yang diubah.")
end
