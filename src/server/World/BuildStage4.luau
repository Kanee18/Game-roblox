--[[
	BuildStage4 (ModuleScript)
	Lokasi: ServerScriptService > World > BuildStage4

	Membangun lintasan terbang "Bandwidth Glider" di Workspace > Stages > Stage4:
	pulau menara, 8 gerbang cincin A/B, pulau pendaratan, dekorasi langit.

	Dipanggil otomatis oleh World > BuildAll saat server mulai, HANYA jika bagian ini
	belum ada. Untuk membangun di mode edit (agar bisa dihias lalu disimpan), jalankan
	tools/BuildWorld.luau di Command Bar. Build() mengembalikan false jika dilewati.
]]

local BuildStage4 = {}

function BuildStage4.Build(): boolean

	local DEFAULT_ORIGIN = Vector3.new(0, 401, -1500) -- permukaan pulau menara

	local GATE_COUNT = 8
	local FIRST_GATE = 200 -- jarak gerbang pertama dari LaunchPad (± 6 detik untuk membaca soal pertama)
	local GATE_SPACING = 260 -- jarak antargerbang (± 8 detik terbang)
	local LANDING_AFTER = 220 -- jarak gerbang terakhir ke pulau pendaratan
	local SLOPE = 0.1 -- turun 1 stud setiap maju 10 stud
	local RING_RADIUS = 8
	local RING_GAP = 14 -- jarak pusat cincin dari pusat gerbang

	-- Pergeseran gerbang ke kiri/kanan dan susunan cincin: "H" = kiri/kanan, "V" = atas/bawah
	local GATE_SHIFT = { 0, 24, -20, 8, -28, 18, -10, 0 }
	local GATE_LAYOUT = { "H", "H", "H", "V", "H", "H", "V", "H" }

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
	local stage = stages:FindFirstChild("Stage4")
	if stage then
		if stage:FindFirstChild("Gates") then
			warn("[BuildStage4] Lintasan sudah ada. Hapus Workspace > Stages > Stage4 dulu jika ingin membangun ulang.")
			return false
		end
		local SKELETON_PARTS = { Platform = true, Spawn = true, ReturnToLobby = true }
		for _, child in stage:GetChildren() do
			if not SKELETON_PARTS[child.Name] then
				warn(`[BuildStage4] Stage4 berisi "{child.Name}" yang bukan dari kerangka. Pindahkan atau hapus dulu agar tidak tertimpa.`)
				return false
			end
		end
		local platform = stage:FindFirstChild("Platform")
		if platform and platform:IsA("BasePart") then
			origin = platform.Position + Vector3.new(0, platform.Size.Y / 2, 0)
		end
		stage:ClearAllChildren()
	else
		stage = Instance.new("Folder")
		stage.Name = "Stage4"
		stage.Parent = stages
	end

	--------------------------------------------------------------------------------
	-- Warna (tema elemen Angin)
	--------------------------------------------------------------------------------
	local ANEMO = Color3.fromRGB(88, 228, 196)
	local ANEMO_LIGHT = Color3.fromRGB(200, 255, 240)
	local GRASS = Color3.fromRGB(118, 186, 82)
	local ROCK = Color3.fromRGB(150, 140, 125)
	local MARBLE = Color3.fromRGB(240, 234, 220)
	local NIGHT = Color3.fromRGB(22, 26, 46)
	local CLOUD = Color3.fromRGB(250, 252, 255)

	--------------------------------------------------------------------------------
	-- Pembantu
	--------------------------------------------------------------------------------
	local rng = Random.new(44)

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

	local function at(x: number, y: number, z: number): Vector3
		return origin + Vector3.new(x, y, z)
	end

	local function block(parent: Instance, name: string, cframe: CFrame, size: Vector3, material: Enum.Material, color: Color3): Part
		return make("Part", {
			Name = name,
			Anchored = true,
			Size = size,
			CFrame = cframe,
			Material = material,
			Color = color,
			TopSurface = Enum.SurfaceType.Smooth,
			BottomSurface = Enum.SurfaceType.Smooth,
			Parent = parent,
		})
	end

	local function label(parent: Instance, text: string, color: Color3, height: number)
		local billboard = make("BillboardGui", {
			Name = "Label",
			Size = UDim2.fromOffset(260, 56),
			StudsOffset = Vector3.new(0, height, 0),
			LightInfluence = 0,
			MaxDistance = 150,
			Parent = parent,
		})
		local textLabel = make("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = NIGHT,
			BackgroundTransparency = 0.25,
			Text = text,
			TextColor3 = color,
			TextScaled = true,
			Font = Enum.Font.FredokaOne,
			Parent = billboard,
		})
		make("UICorner", { CornerRadius = UDim.new(0, 12), Parent = textLabel })
		make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = textLabel })
	end

	-- Pulau melayang: badan batu + lapisan rumput. `top` = tinggi permukaan rumput.
	local function island(parent: Instance, name: string, x: number, top: number, z: number, width: number, depth: number)
		local folder = make("Folder", { Name = name, Parent = parent })
		block(folder, "Rumput", CFrame.new(at(x, top - 1, z)), Vector3.new(width, 2, depth), Enum.Material.Grass, GRASS)
		block(folder, "Batu", CFrame.new(at(x, top - 2 - width * 0.2, z)), Vector3.new(width * 0.9, width * 0.4, depth * 0.9), Enum.Material.Rock, ROCK)
		block(folder, "BatuBawah", CFrame.new(at(x, top - 2 - width * 0.5, z)), Vector3.new(width * 0.5, width * 0.3, depth * 0.5), Enum.Material.Rock, ROCK)
		return folder
	end

	-- Kincir angin hiasan (lambang elemen Angin)
	local function windmill(parent: Instance, x: number, bottom: number, z: number)
		block(parent, "TiangKincir", CFrame.new(at(x, bottom + 9, z)), Vector3.new(2, 18, 2), Enum.Material.Marble, MARBLE)
		for i = 0, 3 do
			block(
				parent,
				"BalingKincir",
				CFrame.new(at(x, bottom + 18, z - 1.3)) * CFrame.Angles(0, 0, math.rad(i * 90 + 20)) * CFrame.new(0, 3.5, 0),
				Vector3.new(1.4, 7, 0.3),
				Enum.Material.Neon,
				if i % 2 == 0 then ANEMO else ANEMO_LIGHT
			)
		end
	end

	--------------------------------------------------------------------------------
	-- Pulau menara & LaunchPad
	--------------------------------------------------------------------------------
	local tower = island(stage, "PulauMenara", 0, 0, 0, 52, 52)
	windmill(tower, -18, 0, 14)
	windmill(tower, 18, 0, 14)

	make("Part", {
		Name = "Spawn", -- WAJIB: menghadap -Z, ke arah lintasan
		Anchored = true,
		Size = Vector3.new(8, 1, 8),
		CFrame = CFrame.new(at(0, 0.5, 12)),
		Material = Enum.Material.Neon,
		Color = ANEMO,
		Parent = stage,
	})

	local launchPad = make("Part", {
		Name = "LaunchPad",
		Anchored = true,
		Size = Vector3.new(12, 1, 8),
		CFrame = CFrame.new(at(0, 0.5, -20)),
		Material = Enum.Material.Neon,
		Color = ANEMO_LIGHT,
		Parent = stage,
	})
	label(launchPad, "🪂 INJAK UNTUK TERBANG!", ANEMO, 5)

	--------------------------------------------------------------------------------
	-- Gerbang & cincin
	--------------------------------------------------------------------------------
	local FORWARD = Vector3.new(0, 0, -1)
	local RIGHT = Vector3.new(1, 0, 0)
	local UP = Vector3.new(0, 1, 0)
	local LAUNCH_Y = 1 + 3 -- permukaan LaunchPad + tinggi badan (lihat Stage4Map.LaunchHeight)
	local LAUNCH_Z = -20

	local function pathPoint(distance: number, shift: number): Vector3
		return at(shift, LAUNCH_Y - SLOPE * distance, LAUNCH_Z - distance)
	end

	local function buildRing(parent: Instance, name: string, center: Vector3)
		local ring = make("Model", { Name = name, Parent = parent })
		local SEGMENTS = 16
		for i = 1, SEGMENTS do
			local angle = (i / SEGMENTS) * math.pi * 2
			local radial = RIGHT * math.cos(angle) + UP * math.sin(angle)
			local tangent = -RIGHT * math.sin(angle) + UP * math.cos(angle)
			local segment = block(ring, "Bingkai", CFrame.fromMatrix(center + radial * RING_RADIUS, tangent, radial), Vector3.new(3.4, 1, 1), Enum.Material.Neon, ANEMO)
			segment.CanCollide = false
		end
		local facing = CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0) -- sumbu silinder searah lintasan
		local film = block(ring, "Lapisan", facing, Vector3.new(0.2, RING_RADIUS * 2 - 1, RING_RADIUS * 2 - 1), Enum.Material.ForceField, ANEMO_LIGHT)
		film.Shape = Enum.PartType.Cylinder
		film.CanCollide = false
		film.CanTouch = false
		film.CanQuery = false
		local trigger = block(ring, "Trigger", facing, Vector3.new(6, RING_RADIUS * 2 - 1, RING_RADIUS * 2 - 1), Enum.Material.SmoothPlastic, ANEMO)
		trigger.Shape = Enum.PartType.Cylinder
		trigger.Transparency = 1
		trigger.CanCollide = false
		ring.PrimaryPart = trigger
	end

	local gates = make("Folder", { Name = "Gates", Parent = stage })
	for index = 1, GATE_COUNT do
		local distance = FIRST_GATE + (index - 1) * GATE_SPACING
		local center = pathPoint(distance, GATE_SHIFT[index] or 0)
		local gate = make("Model", { Name = "Gate" .. index, Parent = gates })
		gate:SetAttribute("Order", index)
		local offset = if GATE_LAYOUT[index] == "V" then UP * RING_GAP * 0.75 else -RIGHT * RING_GAP
		buildRing(gate, "RingA", center + offset)
		buildRing(gate, "RingB", center - offset)
		-- Kristal penanda di tengah gerbang
		block(gate, "KristalGerbang", CFrame.new(center + UP * 20) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Vector3.new(2.5, 2.5, 2.5), Enum.Material.Neon, ANEMO).CanCollide = false
	end

	--------------------------------------------------------------------------------
	-- Pulau pendaratan
	--------------------------------------------------------------------------------
	local landingDistance = FIRST_GATE + (GATE_COUNT - 1) * GATE_SPACING + LANDING_AFTER
	local landingPoint = pathPoint(landingDistance, 0)
	local landingTop = landingPoint.Y - origin.Y - 12
	local landingZ = landingPoint.Z - origin.Z

	-- Volume tak terlihat di ujung garis luncur: menyentuhnya = mendarat.
	make("Part", {
		Name = "LandingZone",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Transparency = 1,
		Size = Vector3.new(160, 80, 60),
		CFrame = CFrame.new(landingPoint),
		Parent = stage,
	})

	local landing = island(stage, "PulauPendaratan", 0, landingTop, landingZ - 20, 96, 96)
	windmill(landing, 0, landingTop, landingZ - 55)

	local relaunch = make("Part", {
		Name = "Relaunch",
		Anchored = true,
		Size = Vector3.new(8, 1, 8),
		CFrame = CFrame.new(at(-14, landingTop + 0.5, landingZ - 35)),
		Material = Enum.Material.Neon,
		Color = ANEMO,
		Parent = landing,
	})
	label(relaunch, "🗼 Terbang lagi", ANEMO, 4)

	local returnPad = make("Part", {
		Name = "ReturnToLobby",
		Anchored = true,
		Size = Vector3.new(8, 1, 8),
		CFrame = CFrame.new(at(14, landingTop + 0.5, landingZ - 35)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 255, 255),
		Parent = landing,
	})
	label(returnPad, "🏠 Kembali ke Lobby", Color3.fromRGB(255, 255, 255), 4)

	--------------------------------------------------------------------------------
	-- Hiasan langit: pulau melayang, awan, pita angin
	--------------------------------------------------------------------------------
	local decor = make("Folder", { Name = "Dekorasi", Parent = stage })
	for i = 1, 26 do
		local side = if i % 2 == 0 then 1 else -1
		local distance = rng:NextNumber(0, landingDistance)
		local point = pathPoint(distance, side * rng:NextNumber(60, 140))
		local size = rng:NextNumber(10, 26)
		local small = island(decor, "PulauMelayang", point.X - origin.X, point.Y - origin.Y + rng:NextNumber(-40, 30), point.Z - origin.Z, size, size)
		for _, part in small:GetChildren() do
			part.CanCollide = false
			part.CastShadow = false
		end
	end

	for i = 1, 40 do
		local distance = rng:NextNumber(-100, landingDistance + 100)
		local side = if i % 2 == 0 then 1 else -1 -- awan di luar jalur agar tidak menutupi cincin
		local point = pathPoint(distance, side * rng:NextNumber(75, 200)) + Vector3.new(0, rng:NextNumber(-70, 50), 0)
		for _ = 1, 3 do
			local size = rng:NextNumber(10, 22)
			make("Part", {
				Name = "Awan",
				Anchored = true,
				CanCollide = false,
				CanTouch = false,
				CanQuery = false,
				CastShadow = false,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size, size),
				CFrame = CFrame.new(point + Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-3, 3), rng:NextNumber(-12, 12))),
				Material = Enum.Material.SmoothPlastic,
				Color = CLOUD,
				Transparency = 0.15,
				Parent = decor,
			})
		end
	end

	for _, side in { -1, 1 } do
		for k = 0, 7 do
			local from = pathPoint(k * 280, side * 65) + UP * rng:NextNumber(-8, 8)
			local to = pathPoint(k * 280 + 200, side * 65) + UP * rng:NextNumber(-8, 8)
			local length = (to - from).Magnitude
			block(decor, "PitaAngin", CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2), Vector3.new(0.4, 0.4, length), Enum.Material.Neon, ANEMO_LIGHT).Transparency = 0.5
		end
	end
	for _, part in decor:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end

	-- Zona jatuh tak terlihat jauh di bawah lintasan
	make("Part", {
		Name = "FallZone",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Transparency = 1,
		Size = Vector3.new(600, 10, landingDistance + 500),
		CFrame = CFrame.new(at(0, landingTop - 100, LAUNCH_Z - landingDistance / 2)),
		Parent = stage,
	})

	pcall(function()
		game:GetService("Selection"):Set({ stage })
	end)
	print(`✅ [BuildStage4] Lintasan Bandwidth Glider selesai: {GATE_COUNT} gerbang, panjang ±{math.floor(landingDistance)} stud.`)
	return true
end

return BuildStage4
