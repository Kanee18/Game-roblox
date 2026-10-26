--[[
	BuildStage1.luau — jalankan SEKALI lewat Command Bar Roblox Studio
	(menu View > Command Bar, tempel SELURUH isi file ini, tekan Enter).
	Jalankan SETELAH BuildLobbySkeleton.luau.

	Membangun lintasan parkour "Routing Runner" lengkap di Workspace > Stages > Stage1:
	  * Area start + spanduk aturan main
	  * 6 rintangan berbeda, masing-masing diakhiri "Gerbang Router"
	    (tembok + 3 pintu jawaban A/B/C + papan soal + checkpoint)
	  * Lava, zona jatuh tak terlihat, garis Finish, dan pad kembali ke Lobby
	  * Pulau-pulau batu melayang sebagai dekorasi

	Semua nama part sudah cocok dengan script Stage1. Setelah dibangun,
	bebas menghias/mengganti bentuk rintangan dengan aset Toolbox.
]]

local DEFAULT_ORIGIN = Vector3.new(1500, 61, 0) -- permukaan lantai area start

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
local stage = stages:FindFirstChild("Stage1")
if stage then
	if stage:FindFirstChild("Sections") then
		warn("[BuildStage1] Lintasan sudah ada. Hapus Workspace > Stages > Stage1 dulu jika ingin membangun ulang.")
		return
	end
	-- Hanya boleh menimpa isi dari BuildLobbySkeleton.
	local SKELETON_PARTS = { Platform = true, Spawn = true, ReturnToLobby = true }
	for _, child in stage:GetChildren() do
		if not SKELETON_PARTS[child.Name] then
			warn(`[BuildStage1] Stage1 berisi "{child.Name}" yang bukan dari kerangka. Pindahkan atau hapus dulu agar tidak tertimpa.`)
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
	stage.Name = "Stage1"
	stage.Parent = stages
end

--------------------------------------------------------------------------------
-- Warna & material (tema elemen Tanah: batu kapur hangat + emas)
--------------------------------------------------------------------------------
local GOLD = Color3.fromRGB(255, 196, 77)
local STONE = Color3.fromRGB(226, 214, 186)
local STONE_DARK = Color3.fromRGB(176, 152, 118)
local MARBLE = Color3.fromRGB(240, 234, 220)
local CABLE_BLUE = Color3.fromRGB(64, 142, 222)
local LAVA = Color3.fromRGB(255, 110, 40)
local DOOR = Color3.fromRGB(255, 236, 180)
local CHECKPOINT = Color3.fromRGB(150, 200, 255)
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

-- Koordinat relatif terhadap origin. Lintasan berjalan ke arah -Z.
local function at(x: number, y: number, z: number): Vector3
	return origin + Vector3.new(x, y, z)
end

-- Balok yang permukaan atasnya berada di ketinggian `top`.
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

-- Tiang silinder tegak yang permukaan atasnya di `top`.
local function pillar(parent: Instance, name: string, x: number, top: number, z: number, diameter: number, height: number, material: Enum.Material, color: Color3): Part
	local part = make("Part", { Name = name, Anchored = true, Material = material, Color = color })
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = CFrame.new(at(x, top - height / 2, z)) * CFrame.Angles(0, 0, math.rad(90))
	part.Parent = parent
	return part
end

-- Part tipis yang sisi Front-nya menghadap +Z (ke arah pemain yang datang).
local function facingPlayers(parent: Instance, name: string, position: Vector3, size: Vector3, color: Color3): Part
	return make("Part", {
		Name = name,
		Anchored = true,
		CanCollide = false,
		Size = size,
		CFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, 1)),
		Material = Enum.Material.SmoothPlastic,
		Color = color,
		Parent = parent,
	})
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
-- Area start
--------------------------------------------------------------------------------
local startArea = make("Folder", { Name = "StartArea", Parent = stage })
slab(startArea, "Platform", 0, 0, 0, Vector3.new(33, 2, 24), Enum.Material.Limestone, STONE)
make("Part", {
	Name = "Spawn", -- WAJIB: titik masuk dari portal (menghadap -Z, ke arah lintasan)
	Anchored = true,
	Size = Vector3.new(8, 1, 8),
	CFrame = CFrame.new(at(0, 0.5, 6)),
	Material = Enum.Material.Neon,
	Color = GOLD,
	Parent = stage,
})

-- Gapura + spanduk aturan main, dibaca dari titik Spawn
for _, side in { -1, 1 } do
	slab(startArea, "Tiang", side * 15.5, 19, -10.5, Vector3.new(2, 19, 2), Enum.Material.Marble, MARBLE)
end
local banner = facingPlayers(startArea, "Spanduk", at(0, 14, -10.5), Vector3.new(33, 10, 1), NIGHT)
local bannerGui = make("SurfaceGui", {
	Face = Enum.NormalId.Front,
	SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
	PixelsPerStud = 30,
	LightInfluence = 0,
	Parent = banner,
})
make("TextLabel", {
	Size = UDim2.fromScale(1, 0.32),
	BackgroundTransparency = 1,
	Text = "⛰️ ROUTING RUNNER",
	TextColor3 = GOLD,
	TextScaled = true,
	Font = Enum.Font.FredokaOne,
	Parent = bannerGui,
})
make("TextLabel", {
	Position = UDim2.fromScale(0.03, 0.34),
	Size = UDim2.fromScale(0.94, 0.62),
	BackgroundTransparency = 1,
	Text = "Kamu adalah PAKET DATA yang harus sampai ke tujuan!\n"
		.. "Lewati rintangan, baca soal di setiap Gerbang Router, lalu masuki pintu jawaban yang BENAR.\n"
		.. "✅ Benar: checkpoint baru + Poin     ❌ Salah: gugur & Poin berkurang",
	TextColor3 = Color3.fromRGB(246, 241, 229),
	TextScaled = true,
	TextWrapped = true,
	Font = Enum.Font.GothamBold,
	Parent = bannerGui,
})

--------------------------------------------------------------------------------
-- Rintangan. Setiap fungsi menerima (folder, z awal, tinggi lantai) dan
-- mengembalikan (z akhir, tinggi lantai berikutnya). Celah lompatan 2–4 stud.
--------------------------------------------------------------------------------
local function stones(folder: Instance, z: number, y: number): (number, number)
	for k, x in { -5, 4, -3, 5, 0 } do
		slab(folder, "BatuLoncatan", x, y, z - 8 - 12 * (k - 1), Vector3.new(8, 2, 8), Enum.Material.Sandstone, STONE_DARK)
	end
	return z - 64, y
end

local function cableBridges(folder: Instance, z: number, y: number): (number, number)
	for k = 1, 3 do
		local width = if k == 2 then 2.5 else 3
		slab(folder, "JembatanKabel", 0, y, z - 11 - 18 * (k - 1), Vector3.new(width, 1.5, 14), Enum.Material.Metal, CABLE_BLUE)
	end
	return z - 58, y
end

local function signalStairs(folder: Instance, z: number, y: number): (number, number)
	for k, x in { -3, 3, -3, 3, -3, 3 } do
		slab(folder, "TanggaSinyal", x, y + 2.5 * k, z - 6.5 - 10 * (k - 1), Vector3.new(7, 1.5, 7), Enum.Material.Limestone, STONE)
	end
	return z - 63, y + 17.5
end

local function lavaFloor(folder: Instance, z: number, y: number): (number, number)
	slab(folder, "Lava", 0, y - 0.5, z - 25, Vector3.new(26, 1, 50), Enum.Material.CrackedLava, LAVA)
	local rows = { { -7, 3 }, { -2, 8 }, { -8, 2 }, { -3, 7 }, { -7, 3 }, { 0 } }
	for k, row in rows do
		for _, x in row do
			slab(folder, "BatuAman", x, y + 0.5, z - 5 - 8 * (k - 1), Vector3.new(6, 1.5, 6), Enum.Material.Slate, Color3.fromRGB(120, 116, 110))
		end
	end
	return z - 50, y
end

local function antennaPillars(folder: Instance, z: number, y: number): (number, number)
	local tops = { 0.5, 2, 3.5, 2, 3.5, 2 }
	local offsets = { 0, 4, -4, 3, -3, 0 }
	for k, top in tops do
		local tip = pillar(folder, "TiangAntena", offsets[k], y + top, z - 6.5 - 9 * (k - 1), 5, 30, Enum.Material.Basalt, Color3.fromRGB(96, 90, 100))
		-- lampu kecil di sisi tiang (dekorasi)
		make("Part", {
			Name = "LampuAntena",
			Anchored = true,
			CanCollide = false,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(tip.Position + Vector3.new(2.6, 15 - 1.5, 0)),
			Material = Enum.Material.Neon,
			Color = GOLD,
			Parent = folder,
		})
	end
	return z - 58, y + 2
end

local function dataPath(folder: Instance, z: number, y: number): (number, number)
	for k, x in { -4, 4, 0 } do
		slab(folder, "BatuLoncatan", x, y, z - 7.5 - 11 * (k - 1), Vector3.new(7, 2, 7), Enum.Material.Sandstone, STONE_DARK)
	end
	slab(folder, "JalurData", 0, y, z - 47, Vector3.new(3, 1.5, 20), Enum.Material.Neon, Color3.fromRGB(255, 205, 100))
	for _, bumpZ in { z - 44, z - 51 } do
		slab(folder, "Lava", 0, y + 1.2, bumpZ, Vector3.new(3, 1.2, 1.5), Enum.Material.CrackedLava, LAVA)
	end
	return z - 61, y
end

local SECTIONS = {
	{ Title = "Batu Loncatan", Build = stones },
	{ Title = "Jembatan Kabel", Build = cableBridges },
	{ Title = "Tangga Sinyal", Build = signalStairs },
	{ Title = "Lantai Lava", Build = lavaFloor },
	{ Title = "Tiang Antena", Build = antennaPillars },
	{ Title = "Jalur Paket Data", Build = dataPath },
}

--------------------------------------------------------------------------------
-- Gerbang Router: lantai, tembok dengan 3 pintu, papan soal, checkpoint
--------------------------------------------------------------------------------
local DOOR_X = { -10, 0, 10 }
local DOOR_WIDTH, DOOR_HEIGHT = 7, 10
local WALL_HEIGHT = 16
local GATE_DEPTH = 40
local WALL_DISTANCE = 14 -- jarak tembok dari awal lantai gerbang

local function buildGate(section: Instance, index: number, z: number, y: number): (number, number)
	local area = make("Folder", { Name = "GateArea", Parent = section })
	local zWall = z - WALL_DISTANCE

	slab(area, "Floor", 0, y, z - GATE_DEPTH / 2, Vector3.new(33, 2, GATE_DEPTH), Enum.Material.Limestone, STONE)

	-- Tembok di antara pintu + ambang di atas pintu
	for _, range in { { -16.5, -13.5 }, { -6.5, -3.5 }, { 3.5, 6.5 }, { 13.5, 16.5 } } do
		slab(area, "Wall", (range[1] + range[2]) / 2, y + WALL_HEIGHT, zWall, Vector3.new(range[2] - range[1], WALL_HEIGHT, 2), Enum.Material.Marble, MARBLE)
	end
	for _, x in DOOR_X do
		slab(area, "Wall", x, y + WALL_HEIGHT, zWall, Vector3.new(DOOR_WIDTH, WALL_HEIGHT - DOOR_HEIGHT, 2), Enum.Material.Marble, MARBLE)
	end
	slab(area, "Trim", 0, y + WALL_HEIGHT + 0.6, zWall, Vector3.new(33.6, 0.6, 2.4), Enum.Material.Neon, GOLD)

	-- Dinding tak terlihat di kiri-kanan supaya gerbang tidak bisa diputari
	for _, side in { -1, 1 } do
		make("Part", {
			Name = "Barrier",
			Anchored = true,
			Transparency = 1,
			Size = Vector3.new(30, 50, 2),
			CFrame = CFrame.new(at(side * 31.5, y + 15, zWall)),
			Parent = area,
		})
	end

	-- Papan soal di atas tembok (teksnya diisi oleh Stage1Client per siswa)
	facingPlayers(area, "QuestionBoard", at(0, y + WALL_HEIGHT + 0.6 + 4.5, zWall), Vector3.new(33, 9, 1), NIGHT)

	-- Pintu jawaban A, B, C
	local doors = make("Folder", { Name = "Doors", Parent = section })
	for slot, x in DOOR_X do
		local door = make("Model", { Name = "Door" .. string.char(64 + slot), Parent = doors })
		make("Part", {
			Name = "Trigger",
			Anchored = true,
			CanCollide = false,
			Size = Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, 1.6),
			CFrame = CFrame.new(at(x, y + DOOR_HEIGHT / 2, zWall)),
			Material = Enum.Material.ForceField,
			Color = DOOR,
			Parent = door,
		})
		facingPlayers(door, "Sign", at(x, y + DOOR_HEIGHT + (WALL_HEIGHT - DOOR_HEIGHT) / 2, zWall + 1.15), Vector3.new(6.6, 5, 0.3), MARBLE)
		for _, side in { -1, 1 } do
			slab(door, "Trim", x + side * (DOOR_WIDTH / 2 + 0.25), y + DOOR_HEIGHT, zWall + 1.1, Vector3.new(0.5, DOOR_HEIGHT, 0.4), Enum.Material.Neon, GOLD)
		end
	end

	-- Checkpoint di balik tembok (menghadap -Z, arah lintasan)
	local checkpoint = make("Part", {
		Name = "Checkpoint",
		Anchored = true,
		Size = Vector3.new(10, 1, 10),
		CFrame = CFrame.new(at(0, y + 0.5, zWall - 13)),
		Material = Enum.Material.Neon,
		Color = CHECKPOINT,
		Parent = section,
	})
	floatingLabel(checkpoint, `📍 Checkpoint {index}`, Color3.fromRGB(255, 255, 255), 4)

	return z - GATE_DEPTH, y
end

--------------------------------------------------------------------------------
-- Susun semua bagian
--------------------------------------------------------------------------------
local sectionsFolder = make("Folder", { Name = "Sections", Parent = stage })
local cursorZ, cursorY = -12, 0
for index, definition in SECTIONS do
	local section = make("Folder", { Name = "Section" .. index, Parent = sectionsFolder })
	section:SetAttribute("Order", index)
	section:SetAttribute("Title", definition.Title)
	local obstacle = make("Folder", { Name = "Obstacle", Parent = section })
	cursorZ, cursorY = definition.Build(obstacle, cursorZ, cursorY)
	cursorZ, cursorY = buildGate(section, index, cursorZ, cursorY)
end

-- Garis finish
local finishArea = make("Folder", { Name = "FinishArea", Parent = stage })
slab(finishArea, "Platform", 0, cursorY, cursorZ - 18, Vector3.new(33, 2, 36), Enum.Material.Limestone, STONE)
local finish = make("Part", {
	Name = "Finish",
	Anchored = true,
	Size = Vector3.new(14, 1, 14),
	CFrame = CFrame.new(at(0, cursorY + 0.5, cursorZ - 14)),
	Material = Enum.Material.Neon,
	Color = GOLD,
	Parent = finishArea,
})
floatingLabel(finish, "🏁 FINISH — injak untuk melihat hasilmu!", NIGHT, 5)
finish.Label.TextLabel.BackgroundColor3 = GOLD

local returnPad = make("Part", {
	Name = "ReturnToLobby",
	Anchored = true,
	Size = Vector3.new(8, 1, 8),
	CFrame = CFrame.new(at(0, cursorY + 0.5, cursorZ - 29)),
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(255, 255, 255),
	Parent = finishArea,
})
floatingLabel(returnPad, "🏠 Kembali ke Lobby", Color3.fromRGB(255, 255, 255), 4)

for _, side in { -1, 1 } do
	slab(finishArea, "TiangPiala", side * 12, cursorY + 10, cursorZ - 33, Vector3.new(3, 10, 3), Enum.Material.Marble, MARBLE)
	make("Part", {
		Name = "KristalPiala",
		Anchored = true,
		CanCollide = false,
		Size = Vector3.new(3, 3, 3),
		CFrame = CFrame.new(at(side * 12, cursorY + 12.5, cursorZ - 33)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Material = Enum.Material.Neon,
		Color = GOLD,
		Parent = finishArea,
	})
end

-- Zona jatuh tak terlihat: siswa yang jatuh langsung kembali ke checkpoint
local courseEnd = cursorZ - 36
make("Part", {
	Name = "FallZone",
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	Transparency = 1,
	Size = Vector3.new(400, 10, -courseEnd + 200),
	CFrame = CFrame.new(at(0, -45, courseEnd / 2)),
	Parent = stage,
})

-- Dekorasi: pulau batu melayang di kiri-kanan lintasan
local decor = make("Folder", { Name = "Dekorasi", Parent = stage })
local rng = Random.new(2024)
for i = 1, 40 do
	local side = if i % 2 == 0 then 1 else -1
	local size = rng:NextNumber(6, 16)
	local rock = make("Part", {
		Name = "PulauMelayang",
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Size = Vector3.new(size, size * 0.7, size),
		CFrame = CFrame.new(at(side * rng:NextNumber(48, 95), rng:NextNumber(-25, 35), rng:NextNumber(courseEnd, 20)))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Material = Enum.Material.Rock,
		Color = Color3.fromRGB(150, 140, 125),
		Parent = decor,
	})
	make("Part", {
		Name = "Rumput",
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Size = Vector3.new(size * 1.05, 1, size * 1.05),
		CFrame = rock.CFrame * CFrame.new(0, size * 0.35 + 0.5, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(118, 186, 82),
		Parent = decor,
	})
end

pcall(function()
	game:GetService("Selection"):Set({ stage })
end)
print(`✅ [BuildStage1] Lintasan Routing Runner selesai: {#SECTIONS} gerbang, panjang ±{math.floor(-courseEnd)} stud. Simpan place (Ctrl+S)!`)
