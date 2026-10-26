--[[
	BuildStage3 (ModuleScript)
	Lokasi: ServerScriptService > World > BuildStage3

	Membangun labirin motherboard "Cable Labyrinth" di Workspace > Stages > Stage3:
	labirin 9x9 acak (seed tetap), Mesin Pusat, dan 22 pedestal perangkat.

	Dipanggil otomatis oleh World > BuildAll saat server mulai, HANYA jika bagian ini
	belum ada. Untuk membangun di mode edit (agar bisa dihias lalu disimpan), jalankan
	tools/BuildWorld.luau di Command Bar. Build() mengembalikan false jika dilewati.
]]

local BuildStage3 = {}

function BuildStage3.Build(): boolean

	local DEFAULT_ORIGIN = Vector3.new(0, 61, 1500) -- permukaan papan sirkuit
	local SEED = 2025

	local GRID = 9 -- jumlah sel per sisi
	local CELL = 18 -- ukuran sel (stud)
	local WALL_HEIGHT = 10 -- lebih tinggi dari lompatan pemain
	local WALL_THICKNESS = 2
	local LOOP_CHANCE = 0.12 -- peluang dinding tambahan dibuka (labirin punya jalan memutar)
	local PLAZA_MIN, PLAZA_MAX = 4, 6 -- sel 4..6 di tengah menjadi plaza

	local ITEM_IDS = { "Router", "Switch", "Hub", "Modem", "AccessPoint", "KabelUTP", "RJ45", "FiberOptik", "NIC", "Coaxial", "Server" }
	local COPIES_PER_ITEM = 2

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
	local stage = stages:FindFirstChild("Stage3")
	if stage then
		if stage:FindFirstChild("Machine") then
			warn("[BuildStage3] Labirin sudah ada. Hapus Workspace > Stages > Stage3 dulu jika ingin membangun ulang.")
			return false
		end
		local SKELETON_PARTS = { Platform = true, Spawn = true, ReturnToLobby = true }
		for _, child in stage:GetChildren() do
			if not SKELETON_PARTS[child.Name] then
				warn(`[BuildStage3] Stage3 berisi "{child.Name}" yang bukan dari kerangka. Pindahkan atau hapus dulu agar tidak tertimpa.`)
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
		stage.Name = "Stage3"
		stage.Parent = stages
	end

	--------------------------------------------------------------------------------
	-- Warna (tema elemen Petir / motherboard)
	--------------------------------------------------------------------------------
	local PCB_GREEN = Color3.fromRGB(26, 96, 60)
	local COPPER = Color3.fromRGB(214, 172, 70)
	local ELECTRO = Color3.fromRGB(176, 112, 255)
	local CYAN = Color3.fromRGB(90, 220, 255)
	local WALL_STYLES = {
		{ Name = "Chip", Weight = 6, Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(34, 36, 42) },
		{ Name = "RAM", Weight = 3, Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(30, 110, 70) },
		{ Name = "Heatsink", Weight = 2, Material = Enum.Material.Metal, Color = Color3.fromRGB(165, 170, 182) },
	}
	local CAPACITOR_COLORS = { Color3.fromRGB(30, 40, 90), Color3.fromRGB(20, 20, 24), Color3.fromRGB(90, 30, 40) }

	--------------------------------------------------------------------------------
	-- Pembantu
	--------------------------------------------------------------------------------
	local rng = Random.new(SEED)

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

	local function block(parent: Instance, name: string, position: Vector3, size: Vector3, material: Enum.Material, color: Color3): Part
		return make("Part", {
			Name = name,
			Anchored = true,
			Size = size,
			CFrame = CFrame.new(position),
			Material = material,
			Color = color,
			TopSurface = Enum.SurfaceType.Smooth,
			BottomSurface = Enum.SurfaceType.Smooth,
			Parent = parent,
		})
	end

	-- Silinder tegak dengan alas di `bottom`.
	local function upright(parent: Instance, name: string, x: number, bottom: number, z: number, diameter: number, height: number, material: Enum.Material, color: Color3): Part
		local part = make("Part", { Name = name, Anchored = true, Material = material, Color = color })
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(height, diameter, diameter)
		part.CFrame = CFrame.new(at(x, bottom + height / 2, z)) * CFrame.Angles(0, 0, math.rad(90))
		part.Parent = parent
		return part
	end

	local function pickStyle()
		local total = 0
		for _, style in WALL_STYLES do
			total += style.Weight
		end
		local roll = rng:NextNumber(0, total)
		for _, style in WALL_STYLES do
			roll -= style.Weight
			if roll <= 0 then
				return style
			end
		end
		return WALL_STYLES[1]
	end

	-- Titik tengah sel (i, j) pada sumbu X/Z
	local function cellX(i: number): number
		return (i - (GRID + 1) / 2) * CELL
	end
	local cellZ = cellX

	local function isPlaza(i: number, j: number): boolean
		return i >= PLAZA_MIN and i <= PLAZA_MAX and j >= PLAZA_MIN and j <= PLAZA_MAX
	end

	--------------------------------------------------------------------------------
	-- Membuat labirin (recursive backtracker)
	-- east[i][j]  = dinding antara sel (i, j) dan (i+1, j)
	-- south[i][j] = dinding antara sel (i, j) dan (i, j+1)
	--------------------------------------------------------------------------------
	local east, south = {}, {}
	for i = 1, GRID do
		east[i], south[i] = {}, {}
		for j = 1, GRID do
			east[i][j] = i < GRID
			south[i][j] = j < GRID
		end
	end

	local function openBetween(i1: number, j1: number, i2: number, j2: number)
		if i1 == i2 then
			south[i1][math.min(j1, j2)] = false
		else
			east[math.min(i1, i2)][j1] = false
		end
	end

	local visited = {}
	local center = math.ceil(GRID / 2)
	local stack = { { center, center } }
	visited[center * 100 + center] = true
	while #stack > 0 do
		local top = stack[#stack]
		local neighbors = {}
		for _, step in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local ni, nj = top[1] + step[1], top[2] + step[2]
			if ni >= 1 and ni <= GRID and nj >= 1 and nj <= GRID and not visited[ni * 100 + nj] then
				table.insert(neighbors, { ni, nj })
			end
		end
		if #neighbors == 0 then
			table.remove(stack)
		else
			local nextCell = neighbors[rng:NextInteger(1, #neighbors)]
			openBetween(top[1], top[2], nextCell[1], nextCell[2])
			visited[nextCell[1] * 100 + nextCell[2]] = true
			table.insert(stack, nextCell)
		end
	end

	-- Plaza: buka semua dinding di dalamnya, plus satu pintu keluar di tiap sisi.
	for i = PLAZA_MIN, PLAZA_MAX do
		for j = PLAZA_MIN, PLAZA_MAX do
			if i < PLAZA_MAX then
				east[i][j] = false
			end
			if j < PLAZA_MAX then
				south[i][j] = false
			end
		end
	end
	east[PLAZA_MIN - 1][center] = false
	east[PLAZA_MAX][center] = false
	south[center][PLAZA_MIN - 1] = false
	south[center][PLAZA_MAX] = false

	-- Buka beberapa dinding tambahan supaya ada jalan memutar (tidak macet saat ramai).
	for i = 1, GRID do
		for j = 1, GRID do
			if east[i][j] and rng:NextNumber() < LOOP_CHANCE then
				east[i][j] = false
			end
			if south[i][j] and rng:NextNumber() < LOOP_CHANCE then
				south[i][j] = false
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Papan sirkuit & jalur tembaga
	--------------------------------------------------------------------------------
	local size = GRID * CELL
	local half = size / 2
	local board = make("Folder", { Name = "Board", Parent = stage })
	block(board, "PCB", at(0, -1, 0), Vector3.new(size + 4, 2, size + 4), Enum.Material.SmoothPlastic, PCB_GREEN)

	local function trace(x1: number, z1: number, x2: number, z2: number)
		local horizontal = z1 == z2
		local length = math.abs(x2 - x1) + math.abs(z2 - z1)
		local part = block(
			board,
			"JalurTembaga",
			at((x1 + x2) / 2, 0.05, (z1 + z2) / 2),
			if horizontal then Vector3.new(length + 0.6, 0.12, 0.6) else Vector3.new(0.6, 0.12, length + 0.6),
			Enum.Material.Foil,
			COPPER
		)
		part.CanCollide = false -- hiasan lantai, tidak mengganggu langkah
	end

	for i = 1, GRID do
		for j = 1, GRID do
			if not isPlaza(i, j) then
				local via = make("Part", { Name = "Via", Anchored = true, CanCollide = false, Material = Enum.Material.Foil, Color = COPPER })
				via.Shape = Enum.PartType.Cylinder
				via.Size = Vector3.new(0.14, 1.6, 1.6)
				via.CFrame = CFrame.new(at(cellX(i), 0.06, cellZ(j))) * CFrame.Angles(0, 0, math.rad(90))
				via.Parent = board
				-- Jalur tembaga mengikuti lorong yang terbuka
				if i < GRID and not east[i][j] and not isPlaza(i + 1, j) then
					trace(cellX(i), cellZ(j), cellX(i + 1), cellZ(j))
				end
				if j < GRID and not south[i][j] and not isPlaza(i, j + 1) then
					trace(cellX(i), cellZ(j), cellX(i), cellZ(j + 1))
				end
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Dinding & kapasitor
	--------------------------------------------------------------------------------
	local walls = make("Folder", { Name = "Walls", Parent = stage })

	local function wall(x: number, z: number, alongX: boolean)
		local style = pickStyle()
		local wallSize = if alongX then Vector3.new(CELL, WALL_HEIGHT, WALL_THICKNESS) else Vector3.new(WALL_THICKNESS, WALL_HEIGHT, CELL)
		local part = block(walls, style.Name, at(x, WALL_HEIGHT / 2, z), wallSize, style.Material, style.Color)
		if style.Name == "RAM" then
			-- garis emas di puncak keping RAM
			local trim = if alongX then Vector3.new(CELL, 0.3, WALL_THICKNESS + 0.1) else Vector3.new(WALL_THICKNESS + 0.1, 0.3, CELL)
			block(walls, "TrimRAM", at(x, WALL_HEIGHT - 0.15, z), trim, Enum.Material.Foil, COPPER)
		elseif style.Name == "Chip" then
			-- lampu kecil di puncak chip
			local glow = if alongX then Vector3.new(CELL * 0.6, 0.2, 0.4) else Vector3.new(0.4, 0.2, CELL * 0.6)
			block(walls, "LampuChip", at(x, WALL_HEIGHT + 0.1, z), glow, Enum.Material.Neon, ELECTRO)
		end
		return part
	end

	for i = 1, GRID do
		for j = 1, GRID do
			if east[i][j] then
				wall(cellX(i) + CELL / 2, cellZ(j), false)
			end
			if south[i][j] then
				wall(cellX(i), cellZ(j) + CELL / 2, true)
			end
		end
	end
	-- Dinding luar
	for k = 1, GRID do
		wall(-half, cellZ(k), false)
		wall(half, cellZ(k), false)
		wall(cellX(k), -half, true)
		wall(cellX(k), half, true)
	end

	-- Kapasitor di setiap sudut kisi (kecuali di dalam plaza)
	for a = 0, GRID do
		for b = 0, GRID do
			local x, z = -half + a * CELL, -half + b * CELL
			local insidePlaza = a > PLAZA_MIN - 1 and a < PLAZA_MAX and b > PLAZA_MIN - 1 and b < PLAZA_MAX
			if not insidePlaza then
				upright(walls, "Kapasitor", x, 0, z, 3, WALL_HEIGHT + 1, Enum.Material.SmoothPlastic, CAPACITOR_COLORS[rng:NextInteger(1, #CAPACITOR_COLORS)])
				upright(walls, "TutupKapasitor", x, WALL_HEIGHT + 1, z, 2.6, 0.2, Enum.Material.Metal, Color3.fromRGB(200, 205, 215))
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Plaza & Mesin Pusat (CPU raksasa)
	--------------------------------------------------------------------------------
	local machine = make("Model", { Name = "Machine", Parent = stage })
	local slot = block(machine, "DeliverySlot", at(0, 0.2, 0), Vector3.new(30, 0.4, 30), Enum.Material.Neon, CYAN)
	slot.Transparency = 0.3
	block(machine, "CPU", at(0, 1.9, 0), Vector3.new(18, 3, 18), Enum.Material.Metal, Color3.fromRGB(60, 64, 72))
	for _, side in { -1, 1 } do
		block(machine, "PinEmas", at(side * 9.4, 0.7, 0), Vector3.new(0.8, 0.3, 16), Enum.Material.Foil, COPPER)
		block(machine, "PinEmas", at(0, 0.7, side * 9.4), Vector3.new(16, 0.3, 0.8), Enum.Material.Foil, COPPER)
	end
	block(machine, "TutupCPU", at(0, 3.6, 0), Vector3.new(12, 0.4, 12), Enum.Material.Metal, Color3.fromRGB(190, 195, 205))
	local core = block(machine, "Inti", at(0, 7.8, 0), Vector3.new(3, 8, 3), Enum.Material.Neon, CYAN)
	make("PointLight", { Color = CYAN, Range = 30, Brightness = 3, Parent = core })
	for _, corner in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		-- kabel data bercahaya dari inti ke sudut CPU
		local from = at(0, 4, 0)
		local to = at(corner[1] * 5.5, 4, corner[2] * 5.5)
		local length = (to - from).Magnitude
		make("Part", {
			Name = "KabelData",
			Anchored = true,
			CanCollide = false,
			Size = Vector3.new(0.5, 0.5, length),
			CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2),
			Material = Enum.Material.Neon,
			Color = ELECTRO,
			Parent = machine,
		})
	end
	machine.PrimaryPart = core

	make("Part", {
		Name = "Spawn", -- WAJIB: menghadap -Z, ke arah Mesin Pusat
		Anchored = true,
		Size = Vector3.new(8, 1, 8),
		CFrame = CFrame.new(at(0, 0.5, 22)),
		Material = Enum.Material.Neon,
		Color = ELECTRO,
		Parent = stage,
	})

	local returnPad = make("Part", {
		Name = "ReturnToLobby",
		Anchored = true,
		Size = Vector3.new(7, 1, 7),
		CFrame = CFrame.new(at(-20, 0.5, 20)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 255, 255),
		Parent = stage,
	})
	local returnLabel = make("BillboardGui", {
		Name = "Label",
		Size = UDim2.fromOffset(220, 50),
		StudsOffset = Vector3.new(0, 4, 0),
		LightInfluence = 0,
		MaxDistance = 100,
		Parent = returnPad,
	})
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(22, 26, 46),
		BackgroundTransparency = 0.25,
		Text = "🏠 Kembali ke Lobby",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		Parent = returnLabel,
	})

	--------------------------------------------------------------------------------
	-- Pedestal perangkat: ujung buntu dan sel terjauh diutamakan
	--------------------------------------------------------------------------------
	local function openings(i: number, j: number): number
		local count = 0
		if i > 1 and not east[i - 1][j] then
			count += 1
		end
		if i < GRID and not east[i][j] then
			count += 1
		end
		if j > 1 and not south[i][j - 1] then
			count += 1
		end
		if j < GRID and not south[i][j] then
			count += 1
		end
		return count
	end

	local candidates = {}
	for i = 1, GRID do
		for j = 1, GRID do
			if not isPlaza(i, j) then
				table.insert(candidates, {
					I = i,
					J = j,
					DeadEnd = openings(i, j) == 1,
					Distance = math.abs(i - center) + math.abs(j - center),
					Tiebreak = rng:NextNumber(),
				})
			end
		end
	end
	table.sort(candidates, function(a, b)
		if a.DeadEnd ~= b.DeadEnd then
			return a.DeadEnd
		end
		if a.Distance ~= b.Distance then
			return a.Distance > b.Distance
		end
		return a.Tiebreak < b.Tiebreak
	end)
	-- Acak urutan sel terpilih supaya dua salinan perangkat yang sama berjauhan.
	local chosen = {}
	for index = 1, math.min(#ITEM_IDS * COPIES_PER_ITEM, #candidates) do
		table.insert(chosen, candidates[index])
	end
	for index = #chosen, 2, -1 do
		local swap = rng:NextInteger(1, index)
		chosen[index], chosen[swap] = chosen[swap], chosen[index]
	end

	local stations = make("Folder", { Name = "Stations", Parent = stage })
	for index, cell in chosen do
		local itemId = ITEM_IDS[(index - 1) % #ITEM_IDS + 1]
		local station = upright(stations, "ItemStation", cellX(cell.I), 0, cellZ(cell.J), 5, 1, Enum.Material.SmoothPlastic, Color3.fromRGB(45, 48, 58))
		station:SetAttribute("ItemId", itemId)
		local beacon = upright(station, "Beacon", cellX(cell.I), 1, cellZ(cell.J), 0.6, 16, Enum.Material.Neon, CYAN)
		beacon.Transparency = 0.45
		beacon.CanCollide = false
		beacon.CanTouch = false
		beacon.CanQuery = false
	end

	-- Zona jatuh tak terlihat di bawah papan
	make("Part", {
		Name = "FallZone",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Transparency = 1,
		Size = Vector3.new(size + 200, 10, size + 200),
		CFrame = CFrame.new(at(0, -40, 0)),
		Parent = stage,
	})

	pcall(function()
		game:GetService("Selection"):Set({ stage })
	end)
	print(`✅ [BuildStage3] Cable Labyrinth selesai: labirin {GRID}×{GRID}, {#chosen} pedestal perangkat.`)
	return true
end

return BuildStage3
