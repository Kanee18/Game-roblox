--[[
	Stage1_RoutingRunner (ModuleScript)
	Lokasi: ServerScriptService > Services > Stages > Stage1_RoutingRunner
	Materi: Dasar Jaringan & LAN/WAN

	Alur permainan:
	  1. Siswa melewati rintangan parkour sampai ke "Gerbang Router".
	  2. Papan soal dan 3 pintu (A/B/C) menampilkan soal MILIK SISWA ITU SENDIRI
	     (setiap siswa mendapat soal & urutan jawaban acak yang berbeda).
	  3. Pintu BENAR  -> +Poin, checkpoint baru, soal berikutnya.
	     Pintu SALAH  -> -Poin, siswa gugur, respawn di checkpoint terakhir,
	                     dan mendapat SOAL BARU (tidak bisa coba-coba pintu).
	  4. Setelah semua gerbang, siswa menyentuh "Finish" untuk bonus Poin.

	Kunci jawaban hanya ada di server; client hanya menerima teks soal & pilihan.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stage1Map = require(ReplicatedStorage.Shared.Stage1Map)
local QuizBank = require(ServerScriptService:WaitForChild("QuizBank"))

local Services = script.Parent.Parent
local NameService = require(Services.NameService)
local NotifyService = require(Services.NotifyService)
local PointsService = require(Services.PointsService)
local ProgressService = require(Services.ProgressService)
local SpawnService = require(Services.SpawnService)

local STAGE_ID = Stage1Map.StageId
local CONFIG = GameConfig.Stage1

type Question = {
	Question: string,
	Correct: string,
	Wrong: { string },
	Explanation: string?,
}

type RunState = {
	Section: number, -- gerbang yang sedang dihadapi (1..jumlah gerbang); > jumlah = semua sudah lewat
	Deck: { Question }, -- sisa soal yang belum keluar untuk siswa ini
	Question: Question?,
	Options: { string }, -- teks jawaban sesuai urutan pintu (A, B, C)
	CorrectSlot: number,
	LockedUntil: number,
	CorrectCount: number,
	WrongCount: number,
	Finished: boolean,
}

local Stage1 = {}

local questionRemote = Remotes.Get("Stage1Question")
local feedbackRemote = Remotes.Get("Stage1Feedback")
local finishRemote = Remotes.Get("Stage1Finish")

local random = Random.new()
local sections: { Stage1Map.Section } = {}
local questions: { Question } = {}
local states: { [Player]: RunState } = {}
local bonusClaimed: { [number]: boolean } = {} -- UserId -> sudah dapat bonus finish

local function shuffled<T>(list: { T }): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = random:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function loadQuestions()
	for index, item in QuizBank.Stage1 or {} do
		local valid = typeof(item) == "table"
			and typeof(item.Question) == "string"
			and typeof(item.Correct) == "string"
			and typeof(item.Wrong) == "table"
			and #item.Wrong >= 1
		if valid then
			table.insert(questions, item)
		else
			warn(`[Stage1] Soal nomor {index} di QuizBank.Stage1 tidak lengkap, dilewati.`)
		end
	end
	if #questions == 0 then
		warn("[Stage1] QuizBank.Stage1 kosong! Tambahkan soal di ServerScriptService > QuizBank.")
	end
end

local function newRun(previous: RunState?): RunState
	return {
		Section = 1,
		-- Lanjutkan tumpukan soal lama agar putaran berikutnya mendapat soal lain.
		Deck = if previous then previous.Deck else shuffled(questions),
		Question = nil,
		Options = {},
		CorrectSlot = 0,
		LockedUntil = 0,
		CorrectCount = 0,
		WrongCount = 0,
		Finished = false,
	}
end

-- Mengambil soal baru untuk gerbang yang sedang dihadapi, lalu mengacak pintunya.
local function drawQuestion(state: RunState)
	local section = sections[state.Section]
	if not section or #questions == 0 then
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
	for i = 1, math.min(#section.Doors - 1, #wrongAnswers) do
		table.insert(options, wrongAnswers[i])
	end
	options = shuffled(options)

	state.Question = question
	state.Options = options
	state.CorrectSlot = table.find(options, question.Correct) or 0
end

local function sendState(player: Player, state: RunState)
	questionRemote:FireClient(player, {
		Section = state.Section,
		Total = #sections,
		Question = if state.Question then state.Question.Question else nil,
		Options = state.Options,
	})
end

local function getLivingPlayer(hit: BasePart): (Player?, Humanoid?)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if player and humanoid and humanoid.Health > 0 then
		return player, humanoid
	end
	return nil, nil
end

local function onCorrect(player: Player, state: RunState, section: Stage1Map.Section, slot: number)
	local question = state.Question :: Question
	state.CorrectCount += 1
	PointsService.Add(player, CONFIG.CorrectPoints, "Jawaban benar!")
	if section.Checkpoint then
		SpawnService.SetRespawn(player, section.Checkpoint)
	end
	feedbackRemote:FireClient(player, {
		Correct = true,
		Section = section.Index,
		Slot = slot,
		CorrectAnswer = question.Correct,
		Explanation = question.Explanation,
		IsLast = section.Index == #sections,
	})

	state.Section += 1
	drawQuestion(state)
	sendState(player, state)
end

local function onWrong(player: Player, humanoid: Humanoid, state: RunState, section: Stage1Map.Section, slot: number)
	local question = state.Question :: Question
	state.WrongCount += 1
	PointsService.Add(player, CONFIG.WrongPoints, "Jawaban salah")
	feedbackRemote:FireClient(player, {
		Correct = false,
		Section = section.Index,
		Slot = slot,
		Chosen = state.Options[slot],
		CorrectAnswer = question.Correct,
		Explanation = question.Explanation,
	})
	humanoid.Health = 0 -- gugur, respawn di checkpoint terakhir (SpawnService)

	-- Soal baru untuk percobaan berikutnya, supaya tidak bisa menebak dengan eliminasi.
	drawQuestion(state)
	sendState(player, state)
end

local function onDoorTouched(section: Stage1Map.Section, slot: number, hit: BasePart)
	local player, humanoid = getLivingPlayer(hit)
	if not (player and humanoid) or SpawnService.GetArea(player) ~= STAGE_ID then
		return
	end
	local state = states[player]
	-- Pintu gerbang yang sudah dilewati (atau belum dicapai) diabaikan.
	if not state or not state.Question or state.Section ~= section.Index then
		return
	end
	local now = os.clock()
	if now < state.LockedUntil then
		return
	end
	state.LockedUntil = now + CONFIG.DoorCooldown

	if slot == state.CorrectSlot then
		onCorrect(player, state, section, slot)
	else
		onWrong(player, humanoid, state, section, slot)
	end
end

local function onFinishTouched(hit: BasePart)
	local player = getLivingPlayer(hit)
	if not player or SpawnService.GetArea(player) ~= STAGE_ID then
		return
	end
	local state = states[player]
	if not state or state.Finished or state.Section <= #sections then
		return
	end
	state.Finished = true
	ProgressService.MarkComplete(player, STAGE_ID)

	local bonus = 0
	if not (CONFIG.FinishBonusOncePerSession and bonusClaimed[player.UserId]) then
		bonus = CONFIG.FinishBonus
		bonusClaimed[player.UserId] = true
		PointsService.Add(player, bonus, "Finish Routing Runner!")
	end
	finishRemote:FireClient(player, {
		Correct = state.CorrectCount,
		Wrong = state.WrongCount,
		Bonus = bonus,
	})
	NotifyService.ToAll(`🏁 {NameService.Get(player)} berhasil menyelesaikan Routing Runner!`, "success")
end

local function onEnterStage(player: Player)
	if #sections == 0 then
		NotifyService.ToPlayer(player, "🚧 Lintasan Routing Runner belum dibangun. Beri tahu Guru, ya!", "error")
		return
	end

	local state = states[player]
	if not state or state.Finished then
		state = newRun(state)
		states[player] = state
	elseif state.Section > 1 then
		-- Pernah bermain lalu kembali ke Lobby: lanjutkan dari checkpoint terakhir.
		local passedSection = sections[state.Section - 1]
		local checkpoint = passedSection and passedSection.Checkpoint
		if checkpoint then
			SpawnService.SetRespawn(player, checkpoint)
			SpawnService.TeleportTo(player, checkpoint)
			NotifyService.ToPlayer(player, `📍 Melanjutkan dari Gerbang Router {state.Section - 1}.`, "info")
		end
	end

	if not state.Question then
		drawQuestion(state)
	end
	sendState(player, state)
end

local function setupMap(stageFolder: Instance)
	sections = Stage1Map.Read(stageFolder)
	for _, section in sections do
		if #section.Doors < 2 then
			warn(`[Stage1] Gerbang {section.Index} hanya punya {#section.Doors} pintu (butuh minimal 2).`)
		end
		if not section.Checkpoint then
			warn(`[Stage1] Gerbang {section.Index} belum punya Part "Checkpoint".`)
		end
		for _, door in section.Doors do
			door.Trigger.CanCollide = false
			door.Trigger.CanTouch = true
			door.Trigger.Touched:Connect(function(hit)
				onDoorTouched(section, door.Slot, hit)
			end)
		end
	end

	local finish = stageFolder:FindFirstChild("Finish", true)
	if finish and finish:IsA("BasePart") then
		finish.Touched:Connect(onFinishTouched)
	else
		warn('[Stage1] Part "Finish" tidak ditemukan di Workspace > Stages > Stage1.')
	end
	print(`[Stage1] Routing Runner siap: {#sections} gerbang, {#questions} soal.`)
end

function Stage1.Start()
	loadQuestions()

	SpawnService.StageChanged:Connect(function(player, newArea)
		if newArea == STAGE_ID then
			onEnterStage(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	PointsService.AllReset:Connect(function()
		table.clear(bonusClaimed)
	end)

	task.spawn(function()
		local stages = workspace:WaitForChild(GameConfig.Names.Stages, 15)
		local stageFolder = stages and stages:WaitForChild(STAGE_ID, 15)
		if not (stageFolder and stageFolder:WaitForChild("Sections", 15)) then
			warn("[Stage1] Lintasan belum ada. Biasanya dibangun otomatis oleh World > BuildAll — periksa pesan [World] di Output.")
			return
		end
		setupMap(stageFolder)
	end)
end

return Stage1
