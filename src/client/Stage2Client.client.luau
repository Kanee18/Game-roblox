--[[
	Stage2Client (LocalScript)
	Lokasi: StarterPlayer > StarterPlayerScripts > Stage2Client

	Tampilan Tahap 2 · Firewall Defender untuk siswa ini:
	  * Menembak dengan Tongkat Firewall (klik/ketuk virus), efek bola api
	  * Panel bawah: gelombang, nyawa Inti Server, soal, dan status jawabanmu
	  * Kartu hasil tembakanmu (hanya kamu yang melihat) dan kartu pengumuman jawaban
]]

local Debris = game:GetService("Debris")
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

local panel = UiKit.new("Frame", {
	Name = "PanelGelombang",
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
local panelStatus = UiKit.label({
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Font = Theme.FontBody,
	TextSize = 16,
	TextColor3 = Theme.GoldBright,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 3,
	Parent = panel,
})

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
	panel.Visible = inStage
	if not inStage then
		return
	end

	local phase = getState("Phase", "Idle")
	local wave = getState("Wave", 0)
	panelHeader.Text = `{STAGE.ElementIcon} FIREWALL DEFENDER · Gelombang {wave} · 🛡️ {heartsText(getState("CoreHP", CONFIG.CoreMaxHP))}`

	if phase == "Question" then
		panelQuestion.Text = getState("Question", "")
		local progress = `Sudah menjawab: {getState("Answered", 0)}/{getState("Required", 0)}`
		panelStatus.Text = if isLocked()
			then `🔒 Jawabanmu: {myResult.Answer} · tunggu hasilnya… ({progress})`
			else `🎯 Klik/ketuk virus pembawa jawaban BENAR. Virus pertama yang kena = jawabanmu! ({progress})`
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
-- Titik yang dibidik + apakah bidikan mengenai virus.
local function getAim(): (Vector3, boolean)
	local ray = mouse.UnitRay
	local result = workspace:Raycast(ray.Origin, ray.Direction * CONFIG.MaxRange, aimParams)
	if result then
		return result.Position, true
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
		if panel.Visible and getState("Phase", "Idle") == "Intermission" then
			renderHud()
		end
	end
end)

renderHud()
