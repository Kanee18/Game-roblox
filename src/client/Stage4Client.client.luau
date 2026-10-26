--[[
	Stage4Client (LocalScript)
	Lokasi: StarterPlayer > StarterPlayerScripts > Stage4Client

	Tampilan & kendali Tahap 4 · Bandwidth Glider untuk siswa ini:
	  * Kendali terbang: maju otomatis, A/D atau ⬅️➡️ = belok, W/S atau ⬆️⬇️ = naik/turun
	    (di ponsel: joystick). Kamera mengikuti dari belakang.
	  * Label soal & jawaban A/B di setiap gerbang (hanya siswa ini yang melihat)
	  * Panel bawah: soal, pilihan, dan "speedometer" dalam Mbps
	  * Efek ⚡ Speed Boost (jawaban benar) dan 🐢 Lemot/Buffering (salah/terlewat)
	  * Kartu rekap setelah mendarat
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UiKit = require(Shared:WaitForChild("UiKit"))
local Stage4Map = require(Shared:WaitForChild("Stage4Map"))

local Theme = GameConfig.Theme
local STAGE_ID = Stage4Map.StageId
local STAGE = GameConfig.StageById[STAGE_ID]
local CONFIG = GameConfig.Stage4
local NORMAL_FOV = 70

local player = Players.LocalPlayer

local stages = workspace:WaitForChild(GameConfig.Names.Stages, 30)
local stageFolder = stages and stages:WaitForChild(STAGE_ID, 30)
if not (stageFolder and stageFolder:WaitForChild("Gates", 30)) then
	return -- lintasan Tahap 4 belum dibangun
end

local map = Stage4Map.Read(stageFolder)
local forward = map.Forward
local up = Vector3.new(0, 1, 0)
local right = forward:Cross(up).Unit

local stateRemote = Remotes.Get("Stage4State")
local feedbackRemote = Remotes.Get("Stage4Feedback")
local finishRemote = Remotes.Get("Stage4Finish")

local controls = nil
task.spawn(function()
	local ok, playerModule = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok then
		controls = playerModule:GetControls()
	else
		warn("[Stage4Client] PlayerModule tidak ditemukan, kendali terbang memakai arah gerak karakter.")
	end
end)

local currentState = nil
local effect = { Kind = "None", Until = 0 }

--------------------------------------------------------------------------------
-- Label gerbang (hanya siswa ini yang melihat)
--------------------------------------------------------------------------------
local gateViews = {}
for _, gate in map.Gates do
	local view = { Rings = {} }
	local anchor = gate.Rings[1].Trigger
	view.Question = UiKit.label({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.15,
		BackgroundColor3 = Theme.Night,
		Font = Theme.FontBold,
		TextScaled = true,
		Parent = UiKit.new("BillboardGui", {
			Name = "Stage4Soal",
			Adornee = anchor,
			Size = UDim2.fromOffset(420, 90),
			StudsOffsetWorldSpace = gate.Center - anchor.Position + Vector3.new(0, 18, 0),
			LightInfluence = 0,
			MaxDistance = 420,
			Parent = anchor,
		}),
	}, { UiKit.corner(14), UiKit.stroke(STAGE.Color, 2), UiKit.padding(8) })

	for _, ring in gate.Rings do
		local radius = math.max(ring.Trigger.Size.Y, ring.Trigger.Size.Z) / 2
		view.Rings[ring.Slot] = UiKit.label({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.Cream,
			Font = Theme.FontBold,
			TextScaled = true,
			TextColor3 = Theme.Ink,
			Parent = UiKit.new("BillboardGui", {
				Name = "Stage4Jawaban",
				Adornee = ring.Trigger,
				Size = UDim2.fromOffset(220, 64),
				StudsOffsetWorldSpace = Vector3.new(0, radius + 3, 0),
				LightInfluence = 0,
				MaxDistance = 420,
				Parent = ring.Trigger,
			}),
		}, { UiKit.corner(12), UiKit.stroke(STAGE.Color, 3), UiKit.padding(6) })
	end
	gateViews[gate.Index] = view
end

local function renderGates()
	local state = currentState
	for index, view in gateViews do
		local isCurrent = state ~= nil and state.Gliding and index == state.Gate and state.Question ~= nil
		local passed = state ~= nil and state.Gliding and index < state.Gate
		view.Question.Text = if isCurrent then `Gerbang {index}: {state.Question}` elseif passed then "✔" else `Gerbang {index}`
		view.Question.Parent.Enabled = not passed
		for slot, label in view.Rings do
			local option = if isCurrent then state.Options[slot] else nil
			label.Text = if option then `{Stage4Map.Letter(slot)} · {option}` else Stage4Map.Letter(slot)
			label.Parent.Enabled = not passed
		end
	end
end

--------------------------------------------------------------------------------
-- UI layar
--------------------------------------------------------------------------------
local gui = UiKit.new("ScreenGui", {
	Name = "Stage4HUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 4,
	Parent = player:WaitForChild("PlayerGui"),
})

local panel = UiKit.new("Frame", {
	Name = "PanelTerbang",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0.55, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Theme.Night,
	BackgroundTransparency = 0.15,
	Visible = false,
	Parent = gui,
}, {
	UiKit.corner(16),
	UiKit.stroke(STAGE.Color, 2),
	UiKit.padding(12),
	UiKit.new("UISizeConstraint", { MinSize = Vector2.new(320, 0), MaxSize = Vector2.new(680, math.huge) }),
	UiKit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local panelHeader = UiKit.label({
	Size = UDim2.new(1, 0, 0, 22),
	TextSize = 18,
	TextColor3 = STAGE.Color,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = false,
	TextTruncate = Enum.TextTruncate.AtEnd,
	LayoutOrder = 1,
	Parent = panel,
})
local panelQuestion = UiKit.label({
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Font = Theme.FontBold,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 2,
	Parent = panel,
})
local panelHint = UiKit.label({
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Font = Theme.FontBody,
	TextSize = 15,
	TextColor3 = Theme.Cream,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 3,
	Parent = panel,
})

-- Speedometer bergaya kecepatan internet
local speedLabel = UiKit.label({
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -20, 1, -150),
	Size = UDim2.fromOffset(230, 56),
	BackgroundTransparency = 0.15,
	BackgroundColor3 = Theme.Night,
	TextSize = 30,
	TextColor3 = Theme.White,
	Visible = false,
	Parent = gui,
}, { UiKit.corner(16), UiKit.stroke(STAGE.Color, 2) })

-- Kartu kecil hasil tiap gerbang (di atas, agar tidak menutupi jalur terbang)
local feedbackCard = UiKit.card(gui, "HasilGerbang")
feedbackCard.Frame.Position = UDim2.fromScale(0.5, 0.24)
local feedbackTitle = feedbackCard.Line(1, { TextSize = 28 })
local feedbackAnswer = feedbackCard.Line(2, { Font = Theme.FontBold, TextSize = 18 })
local feedbackExplanation = feedbackCard.Line(3, { Font = Theme.FontBody, TextSize = 16 })

local finishCard = UiKit.card(gui, "RekapTerbang")
finishCard.Line(1, { TextSize = 36, Text = "🪂 MENDARAT!" })
local finishStats = finishCard.Line(2, { Font = Theme.FontBold, TextSize = 20 })
local finishList = finishCard.Line(3, { Font = Theme.FontBody, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left })
local finishBonus = finishCard.Line(4, { TextSize = 24 })
finishCard.Line(5, {
	Font = Theme.FontBody,
	TextSize = 15,
	TextColor3 = Theme.InkSoft,
	Text = "Injak pad 🗼 untuk terbang lagi dengan soal baru, atau 🏠 untuk kembali ke Lobby.",
})

local function currentMultiplier(): number
	if os.clock() > effect.Until then
		return 1
	end
	if effect.Kind == "Boost" then
		return CONFIG.BoostMultiplier
	elseif effect.Kind == "Slow" then
		return CONFIG.SlowMultiplier
	end
	return 1
end

local function renderHud()
	local inStage = player:GetAttribute("CurrentStage") == STAGE_ID
	local state = currentState
	local gliding = player:GetAttribute("Gliding") == true
	panel.Visible = inStage
	speedLabel.Visible = inStage and gliding
	if not inStage then
		return
	end

	if gliding and state and state.Question then
		panelHeader.Text = `{STAGE.ElementIcon} BANDWIDTH GLIDER · Gerbang {state.Gate}/{state.Total}`
		panelQuestion.Text = state.Question
		local choices = {}
		for slot, option in state.Options do
			table.insert(choices, `{Stage4Map.Letter(slot)} · {option}`)
		end
		panelHint.Text = `{table.concat(choices, "     ")}\n⬅️➡️ / A D: belok   ·   ⬆️⬇️ / W S: naik-turun`
	elseif gliding then
		panelHeader.Text = `{STAGE.ElementIcon} BANDWIDTH GLIDER`
		panelQuestion.Text = "🏝️ Semua gerbang terlewati! Mendaratlah di pulau di depan."
		panelHint.Text = "⬅️➡️ / A D: belok   ·   ⬆️⬇️ / W S: naik-turun"
	else
		panelHeader.Text = `{STAGE.ElementIcon} BANDWIDTH GLIDER`
		panelQuestion.Text = "Injak pad 🪂 di ujung menara untuk mulai terbang!"
		panelHint.Text = "Masuki cincin A atau B yang berisi jawaban benar. Benar = ⚡ Speed Boost, salah = 🐢 lemot."
	end
end

--------------------------------------------------------------------------------
-- Efek kecepatan (lokal)
--------------------------------------------------------------------------------
local camera = workspace.CurrentCamera
local slowTint = UiKit.new("ColorCorrectionEffect", {
	Name = "EfekLemot",
	Enabled = false,
	Saturation = -0.7,
	Contrast = -0.1,
	TintColor = Color3.fromRGB(200, 205, 215),
	Parent = camera,
})
local windEmitter: ParticleEmitter? = nil

local function setWind(root: BasePart?, enabled: boolean)
	if enabled and root and not windEmitter then
		local attachment = UiKit.new("Attachment", { Name = "AnginBoost", Position = Vector3.new(0, 0, 0), Parent = root })
		windEmitter = UiKit.new("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(220, 255, 250)),
			LightEmission = 1,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.3, 0.6),
			Speed = NumberRange.new(30, 45),
			SpreadAngle = Vector2.new(25, 25),
			EmissionDirection = Enum.NormalId.Bottom,
			Rate = 60,
			Parent = attachment,
		})
	elseif not enabled and windEmitter then
		local attachment = windEmitter.Parent
		windEmitter = nil
		if attachment then
			attachment:Destroy()
		end
	end
end

--------------------------------------------------------------------------------
-- Kendali terbang
--------------------------------------------------------------------------------
local flight = nil -- { Root, Humanoid, Attachment, Velocity, Align, Connection }

local function readInput(humanoid: Humanoid): (number, number)
	local move = Vector3.zero
	if controls then
		move = controls:GetMoveVector()
	else
		-- Cadangan: arah gerak karakter relatif terhadap lintasan
		local direction = humanoid.MoveDirection
		move = Vector3.new(direction:Dot(right), 0, -direction:Dot(forward))
	end
	return math.clamp(move.X, -1, 1), math.clamp(-move.Z, -1, 1)
end

local function stopFlight()
	if not flight then
		return
	end
	flight.Connection:Disconnect()
	flight.Velocity:Destroy()
	flight.Align:Destroy()
	flight.Attachment:Destroy()
	if flight.Humanoid.Parent then
		flight.Humanoid.PlatformStand = false
		flight.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	setWind(nil, false)
	flight = nil
	slowTint.Enabled = false
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = NORMAL_FOV
	renderHud()
end

local function startFlight()
	if flight then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and root:IsA("BasePart")) then
		return
	end

	humanoid.PlatformStand = true
	local attachment = UiKit.new("Attachment", { Name = "TerbangAttachment", Parent = root })
	local velocity = UiKit.new("LinearVelocity", {
		Attachment0 = attachment,
		MaxForce = 1e6,
		VelocityConstraintMode = Enum.VelocityConstraintMode.Vector,
		RelativeTo = Enum.ActuatorRelativeTo.World,
		VectorVelocity = forward * CONFIG.BaseSpeed,
		Parent = root,
	})
	local align = UiKit.new("AlignOrientation", {
		Mode = Enum.OrientationAlignmentMode.OneAttachment,
		Attachment0 = attachment,
		MaxTorque = 1e6,
		Responsiveness = 25,
		CFrame = CFrame.lookAt(Vector3.zero, forward),
		Parent = root,
	})
	camera.CameraType = Enum.CameraType.Scriptable

	flight = {
		Root = root,
		Humanoid = humanoid,
		Attachment = attachment,
		Velocity = velocity,
		Align = align,
		Connection = nil :: RBXScriptConnection?,
	}
	effect.Kind = "None"

	flight.Connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not root.Parent then
			stopFlight()
			return
		end
		local lateral, vertical = readInput(humanoid)
		local multiplier = currentMultiplier()
		local speed = CONFIG.BaseSpeed * multiplier
		-- Turun mengikuti kemiringan lintasan, ditambah kendali naik/turun.
		velocity.VectorVelocity = forward * speed
			+ right * (lateral * CONFIG.SteerSpeed)
			+ up * (vertical * CONFIG.ClimbSpeed - map.Slope * speed)
		-- Tubuh rebah tengkurap (kepala ke depan), miring saat belok.
		align.CFrame = CFrame.lookAt(Vector3.zero, forward)
			* CFrame.Angles(0, 0, -lateral * 0.5)
			* CFrame.Angles(math.rad(-80) + vertical * 0.25, 0, 0)

		-- Kamera mengikuti dari belakang
		local focus = root.Position
		local desired = CFrame.lookAt(focus - forward * 22 + up * 7, focus + forward * 40 - up * (map.Slope * 40))
		camera.CFrame = camera.CFrame:Lerp(desired, math.min(1, deltaTime * 6))
		local boosting = multiplier > 1
		local slowed = multiplier < 1
		local targetFov = if boosting then 90 elseif slowed then 62 else 74
		camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(1, deltaTime * 4)
		slowTint.Enabled = slowed
		setWind(root, boosting)

		speedLabel.Text = if boosting
			then `⚡ {math.floor(speed)} Mbps`
			elseif slowed then `🐢 {math.floor(speed)} Mbps · Buffering…`
			else `📶 {math.floor(speed)} Mbps`
		speedLabel.TextColor3 = if boosting then Theme.Success elseif slowed then Theme.Danger else Theme.White
	end)
	renderHud()
end

local function onGlidingChanged()
	if player:GetAttribute("Gliding") == true then
		startFlight()
	else
		stopFlight()
	end
end

--------------------------------------------------------------------------------
stateRemote.OnClientEvent:Connect(function(state)
	currentState = state
	renderGates()
	renderHud()
end)

feedbackRemote.OnClientEvent:Connect(function(result)
	effect.Kind = result.Effect
	effect.Until = os.clock() + CONFIG.EffectDuration

	local gate = map.Gates[result.Gate]
	local ring = gate and result.Slot and gate.Rings[result.Slot]
	if ring then
		UiKit.burst(ring.Trigger.Position, if result.Result == "correct" then Theme.Success else Theme.Danger, 70)
	end

	if result.Result == "correct" then
		feedbackCard.Stroke.Color = Theme.Success
		feedbackTitle.Text = "✅ BENAR! ⚡ Bandwidth naik!"
		feedbackTitle.TextColor3 = Theme.SuccessDark
		feedbackAnswer.Text = `Jawaban: {result.CorrectAnswer}`
	else
		feedbackCard.Stroke.Color = Theme.Danger
		feedbackTitle.Text = if result.Result == "missed" then "📶 Sinyal hilang! Cincin terlewat" else "❌ SALAH! 🐢 Koneksi lemot…"
		feedbackTitle.TextColor3 = Theme.Danger
		feedbackAnswer.Text = `Jawaban benar: {result.CorrectAnswer}`
	end
	feedbackExplanation.Text = if result.Explanation then `💡 {result.Explanation}` else ""
	feedbackExplanation.Visible = result.Explanation ~= nil
	feedbackCard.Show(3.5)
end)

finishRemote.OnClientEvent:Connect(function(result)
	feedbackCard.Hide()
	finishStats.Text = `✅ Benar: {result.Correct}    ❌ Salah: {result.Wrong}    📶 Terlewat: {result.Missed}`
	local lines = {}
	for index, entry in result.Results do
		local icon = if entry.Result == "correct" then "✅" elseif entry.Result == "wrong" then "❌" else "📶"
		table.insert(lines, `{icon} Gerbang {index}: {entry.Correct}`)
	end
	finishList.Text = table.concat(lines, "\n")
	finishBonus.Text = if result.Bonus > 0 then `🎁 Bonus +{result.Bonus} Poin` else "Bonus mendarat sudah kamu ambil di sesi ini."
	finishBonus.TextColor3 = if result.Bonus > 0 then Theme.SuccessDark else Theme.InkSoft
	finishCard.Show(10)
end)

player:GetAttributeChangedSignal("Gliding"):Connect(onGlidingChanged)
player:GetAttributeChangedSignal("CurrentStage"):Connect(function()
	if player:GetAttribute("CurrentStage") ~= STAGE_ID then
		feedbackCard.Hide()
		finishCard.Hide()
	end
	renderHud()
end)
player.CharacterAdded:Connect(function()
	stopFlight()
	camera = workspace.CurrentCamera
end)

renderGates()
renderHud()
onGlidingChanged()
