--[[
	GameConfig (ModuleScript)
	Lokasi: ReplicatedStorage > Shared > GameConfig

	Semua pengaturan game ada di sini, jadi Guru tidak perlu membongkar
	script lain. Semua teks yang tampil di dalam game berbahasa Indonesia.
]]

local GameConfig = {}

GameConfig.GameTitle = "Petualangan Jaringan Komputer"
GameConfig.GameSubtitle = "Informatika Kelas 7 · Jaringan Komputer dan Internet"

--------------------------------------------------------------------------------
-- ADMIN (GURU)
--------------------------------------------------------------------------------
GameConfig.Admin = {
	-- UserId akun Roblox Guru. Cara melihatnya: buka profil Roblox,
	-- angka di URL adalah UserId (roblox.com/users/123456789/profile).
	UserIds = {
		-- 123456789,
	},

	-- Pemilik game (akun yang mempublikasikan game) otomatis menjadi admin.
	CreatorIsAdmin = true,

	-- Jika game dipublikasikan atas nama Group, isi GroupId dan rank minimal.
	GroupId = 0,
	GroupMinRank = 254,

	-- Khusus pengujian di Roblox Studio:
	--   * Play Solo    -> akunmu sendiri (UserId positif) otomatis admin.
	--   * Local Server -> pemain uji ber-UserId negatif (-1, -2, ...).
	--     Player1 (-1) dijadikan Guru, sisanya menjadi siswa.
	StudioTestAdminIds = { -1 },

	-- Guru tidak ikut tampil di Videotron / papan peringkat.
	ExcludeFromLeaderboard = true,
}

--------------------------------------------------------------------------------
-- POIN
--------------------------------------------------------------------------------
GameConfig.Points = {
	StatName = "Poin", -- nama kolom di daftar pemain (leaderstats)
	StartingPoints = 0,
	AllowNegative = false, -- false = Poin tidak bisa turun di bawah 0

	-- Nilai bawaan. Tiap tahap boleh memakai nilainya sendiri.
	CorrectAnswer = 10,
	WrongAnswer = -5,

	-- false = Poin hanya berlaku untuk sesi kelas ini (tetap aman jika siswa
	-- keluar lalu masuk lagi ke server yang sama).
	-- true  = Poin disimpan permanen dengan DataStore (wajib mengaktifkan
	-- "Enable Studio Access to API Services" untuk uji di Studio).
	SaveToDataStore = false,
	DataStoreName = "JarkomPoin_v1",
	AutoSaveInterval = 120, -- detik
}

--------------------------------------------------------------------------------
-- NAMA SISWA (diketik siswa saat pertama kali masuk game)
--------------------------------------------------------------------------------
GameConfig.StudentNames = {
	Enabled = true, -- false = tidak meminta nama (memakai nama tampilan Roblox)
	MinLength = 2,
	MaxLength = 20,
	RequiredForPortal = true, -- siswa yang belum mengisi nama tidak bisa masuk portal
	ShowInPlayerList = true, -- kolom "Nama" di daftar pemain Roblox (leaderstats)
	ShowAboveHead = true, -- nama tampil di atas kepala karakter
	StatName = "Nama",
}

--------------------------------------------------------------------------------
-- PAPAN POIN KELAS (ditampilkan Guru lewat Panel Guru)
--------------------------------------------------------------------------------
GameConfig.Scoreboard = {
	RefreshInterval = 1, -- detik
	KeepLeftPlayers = true, -- siswa yang keluar tetap tercantum (abu-abu) sampai Reset Poin
}

--------------------------------------------------------------------------------
-- PORTAL
--------------------------------------------------------------------------------
GameConfig.Portals = {
	OnlyOneOpen = true, -- membuka satu portal otomatis menutup portal lainnya
	StartOpen = false, -- semua portal tertutup saat server dimulai
	TouchCooldown = 2, -- detik
	ClosedColor = Color3.fromRGB(88, 92, 110),
}

-- Nama Attribute di ReplicatedStorage > GameState, contoh: "PortalOpen_Stage1"
GameConfig.PortalStatePrefix = "PortalOpen_"

--------------------------------------------------------------------------------
-- NAMA OBJEK DI WORKSPACE (harus sama persis dengan di Explorer)
--------------------------------------------------------------------------------
GameConfig.Names = {
	Lobby = "Lobby",
	Portals = "Portals",
	PortalGate = "Gate",
	PortalGlow = "Glow",
	Videotron = "Videotron",
	VideotronScreen = "Screen",
	VideotronPodium = "Podium",
	Stages = "Stages",
	StageSpawn = "Spawn",
	ReturnToLobby = "ReturnToLobby",
	Lava = "Lava", -- part di dalam Stages: menyentuhnya = gugur (respawn di checkpoint)
	FallZone = "FallZone", -- part tak terlihat di bawah peta: jatuh = kembali ke checkpoint
}

--------------------------------------------------------------------------------
-- TAHAP (4 PORTAL ELEMEN)
--------------------------------------------------------------------------------
GameConfig.Stages = {
	{
		Id = "Stage1",
		Number = 1,
		Title = "Routing Runner",
		Element = "Tanah",
		ElementIcon = "⛰️",
		Materi = "Dasar Jaringan & LAN/WAN",
		Description = "Lewati rintangan parkour dan masuki pintu jawaban yang benar!",
		Color = Color3.fromRGB(255, 196, 77),
	},
	{
		Id = "Stage2",
		Number = 2,
		Title = "Firewall Defender",
		Element = "Api",
		ElementIcon = "🔥",
		Materi = "Keamanan Data & Virus",
		Description = "Tembak monster yang membawa jawaban benar untuk melindungi jaringan!",
		Color = Color3.fromRGB(255, 102, 64),
	},
	{
		Id = "Stage3",
		Number = 3,
		Title = "Cable Labyrinth",
		Element = "Petir",
		ElementIcon = "⚡",
		Materi = "Perangkat Keras Jaringan",
		Description = "Temukan perangkat jaringan yang diminta di dalam labirin motherboard!",
		Color = Color3.fromRGB(176, 112, 255),
	},
	{
		Id = "Stage4",
		Number = 4,
		Title = "Bandwidth Glider",
		Element = "Angin",
		ElementIcon = "🍃",
		Materi = "Kecepatan Internet & Koneksi",
		Description = "Terbang melewati cincin jawaban yang benar untuk mendapat dorongan kecepatan!",
		Color = Color3.fromRGB(88, 228, 196),
	},
}

GameConfig.StageById = {}
for _, stage in GameConfig.Stages do
	GameConfig.StageById[stage.Id] = stage
end

-- Tahap 1 · Routing Runner (soal ada di ServerScriptService > QuizBank)
GameConfig.Stage1 = {
	CorrectPoints = 10, -- masuk pintu benar
	WrongPoints = -5, -- masuk pintu salah (pemain juga gugur)
	FinishBonus = 25, -- menyentuh garis finish setelah semua gerbang dilewati
	FinishBonusOncePerSession = true, -- bonus finish hanya sekali per sesi kelas
	DoorCooldown = 1, -- detik, mencegah satu langkah terhitung dua kali
}

-- Tahap 2 · Firewall Defender
GameConfig.Stage2 = {
	ToolName = "TongkatFirewall", -- senjata yang dibagikan saat masuk tahap ini

	CorrectPoints = 10, -- tembakan pertama mengenai virus pembawa jawaban benar
	SpeedBonusMax = 5, -- bonus tambahan untuk penjawab cepat
	SpeedBonusWindow = 15, -- detik; bonus berkurang sampai 0 dalam waktu ini
	WrongPoints = -5, -- tembakan pertama mengenai virus pembawa jawaban salah

	MonstersPerWave = 4, -- 1 jawaban benar + 3 jawaban salah
	MonsterSpeed = 7, -- stud per detik pada gelombang 1
	SpeedPerWave = 0.4, -- virus makin cepat setiap gelombang
	MaxMonsterSpeed = 12,
	SpawnStagger = 1.5, -- detik; virus muncul tidak bersamaan

	CoreMaxHP = 5, -- nyawa Inti Server (milik seluruh kelas)
	CoreMinCorrectRatio = 0.5, -- jika siswa yang benar < 50%, Inti Server -1

	IntermissionTime = 4, -- jeda sebelum gelombang berikutnya
	RevealTime = 8, -- lama pengumuman jawaban
	MaxWaveTime = 60, -- batas waktu satu gelombang
	FireCooldown = 0.25, -- detik antar tembakan
	MaxRange = 350, -- jarak tembak maksimal (stud)
	LabelHeight = 7, -- tinggi label jawaban di atas virus (stud)
	-- Bantuan membidik: ketukan/klik sejauh ini (piksel) dari virus atau labelnya tetap
	-- dihitung mengenai virus itu. Di HP lebih besar karena jari menutupi sasaran.
	AimAssistTouch = 90,
	AimAssistMouse = 40,
	-- Tahap 2 tidak punya garis finish: dianggap selesai setelah menjawab sekian gelombang.
	WavesToComplete = 5,
}

-- Tahap 3 · Cable Labyrinth
GameConfig.Stage3 = {
	CorrectPoints = 15, -- membawa perangkat yang tepat ke Mesin Pusat
	WrongPoints = -5, -- membawa perangkat yang salah
	MissionGoal = 6, -- jumlah pengiriman benar untuk menyelesaikan misi
	MissionBonus = 25,
	MissionBonusOncePerSession = true,
	PickupCooldown = 1, -- detik

	-- Daftar perangkat di labirin. Id dipakai di QuizBank.Stage3 (Correct = Id)
	-- dan di Attribute "ItemId" pada setiap ItemStation.
	Items = {
		{ Id = "Router", Name = "Router", Icon = "📡", Color = Color3.fromRGB(255, 120, 80) },
		{ Id = "Switch", Name = "Switch", Icon = "🔀", Color = Color3.fromRGB(90, 170, 255) },
		{ Id = "Hub", Name = "Hub", Icon = "🔘", Color = Color3.fromRGB(225, 205, 130) },
		{ Id = "Modem", Name = "Modem", Icon = "📟", Color = Color3.fromRGB(245, 245, 255) },
		{ Id = "AccessPoint", Name = "Access Point", Icon = "📶", Color = Color3.fromRGB(120, 230, 255) },
		{ Id = "KabelUTP", Name = "Kabel UTP", Icon = "🔵", Color = Color3.fromRGB(70, 120, 255) },
		{ Id = "RJ45", Name = "Konektor RJ-45", Icon = "🔌", Color = Color3.fromRGB(200, 240, 255) },
		{ Id = "FiberOptik", Name = "Kabel Fiber Optik", Icon = "💡", Color = Color3.fromRGB(255, 170, 40) },
		{ Id = "NIC", Name = "NIC (Kartu Jaringan)", Icon = "💳", Color = Color3.fromRGB(80, 210, 120) },
		{ Id = "Coaxial", Name = "Kabel Coaxial", Icon = "📺", Color = Color3.fromRGB(160, 160, 175) },
		{ Id = "Server", Name = "Server", Icon = "🗄️", Color = Color3.fromRGB(176, 112, 255) },
	},
}

-- Tahap 4 · Bandwidth Glider
GameConfig.Stage4 = {
	CorrectPoints = 10, -- terbang melewati cincin jawaban benar
	WrongPoints = -5, -- melewati cincin jawaban salah
	FinishBonus = 25, -- mendarat di pulau akhir
	FinishBonusOncePerSession = true,

	BaseSpeed = 32, -- kecepatan maju (stud/detik), tampil sebagai "32 Mbps"
	SteerSpeed = 20, -- belok kiri/kanan
	ClimbSpeed = 12, -- naik/turun
	BoostMultiplier = 1.7, -- jawaban benar: Speed Boost
	SlowMultiplier = 0.5, -- jawaban salah / terlewat: lemot
	EffectDuration = 3, -- detik

	MissMargin = 25, -- stud melewati bidang gerbang tanpa masuk cincin = terlewat
}

--------------------------------------------------------------------------------
-- VIDEOTRON (PAPAN PERINGKAT RAKSASA)
--------------------------------------------------------------------------------
GameConfig.Videotron = {
	Title = "🏆 JUARA SEMENTARA 🏆",
	Subtitle = "Papan Peringkat · Jaringan Komputer dan Internet",
	ShowTop = 5, -- juara 1 + peringkat 2 s.d. 5 (maksimal 5)
	RefreshInterval = 1, -- detik
	TickerPrefix = "💡 Tahukah kamu? ",
	TickerSpeed = 170, -- piksel per detik
	Facts = {
		"LAN (Local Area Network) menghubungkan perangkat di area kecil, misalnya lab komputer sekolah.",
		"WAN (Wide Area Network) mencakup wilayah sangat luas. Internet adalah contoh WAN terbesar!",
		"Router bertugas mengarahkan data agar sampai ke jaringan tujuan.",
		"Switch menghubungkan banyak komputer dalam satu jaringan LAN.",
		"Modem membantu perangkat di rumah terhubung ke penyedia layanan Internet (ISP).",
		"Kabel UTP memakai konektor RJ-45 untuk menghubungkan komputer ke jaringan.",
		"Wi-Fi, Bluetooth, dan jaringan seluler (4G/5G) adalah contoh koneksi nirkabel.",
		"Kecepatan internet diukur dalam bps (bit per detik), misalnya 20 Mbps.",
		"Kata sandi yang kuat memadukan huruf besar, huruf kecil, angka, dan simbol.",
		"Enkripsi mengubah data menjadi kode rahasia agar tidak bisa dibaca orang lain.",
		"Jangan sembarangan mengklik tautan atau mengunduh file dari orang yang tidak dikenal!",
		"Firewall menyaring lalu lintas data untuk melindungi jaringan dari ancaman.",
	},
}

--------------------------------------------------------------------------------
-- AUDIO (musik latar & efek suara) — lihat docs/07-audio.md
--------------------------------------------------------------------------------
GameConfig.Audio = {
	MusicVolume = 0.35,
	SfxVolume = 0.7,
	CrossfadeTime = 1.5, -- detik, perpindahan musik antar-area

	-- Musik latar per area. Isi dengan ID audio dari Creator Store (Toolbox > Audio),
	-- contoh: "rbxassetid://1234567890" atau cukup angkanya: 1234567890.
	-- Kosong ("") = memakai melodi kotak-musik bawaan (lihat FallbackMusic).
	Music = {
		Lobby = "", -- kata kunci: "fantasy village", "peaceful adventure"
		Stage1 = "", -- "adventure upbeat", "platformer"
		Stage2 = "", -- "epic battle", "action drums"
		Stage3 = "", -- "electronic puzzle", "synth mystery"
		Stage4 = "", -- "uplifting sky", "flying orchestral"
	},
	-- true = jika ID musik kosong atau gagal dimuat, mainkan melodi lembut dari
	-- suara bawaan Roblox (tidak perlu ID apa pun). false = hening.
	FallbackMusic = true,

	-- Efek suara. Bawaan memakai file suara yang sudah ada di setiap client Roblox
	-- (rbxasset://sounds/...), jadi langsung berbunyi tanpa perlu ID.
	-- Boleh diganti dengan "rbxassetid://ID" dari Creator Store.
	-- Speed = PlaybackSpeed (nada), Volume dikalikan SfxVolume.
	Sfx = {
		Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5 },
		Notify = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.3, Speed = 1.2 },
		Error = { Id = "rbxasset://sounds/button.wav", Volume = 0.6, Speed = 0.8 },
		Announcement = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.9, Speed = 0.8 },
		Correct = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8, Speed = 1.25 },
		Wrong = { Id = "rbxasset://sounds/collide.wav", Volume = 0.7, Speed = 0.7 },
		Success = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Speed = 1.0 },
		Fanfare = { Id = "rbxasset://sounds/victory.wav", Volume = 0.8 },
		PortalOpen = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.6 },
		Teleport = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.7 },
		Shoot = { Id = "rbxasset://sounds/Rocket shot.wav", Volume = 0.35, Speed = 1.5 },
		CoreHit = { Id = "rbxasset://sounds/collide.wav", Volume = 0.9, Speed = 0.45 },
		Pickup = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.5, Speed = 1.3 },
		Launch = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.8, Speed = 0.8 },
		Boost = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.6, Speed = 1.3 },
		Slow = { Id = "rbxasset://sounds/collide.wav", Volume = 0.6, Speed = 0.5 },
		Land = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.8 },
		WindLoop = { Id = "rbxasset://sounds/action_falling.mp3", Volume = 0.35 },
		Chime = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.2 }, -- nada melodi kotak-musik
	},
}

--------------------------------------------------------------------------------
-- TEMA UI (gaya fantasi/anime: panel krem + aksen emas)
--------------------------------------------------------------------------------
GameConfig.Theme = {
	Font = Enum.Font.FredokaOne, -- judul
	FontBody = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,

	Cream = Color3.fromRGB(246, 241, 229),
	CreamDark = Color3.fromRGB(225, 214, 192),
	Gold = Color3.fromRGB(222, 189, 120),
	GoldBright = Color3.fromRGB(255, 212, 110),
	Ink = Color3.fromRGB(59, 66, 87),
	InkSoft = Color3.fromRGB(112, 118, 138),
	Night = Color3.fromRGB(22, 26, 46),
	White = Color3.fromRGB(255, 255, 255),
	Success = Color3.fromRGB(96, 206, 120),
	SuccessDark = Color3.fromRGB(40, 150, 76),
	Danger = Color3.fromRGB(240, 92, 92),
	Info = Color3.fromRGB(116, 184, 255),
}

return GameConfig
