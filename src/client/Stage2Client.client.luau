--[[
	Stage2Client (LocalScript)
	Lokasi: StarterPlayer > StarterPlayerScripts > Stage2Client

	Tampilan Tahap 2 · Firewall Defender untuk siswa ini:
	  * Menembak dengan Tongkat Firewall (klik/ketuk virus), efek bola api.
	    Bantuan membidik: ketukan di dekat virus atau labelnya tetap kena (penting di HP).
	  * Panel: gelombang, nyawa Inti Server, soal, pilihan jawaban berwarna sama dengan
	    virusnya, dan status jawabanmu (PC: bawah; HP: kanan atas, bisa diciutkan)
	  * Kartu hasil tembakanmu (hanya kamu yang melihat) dan kartu pengumuman jawaban
]]

local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UiKit = require(Shared:WaitForChild("UiKit"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local Theme = GameConfig.Theme
local STAGE_ID = "Stage2"
local STAGE = GameConfig.StageById[STAGE_ID]
local CONFIG = GameConfig.Stage2
local AIM_CURSOR = "rbxasset://textures/GunCursor.png"

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local stages = workspace:WaitForChild(GameConfig.Names.Stages, 30)
local stageFolder = stages and stages:WaitForChild(STAGE_ID, 30)
local monstersFolder = stageFolder and stageFolder:WaitForChild("Monsters", 30)
if not monstersFolder then
	return -- arena Tahap 2 belum dibangun
end

local stateFolder = Remotes.GetState():WaitForChild(STAGE_ID)
local shootRemote = Remotes.Get("Stage2Shoot")
local feedbackRemote = Remotes.Get("Stage2Feedback")

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Include
aimParams.FilterDescendantsInstances = { monstersFolder }

local myResult = nil -- hasil tembakanku di gelombang terakhir
local lastShotAt = 0
local lastHintAt = 0

local function getState(name: string, default: any): any
	local value = stateFolder:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

local function heartsText(hp: number): string
	local max = getState("CoreMax", CONFIG.CoreMaxHP)
	hp = math.clamp(hp, 0, max)
	return string.rep("❤️", hp) .. string.rep("🖤", max - hp)
end

local function isLocked(): boolean
	return myResult ~= nil and myResult.Wave == getState("Wave", 0)
end

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------
local gui = UiKit.new("ScreenGui", {
	Name = "Stage2HUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 4,
	Parent = player:WaitForChild("PlayerGui"),
})

local hud = UiKit.hudPanel(gui, STAGE.Color)
hud.Frame.Active = true -- ketukan pada panel tidak ikut menembak
local panelHeader = hud.Header
local panelQuestion = hud.Line(1, { Font = Theme.FontBold })

-- Pilihan jawaban, warnanya sama dengan virus pembawanya.
local chipGrid = UiKit.new("UIGridLayout", {
	CellPadding = UDim2.fromOffset(6, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
local chipRow = UiKit.new("Frame", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 2,
	Parent = hud.Body,
}, { chipGrid })
local chipsKey = ""

local panelStatus = hud.Line(3, {
	Font = Theme.FontBody,
	TextSize = 16,
	TextColor3 = Theme.GoldBright,
})

local function decodeOptions(): { { Answer: string, Color: string } }
	local raw = getState("Options", "")
	if raw == "" then
		return {}
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and typeof(list) == "table" then list else {}
end

local function renderChips(phase: string)
	local options = if phase == "Question" or phase == "Reveal" then decodeOptions() else {}
	local revealAnswer = if phase == "Reveal" then getState("RevealAnswer", "") else nil
	local key = `{getState("Options", "")}|{revealAnswer or ""}|{UiKit.IsCompact()}|{#options}`
	if key == chipsKey then
		return
	end
	chipsKey = key
	for _, child in chipRow:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	chipRow.Visible = #options > 0
	-- HP: 2 kolom (teks tetap besar). PC: semua pilihan dalam satu baris.
	local columns = if UiKit.IsCompact() then 2 else math.max(#options, 1)
	chipGrid.CellSize = UDim2.new(1 / columns, -6 * (columns - 1) / columns, 0, 34)
	for index, option in options do
		local ok, color = pcall(Color3.fromHex, option.Color)
		color = if ok then color else STAGE.Color
		local text = option.Answer
		local background = color:Lerp(Theme.Night, 0.3)
		local transparency = 0
		if revealAnswer then
			if option.Answer == revealAnswer then
				text = `✅ {text}`
				background = Theme.Success
			else
				transparency = 0.6
			end
		end
		local chip = UiKit.new("Frame", {
			BackgroundTransparency = transparency,
			BackgroundColor3 = background,
			LayoutOrder = index,
			Parent = chipRow,
		}, {
			UiKit.corner(8),
			UiKit.stroke(Theme.Cream, 1, transparency),
			UiKit.new("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 3),
				PaddingBottom = UDim.new(0, 3),
			}),
		})
		UiKit.label({
			Size = UDim2.fromScale(1, 1),
			Text = text,
			Font = Theme.FontBold,
			TextScaled = true,
			TextColor3 = Theme.White,
			TextTransparency = transparency * 0.5,
			Parent = chip,
		}, {
			UiKit.new("UITextSizeConstraint", { MaxTextSize = 17 }),
			UiKit.textStroke(Theme.Night, 1),
		})
	end
end

-- Pesan singkat di atas panel ("Tunggu gelombang berikutnya!", dll)
local hintLabel = UiKit.label({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0.72, 0),
	Size = UDim2.new(0.8, 0, 0, 34),
	TextSize = 24,
	TextColor3 = Theme.Cream,
	Visible = false,
	Parent = gui,
}, { UiKit.textStroke(Theme.Night, 2) })

local function hint(text: string)
	local now = os.clock()
	if now - lastHintAt < 1.2 then
		return
	end
	lastHintAt = now
	hintLabel.Text = text
	hintLabel.Visible = true
	task.delay(1.6, function()
		if os.clock() - lastHintAt >= 1.5 then
			hintLabel.Visible = false
		end
	end)
end

-- Kartu hasil tembakanku (langsung) dan kartu pengumuman (akhir gelombang)
local shotCard = UiKit.card(gui, "HasilTembakan")
local shotTitle = shotCard.Line(1, { TextSize = 34 })
local shotAnswer = shotCard.Line(2, { Font = Theme.FontBold, TextSize = 20 })
shotCard.Line(3, {
	Font = Theme.FontBody,
	TextSize = 16,
	TextColor3 = Theme.InkSoft,
	Text = "Jawaban benar diumumkan di akhir gelombang.",
})

local revealCard = UiKit.card(gui, "PengumumanJawaban")
local revealPersonal = revealCard.Line(1, { TextSize = 28 })
local revealAnswer = revealCard.Line(2, { Font = Theme.FontBold, TextSize = 22 })
local revealExplanation = revealCard.Line(3, { Font = Theme.FontBody, TextSize = 18 })
local revealStats = revealCard.Line(4, { Font = Theme.FontBold, TextSize = 18, TextColor3 = Theme.InkSoft })
local revealCore = revealCard.Line(5, { TextSize = 22 })

local function renderHud()
	local inStage = player:GetAttribute("CurrentStage") == STAGE_ID
	hud.Frame.Visible = inStage
	if not inStage then
		return
	end

	local compact = UiKit.IsCompact()
	local phase = getState("Phase", "Idle")
	local wave = getState("Wave", 0)
	local hearts = heartsText(getState("CoreHP", CONFIG.CoreMaxHP))
	panelHeader.Text = if compact
		then `{STAGE.ElementIcon} Gelombang {wave} · 🛡️ {hearts}`
		else `{STAGE.ElementIcon} FIREWALL DEFENDER · Gelombang {wave} · 🛡️ {hearts}`
	renderChips(phase)

	if phase == "Question" then
		panelQuestion.Text = getState("Question", "")
		local progress = `Sudah menjawab: {getState("Answered", 0)}/{getState("Required", 0)}`
		local instruction = if UiKit.IsTouch()
			then "🎯 Ketuk virus (atau labelnya) yang membawa jawaban BENAR."
			else "🎯 Klik virus pembawa jawaban BENAR."
		panelStatus.Text = if isLocked()
			then `🔒 Jawabanmu: {myResult.Answer} · tunggu hasilnya… ({progress})`
			else `{instruction} Virus pertama yang kena = jawabanmu! ({progress})`
	elseif phase == "Reveal" then
		panelQuestion.Text = getState("Question", "")
		panelStatus.Text = `✅ Jawaban benar: {getState("RevealAnswer", "")}`
	elseif phase == "Intermission" then
		local secondsLeft = math.max(0, math.ceil(getState("PhaseEndsAt", 0) - workspace:GetServerTimeNow()))
		panelQuestion.Text = "🔥 Bersiap! Gelombang virus berikutnya segera datang…"
		panelStatus.Text = `Dimulai dalam {secondsLeft} detik`
	else
		panelQuestion.Text = "Menunggu gelombang pertama…"
		panelStatus.Text = ""
	end
end

local function showReveal()
	if player:GetAttribute("CurrentStage") ~= STAGE_ID then
		return
	end
	shotCard.Hide()
	local wave = getState("Wave", 0)
	local mine = if myResult and myResult.Wave == wave then myResult else nil

	if mine == nil then
		revealPersonal.Text = "⏳ Kamu belum menembak di gelombang ini."
		revealPersonal.TextColor3 = Theme.InkSoft
		revealCard.Stroke.Color = Theme.Gold
	elseif mine.Correct then
		revealPersonal.Text = `🎉 Jawabanmu BENAR: {mine.Answer}`
		revealPersonal.TextColor3 = Theme.SuccessDark
		revealCard.Stroke.Color = Theme.Success
	else
		revealPersonal.Text = `😵 Jawabanmu: {mine.Answer} (kurang tepat)`
		revealPersonal.TextColor3 = Theme.Danger
		revealCard.Stroke.Color = Theme.Danger
	end

	revealAnswer.Text = `✅ Jawaban benar: {getState("RevealAnswer", "")}`
	local explanation = getState("RevealExplanation", "")
	revealExplanation.Text = `💡 {explanation}`
	revealExplanation.Visible = explanation ~= ""

	local total = getState("RevealTotal", 0)
	revealStats.Text = `{getState("RevealCorrect", 0)} dari {total} siswa menjawab benar`
	revealStats.Visible = total > 0

	if getState("CoreBreached", false) then
		revealCore.Text = "💥 INTI SERVER TERINFEKSI! Firewall dipulihkan, ayo lebih teliti!"
		revealCore.TextColor3 = Theme.Danger
	elseif getState("CoreHit", false) then
		revealCore.Text = "💥 Virus menembus firewall! Inti Server -1 ❤️"
		revealCore.TextColor3 = Theme.Danger
	else
		revealCore.Text = "🛡️ Firewall bertahan! Kerja bagus, tim!"
		revealCore.TextColor3 = Theme.SuccessDark
	end
	revealCard.Show(math.max(CONFIG.RevealTime - 0.5, 2))
	Sfx.Play(if getState("CoreHit", false) then "CoreHit" else "Success")
end

--------------------------------------------------------------------------------
-- Menembak
--------------------------------------------------------------------------------
-- Bantuan membidik: virus terdekat dari arah ketukan/klik, diukur dari badan virus
-- maupun label jawabannya. Di HP jari menutupi sasaran yang kecil dan bergerak.
local function findAssistTarget(ray: Ray): BasePart?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local radiusPixels = if UiKit.IsTouch() then CONFIG.AimAssistTouch else CONFIG.AimAssistMouse
	local pixelsPerRadian = camera.ViewportSize.Y / math.rad(camera.FieldOfView)
	local bestAngle = radiusPixels / pixelsPerRadian
	local best: BasePart? = nil
	for _, model in monstersFolder:GetChildren() do
		local root = if model:IsA("Model") then model.PrimaryPart else nil
		if root then
			for _, point in { root.Position, root.Position + Vector3.new(0, CONFIG.LabelHeight, 0) } do
				local toPoint = point - ray.Origin
				local distance = toPoint.Magnitude
				if distance > 1 and distance <= CONFIG.MaxRange then
					local angle = math.acos(math.clamp(toPoint.Unit:Dot(ray.Direction), -1, 1))
					if angle < bestAngle then
						bestAngle = angle
						best = root
					end
				end
			end
		end
	end
	return best
end

-- Titik yang dibidik + apakah bidikan mengenai virus.
local function getAim(): (Vector3, boolean)
	local ray = mouse.UnitRay
	local result = workspace:Raycast(ray.Origin, ray.Direction * CONFIG.MaxRange, aimParams)
	if result then
		return result.Position, true
	end
	local assisted = findAssistTarget(ray)
	if assisted then
		return assisted.Position, true
	end
	return ray.Origin + ray.Direction * CONFIG.MaxRange, false
end

local function drawBolt(from: Vector3, to: Vector3)
	local distance = (to - from).Magnitude
	if distance < 0.5 then
		return
	end
	local bolt = UiKit.new("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = STAGE.Color,
		Size = Vector3.new(0.35, 0.35, distance),
		CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -distance / 2),
		Parent = workspace,
	})
	UiKit.tween(bolt, 0.18, { Transparency = 1, Size = Vector3.new(0.05, 0.05, distance) })
	Debris:AddItem(bolt, 0.3)
end

local function shoot(tool: Tool)
	local now = os.clock()
	if now - lastShotAt < CONFIG.FireCooldown then
		return
	end
	if getState("Phase", "Idle") ~= "Question" then
		hint("⏳ Tunggu gelombang virus berikutnya!")
		return
	end
	if isLocked() then
		hint("🔒 Jawabanmu sudah terkunci. Tunggu hasilnya!")
		return
	end
	lastShotAt = now
	Sfx.Play("Shoot")

	local target, hitVirus = getAim()
	local muzzle = tool:FindFirstChild("Tip") or tool:FindFirstChild("Handle")
	if muzzle and muzzle:IsA("BasePart") then
		drawBolt(muzzle.Position, target)
	end
	-- Tembakan meleset tidak dikirim, supaya tidak ada jawaban terkunci tanpa sengaja.
	if hitVirus then
		shootRemote:FireServer(target)
	end
end

local hookedTools: { [Tool]: boolean } = {}

local function hookTool(child: Instance)
	if not child:IsA("Tool") or child.Name ~= CONFIG.ToolName or hookedTools[child] then
		return
	end
	local tool = child :: Tool
	hookedTools[tool] = true
	tool.Activated:Connect(function()
		shoot(tool)
	end)
	tool.Equipped:Connect(function()
		mouse.Icon = AIM_CURSOR
	end)
	tool.Unequipped:Connect(function()
		mouse.Icon = ""
	end)
	tool.Destroying:Connect(function()
		hookedTools[tool] = nil
		mouse.Icon = ""
	end)
end

local function watchContainer(container: Instance)
	for _, child in container:GetChildren() do
		hookTool(child)
	end
	container.ChildAdded:Connect(hookTool)
end

local function onPlayerChild(child: Instance)
	if child:IsA("Backpack") then
		watchContainer(child)
	end
end
for _, child in player:GetChildren() do
	onPlayerChild(child)
end
player.ChildAdded:Connect(onPlayerChild)
if player.Character then
	watchContainer(player.Character)
end
player.CharacterAdded:Connect(watchContainer)

--------------------------------------------------------------------------------
feedbackRemote.OnClientEvent:Connect(function(result)
	myResult = result
	UiKit.burst(result.Position, if result.Correct then Theme.Success else Theme.Danger, 60)
	if result.Correct then
		shotCard.Stroke.Color = Theme.Success
		shotTitle.Text = "🎯 TEPAT SASARAN!"
		shotTitle.TextColor3 = Theme.SuccessDark
	else
		shotCard.Stroke.Color = Theme.Danger
		shotTitle.Text = "💢 SALAH SASARAN!"
		shotTitle.TextColor3 = Theme.Danger
	end
	shotAnswer.Text = `Jawabanmu: {result.Answer}`
	shotCard.Show(3)
	renderHud()
end)

stateFolder.AttributeChanged:Connect(function(name)
	if name == "Phase" then
		local phase = getState("Phase", "Idle")
		if phase == "Reveal" then
			showReveal()
		elseif phase == "Question" then
			revealCard.Hide()
			hud.Expand() -- soal baru: buka lagi panel yang diciutkan
		end
	end
	renderHud()
end)
player:GetAttributeChangedSignal("CurrentStage"):Connect(function()
	if player:GetAttribute("CurrentStage") ~= STAGE_ID then
		shotCard.Hide()
		revealCard.Hide()
		mouse.Icon = ""
	end
	renderHud()
end)

-- Hitung mundur jeda antar gelombang
task.spawn(function()
	while true do
		task.wait(0.25)
		if hud.Frame.Visible and getState("Phase", "Idle") == "Intermission" then
			renderHud()
		end
	end
end)

UiKit.OnLayout(function()
	renderHud()
end)
