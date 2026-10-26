--[[
	Stage2_FirewallDefender (ModuleScript)
	Lokasi: ServerScriptService > Services > Stages > Stage2_FirewallDefender
	Materi: Keamanan Data & Virus

	Alur permainan (bergelombang, dimainkan bersama satu kelas):
	  1. Jeda singkat: "Gelombang N segera datang!"
	  2. Soal muncul di papan langit. 4 virus keluar dari Gerbang Virus, masing-masing
	     membawa satu jawaban, lalu melayang di jalurnya menuju Inti Server.
	  3. Setiap siswa memegang Tongkat Firewall. Virus PERTAMA yang terkena
	     tembakanmu = jawabanmu (terkunci untuk gelombang ini).
	       Benar -> +Poin (+ bonus cepat)      Salah -> -Poin
	     Hasil hanya terlihat oleh penembaknya, jadi tidak bisa menyontek.
	  4. Gelombang berakhir saat semua siswa sudah menjawab, atau saat virus pembawa
	     jawaban benar sampai di Inti Server.
	  5. Pengumuman: jawaban benar + penjelasan. Jika kurang dari separuh kelas
	     menjawab benar, virus menembus firewall dan Inti Server kehilangan 1 nyawa.

	Kunci jawaban hanya ada di server. Model virus tidak menyimpan tanda benar/salah.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(ReplicatedStorage.Shared.UiKit)
local QuizBank = require(ServerScriptService:WaitForChild("QuizBank"))

local Services = script.Parent.Parent
local NameService = require(Services.NameService)
local NotifyService = require(Services.NotifyService)
local PointsService = require(Services.PointsService)
local ProgressService = require(Services.ProgressService)
local SpawnService = require(Services.SpawnService)

local STAGE_ID = "Stage2"
local STAGE = GameConfig.StageById[STAGE_ID]
local CONFIG = GameConfig.Stage2
local Theme = GameConfig.Theme

local VIRUS_COLORS = {
	Color3.fromRGB(170, 85, 255),
	Color3.fromRGB(90, 210, 110),
	Color3.fromRGB(255, 80, 130),
	Color3.fromRGB(80, 160, 255),
	Color3.fromRGB(255, 170, 60),
}

type Question = {
	Question: string,
	Correct: string,
	Wrong: { string },
	Explanation: string?,
}

type Monster = {
	Model: Model,
	Root: BasePart,
	Velocity: LinearVelocity,
	Align: AlignOrientation,
	Path: { Vector3 },
	Waypoint: number,
	Speed: number,
	Answer: string,
	IsCorrect: boolean,
	Card: Frame,
	Label: TextLabel,
	Stopped: boolean, -- sudah sampai ujung jalur / sedang diumumkan (tetap bisa ditembak selama gelombang aktif)
}

local Stage2 = {}

local shootRemote = Remotes.Get("Stage2Shoot")
local feedbackRemote = Remotes.Get("Stage2Feedback")

-- Status gelombang untuk semua client: ReplicatedStorage > GameState > Stage2 (Attribute)
local stateFolder = Remotes.GetState():FindFirstChild(STAGE_ID)
if not stateFolder then
	stateFolder = Instance.new("Folder")
	stateFolder.Name = STAGE_ID
	stateFolder.Parent = Remotes.GetState()
end

local random = Random.new()
local questions: { Question } = {}
local deck: { Question } = {}

local lanes: { { Vector3 } } = {}
local monstersFolder: Folder? = nil
local monsterTemplate: Model? = nil
local coreFocus: BasePart? = nil
local coreLabel: TextLabel? = nil
local sky: { Header: TextLabel, Body: TextLabel, Footer: TextLabel }? = nil

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include

local monsters: { [Model]: Monster } = {}
local lastShotAt: { [Player]: number } = {}

local round = {
	Wave = 0,
	Token = 0,
	Active = false,
	Question = nil :: Question?,
	StartedAt = 0,
	Answers = {} :: { [Player]: { Correct: boolean, Answer: string } },
	EndReason = nil :: string?,
}
local coreHP = CONFIG.CoreMaxHP
local loopRunning = false

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
	for index, item in QuizBank.Stage2 or {} do
		local valid = typeof(item) == "table"
			and typeof(item.Question) == "string"
			and typeof(item.Correct) == "string"
			and typeof(item.Wrong) == "table"
		if valid then
			local wrong = {}
			for _, answer in item.Wrong do
				if typeof(answer) == "string" and answer ~= item.Correct then
					table.insert(wrong, answer)
				end
			end
			valid = #wrong >= 1
			item.Wrong = wrong
		end
		if valid then
			table.insert(questions, item)
		else
			warn(`[Stage2] Soal nomor {index} di QuizBank.Stage2 tidak lengkap, dilewati.`)
		end
	end
	if #questions == 0 then
		warn("[Stage2] QuizBank.Stage2 kosong! Tambahkan soal di ServerScriptService > QuizBank.")
	end
end

local function drawQuestion(): Question?
	if #questions == 0 then
		return nil
	end
	if #deck == 0 then
		deck = shuffled(questions)
	end
	return table.remove(deck)
end

--------------------------------------------------------------------------------
-- Pemain
--------------------------------------------------------------------------------
local function playersInStage(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if SpawnService.GetArea(player) == STAGE_ID then
			table.insert(list, player)
		end
	end
	return list
end

-- Siswa yang ditunggu jawabannya (Guru tidak dihitung).
local function requiredPlayers(): { Player }
	local list = {}
	for _, player in playersInStage() do
		if player:GetAttribute("IsAdmin") ~= true then
			table.insert(list, player)
		end
	end
	return list
end

--------------------------------------------------------------------------------
-- Papan langit & Inti Server
--------------------------------------------------------------------------------
local function heartsText(hp: number): string
	hp = math.clamp(hp, 0, CONFIG.CoreMaxHP)
	return string.rep("❤️", hp) .. string.rep("🖤", CONFIG.CoreMaxHP - hp)
end

local function updateBoards()
	local phase = stateFolder:GetAttribute("Phase")
	local hearts = heartsText(coreHP)
	if coreLabel then
		coreLabel.Text = `🛡️ INTI SERVER\n{hearts}`
	end
	if not sky then
		return
	end

	if phase == "Question" then
		sky.Header.Text = `🔥 GELOMBANG {round.Wave} · 🛡️ {hearts}`
		sky.Body.Text = if round.Question then round.Question.Question else ""
		local answered = stateFolder:GetAttribute("Answered") or 0
		local required = stateFolder:GetAttribute("Required") or 0
		sky.Footer.Text = `🎯 Tembak virus pembawa jawaban BENAR! · Sudah menjawab: {answered}/{required}`
	elseif phase == "Reveal" then
		sky.Header.Text = `🔥 GELOMBANG {round.Wave} · 🛡️ {hearts}`
		sky.Body.Text = `✅ Jawaban: {stateFolder:GetAttribute("RevealAnswer") or ""}`
		local total = stateFolder:GetAttribute("RevealTotal") or 0
		local verdict = if stateFolder:GetAttribute("CoreHit") then "💥 Virus menembus firewall!" else "🛡️ Firewall bertahan!"
		sky.Footer.Text = if total > 0
			then `{stateFolder:GetAttribute("RevealCorrect")}/{total} siswa menjawab benar · {verdict}`
			else verdict
	elseif phase == "Intermission" then
		sky.Header.Text = `🔥 FIREWALL DEFENDER · 🛡️ {hearts}`
		sky.Body.Text = `Gelombang {round.Wave + 1} segera datang! Bersiap…`
		sky.Footer.Text = "Baca soal di langit, lalu tembak virus yang membawa jawaban benar."
	else
		sky.Header.Text = "🔥 FIREWALL DEFENDER"
		sky.Body.Text = "Menunggu pemain masuk…"
		sky.Footer.Text = ""
	end
end

local function setPhase(phase: string, duration: number?)
	stateFolder:SetAttribute("PhaseEndsAt", if duration then workspace:GetServerTimeNow() + duration else 0)
	stateFolder:SetAttribute("Phase", phase)
	updateBoards()
end

local function buildSkyBoard(part: BasePart)
	local old = part:FindFirstChild("SkyBoardGui")
	if old then
		old:Destroy()
	end
	local gui = UiKit.new("SurfaceGui", {
		Name = "SkyBoardGui",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 25,
		LightInfluence = 0,
		Brightness = 1.4,
		Parent = part,
	})
	local card = UiKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Night,
		BackgroundTransparency = 0.05,
		Parent = gui,
	}, { UiKit.corner(30), UiKit.stroke(STAGE.Color, 8), UiKit.padding(24) })

	sky = {
		Header = UiKit.label({
			Size = UDim2.fromScale(1, 0.2),
			TextScaled = true,
			TextColor3 = Theme.GoldBright,
			Parent = card,
		}, { UiKit.new("UITextSizeConstraint", { MaxTextSize = 70 }) }),
		Body = UiKit.label({
			Position = UDim2.fromScale(0, 0.23),
			Size = UDim2.fromScale(1, 0.55),
			Font = Theme.FontBold,
			TextScaled = true,
			Parent = card,
		}, { UiKit.new("UITextSizeConstraint", { MaxTextSize = 90 }) }),
		Footer = UiKit.label({
			Position = UDim2.fromScale(0, 0.8),
			Size = UDim2.fromScale(1, 0.2),
			Font = Theme.FontBold,
			TextScaled = true,
			TextColor3 = Theme.Cream,
			Parent = card,
		}, { UiKit.new("UITextSizeConstraint", { MaxTextSize = 50 }) }),
	}
end

local function buildCoreLabel(part: BasePart)
	local billboard = UiKit.new("BillboardGui", {
		Name = "CoreLabel",
		Adornee = part,
		-- Ukuran campuran (stud + piksel): ikut mengecil di kejauhan, tetap terbaca di HP.
		Size = UDim2.new(12, 80, 3.5, 24),
		StudsOffsetWorldSpace = Vector3.new(0, 8, 0),
		LightInfluence = 0,
		MaxDistance = 200,
		Parent = part,
	})
	coreLabel = UiKit.label({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = Theme.Night,
		TextScaled = true,
		TextColor3 = Theme.White,
		Parent = billboard,
	}, { UiKit.corner(14), UiKit.stroke(Color3.fromRGB(90, 220, 255), 2), UiKit.padding(6) })
end

--------------------------------------------------------------------------------
-- Tongkat Firewall (senjata)
--------------------------------------------------------------------------------
local function createWand(): Tool
	local tool = Instance.new("Tool")
	tool.Name = CONFIG.ToolName
	tool.ToolTip = "Tongkat Firewall: klik virus untuk menembak"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	-- Pegangan seperti pedang yang diacungkan ke depan.
	tool.Grip = CFrame.new(0, 0, -1.2, 0, 1, 0, 1, 0, 0, 0, 0, -1)

	local handle = UiKit.new("Part", {
		Name = "Handle",
		Size = Vector3.new(0.45, 0.45, 3.6),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(96, 62, 40),
		CanCollide = false,
		Massless = true,
		CFrame = CFrame.new(),
		Parent = tool,
	})
	local tip = UiKit.new("Part", {
		Name = "Tip",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1, 1, 1),
		Material = Enum.Material.Neon,
		Color = STAGE.Color,
		CanCollide = false,
		Massless = true,
		CFrame = CFrame.new(0, 0, -2.1),
		Parent = tool,
	})
	local ring = UiKit.new("Part", {
		Name = "Ring",
		Size = Vector3.new(0.8, 0.8, 0.25),
		Material = Enum.Material.Neon,
		Color = Theme.GoldBright,
		CanCollide = false,
		Massless = true,
		CFrame = CFrame.new(0, 0, -1.5),
		Parent = tool,
	})
	for _, part in { tip, ring } do
		UiKit.new("WeldConstraint", { Part0 = handle, Part1 = part, Parent = part })
	end
	UiKit.new("Fire", {
		Size = 2,
		Heat = 4,
		Color = STAGE.Color,
		SecondaryColor = Theme.GoldBright,
		Parent = tip,
	})
	UiKit.new("PointLight", { Color = STAGE.Color, Range = 8, Brightness = 1.5, Parent = tip })
	return tool
end

local function findWand(player: Player): Tool?
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		local tool = container and container:FindFirstChild(CONFIG.ToolName)
		if tool and tool:IsA("Tool") then
			return tool
		end
	end
	return nil
end

local function giveWand(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	if not (backpack and character) or findWand(player) then
		return
	end
	local tool = createWand()
	tool.Parent = backpack
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:EquipTool(tool)
	end
end

local function removeWand(player: Player)
	local tool = findWand(player)
	while tool do
		tool:Destroy()
		tool = findWand(player)
	end
end

--------------------------------------------------------------------------------
-- Virus
--------------------------------------------------------------------------------
-- Mengelas semua part ke PrimaryPart, mematikan tabrakan, dan menambah Hitbox.
local function prepareTemplate(model: Model): Model?
	local root = model.PrimaryPart
	if not root then
		warn(`[Stage2] Model virus "{model.Name}" belum punya PrimaryPart.`)
		return nil
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			if descendant ~= root then
				descendant.Massless = true
				UiKit.new("WeldConstraint", { Part0 = root, Part1 = descendant, Parent = descendant })
			end
		end
	end
	if not model:FindFirstChild("Hitbox") then
		-- Bola tak terlihat yang sedikit lebih besar dari virus: lebih mudah dibidik.
		local _, size = model:GetBoundingBox()
		local diameter = math.max(size.X, size.Y, size.Z) + 1
		local hitbox = UiKit.new("Part", {
			Name = "Hitbox",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(diameter, diameter, diameter),
			CFrame = root.CFrame,
			Transparency = 1,
			CanCollide = false,
			CanTouch = false,
			Massless = true,
			Parent = model,
		})
		UiKit.new("WeldConstraint", { Part0 = root, Part1 = hitbox, Parent = hitbox })
	end
	return model
end

-- Virus bawaan: bola berduri dengan dua mata, menghadap -Z.
local function buildVirusTemplate(): Model
	local model = Instance.new("Model")
	model.Name = "Virus"
	local body = UiKit.new("Part", {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6, 6, 6),
		Material = Enum.Material.SmoothPlastic,
		CFrame = CFrame.new(),
		Parent = model,
	})
	model.PrimaryPart = body

	local SPIKES = 12
	for i = 1, SPIKES do
		local y = 1 - (i - 0.5) / SPIKES * 2
		local radius = math.sqrt(1 - y * y)
		local angle = i * 2.39996 -- sudut emas: duri tersebar merata
		local pointing = CFrame.lookAt(Vector3.zero, Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius))
		UiKit.new("Part", {
			Name = "Spike",
			Size = Vector3.new(0.7, 0.7, 2.2),
			Material = Enum.Material.SmoothPlastic,
			CFrame = pointing * CFrame.new(0, 0, -3.3),
			Parent = model,
		})
		UiKit.new("Part", {
			Name = "Tip",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.1, 1.1, 1.1),
			Material = Enum.Material.Neon,
			CFrame = pointing * CFrame.new(0, 0, -4.5),
			Parent = model,
		})
	end

	for _, side in { -1, 1 } do
		UiKit.new("Part", {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.6, 1.6, 1.6),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.new(1, 1, 1),
			CFrame = CFrame.new(side * 1.1, 0.7, -2.55),
			Parent = model,
		})
		UiKit.new("Part", {
			Name = "Pupil",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.75, 0.75, 0.75),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(20, 20, 30),
			CFrame = CFrame.new(side * 1.1, 0.7, -3.25),
			Parent = model,
		})
	end

	return prepareTemplate(model) :: Model
end

local function makeAnswerLabel(root: BasePart, answer: string, color: Color3): (Frame, TextLabel)
	local billboard = UiKit.new("BillboardGui", {
		Name = "AnswerLabel",
		Adornee = root,
		-- Ukuran campuran (stud + piksel): label virus yang jauh ikut mengecil sehingga
		-- tidak saling menumpuk di layar HP, tapi tidak pernah lebih kecil dari 40x14 piksel.
		Size = UDim2.new(10, 40, 2.5, 14),
		StudsOffsetWorldSpace = Vector3.new(0, CONFIG.LabelHeight, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 400,
		Parent = root,
	})
	-- Latar label berwarna sama dengan virusnya (dan dengan kotak jawaban di panel layar).
	local card = UiKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color:Lerp(Theme.Night, 0.3),
		Parent = billboard,
	}, { UiKit.corner(UDim.new(0.25, 0)), UiKit.stroke(Theme.Cream, 2) })
	local label = UiKit.label({
		Size = UDim2.fromScale(1, 1),
		Text = answer,
		Font = Theme.FontBold,
		TextScaled = true,
		TextColor3 = Theme.White,
		Parent = card,
	}, {
		UiKit.new("UIPadding", {
			PaddingLeft = UDim.new(0.04, 0),
			PaddingRight = UDim.new(0.04, 0),
			PaddingTop = UDim.new(0.1, 0),
			PaddingBottom = UDim.new(0.1, 0),
		}),
		UiKit.textStroke(Theme.Night, 1),
	})
	return card, label
end

-- color: warna virus. Diacak tiap gelombang dan TIDAK berhubungan dengan benar/salah.
local function spawnMonster(path: { Vector3 }, answer: string, isCorrect: boolean, speed: number, color: Color3)
	if not (monsterTemplate and monstersFolder) then
		return
	end
	local model = monsterTemplate:Clone()
	local root = model.PrimaryPart :: BasePart

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			if part.Name == "Body" or part.Name == "Spike" then
				part.Color = color
			elseif part.Name == "Tip" then
				part.Color = color:Lerp(Color3.new(1, 1, 1), 0.45)
			end
		end
	end

	local facing = Vector3.new(path[2].X - path[1].X, 0, path[2].Z - path[1].Z)
	if facing.Magnitude < 0.01 then
		facing = Vector3.new(0, 0, 1)
	end
	model:PivotTo(CFrame.lookAt(path[1], path[1] + facing))

	local attachment = UiKit.new("Attachment", { Parent = root })
	local velocity = UiKit.new("LinearVelocity", {
		Attachment0 = attachment,
		MaxForce = 1e7,
		VelocityConstraintMode = Enum.VelocityConstraintMode.Vector,
		RelativeTo = Enum.ActuatorRelativeTo.World,
		VectorVelocity = Vector3.zero,
		Parent = root,
	})
	local align = UiKit.new("AlignOrientation", {
		Mode = Enum.OrientationAlignmentMode.OneAttachment,
		Attachment0 = attachment,
		RigidityEnabled = true,
		CFrame = CFrame.lookAt(Vector3.zero, facing),
		Parent = root,
	})
	local card, label = makeAnswerLabel(root, answer, color)

	model.Parent = monstersFolder
	pcall(root.SetNetworkOwner, root, nil) -- server yang menggerakkan, gerakan mulus di semua client

	monsters[model] = {
		Model = model,
		Root = root,
		Velocity = velocity,
		Align = align,
		Path = path,
		Waypoint = 2,
		Speed = speed,
		Answer = answer,
		IsCorrect = isCorrect,
		Card = card,
		Label = label,
		Stopped = false,
	}
end

-- Dipanggil setiap frame: arahkan virus ke titik jalur berikutnya.
local function stepMonsters(deltaTime: number)
	for _, monster in monsters do
		if monster.Stopped then
			continue
		end
		local target = monster.Path[monster.Waypoint]
		local offset = target - monster.Root.Position
		local distance = offset.Magnitude
		if distance <= math.max(1.5, monster.Speed * deltaTime * 1.5) then
			monster.Waypoint += 1
			if monster.Waypoint > #monster.Path then
				-- Sampai di depan firewall: berhenti melayang di sana.
				monster.Stopped = true
				monster.Velocity.VectorVelocity = Vector3.zero
				if monster.IsCorrect and round.Active then
					round.EndReason = round.EndReason or "Arrived"
				end
			end
		else
			local direction = offset / distance
			monster.Velocity.VectorVelocity = direction * monster.Speed
			local flat = Vector3.new(direction.X, 0, direction.Z)
			if flat.Magnitude > 0.05 then
				monster.Align.CFrame = CFrame.lookAt(Vector3.zero, flat)
			end
		end
	end
end

local function explodeAt(position: Vector3)
	local explosion = Instance.new("Explosion")
	explosion.BlastPressure = 0 -- hanya efek visual, tidak melukai siapa pun
	explosion.BlastRadius = 6
	explosion.DestroyJointRadiusPercent = 0
	explosion.ExplosionType = Enum.ExplosionType.NoCraters
	explosion.Position = position
	explosion.Parent = workspace
end

local function clearMonsters()
	for model in monsters do
		model:Destroy()
	end
	table.clear(monsters)
end

--------------------------------------------------------------------------------
-- Menembak
--------------------------------------------------------------------------------
local function findMonster(hitPart: Instance): Monster?
	local current: Instance? = hitPart
	while current and current.Parent ~= monstersFolder do
		current = current.Parent
	end
	return if current then monsters[current :: Model] else nil
end

local function lockAnswer(player: Player, monster: Monster)
	local elapsed = os.clock() - round.StartedAt
	if monster.IsCorrect then
		local bonus = math.clamp(
			math.floor(CONFIG.SpeedBonusMax * (1 - elapsed / CONFIG.SpeedBonusWindow) + 0.5),
			0,
			CONFIG.SpeedBonusMax
		)
		local reason = if bonus > 0 then `Tepat sasaran! (bonus cepat +{bonus})` else "Tepat sasaran!"
		PointsService.Add(player, CONFIG.CorrectPoints + bonus, reason)
	else
		PointsService.Add(player, CONFIG.WrongPoints, "Salah sasaran")
	end
	round.Answers[player] = { Correct = monster.IsCorrect, Answer = monster.Answer }

	-- Tahap 2 tidak punya garis finish: selesai setelah menjawab sejumlah gelombang.
	local answered = ProgressService.CountAnswer(player, STAGE_ID)
	if answered >= CONFIG.WavesToComplete and ProgressService.MarkComplete(player, STAGE_ID) then
		NotifyService.ToPlayer(
			player,
			`🏅 Tahap 2 selesai! Kamu sudah menjawab {answered} gelombang. Lanjutkan untuk menambah Poin.`,
			"success"
		)
		NotifyService.ToAll(`🛡️ {NameService.Get(player)} menyelesaikan Firewall Defender!`, "success")
	end
	feedbackRemote:FireClient(player, {
		Wave = round.Wave,
		Correct = monster.IsCorrect,
		Answer = monster.Answer,
		Position = monster.Root.Position,
	})
end

local function onShoot(player: Player, target: any)
	if typeof(target) ~= "Vector3" or not round.Active or round.Answers[player] then
		return
	end
	if SpawnService.GetArea(player) ~= STAGE_ID then
		return
	end
	local now = os.clock()
	if (lastShotAt[player] or 0) + CONFIG.FireCooldown * 0.8 > now then
		return
	end
	lastShotAt[player] = now

	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (head and head:IsA("BasePart") and humanoid and humanoid.Health > 0) then
		return
	end
	if not character:FindFirstChild(CONFIG.ToolName) then
		return -- harus sedang memegang Tongkat Firewall
	end

	-- Server menghitung ulang tembakan dari kepala pemain (bukan percaya client).
	local toTarget = target - head.Position
	if toTarget.Magnitude < 1 then
		return
	end
	local result = workspace:Raycast(head.Position, toTarget.Unit * CONFIG.MaxRange, raycastParams)
	local monster = result and findMonster(result.Instance)
	if monster then
		lockAnswer(player, monster)
	end
end

--------------------------------------------------------------------------------
-- Gelombang
--------------------------------------------------------------------------------
local function waitForWaveEnd(token: number)
	local deadline = os.clock() + CONFIG.MaxWaveTime
	while round.Token == token and not round.EndReason do
		if #playersInStage() == 0 then
			round.EndReason = "Empty"
			break
		end

		local required = requiredPlayers()
		local answered = 0
		for _, player in required do
			if round.Answers[player] then
				answered += 1
			end
		end
		if answered ~= stateFolder:GetAttribute("Answered") or #required ~= stateFolder:GetAttribute("Required") then
			stateFolder:SetAttribute("Answered", answered)
			stateFolder:SetAttribute("Required", #required)
			updateBoards()
		end

		if #required > 0 and answered >= #required then
			round.EndReason = "AllAnswered"
		elseif os.clock() > deadline then
			round.EndReason = "Timeout"
		else
			task.wait(0.25)
		end
	end
end

local function reveal()
	local question = round.Question :: Question
	local required = requiredPlayers()
	local correctCount = 0
	for _, player in required do
		local answer = round.Answers[player]
		if answer and answer.Correct then
			correctCount += 1
		end
	end
	local total = #required
	local coreHit = total > 0 and correctCount / total < CONFIG.CoreMinCorrectRatio
	if coreHit then
		coreHP -= 1
	end
	local breached = coreHP <= 0

	stateFolder:SetAttribute("RevealAnswer", question.Correct)
	stateFolder:SetAttribute("RevealExplanation", question.Explanation or "")
	stateFolder:SetAttribute("RevealCorrect", correctCount)
	stateFolder:SetAttribute("RevealTotal", total)
	stateFolder:SetAttribute("CoreHit", coreHit)
	stateFolder:SetAttribute("CoreBreached", breached)
	stateFolder:SetAttribute("CoreHP", math.max(coreHP, 0))
	setPhase("Reveal", CONFIG.RevealTime)

	-- Tunjukkan virus mana yang benar, lalu ledakkan semuanya.
	for _, monster in monsters do
		monster.Stopped = true
		monster.Velocity.VectorVelocity = Vector3.zero
		monster.Card.BackgroundColor3 = if monster.IsCorrect then Theme.Success else Theme.Danger
		monster.Label.Text = (if monster.IsCorrect then "✅ " else "❌ ") .. monster.Answer
		monster.Label.TextColor3 = Theme.White
	end
	task.wait(2.5)
	for _, monster in monsters do
		local position = monster.Root.Position
		if monster.IsCorrect then
			UiKit.burst(position, Theme.Success, 80)
			if coreHit and coreFocus then
				explodeAt(coreFocus.Position)
			end
		end
		explodeAt(position)
	end
	clearMonsters()

	if breached then
		for _, player in playersInStage() do
			NotifyService.ToPlayer(player, "💥 Inti Server terinfeksi! Firewall dipulihkan, ayo lebih teliti!", "error")
		end
		coreHP = CONFIG.CoreMaxHP
	end
	task.wait(math.max(CONFIG.RevealTime - 2.5, 0))
	stateFolder:SetAttribute("CoreHP", coreHP)
end

local function runWave(question: Question)
	round.Wave += 1
	round.Token += 1
	local token = round.Token
	round.Question = question
	round.Answers = {}
	round.EndReason = nil
	round.StartedAt = os.clock()
	round.Active = true

	local count = math.min(CONFIG.MonstersPerWave, #lanes, #question.Wrong + 1)
	local options = { question.Correct }
	for _, wrong in shuffled(question.Wrong) do
		if #options >= count then
			break
		end
		table.insert(options, wrong)
	end
	options = shuffled(options)
	local laneOrder = shuffled(lanes)
	local speed = math.min(CONFIG.MonsterSpeed + CONFIG.SpeedPerWave * (round.Wave - 1), CONFIG.MaxMonsterSpeed)

	-- Setiap virus berwarna beda. Daftar jawaban + warnanya ditampilkan di panel layar
	-- (memudahkan siswa di HP mencocokkan label kecil dengan jawabannya).
	local colors = shuffled(VIRUS_COLORS)
	local optionList = {}
	for index, option in options do
		table.insert(optionList, { Answer = option, Color = colors[(index - 1) % #colors + 1]:ToHex() })
	end

	stateFolder:SetAttribute("Wave", round.Wave)
	stateFolder:SetAttribute("Options", HttpService:JSONEncode(optionList))
	stateFolder:SetAttribute("Question", question.Question)
	stateFolder:SetAttribute("Answered", 0)
	stateFolder:SetAttribute("Required", #requiredPlayers())
	setPhase("Question")

	for index, option in options do
		local delay = if index == 1 then 0 else random:NextNumber(0, CONFIG.SpawnStagger)
		task.delay(delay, function()
			if round.Token == token and round.Active then
				local color = colors[(index - 1) % #colors + 1]
				spawnMonster(laneOrder[index], option, option == question.Correct, speed, color)
			end
		end)
	end

	waitForWaveEnd(token)
	round.Active = false
	if round.EndReason == "Empty" then
		return
	end
	if round.EndReason == "AllAnswered" then
		task.wait(1) -- beri waktu efek tembakan terakhir
	end
	reveal()
end

local ensureLoop: () -> ()

local function gameLoop()
	loopRunning = true
	round.Wave = 0
	coreHP = CONFIG.CoreMaxHP
	stateFolder:SetAttribute("CoreHP", coreHP)
	stateFolder:SetAttribute("CoreMax", CONFIG.CoreMaxHP)

	while #playersInStage() > 0 do
		stateFolder:SetAttribute("Options", "")
		setPhase("Intermission", CONFIG.IntermissionTime)
		task.wait(CONFIG.IntermissionTime)
		if #playersInStage() == 0 then
			break
		end
		local question = drawQuestion()
		if not question then
			break
		end
		runWave(question)
	end

	round.Active = false
	round.Token += 1
	clearMonsters()
	setPhase("Idle")
	loopRunning = false
	ensureLoop() -- ada pemain yang masuk tepat saat permainan berhenti?
end

function ensureLoop()
	if loopRunning or #lanes == 0 or #questions == 0 then
		return
	end
	if #playersInStage() > 0 then
		task.spawn(gameLoop)
	end
end

--------------------------------------------------------------------------------
-- Peta
--------------------------------------------------------------------------------
local function readLanes(lanesFolder: Instance)
	local laneFolders = lanesFolder:GetChildren()
	table.sort(laneFolders, function(a, b)
		return a.Name < b.Name
	end)
	for _, laneFolder in laneFolders do
		local points = {}
		for _, child in laneFolder:GetChildren() do
			local order = tonumber(child.Name)
			if order and child:IsA("BasePart") then
				table.insert(points, { Order = order, Part = child })
				-- Penanda jalur hanya terlihat saat mengedit di Studio.
				child.Transparency = 1
				child.CanCollide = false
				child.CanQuery = false
				child.CanTouch = false
			end
		end
		table.sort(points, function(a, b)
			return a.Order < b.Order
		end)
		if #points >= 2 then
			local path = {}
			for _, point in points do
				table.insert(path, point.Part.Position)
			end
			table.insert(lanes, path)
		else
			warn(`[Stage2] Jalur "{laneFolder.Name}" butuh minimal 2 titik bernama 1, 2, 3, ...`)
		end
	end
end

local function setupMap(stageFolder: Instance)
	readLanes(stageFolder:FindFirstChild("Lanes") :: Instance)

	local folder = stageFolder:FindFirstChild("Monsters")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Monsters"
		folder.Parent = stageFolder
	end
	monstersFolder = folder :: Folder
	raycastParams.FilterDescendantsInstances = { folder }

	local custom = ServerStorage:FindFirstChild("VirusMonster")
	if custom and custom:IsA("Model") then
		monsterTemplate = prepareTemplate(custom:Clone())
	end
	monsterTemplate = monsterTemplate or buildVirusTemplate()

	local board = stageFolder:FindFirstChild("SkyBoard", true)
	if board and board:IsA("BasePart") then
		buildSkyBoard(board)
	else
		warn('[Stage2] Part "SkyBoard" tidak ditemukan: soal hanya tampil di layar siswa.')
	end

	local core = stageFolder:FindFirstChild("Core", true)
	if core and core:IsA("Model") then
		coreFocus = core.PrimaryPart or core:FindFirstChildWhichIsA("BasePart", true)
	elseif core and core:IsA("BasePart") then
		coreFocus = core
	end
	if coreFocus then
		buildCoreLabel(coreFocus)
	end

	setPhase("Idle")
	print(`[Stage2] Firewall Defender siap: {#lanes} jalur virus, {#questions} soal.`)
	ensureLoop()
end

function Stage2.Start()
	loadQuestions()
	stateFolder:SetAttribute("CoreHP", coreHP)
	stateFolder:SetAttribute("CoreMax", CONFIG.CoreMaxHP)
	stateFolder:SetAttribute("Phase", "Idle")

	shootRemote.OnServerEvent:Connect(onShoot)
	RunService.Heartbeat:Connect(stepMonsters)

	SpawnService.StageChanged:Connect(function(player, newArea, oldArea)
		if newArea == STAGE_ID then
			giveWand(player)
			NotifyService.ToPlayer(
				player,
				"🔥 Baca soal di langit, lalu tembak virus pembawa jawaban BENAR. Virus pertama yang kena = jawabanmu!",
				"info"
			)
			if #lanes == 0 then
				NotifyService.ToPlayer(player, "🚧 Arena Firewall Defender belum dibangun. Beri tahu Guru, ya!", "error")
			end
			ensureLoop()
		elseif oldArea == STAGE_ID then
			removeWand(player)
		end
	end)

	local function watchPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5) -- tunggu Backpack baru siap setelah respawn
			if SpawnService.GetArea(player) == STAGE_ID then
				giveWand(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastShotAt[player] = nil
		round.Answers[player] = nil
	end)

	task.spawn(function()
		local stages = workspace:WaitForChild(GameConfig.Names.Stages, 15)
		local stageFolder = stages and stages:WaitForChild(STAGE_ID, 15)
		if not (stageFolder and stageFolder:WaitForChild("Lanes", 15)) then
			warn("[Stage2] Arena belum ada. Biasanya dibangun otomatis oleh World > BuildAll — periksa pesan [World] di Output.")
			return
		end
		setupMap(stageFolder)
	end)
end

return Stage2
