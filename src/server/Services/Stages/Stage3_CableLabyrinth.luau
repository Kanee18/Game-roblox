--[[
	Stage3_CableLabyrinth (ModuleScript)
	Lokasi: ServerScriptService > Services > Stages > Stage3_CableLabyrinth
	Materi: Perangkat Keras Jaringan

	Alur permainan (setiap siswa punya misinya sendiri):
	  1. Mesin Pusat di tengah labirin menjelaskan FUNGSI sebuah perangkat
	     (contoh: "perangkat yang memancarkan sinyal Wi-Fi…").
	  2. Siswa menebak perangkatnya, mencarinya di labirin motherboard, lalu
	     menyentuh pedestalnya untuk mengambil (dibawa di atas kepala).
	     Pedestal tidak pernah habis, jadi semua siswa bisa mengambil.
	  3. Bawa ke Mesin Pusat (injak lantai bercahaya di sekelilingnya):
	       Benar -> +Poin, permintaan berikutnya
	       Salah -> -Poin, penjelasan fungsi perangkat yang dibawa + yang diminta,
	                lalu permintaan baru
	  4. Setelah 6 pengiriman benar: misi selesai + bonus Poin (sekali per sesi).

	Kunci jawaban (permintaan -> perangkat) hanya ada di server.
	Model 3D perangkat dibuat dari part. Untuk memakai model sendiri, taruh Model
	bernama sesuai Id (mis. "Router") di ServerStorage > Stage3Items.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(ReplicatedStorage.Shared.UiKit)
local QuizBank = require(ServerScriptService:WaitForChild("QuizBank"))

local Services = script.Parent.Parent
local NotifyService = require(Services.NotifyService)
local PointsService = require(Services.PointsService)
local SpawnService = require(Services.SpawnService)

local STAGE_ID = "Stage3"
local CONFIG = GameConfig.Stage3
local Theme = GameConfig.Theme

local ITEMS = {}
for _, item in CONFIG.Items do
	ITEMS[item.Id] = item
end

type Request = {
	Question: string,
	Correct: string,
	Explanation: string?,
}

type PlayerState = {
	Request: Request?,
	Deck: { Request },
	Carrying: string?,
	CarriedModel: Model?,
	CorrectCount: number,
	WrongCount: number,
	LockedUntil: number,
	LastPickupAt: number,
}

local Stage3 = {}

local stateRemote = Remotes.Get("Stage3State")
local feedbackRemote = Remotes.Get("Stage3Feedback")
local completeRemote = Remotes.Get("Stage3Complete")

local random = Random.new()
local requests: { Request } = {}
local states: { [Player]: PlayerState } = {}
local bonusClaimed: { [number]: boolean } = {}
local machineFocus: BasePart? = nil

--------------------------------------------------------------------------------
-- Model 3D perangkat (dibuat dari part, menghadap -Z, alas di Y = 0)
--------------------------------------------------------------------------------
local BLACK = Color3.fromRGB(28, 30, 36)
local SILVER = Color3.fromRGB(190, 195, 205)
local GOLD = Color3.fromRGB(214, 172, 70)
local LED_GREEN = Color3.fromRGB(110, 255, 140)
local LED_BLUE = Color3.fromRGB(90, 200, 255)

local function piece(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local VERTICAL = CFrame.Angles(0, 0, math.rad(90)) -- sumbu silinder (X) menjadi tegak
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- sumbu silinder (X) searah Z

-- Gulungan kabel: potongan silinder yang disusun melingkar.
local function cableLoop(model: Model, radius: number, height: number, thickness: number, color: Color3)
	local SEGMENTS = 12
	for i = 1, SEGMENTS do
		local angle = (i / SEGMENTS) * math.pi * 2
		local position = Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local length = 2 * math.pi * radius / SEGMENTS + 0.15
		piece(model, "Kabel", Vector3.new(length, thickness, thickness), CFrame.lookAt(position, position + tangent) * ALONG_Z, color, nil, Enum.PartType.Cylinder)
	end
end

local BUILDERS: { [string]: (Model) -> BasePart } = {
	Router = function(model)
		local base = piece(model, "Base", Vector3.new(3.2, 0.8, 2.2), CFrame.new(0, 0.4, 0), Color3.fromRGB(40, 44, 54))
		for _, x in { -1.1, 0, 1.1 } do
			piece(model, "Antena", Vector3.new(2.4, 0.25, 0.25), CFrame.new(x, 2, 0.85) * CFrame.Angles(0, 0, math.rad(90 + x * 14)), BLACK, nil, Enum.PartType.Cylinder)
		end
		for i = 1, 4 do
			piece(model, "LED", Vector3.new(0.22, 0.22, 0.22), CFrame.new(-1.05 + i * 0.42, 0.5, -1.12), LED_GREEN, Enum.Material.Neon, Enum.PartType.Ball)
		end
		return base
	end,

	Switch = function(model)
		local base = piece(model, "Base", Vector3.new(4.2, 0.6, 1.8), CFrame.new(0, 0.3, 0), Color3.fromRGB(60, 90, 140), Enum.Material.Metal)
		for i = 0, 7 do
			local x = -1.6 + i * 0.46
			piece(model, "Port", Vector3.new(0.36, 0.26, 0.08), CFrame.new(x, 0.28, -0.92), BLACK)
			piece(model, "LED", Vector3.new(0.12, 0.12, 0.12), CFrame.new(x, 0.5, -0.92), LED_GREEN, Enum.Material.Neon, Enum.PartType.Ball)
		end
		return base
	end,

	Hub = function(model)
		local base = piece(model, "Base", Vector3.new(2.8, 0.7, 1.6), CFrame.new(0, 0.35, 0), Color3.fromRGB(210, 195, 160))
		for i = 0, 3 do
			local x = -0.9 + i * 0.6
			piece(model, "Port", Vector3.new(0.4, 0.28, 0.08), CFrame.new(x, 0.3, -0.82), BLACK)
			piece(model, "LED", Vector3.new(0.14, 0.14, 0.14), CFrame.new(x, 0.56, -0.82), Color3.fromRGB(255, 180, 60), Enum.Material.Neon, Enum.PartType.Ball)
		end
		return base
	end,

	Modem = function(model)
		piece(model, "Kaki", Vector3.new(1.8, 0.2, 2.4), CFrame.new(0, 0.1, 0), BLACK)
		local base = piece(model, "Base", Vector3.new(1.2, 2.6, 2.2), CFrame.new(0, 1.5, 0), Color3.fromRGB(235, 235, 240))
		for i = 1, 5 do
			piece(model, "LED", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0.5 + i * 0.38, -1.12), LED_BLUE, Enum.Material.Neon, Enum.PartType.Ball)
		end
		return base
	end,

	AccessPoint = function(model)
		local base = piece(model, "Base", Vector3.new(0.5, 3, 3), CFrame.new(0, 0.25, 0) * VERTICAL, Color3.fromRGB(240, 240, 245), nil, Enum.PartType.Cylinder)
		piece(model, "Cincin", Vector3.new(0.1, 1.3, 1.3), CFrame.new(0, 0.52, 0) * VERTICAL, LED_BLUE, Enum.Material.Neon, Enum.PartType.Cylinder)
		piece(model, "Tengah", Vector3.new(0.12, 0.9, 0.9), CFrame.new(0, 0.54, 0) * VERTICAL, Color3.fromRGB(240, 240, 245), nil, Enum.PartType.Cylinder)
		return base
	end,

	KabelUTP = function(model)
		cableLoop(model, 1.3, 0.2, 0.35, Color3.fromRGB(70, 120, 255))
		cableLoop(model, 1.05, 0.5, 0.35, Color3.fromRGB(70, 120, 255))
		local base = piece(model, "Base", Vector3.new(0.45, 0.4, 0.75), CFrame.new(1.3, 0.25, -0.9), Color3.fromRGB(220, 240, 255), Enum.Material.Glass)
		base.Transparency = 0.3
		return base
	end,

	RJ45 = function(model)
		local base = piece(model, "Base", Vector3.new(1.6, 1.2, 2.4), CFrame.new(0, 0.6, 0), Color3.fromRGB(220, 240, 255), Enum.Material.Glass)
		base.Transparency = 0.35
		for i = 0, 7 do
			piece(model, "Pin", Vector3.new(0.1, 0.06, 1.1), CFrame.new(-0.7 + i * 0.2, 1.05, -0.55), GOLD, Enum.Material.Foil)
		end
		local clip = piece(model, "Klip", Vector3.new(0.7, 0.18, 1.3), CFrame.new(0, 1.28, 0.2) * CFrame.Angles(math.rad(-8), 0, 0), Color3.fromRGB(220, 240, 255), Enum.Material.Glass)
		clip.Transparency = 0.35
		piece(model, "Kabel", Vector3.new(1.6, 0.7, 0.7), CFrame.new(0, 0.6, 2) * ALONG_Z, Color3.fromRGB(70, 120, 255), nil, Enum.PartType.Cylinder)
		return base
	end,

	FiberOptik = function(model)
		local base = piece(model, "Base", Vector3.new(3, 0.5, 0.5), CFrame.new(0.3, 0.35, 0), Color3.fromRGB(255, 150, 40), nil, Enum.PartType.Cylinder)
		piece(model, "Konektor", Vector3.new(0.6, 0.6, 0.6), CFrame.new(2.05, 0.35, 0), SILVER, Enum.Material.Metal)
		local colors = { LED_BLUE, Color3.fromRGB(255, 90, 220), Color3.fromRGB(255, 240, 90) }
		for i = 1, 6 do
			local spread = math.rad(-25 + (i - 1) * 10)
			local lift = math.rad(if i % 2 == 0 then 10 else -6)
			local cframe = CFrame.new(-1.2, 0.4, 0) * CFrame.Angles(0, spread, lift) * CFrame.new(-0.7, 0, 0)
			piece(model, "Serat", Vector3.new(1.4, 0.1, 0.1), cframe, colors[(i - 1) % 3 + 1], Enum.Material.Neon, Enum.PartType.Cylinder)
		end
		return base
	end,

	NIC = function(model)
		local base = piece(model, "Base", Vector3.new(3, 2, 0.15), CFrame.new(0, 1.2, 0), Color3.fromRGB(30, 120, 70))
		piece(model, "KakiEmas", Vector3.new(2.2, 0.3, 0.17), CFrame.new(-0.2, 0.15, 0), GOLD, Enum.Material.Foil)
		piece(model, "Bracket", Vector3.new(0.12, 2.6, 0.7), CFrame.new(1.56, 1.3, 0.1), SILVER, Enum.Material.Metal)
		piece(model, "PortLAN", Vector3.new(0.5, 0.5, 0.55), CFrame.new(1.3, 1.7, -0.2), BLACK)
		piece(model, "Chip", Vector3.new(0.8, 0.8, 0.12), CFrame.new(-0.4, 1.3, -0.13), BLACK)
		piece(model, "LED", Vector3.new(0.15, 0.15, 0.15), CFrame.new(1.3, 2.05, -0.3), LED_GREEN, Enum.Material.Neon, Enum.PartType.Ball)
		return base
	end,

	Coaxial = function(model)
		cableLoop(model, 1.2, 0.3, 0.5, BLACK)
		local base = piece(model, "Base", Vector3.new(0.7, 0.7, 0.7), CFrame.new(1.2, 0.35, -0.95) * ALONG_Z, SILVER, Enum.Material.Metal, Enum.PartType.Cylinder)
		piece(model, "Inti", Vector3.new(0.5, 0.15, 0.15), CFrame.new(1.2, 0.35, -1.5) * ALONG_Z, GOLD, Enum.Material.Foil, Enum.PartType.Cylinder)
		return base
	end,

	Server = function(model)
		local base = piece(model, "Base", Vector3.new(1.8, 3.8, 2.6), CFrame.new(0, 1.9, 0), Color3.fromRGB(35, 38, 46), Enum.Material.Metal)
		for i = 1, 4 do
			piece(model, "Lampu", Vector3.new(1.4, 0.12, 0.05), CFrame.new(0, 0.3 + i * 0.75, -1.32), LED_BLUE, Enum.Material.Neon)
			piece(model, "LED", Vector3.new(0.14, 0.14, 0.14), CFrame.new(0.6, 0.55 + i * 0.75, -1.32), LED_GREEN, Enum.Material.Neon, Enum.PartType.Ball)
		end
		return base
	end,
}

-- Model baru untuk sebuah perangkat. Model custom di ServerStorage > Stage3Items dipakai jika ada.
local function buildItemModel(itemId: string): Model
	local customFolder = ServerStorage:FindFirstChild("Stage3Items")
	local custom = customFolder and customFolder:FindFirstChild(itemId)
	if custom and custom:IsA("Model") then
		local model = custom:Clone()
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
		return model
	end

	local model = Instance.new("Model")
	model.Name = itemId
	local builder = BUILDERS[itemId]
	if builder then
		model.PrimaryPart = builder(model)
	else
		local item = ITEMS[itemId]
		model.PrimaryPart = piece(model, "Base", Vector3.new(2, 2, 2), CFrame.new(0, 1, 0), if item then item.Color else SILVER)
	end
	return model
end

-- Letakkan model sehingga bagian bawahnya berada `lift` stud di atas permukaan part.
local function placeOnTop(model: Model, surface: BasePart, lift: number)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local pivotFromBox = boxCFrame:ToObjectSpace(model:GetPivot())
	local center = SpawnService.GetTopPosition(surface) + Vector3.new(0, boxSize.Y / 2 + lift, 0)
	model:PivotTo(CFrame.new(center) * pivotFromBox)
end

--------------------------------------------------------------------------------
-- Barang yang dibawa siswa
--------------------------------------------------------------------------------
local function removeCarried(state: PlayerState)
	if state.CarriedModel then
		state.CarriedModel:Destroy()
	end
	state.CarriedModel = nil
	state.Carrying = nil
end

local function attachCarried(player: Player, state: PlayerState, itemId: string)
	removeCarried(state)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and root and root:IsA("BasePart")) then
		return
	end

	local model = buildItemModel(itemId)
	model.Name = "BarangDibawa"
	pcall(function()
		model:ScaleTo(0.6)
	end)
	-- Melayang di atas kepala supaya teman-teman bisa melihat apa yang dibawa.
	local boxCFrame, size = model:GetBoundingBox()
	local pivotFromBox = boxCFrame:ToObjectSpace(model:GetPivot())
	model:PivotTo(root.CFrame * CFrame.new(0, 3.2 + size.Y / 2, 0) * pivotFromBox)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			UiKit.new("WeldConstraint", { Part0 = root, Part1 = part, Parent = part })
		end
	end
	model.Parent = character

	state.Carrying = itemId
	state.CarriedModel = model
end

--------------------------------------------------------------------------------
-- Permintaan Mesin Pusat
--------------------------------------------------------------------------------
local function shuffled<T>(list: { T }): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = random:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function loadRequests()
	for index, item in QuizBank.Stage3 or {} do
		local valid = typeof(item) == "table" and typeof(item.Question) == "string" and ITEMS[item.Correct] ~= nil
		if valid then
			table.insert(requests, item)
		else
			warn(`[Stage3] Soal nomor {index} di QuizBank.Stage3 tidak valid (Correct harus Id perangkat di GameConfig.Stage3.Items).`)
		end
	end
	if #requests == 0 then
		warn("[Stage3] QuizBank.Stage3 kosong! Tambahkan soal di ServerScriptService > QuizBank.")
	end
end

local function drawRequest(state: PlayerState): Request?
	if #requests == 0 then
		return nil
	end
	if #state.Deck == 0 then
		state.Deck = shuffled(requests)
	end
	return table.remove(state.Deck)
end

local function sendState(player: Player, state: PlayerState)
	local carried = if state.Carrying then ITEMS[state.Carrying] else nil
	stateRemote:FireClient(player, {
		Request = if state.Request then state.Request.Question else nil,
		Carrying = if carried then `{carried.Icon} {carried.Name}` else nil,
		Correct = state.CorrectCount,
		Goal = CONFIG.MissionGoal,
	})
end

local function getState(player: Player): PlayerState
	local state = states[player]
	if not state then
		state = {
			Request = nil,
			Deck = shuffled(requests),
			Carrying = nil,
			CarriedModel = nil,
			CorrectCount = 0,
			WrongCount = 0,
			LockedUntil = 0,
			LastPickupAt = 0,
		}
		states[player] = state
	end
	return state
end

local function getLivingPlayer(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if player and humanoid and humanoid.Health > 0 then
		return player
	end
	return nil
end

local function completeMission(player: Player, state: PlayerState)
	local bonus = 0
	if not (CONFIG.MissionBonusOncePerSession and bonusClaimed[player.UserId]) then
		bonus = CONFIG.MissionBonus
		bonusClaimed[player.UserId] = true
		PointsService.Add(player, bonus, "Misi Cable Labyrinth selesai!")
	end
	completeRemote:FireClient(player, {
		Correct = state.CorrectCount,
		Wrong = state.WrongCount,
		Bonus = bonus,
	})
	NotifyService.ToAll(`🏆 {player.DisplayName} menyelesaikan misi Cable Labyrinth!`, "success")
end

local function deliver(player: Player, state: PlayerState)
	local broughtId = state.Carrying :: string
	local request = state.Request :: Request
	removeCarried(state)

	local brought = ITEMS[broughtId]
	local expected = ITEMS[request.Correct]
	local isCorrect = broughtId == request.Correct
	if isCorrect then
		state.CorrectCount += 1
		PointsService.Add(player, CONFIG.CorrectPoints, "Perangkat yang tepat!")
	else
		state.WrongCount += 1
		PointsService.Add(player, CONFIG.WrongPoints, "Perangkat salah")
	end
	feedbackRemote:FireClient(player, {
		Correct = isCorrect,
		Brought = `{brought.Icon} {brought.Name}`,
		BroughtInfo = if isCorrect then nil else QuizBank.Stage3Info and QuizBank.Stage3Info[broughtId],
		Expected = `{expected.Icon} {expected.Name}`,
		Explanation = request.Explanation,
	})
	if machineFocus then
		UiKit.burst(machineFocus.Position, if isCorrect then Theme.Success else Theme.Danger, 60)
	end
	if isCorrect and state.CorrectCount == CONFIG.MissionGoal then
		completeMission(player, state)
	end

	state.Request = drawRequest(state)
	sendState(player, state)
end

--------------------------------------------------------------------------------
-- Sentuhan: pedestal perangkat & Mesin Pusat
--------------------------------------------------------------------------------
local function onStationTouched(itemId: string, hit: BasePart)
	local player = getLivingPlayer(hit)
	if not player or SpawnService.GetArea(player) ~= STAGE_ID then
		return
	end
	local state = states[player]
	if not state or state.Carrying == itemId then
		return
	end
	local now = os.clock()
	if now - state.LastPickupAt < CONFIG.PickupCooldown then
		return
	end
	state.LastPickupAt = now

	local previous = if state.Carrying then ITEMS[state.Carrying] else nil
	local item = ITEMS[itemId]
	attachCarried(player, state, itemId)
	if previous then
		NotifyService.ToPlayer(player, `🔄 {previous.Name} kamu tukar dengan {item.Icon} {item.Name}.`, "info")
	else
		NotifyService.ToPlayer(player, `📦 Kamu membawa {item.Icon} {item.Name}. Antar ke Mesin Pusat!`, "info")
	end
	sendState(player, state)
end

local function onSlotTouched(hit: BasePart)
	local player = getLivingPlayer(hit)
	if not player or SpawnService.GetArea(player) ~= STAGE_ID then
		return
	end
	local state = states[player]
	if not (state and state.Carrying and state.Request) then
		return
	end
	local now = os.clock()
	if now < state.LockedUntil then
		return
	end
	state.LockedUntil = now + 1.5
	deliver(player, state)
end

local function setupStation(station: BasePart)
	local itemId = station:GetAttribute("ItemId")
	local item = if typeof(itemId) == "string" then ITEMS[itemId] else nil
	if not item then
		warn(`[Stage3] ItemStation "{station:GetFullName()}" punya ItemId tidak dikenal: {itemId}`)
		return
	end

	-- Model pajangan (diputar pelan oleh Stage3Client)
	local display = buildItemModel(item.Id)
	display.Name = "Display"
	for _, part in display:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
		end
	end
	placeOnTop(display, station, 1)
	display.Parent = station

	local beacon = station:FindFirstChild("Beacon")
	if beacon and beacon:IsA("BasePart") then
		beacon.Color = item.Color
	end

	-- Papan nama tinggi di atas dinding labirin: jadi patokan arah dari jauh.
	local billboard = UiKit.new("BillboardGui", {
		Name = "ItemLabel",
		Adornee = station,
		-- Ukuran campuran (stud + piksel): papan nama yang jauh ikut mengecil sehingga
		-- tidak saling menumpuk di layar HP.
		Size = UDim2.new(6, 60, 1.5, 16),
		StudsOffsetWorldSpace = Vector3.new(0, 15, 0),
		LightInfluence = 0,
		MaxDistance = 200,
		Parent = station,
	})
	UiKit.label({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.15,
		BackgroundColor3 = Theme.Night,
		Text = `{item.Icon} {item.Name}`,
		TextScaled = true,
		Parent = billboard,
	}, {
		UiKit.corner(UDim.new(0.25, 0)),
		UiKit.stroke(item.Color, 2),
		UiKit.new("UIPadding", {
			PaddingLeft = UDim.new(0.04, 0),
			PaddingRight = UDim.new(0.04, 0),
			PaddingTop = UDim.new(0.1, 0),
			PaddingBottom = UDim.new(0.1, 0),
		}),
	})

	station.Touched:Connect(function(hit)
		onStationTouched(item.Id, hit)
	end)
end

local function setupMap(stageFolder: Instance)
	local stationCount = 0
	for _, descendant in stageFolder:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == "ItemStation" then
			setupStation(descendant)
			stationCount += 1
		end
	end

	local machine = stageFolder:FindFirstChild("Machine")
	if machine and machine:IsA("Model") then
		machineFocus = machine.PrimaryPart or machine:FindFirstChildWhichIsA("BasePart", true)
	end
	local slot = stageFolder:FindFirstChild("DeliverySlot", true)
	if slot and slot:IsA("BasePart") then
		slot.CanTouch = true
		slot.Touched:Connect(onSlotTouched)
	else
		warn('[Stage3] Part "DeliverySlot" tidak ditemukan: siswa tidak bisa mengantar perangkat.')
	end
	print(`[Stage3] Cable Labyrinth siap: {stationCount} pedestal perangkat, {#requests} permintaan.`)
end

local function onEnterStage(player: Player)
	local state = getState(player)
	if not state.Request then
		state.Request = drawRequest(state)
	end
	NotifyService.ToPlayer(
		player,
		"⚡ Baca permintaan Mesin Pusat, cari perangkatnya di labirin, lalu antar ke lantai bercahaya di sekeliling mesin!",
		"info"
	)
	sendState(player, state)
end

function Stage3.Start()
	loadRequests()

	SpawnService.StageChanged:Connect(function(player, newArea, oldArea)
		if newArea == STAGE_ID then
			onEnterStage(player)
		elseif oldArea == STAGE_ID then
			local state = states[player]
			if state then
				removeCarried(state)
			end
		end
	end)

	local function watchPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			-- Barang yang dibawa ikut hilang bersama karakter lama.
			local state = states[player]
			if state then
				state.CarriedModel = nil
				state.Carrying = nil
				if SpawnService.GetArea(player) == STAGE_ID then
					sendState(player, state)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	PointsService.AllReset:Connect(function()
		table.clear(bonusClaimed)
	end)

	task.spawn(function()
		local stages = workspace:WaitForChild(GameConfig.Names.Stages, 15)
		local stageFolder = stages and stages:WaitForChild(STAGE_ID, 15)
		if not (stageFolder and stageFolder:WaitForChild("Machine", 15)) then
			warn("[Stage3] Labirin belum ada. Biasanya dibangun otomatis oleh World > BuildAll — periksa pesan [World] di Output.")
			return
		end
		setupMap(stageFolder)
	end)
end

return Stage3
