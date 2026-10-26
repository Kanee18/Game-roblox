--[[
	Stage4_BandwidthGlider (ModuleScript)
	Lokasi: ServerScriptService > Services > Stages > Stage4_BandwidthGlider
	Materi: Kecepatan Internet & Koneksi

	Alur permainan (setiap siswa terbang sendiri, kapan saja):
	  1. Injak LaunchPad di ujung menara langit -> mulai melayang dengan glider.
	     Siswa terbang maju otomatis dan mengendalikan arah (kiri/kanan, naik/turun).
	  2. Setiap gerbang punya 2 cincin: A dan B. Soal dan jawaban di cincin hanya
	     terlihat oleh siswa itu sendiri (setiap siswa mendapat soal berbeda).
	       Cincin benar   -> +Poin, ⚡ Speed Boost
	       Cincin salah   -> -Poin, 🐢 lemot (diperlambat)
	       Tidak masuk    -> terlewat, juga diperlambat
	  3. Setelah gerbang terakhir, mendarat di pulau akhir -> rekap jawaban + bonus.

	Server memegang kunci jawaban dan menilai cincin yang dilewati.
	Gerakan terbang dijalankan di komputer siswa (Stage4Client) agar mulus.
	Status terbang: Attribute pemain "Gliding" = true/false.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stage4Map = require(ReplicatedStorage.Shared.Stage4Map)
local UiKit = require(ReplicatedStorage.Shared.UiKit)
local QuizBank = require(ServerScriptService:WaitForChild("QuizBank"))

local Services = script.Parent.Parent
local NameService = require(Services.NameService)
local NotifyService = require(Services.NotifyService)
local PointsService = require(Services.PointsService)
local ProgressService = require(Services.ProgressService)
local SpawnService = require(Services.SpawnService)

local STAGE_ID = Stage4Map.StageId
local STAGE = GameConfig.StageById[STAGE_ID]
local CONFIG = GameConfig.Stage4

type Question = {
	Question: string,
	Correct: string,
	Wrong: { string },
	Explanation: string?,
}

type GateResult = {
	Result: string, -- "correct" | "wrong" | "missed"
	Correct: string,
}

type PlayerState = {
	Gliding: boolean,
	Gate: number,
	Deck: { Question },
	Question: Question?,
	Options: { string },
	CorrectSlot: number,
	Results: { GateResult },
	LockedUntil: number,
	Glider: Model?,
}

local Stage4 = {}

local stateRemote = Remotes.Get("Stage4State")
local feedbackRemote = Remotes.Get("Stage4Feedback")
local finishRemote = Remotes.Get("Stage4Finish")

local random = Random.new()
local map: Stage4Map.Map? = nil
local questions: { Question } = {}
local states: { [Player]: PlayerState } = {}
local bonusClaimed: { [number]: boolean } = {}
local lowestY = -math.huge

--------------------------------------------------------------------------------
-- Soal
--------------------------------------------------------------------------------
local function shuffled<T>(list: { T }): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = random:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function loadQuestions()
	for index, item in QuizBank.Stage4 or {} do
		local valid = typeof(item) == "table"
			and typeof(item.Question) == "string"
			and typeof(item.Correct) == "string"
			and typeof(item.Wrong) == "table"
			and #item.Wrong >= 1
		if valid then
			table.insert(questions, item)
		else
			warn(`[Stage4] Soal nomor {index} di QuizBank.Stage4 tidak lengkap, dilewati.`)
		end
	end
	if #questions == 0 then
		warn("[Stage4] QuizBank.Stage4 kosong! Tambahkan soal di ServerScriptService > QuizBank.")
	end
end

local function drawQuestion(state: PlayerState)
	local gate = map and map.Gates[state.Gate]
	if not gate or #questions == 0 then
		state.Question = nil
		state.Options = {}
		state.CorrectSlot = 0
		return
	end
	if #state.Deck == 0 then
		state.Deck = shuffled(questions)
	end
	local question = table.remove(state.Deck) :: Question
	local options = { question.Correct }
	local wrongAnswers = shuffled(question.Wrong)
	for i = 1, math.min(#gate.Rings - 1, #wrongAnswers) do
		table.insert(options, wrongAnswers[i])
	end
	options = shuffled(options)
	state.Question = question
	state.Options = options
	state.CorrectSlot = table.find(options, question.Correct) or 0
end

local function sendState(player: Player, state: PlayerState)
	stateRemote:FireClient(player, {
		Gliding = state.Gliding,
		Gate = state.Gate,
		Total = if map then #map.Gates else 0,
		Question = if state.Question then state.Question.Question else nil,
		Options = state.Options,
	})
end

local function getState(player: Player): PlayerState
	local state = states[player]
	if not state then
		state = {
			Gliding = false,
			Gate = 1,
			Deck = shuffled(questions),
			Question = nil,
			Options = {},
			CorrectSlot = 0,
			Results = {},
			LockedUntil = 0,
			Glider = nil,
		}
		states[player] = state
	end
	return state
end

--------------------------------------------------------------------------------
-- Glider (sayap yang terlihat oleh semua pemain)
--------------------------------------------------------------------------------
-- Dibuat dalam ruang lokal badan: X = rentang sayap, +Y = arah kepala, +Z = punggung.
-- Saat terbang, badan rebah tengkurap, jadi sayap berada di atas punggung.
local function buildGlider(torso: BasePart): Model
	local model = Instance.new("Model")
	model.Name = "Glider"
	local function wingPart(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
		local part = UiKit.new("Part", {
			Name = name,
			Size = size,
			CFrame = torso.CFrame * offset,
			Color = color,
			Material = material,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Massless = true,
			CastShadow = false,
			Parent = model,
		})
		UiKit.new("WeldConstraint", { Part0 = torso, Part1 = part, Parent = part })
	end
	local fabric = Color3.fromRGB(88, 228, 196)
	wingPart("Sayap", Vector3.new(11, 4, 0.2), CFrame.new(0, 0.6, 1.8), fabric, Enum.Material.SmoothPlastic)
	wingPart("UjungKiri", Vector3.new(2.4, 2.6, 0.18), CFrame.new(-6.4, 0.2, 1.75) * CFrame.Angles(0, 0, math.rad(-12)), fabric, Enum.Material.SmoothPlastic)
	wingPart("UjungKanan", Vector3.new(2.4, 2.6, 0.18), CFrame.new(6.4, 0.2, 1.75) * CFrame.Angles(0, 0, math.rad(12)), fabric, Enum.Material.SmoothPlastic)
	wingPart("TepiDepan", Vector3.new(13.5, 0.3, 0.3), CFrame.new(0, 2.65, 1.8), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	wingPart("Rangka", Vector3.new(0.25, 4.2, 0.25), CFrame.new(0, 0.6, 1.6), Color3.fromRGB(60, 64, 72), Enum.Material.Metal)
	return model
end

local function removeGlider(state: PlayerState)
	if state.Glider then
		state.Glider:Destroy()
		state.Glider = nil
	end
end

local function attachGlider(player: Player, state: PlayerState)
	removeGlider(state)
	local character = player.Character
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
	if character and torso and torso:IsA("BasePart") then
		local glider = buildGlider(torso)
		glider.Parent = character
		state.Glider = glider
	end
end

--------------------------------------------------------------------------------
-- Terbang
--------------------------------------------------------------------------------
local function endGlide(player: Player, state: PlayerState)
	state.Gliding = false
	removeGlider(state)
	player:SetAttribute("Gliding", false)
end

local function startGlide(player: Player, state: PlayerState)
	if not map or #map.Gates == 0 then
		NotifyService.ToPlayer(player, "🚧 Lintasan Bandwidth Glider belum dibangun. Beri tahu Guru, ya!", "error")
		return
	end
	state.Gliding = true
	state.Gate = 1
	state.Results = {}
	state.LockedUntil = 0
	drawQuestion(state)
	attachGlider(player, state)
	player:SetAttribute("Gliding", true)
	sendState(player, state)
	NotifyService.ToPlayer(player, "🪂 Terbang! Masuki cincin dengan jawaban yang BENAR untuk Speed Boost.", "portal")
end

local function resolveGate(player: Player, state: PlayerState, result: string, slot: number?)
	local question = state.Question
	if not question then
		return
	end
	if result == "correct" then
		PointsService.Add(player, CONFIG.CorrectPoints, "Bandwidth naik!")
	elseif result == "wrong" then
		PointsService.Add(player, CONFIG.WrongPoints, "Koneksi lemot")
	end
	table.insert(state.Results, { Result = result, Correct = question.Correct })
	feedbackRemote:FireClient(player, {
		Result = result,
		Gate = state.Gate,
		Slot = slot,
		CorrectAnswer = question.Correct,
		Explanation = question.Explanation,
		Effect = if result == "correct" then "Boost" else "Slow",
	})
	state.Gate += 1
	drawQuestion(state)
	sendState(player, state)
end

local function finishFlight(player: Player, state: PlayerState)
	endGlide(player, state)
	ProgressService.MarkComplete(player, STAGE_ID)
	local counts = { correct = 0, wrong = 0, missed = 0 }
	for _, entry in state.Results do
		counts[entry.Result] += 1
	end
	local bonus = 0
	if not (CONFIG.FinishBonusOncePerSession and bonusClaimed[player.UserId]) then
		bonus = CONFIG.FinishBonus
		bonusClaimed[player.UserId] = true
		PointsService.Add(player, bonus, "Mendarat dengan selamat!")
	end
	finishRemote:FireClient(player, {
		Results = state.Results,
		Correct = counts.correct,
		Wrong = counts.wrong,
		Missed = counts.missed,
		Bonus = bonus,
	})
	NotifyService.ToAll(`🪂 {NameService.Get(player)} mendarat di pulau Bandwidth Glider!`, "success")
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

local function onRingTouched(gate: Stage4Map.Gate, ring: Stage4Map.Ring, hit: BasePart)
	local player = getLivingPlayer(hit)
	local state = player and states[player]
	if not (player and state and state.Gliding) or state.Gate ~= gate.Index then
		return
	end
	local now = os.clock()
	if now < state.LockedUntil then
		return
	end
	state.LockedUntil = now + 0.5
	resolveGate(player, state, if ring.Slot == state.CorrectSlot then "correct" else "wrong", ring.Slot)
end

local function onLaunchTouched(hit: BasePart)
	local player = getLivingPlayer(hit)
	if not player or SpawnService.GetArea(player) ~= STAGE_ID then
		return
	end
	local state = getState(player)
	if not state.Gliding then
		startGlide(player, state)
	end
end

local function onLandingTouched(hit: BasePart)
	local player = getLivingPlayer(hit)
	local state = player and states[player]
	if not (player and state and state.Gliding and map) then
		return
	end
	-- Gerbang yang belum dilewati dihitung terlewat.
	while state.Gate <= #map.Gates do
		resolveGate(player, state, "missed")
	end
	finishFlight(player, state)
end

local function onRelaunchTouched(hit: BasePart)
	local player = getLivingPlayer(hit)
	if not player or SpawnService.GetArea(player) ~= STAGE_ID then
		return
	end
	local state = getState(player)
	local spawnPart = SpawnService.GetStageSpawn(STAGE_ID)
	if not state.Gliding and spawnPart then
		SpawnService.TeleportTo(player, spawnPart)
		NotifyService.ToPlayer(player, "🗼 Kembali ke menara. Injak pad 🪂 untuk terbang lagi dengan soal baru!", "info")
	end
end

-- Setiap frame: cek gerbang yang terlewat dan pemain yang jatuh terlalu rendah.
local function watchFlights()
	local currentMap = map
	if not currentMap then
		return
	end
	for player, state in states do
		if not state.Gliding then
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then
			continue
		end
		local gate = currentMap.Gates[state.Gate]
		if gate and (root.Position - gate.Center):Dot(currentMap.Forward) > CONFIG.MissMargin then
			resolveGate(player, state, "missed")
		end
		if root.Position.Y < lowestY then
			endGlide(player, state)
			local spawnPart = SpawnService.GetStageSpawn(STAGE_ID)
			if spawnPart then
				SpawnService.TeleportTo(player, spawnPart)
			end
			NotifyService.ToPlayer(player, "💨 Kamu terbang terlalu rendah! Coba lagi dari menara.", "error")
		end
	end
end

--------------------------------------------------------------------------------
local function setupMap(stageFolder: Instance)
	local currentMap = Stage4Map.Read(stageFolder)
	map = currentMap

	for _, gate in currentMap.Gates do
		if #gate.Rings < 2 then
			warn(`[Stage4] Gerbang {gate.Index} hanya punya {#gate.Rings} cincin (butuh 2).`)
		end
		for _, ring in gate.Rings do
			ring.Trigger.CanCollide = false
			ring.Trigger.CanTouch = true
			ring.Trigger.Transparency = 1
			ring.Trigger.Touched:Connect(function(hit)
				onRingTouched(gate, ring, hit)
			end)
		end
	end

	if currentMap.LaunchPad then
		currentMap.LaunchPad.Touched:Connect(onLaunchTouched)
	else
		warn('[Stage4] Part "LaunchPad" tidak ditemukan.')
	end
	if currentMap.Landing then
		currentMap.Landing.CanCollide = false
		currentMap.Landing.Touched:Connect(onLandingTouched)
		lowestY = currentMap.Landing.Position.Y - 60
	else
		warn('[Stage4] Part "LandingZone" tidak ditemukan.')
	end
	for _, descendant in stageFolder:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == "Relaunch" then
			descendant.Touched:Connect(onRelaunchTouched)
		end
	end

	RunService.Heartbeat:Connect(watchFlights)
	print(`[Stage4] Bandwidth Glider siap: {#currentMap.Gates} gerbang, {#questions} soal.`)
end

function Stage4.Start()
	loadQuestions()

	SpawnService.StageChanged:Connect(function(player, newArea, oldArea)
		if newArea == STAGE_ID then
			local state = getState(player)
			sendState(player, state)
			NotifyService.ToPlayer(player, `{STAGE.ElementIcon} Injak pad 🪂 di ujung menara untuk mulai terbang!`, "info")
		elseif oldArea == STAGE_ID then
			local state = states[player]
			if state and state.Gliding then
				endGlide(player, state)
			end
		end
	end)

	local function watchPlayer(player: Player)
		player:SetAttribute("Gliding", false)
		player.CharacterAdded:Connect(function()
			local state = states[player]
			if state and state.Gliding then
				endGlide(player, state)
				sendState(player, state)
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
		if not (stageFolder and stageFolder:WaitForChild("Gates", 15)) then
			warn("[Stage4] Lintasan belum ada. Biasanya dibangun otomatis oleh World > BuildAll — periksa pesan [World] di Output.")
			return
		end
		setupMap(stageFolder)
	end)
end

return Stage4
