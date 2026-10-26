--[[
	Stage3Client (LocalScript)
	Lokasi: StarterPlayer > StarterPlayerScripts > Stage3Client

	Tampilan Tahap 3 · Cable Labyrinth untuk siswa ini:
	  * Papan permintaan Mesin Pusat (hanya siswa ini yang melihat permintaannya)
	  * Pajangan perangkat di pedestal berputar pelan
	  * Panel bawah: permintaan, barang yang dibawa, progres misi
	  * Kartu hasil pengiriman dan kartu misi selesai
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
local Sfx = require(Shared:WaitForChild("Sfx"))

local Theme = GameConfig.Theme
local STAGE_ID = "Stage3"
local STAGE = GameConfig.StageById[STAGE_ID]
local SPIN_SPEED = 0.8 -- radian per detik
local SPIN_RANGE = 120 -- hanya pajangan sejauh ini yang diputar (hemat performa)

local player = Players.LocalPlayer

local stages = workspace:WaitForChild(GameConfig.Names.Stages, 30)
local stageFolder = stages and stages:WaitForChild(STAGE_ID, 30)
local machine = stageFolder and stageFolder:WaitForChild("Machine", 30)
if not machine then
	return -- labirin Tahap 3 belum dibangun
end

local stateRemote = Remotes.Get("Stage3State")
local feedbackRemote = Remotes.Get("Stage3Feedback")
local completeRemote = Remotes.Get("Stage3Complete")

local currentState = nil

--------------------------------------------------------------------------------
-- Papan permintaan di atas Mesin Pusat
--------------------------------------------------------------------------------
local machineFocus = if machine:IsA("Model") then machine.PrimaryPart else nil
machineFocus = machineFocus or machine:FindFirstChildWhichIsA("BasePart", true)

local requestBoard = UiKit.new("BillboardGui", {
	Name = "PermintaanMesin",
	Adornee = machineFocus,
	Size = UDim2.fromOffset(460, 170),
	StudsOffsetWorldSpace = Vector3.new(0, 12, 0),
	LightInfluence = 0,
	MaxDistance = 400,
	ResetOnSpawn = false,
	Parent = player:WaitForChild("PlayerGui"),
})
local requestCard = UiKit.new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Theme.Night,
	BackgroundTransparency = 0.1,
	Parent = requestBoard,
}, { UiKit.corner(18), UiKit.stroke(STAGE.Color, 3), UiKit.padding(10) })
UiKit.label({
	Size = UDim2.fromScale(1, 0.24),
	Text = "🖥️ MESIN PUSAT MEMINTA:",
	TextScaled = true,
	TextColor3 = STAGE.Color,
	Parent = requestCard,
})
local requestText = UiKit.label({
	Position = UDim2.fromScale(0, 0.28),
	Size = UDim2.fromScale(1, 0.72),
	Font = Theme.FontBold,
	TextScaled = true,
	Parent = requestCard,
}, { UiKit.new("UITextSizeConstraint", { MaxTextSize = 30 }) })

--------------------------------------------------------------------------------
-- Panel bawah & kartu
--------------------------------------------------------------------------------
local gui = UiKit.new("ScreenGui", {
	Name = "Stage3HUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 4,
	Parent = player:WaitForChild("PlayerGui"),
})

local panel = UiKit.new("Frame", {
	Name = "PanelMisi",
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
local panelRequest = UiKit.label({
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Font = Theme.FontBold,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 2,
	Parent = panel,
})
local panelCarrying = UiKit.label({
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Font = Theme.FontBody,
	TextSize = 16,
	TextColor3 = Theme.GoldBright,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 3,
	Parent = panel,
})

local resultCard = UiKit.card(gui, "HasilPengiriman")
local resultTitle = resultCard.Line(1, { TextSize = 34 })
local resultBrought = resultCard.Line(2, { Font = Theme.FontBold, TextSize = 20 })
local resultInfo = resultCard.Line(3, { Font = Theme.FontBody, TextSize = 17, TextColor3 = Theme.InkSoft })
local resultExpected = resultCard.Line(4, { Font = Theme.FontBold, TextSize = 20, TextColor3 = Theme.SuccessDark })
local resultExplanation = resultCard.Line(5, { Font = Theme.FontBody, TextSize = 18 })

local missionCard = UiKit.card(gui, "MisiSelesai")
missionCard.Line(1, { TextSize = 38, Text = "🏆 MISI SELESAI!" })
local missionSubtitle = missionCard.Line(2, { Font = Theme.FontBody, TextSize = 18 })
local missionStats = missionCard.Line(3, { Font = Theme.FontBold, TextSize = 22 })
local missionBonus = missionCard.Line(4, { TextSize = 26 })
missionCard.Line(5, {
	Font = Theme.FontBody,
	TextSize = 16,
	TextColor3 = Theme.InkSoft,
	Text = "Lanjutkan untuk mengumpulkan Poin tambahan, atau injak pad 🏠 untuk kembali ke Lobby.",
})

local function render()
	local inStage = player:GetAttribute("CurrentStage") == STAGE_ID
	local state = currentState
	panel.Visible = inStage and state ~= nil
	requestBoard.Enabled = inStage

	if not state then
		requestText.Text = "Masuk lewat Portal Petir ⚡ untuk menerima misi."
		return
	end
	local request = state.Request or "Semua permintaan sudah habis. Hebat!"
	requestText.Text = request

	local progress = if state.Correct >= state.Goal
		then `Misi {state.Goal}/{state.Goal} ✅`
		else `Misi {state.Correct}/{state.Goal}`
	panelHeader.Text = `{STAGE.ElementIcon} CABLE LABYRINTH · {progress}`
	panelRequest.Text = `🖥️ {request}`
	panelCarrying.Text = if state.Carrying
		then `🎒 Kamu membawa: {state.Carrying}. Antar ke lantai bercahaya di sekeliling Mesin Pusat!`
		else "🎒 Tanganmu kosong. Cari perangkatnya di labirin (lihat papan nama yang melayang)!"
end

--------------------------------------------------------------------------------
-- Pajangan perangkat berputar
--------------------------------------------------------------------------------
local displays: { { Model: Model, Base: CFrame } } = {}

local function registerDisplay(model: Instance)
	if model:IsA("Model") and model.Name == "Display" then
		table.insert(displays, { Model = model, Base = model:GetPivot() })
	end
end
for _, descendant in stageFolder:GetDescendants() do
	registerDisplay(descendant)
end
stageFolder.DescendantAdded:Connect(registerDisplay)

local elapsed = 0
RunService.RenderStepped:Connect(function(deltaTime)
	if player:GetAttribute("CurrentStage") ~= STAGE_ID then
		return
	end
	elapsed += deltaTime
	local camera = workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
	local spin = CFrame.Angles(0, elapsed * SPIN_SPEED, 0)
	local bob = CFrame.new(0, math.sin(elapsed * 2) * 0.25, 0)
	for _, entry in displays do
		if entry.Model.Parent and (entry.Base.Position - cameraPosition).Magnitude < SPIN_RANGE then
			entry.Model:PivotTo(entry.Base * bob * spin)
		end
	end
end)

--------------------------------------------------------------------------------
stateRemote.OnClientEvent:Connect(function(state)
	local previous = currentState
	if state.Carrying and (previous == nil or previous.Carrying ~= state.Carrying) then
		Sfx.Play("Pickup")
	end
	currentState = state
	render()
end)

feedbackRemote.OnClientEvent:Connect(function(result)
	missionCard.Hide()
	if result.Correct then
		resultCard.Stroke.Color = Theme.Success
		resultTitle.Text = "✅ BENAR!"
		resultTitle.TextColor3 = Theme.SuccessDark
		resultBrought.Text = `Mesin Pusat menerima {result.Brought}.`
		resultInfo.Visible = false
		resultExpected.Visible = false
	else
		resultCard.Stroke.Color = Theme.Danger
		resultTitle.Text = "❌ BUKAN ITU!"
		resultTitle.TextColor3 = Theme.Danger
		resultBrought.Text = `Kamu membawa {result.Brought}.`
		resultInfo.Text = result.BroughtInfo or ""
		resultInfo.Visible = result.BroughtInfo ~= nil
		resultExpected.Text = `Yang diminta: {result.Expected}`
		resultExpected.Visible = true
	end
	resultExplanation.Text = if result.Explanation then `💡 {result.Explanation}` else ""
	resultExplanation.Visible = result.Explanation ~= nil
	resultCard.Show(if result.Correct then 5 else 7)
end)

completeRemote.OnClientEvent:Connect(function(result)
	Sfx.Play("Fanfare")
	resultCard.Hide()
	missionSubtitle.Text = `Hebat, {player.DisplayName}! Kamu sudah mengenal perangkat keras jaringan.`
	missionStats.Text = `✅ Benar: {result.Correct}    ❌ Salah: {result.Wrong}`
	missionBonus.Text = if result.Bonus > 0 then `🎁 Bonus +{result.Bonus} Poin` else "Bonus misi sudah kamu ambil di sesi ini."
	missionBonus.TextColor3 = if result.Bonus > 0 then Theme.SuccessDark else Theme.InkSoft
	missionCard.Show(9)
end)

player:GetAttributeChangedSignal("CurrentStage"):Connect(function()
	if player:GetAttribute("CurrentStage") ~= STAGE_ID then
		resultCard.Hide()
		missionCard.Hide()
	end
	render()
end)

render()
