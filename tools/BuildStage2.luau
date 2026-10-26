--[[
	BuildStage2.luau — jalankan SEKALI lewat Command Bar Roblox Studio
	(menu View > Command Bar, tempel SELURUH isi file ini, tekan Enter).
	Jalankan SETELAH BuildLobbySkeleton.luau.

	Membangun arena "Firewall Defender" di Workspace > Stages > Stage2:
	  * Benteng Firewall (tempat siswa berdiri) dengan dinding api
	  * Inti Server + rak server di belakang benteng
	  * Lapangan basal berlava dengan 4 Gerbang Virus dan 4 jalur virus berkelok
	  * Papan soal raksasa melayang di langit (SkyBoard)
	  * Anglo api, bara beterbangan, pagar tak terlihat, zona jatuh, pad ke Lobby

	Semua nama sudah cocok dengan script Stage2. Setelah dibangun, bebas
	menghias atau menggeser titik jalur (Lanes > LaneN > 1, 2, 3, ...).
]]

local DEFAULT_ORIGIN = Vector3.new(-1500, 61, 0) -- permukaan lantai lapangan

--------------------------------------------------------------------------------
-- Persiapan folder
--------------------------------------------------------------------------------
local stages = workspace:FindFirstChild("Stages")
if not stages then
	stages = Instance.new("Folder")
	stages.Name = "Stages"
	stages.Parent = workspace
end

local origin = DEFAULT_ORIGIN
local stage = stages:FindFirstChild("Stage2")
if stage then
	if stage:FindFirstChild("Lanes") then
		warn("[BuildStage2] Arena sudah ada. Hapus Workspace > Stages > Stage2 dulu jika ingin membangun ulang.")
		return
	end
	local SKELETON_PARTS = { Platform = true, Spawn = true, ReturnToLobby = true }
	for _, child in stage:GetChildren() do
		if not SKELETON_PARTS[child.Name] then
			warn(`[BuildStage2] Stage2 berisi "{child.Name}" yang bukan dari kerangka. Pindahkan atau hapus dulu agar tidak tertimpa.`)
			return
		end
	end
	local platform = stage:FindFirstChild("Platform")
	if platform and platform:IsA("BasePart") then
		origin = platform.Position + Vector3.new(0, platform.Size.Y / 2, 0)
	end
	stage:ClearAllChildren()
else
	stage = Instance.new("Folder")
	stage.Name = "Stage2"
	stage.Parent = stages
end

--------------------------------------------------------------------------------
-- Warna (tema elemen Api)
--------------------------------------------------------------------------------
local FIRE = Color3.fromRGB(255, 102, 64)
local EMBER = Color3.fromRGB(255, 196, 77)
local BASALT = Color3.fromRGB(58, 52, 60)
local OBSIDIAN = Color3.fromRGB(34, 28, 42)
local RAMPART = Color3.fromRGB(96, 88, 96)
local LAVA = Color3.fromRGB(255, 110, 40)
local VIRUS_PURPLE = Color3.fromRGB(170, 85, 255)
local CORE_CYAN = Color3.fromRGB(90, 220, 255)
local NIGHT = Color3.fromRGB(22, 26, 46)

--------------------------------------------------------------------------------
-- Pembantu
--------------------------------------------------------------------------------
local function make(className: string, props: { [string]: any }): any
	local instance: any = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

-- Koordinat relatif terhadap origin. Siswa menghadap -Z (ke arah datangnya virus).
local function at(x: number, y: number, z: number): Vector3
	return origin + Vector3.new(x, y, z)
end

local function slab(parent: Instance, name: string, x: number, top: number, z: number, size: Vector3, material: Enum.Material, color: Color3): Part
	return make("Part", {
		Name = name,
		Anchored = true,
		Size = size,
		CFrame = CFrame.new(at(x, top - size.Y / 2, z)),
		Material = material,
		Color = color,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Parent = parent,
	})
end

local function pillar(parent: Instance, name: string, x: number, top: number, z: number, diameter: number, height: number, material: Enum.Material, color: Color3): Part
	local part = make("Part", { Name = name, Anchored = true, Material = material, Color = color })
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = CFrame.new(at(x, top - height / 2, z)) * CFrame.Angles(0, 0, math.rad(90))
	part.Parent = parent
	return part
end

local function invisible(parent: Instance, name: string, position: Vector3, size: Vector3, collide: boolean): Part
	return make("Part", {
		Name = name,
		Anchored = true,
		CanCollide = collide,
		CanTouch = name == "FallZone",
		Transparency = 1,
		Size = size,
		CFrame = CFrame.new(position),
		Parent = parent,
	})
end

local function addFire(parent: BasePart, size: number)
	make("Fire", { Size = size, Heat = 9, Color = FIRE, SecondaryColor = EMBER, Parent = parent })
end

local function floatingLabel(parent: Instance, text: string, color: Color3, height: number)
	local billboard = make("BillboardGui", {
		Name = "Label",
		Size = UDim2.fromOffset(240, 56),
		StudsOffset = Vector3.new(0, height, 0),
		LightInfluence = 0,
		MaxDistance = 120,
		Parent = parent,
	})
	local label = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = NIGHT,
		BackgroundTransparency = 0.25,
		Text = text,
		TextColor3 = color,
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		Parent = billboard,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 12), Parent = label })
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = label })
end

--------------------------------------------------------------------------------
-- Lapangan & lava (z +45 .. -125)
--------------------------------------------------------------------------------
local arena = make("Folder", { Name = "Arena", Parent = stage })
slab(arena, "Lapangan", 0, 0, -40, Vector3.new(110, 2, 170), Enum.Material.Basalt, BASALT)

local rng = Random.new(77)
for _ = 1, 10 do
	-- Retakan lava di lapangan (hanya hiasan: virus melayang di atasnya)
	slab(arena, "RetakanLava", rng:NextNumber(-45, 45), 0.05, rng:NextNumber(-115, 30), Vector3.new(rng:NextNumber(1.5, 3), 0.2, rng:NextNumber(14, 34)), Enum.Material.Neon, LAVA)
end

-- Parit lava di sekeliling lapangan (berbahaya jika ada yang jatuh ke sana)
slab(arena, "Lava", -65, -1, -40, Vector3.new(20, 2, 190), Enum.Material.CrackedLava, LAVA)
slab(arena, "Lava", 65, -1, -40, Vector3.new(20, 2, 190), Enum.Material.CrackedLava, LAVA)
slab(arena, "Lava", 0, -1, -135, Vector3.new(150, 2, 20), Enum.Material.CrackedLava, LAVA)

-- Paku obsidian di luar parit
for i = 1, 28 do
	local side = if i % 2 == 0 then 1 else -1
	local height = rng:NextNumber(8, 22)
	make("Part", {
		Name = "PakuObsidian",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Size = Vector3.new(4, height, 4),
		CFrame = CFrame.new(at(side * rng:NextNumber(78, 95), height / 2 - 4, rng:NextNumber(-150, 60)))
			* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi), rng:NextNumber(-0.25, 0.25)),
		Material = Enum.Material.Basalt,
		Color = OBSIDIAN,
		Parent = arena,
	})
end

-- Bara api beterbangan di atas lapangan
local embers = invisible(arena, "Bara", at(0, 1, -40), Vector3.new(100, 1, 160), false)
make("ParticleEmitter", {
	Texture = "rbxasset://textures/particles/sparkles_main.dds",
	Color = ColorSequence.new(FIRE, EMBER),
	LightEmission = 1,
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
	Lifetime = NumberRange.new(4, 7),
	Speed = NumberRange.new(2, 5),
	SpreadAngle = Vector2.new(25, 25),
	EmissionDirection = Enum.NormalId.Top,
	Rate = 25,
	Parent = embers,
})

-- Anglo api di sudut lapangan
for _, spot in { { -52, -118 }, { 52, -118 }, { -52, -40 }, { 52, -40 }, { -52, 30 }, { 52, 30 } } do
	local base = pillar(arena, "Anglo", spot[1], 6, spot[2], 3, 6, Enum.Material.Basalt, OBSIDIAN)
	local bowl = slab(arena, "MangkukAnglo", spot[1], 7, spot[2], Vector3.new(4, 1, 4), Enum.Material.Metal, Color3.fromRGB(70, 60, 60))
	addFire(bowl, 6)
	make("PointLight", { Color = FIRE, Range = 18, Brightness = 2, Parent = base })
end

--------------------------------------------------------------------------------
-- Benteng Firewall (z +45 .. +101), tempat siswa berdiri
--------------------------------------------------------------------------------
local fort = make("Folder", { Name = "BentengFirewall", Parent = stage })
slab(fort, "Benteng", 0, 6, 73, Vector3.new(110, 8, 56), Enum.Material.Slate, RAMPART)
slab(fort, "Parapet", 0, 9, 45.75, Vector3.new(110, 3, 1.5), Enum.Material.Basalt, BASALT)
slab(fort, "Trim", 0, 9.4, 45.75, Vector3.new(110, 0.4, 1.7), Enum.Material.Neon, FIRE)

-- Dinding api di sepanjang parapet: inilah "firewall"-nya
for x = -50, 50, 10 do
	local holder = invisible(fort, "ApiFirewall", at(x, 9.5, 45.75), Vector3.new(2, 1, 2), false)
	addFire(holder, 7)
end

-- Pagar tak terlihat: siswa tetap di atas benteng
invisible(fort, "Barrier", at(0, 30, 45.2), Vector3.new(110, 48, 1), true)
invisible(fort, "Barrier", at(-56, 30, 73), Vector3.new(2, 48, 58), true)
invisible(fort, "Barrier", at(56, 30, 73), Vector3.new(2, 48, 58), true)
invisible(fort, "Barrier", at(0, 30, 102), Vector3.new(114, 48, 2), true)

make("Part", {
	Name = "Spawn", -- WAJIB: menghadap -Z, ke arah datangnya virus
	Anchored = true,
	Size = Vector3.new(8, 1, 8),
	CFrame = CFrame.new(at(0, 6.5, 62)),
	Material = Enum.Material.Neon,
	Color = FIRE,
	Parent = stage,
})

local returnPad = make("Part", {
	Name = "ReturnToLobby",
	Anchored = true,
	Size = Vector3.new(8, 1, 8),
	CFrame = CFrame.new(at(-44, 6.5, 64)),
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(255, 255, 255),
	Parent = fort,
})
floatingLabel(returnPad, "🏠 Kembali ke Lobby", Color3.fromRGB(255, 255, 255), 4)

--------------------------------------------------------------------------------
-- Inti Server (dilindungi) + rak server
--------------------------------------------------------------------------------
local core = make("Model", { Name = "Core", Parent = stage })
pillar(core, "Alas", 0, 10, 88, 14, 4, Enum.Material.Basalt, OBSIDIAN)
local crystalCFrame = CFrame.new(at(0, 17, 88)) * CFrame.Angles(math.rad(45), 0, math.rad(45))
make("Part", {
	Name = "Cangkang",
	Anchored = true,
	CanCollide = false,
	Size = Vector3.new(7, 7, 7),
	CFrame = crystalCFrame,
	Material = Enum.Material.Glass,
	Transparency = 0.35,
	Color = CORE_CYAN,
	Parent = core,
})
local crystal = make("Part", {
	Name = "CoreCrystal",
	Anchored = true,
	CanCollide = false,
	Size = Vector3.new(4, 4, 4),
	CFrame = crystalCFrame,
	Material = Enum.Material.Neon,
	Color = CORE_CYAN,
	Parent = core,
})
make("PointLight", { Color = CORE_CYAN, Range = 24, Brightness = 3, Parent = crystal })
local ring = make("Part", { Name = "Cincin", Anchored = true, CanCollide = false, Material = Enum.Material.Neon, Color = CORE_CYAN })
ring.Shape = Enum.PartType.Cylinder
ring.Size = Vector3.new(0.4, 14, 14)
ring.CFrame = CFrame.new(at(0, 17, 88)) * CFrame.Angles(math.rad(20), 0, math.rad(90))
ring.Parent = core
core.PrimaryPart = crystal

for _, x in { -18, -11, 11, 18 } do
	local rack = slab(core, "RakServer", x, 16, 96, Vector3.new(5, 10, 3), Enum.Material.Metal, Color3.fromRGB(40, 44, 60))
	for row = 1, 4 do
		make("Part", {
			Name = "LampuRak",
			Anchored = true,
			CanCollide = false,
			Size = Vector3.new(4, 0.3, 0.2),
			CFrame = rack.CFrame * CFrame.new(0, -4 + row * 1.8, -1.55),
			Material = Enum.Material.Neon,
			Color = if row % 2 == 0 then CORE_CYAN else Color3.fromRGB(110, 255, 140),
			Parent = core,
		})
	end
end

--------------------------------------------------------------------------------
-- Gerbang Virus & jalur virus
--------------------------------------------------------------------------------
-- Titik jalur (x pada z = -122, -80, -40, 0, 38). Jarak antarjalur selalu ≥ 16 stud
-- supaya virus tidak saling menutupi saat dibidik.
local LANES = {
	{ -42, -34, -44, -36, -30 },
	{ -14, -18, -10, -16, -10 },
	{ 14, 10, 18, 12, 10 },
	{ 42, 36, 44, 38, 30 },
}
local LANE_Z = { -122, -80, -40, 0, 38 }

local gates = make("Folder", { Name = "GerbangVirus", Parent = stage })
local lanesFolder = make("Folder", { Name = "Lanes", Parent = stage })
for index, xs in LANES do
	local gateX = xs[1]
	for _, side in { -1, 1 } do
		slab(gates, "Tiang", gateX + side * 5.5, 16, -125, Vector3.new(2.5, 16, 2.5), Enum.Material.Basalt, OBSIDIAN)
	end
	slab(gates, "Ambang", gateX, 18.5, -125, Vector3.new(13.5, 2.5, 3), Enum.Material.Basalt, OBSIDIAN)
	local portalPosition = at(gateX, 8, -125)
	make("Part", {
		Name = "PortalVirus",
		Anchored = true,
		CanCollide = false,
		Size = Vector3.new(8.5, 15, 0.5),
		CFrame = CFrame.lookAt(portalPosition, portalPosition + Vector3.new(0, 0, 1)),
		Material = Enum.Material.ForceField,
		Color = VIRUS_PURPLE,
		Parent = gates,
	})
	make("Part", {
		Name = "KristalVirus",
		Anchored = true,
		CanCollide = false,
		Size = Vector3.new(2.5, 2.5, 2.5),
		CFrame = CFrame.new(at(gateX, 21.5, -125)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Material = Enum.Material.Neon,
		Color = VIRUS_PURPLE,
		Parent = gates,
	})

	-- Titik jalur: terlihat saat mengedit, disembunyikan otomatis saat game berjalan
	local lane = make("Folder", { Name = "Lane" .. index, Parent = lanesFolder })
	for step, x in xs do
		make("Part", {
			Name = tostring(step),
			Anchored = true,
			CanCollide = false,
			CanTouch = false,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.5, 1.5, 1.5),
			CFrame = CFrame.new(at(x, if step == #xs then 9 else 7, LANE_Z[step])),
			Material = Enum.Material.Neon,
			Color = VIRUS_PURPLE,
			Transparency = 0.4,
			Parent = lane,
		})
	end
end

make("Folder", { Name = "Monsters", Parent = stage }) -- diisi virus oleh server

--------------------------------------------------------------------------------
-- Papan soal di langit (Front menghadap siswa, sedikit menunduk)
--------------------------------------------------------------------------------
local boardPosition = at(0, 44, -55)
local boardCFrame = CFrame.lookAt(boardPosition, boardPosition + Vector3.new(0, -0.18, 1))
make("Part", {
	Name = "SkyBoard",
	Anchored = true,
	CanCollide = false,
	Size = Vector3.new(64, 24, 1),
	CFrame = boardCFrame,
	Material = Enum.Material.SmoothPlastic,
	Color = NIGHT,
	Parent = stage,
})
make("Part", {
	Name = "BingkaiPapan",
	Anchored = true,
	CanCollide = false,
	Size = Vector3.new(66.5, 26.5, 0.6),
	CFrame = boardCFrame * CFrame.new(0, 0, 0.8),
	Material = Enum.Material.Neon,
	Color = FIRE,
	Parent = stage,
})

-- Zona jatuh tak terlihat di bawah seluruh arena
invisible(stage, "FallZone", at(0, -50, -20), Vector3.new(400, 10, 400), false)

pcall(function()
	game:GetService("Selection"):Set({ stage })
end)
print("✅ [BuildStage2] Arena Firewall Defender selesai: 4 jalur virus, Inti Server, dan papan soal langit. Simpan place (Ctrl+S)!")
