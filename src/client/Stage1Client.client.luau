--[[
	Stage1Client (LocalScript)
	Lokasi: StarterPlayer > StarterPlayerScripts > Stage1Client

	Tampilan Tahap 1 · Routing Runner untuk siswa ini saja:
	  * Papan soal & papan pintu A/B/C di dunia (setiap siswa melihat soalnya sendiri)
	  * Panel soal di bawah layar (di HP: kanan atas, bisa diciutkan)
	  * Kartu hasil: Benar/Salah + jawaban benar + penjelasan
	  * Kartu finish berisi rekap jawaban
]]

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
local Stage1Map = require(Shared:WaitForChild("Stage1Map"))

local Theme = GameConfig.Theme
local STAGE_ID = Stage1Map.StageId
local STAGE = GameConfig.StageById[STAGE_ID]

local player = Players.LocalPlayer

local stages = workspace:WaitForChild(GameConfig.Names.Stages, 30)
local stageFolder = stages and stages:WaitForChild(STAGE_ID, 30)
if not (stageFolder and stageFolder:WaitForChild("Sections", 30)) then
	return -- lintasan Tahap 1 belum dibangun
end

local sections = Stage1Map.Read(stageFolder)
local currentState = nil

--------------------------------------------------------------------------------
-- Papan di dunia 3D (hanya terlihat oleh siswa ini)
--------------------------------------------------------------------------------
local function getFace(part: BasePart): Enum.NormalId
	local faceName = part:GetAttribute("Face")
	for _, item in Enum.NormalId:GetEnumItems() do
		if item.Name == faceName then
			return item
		end
	end
	return Enum.NormalId.Front
end

local function surfaceOn(part: BasePart, pixelsPerStud: number): SurfaceGui
	local old = part:FindFirstChild("Stage1Gui")
	if old then
		old:Destroy()
	end
	return UiKit.new("SurfaceGui", {
		Name = "Stage1Gui",
		Face = getFace(part),
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = pixelsPerStud,
		LightInfluence = 0,
		Brightness = 1.2,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = part,
	})
end

local function buildBoard(part: BasePart): (TextLabel, TextLabel)
	local card = UiKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Night,
		BackgroundTransparency = 0.08,
		Parent = surfaceOn(part, 30),
	}, { UiKit.corner(24), UiKit.stroke(STAGE.Color, 6), UiKit.padding(18) })

	local header = UiKit.label({
		Size = UDim2.fromScale(1, 0.26),
		TextScaled = true,
		TextColor3 = Theme.GoldBright,
		Parent = card,
	}, { UiKit.new("UITextSizeConstraint", { MaxTextSize = 48 }) })

	local body = UiKit.label({
		Position = UDim2.fromScale(0, 0.3),
		Size = UDim2.fromScale(1, 0.7),
		Font = Theme.FontBold,
		TextScaled = true,
		Parent = card,
	}, { UiKit.new("UITextSizeConstraint", { MaxTextSize = 56 }) })

	return header, body
end

local function buildDoorCard(door: Stage1Map.Door): TextLabel
	local container: Instance
	if door.Sign then
		container = surfaceOn(door.Sign, 40)
	else
		container = UiKit.new("BillboardGui", {
			Name = "Stage1Gui",
			Adornee = door.Trigger,
			Size = UDim2.fromOffset(190, 120),
			StudsOffsetWorldSpace = Vector3.new(0, door.Trigger.Size.Y / 2 + 3, 0),
			LightInfluence = 0,
			MaxDistance = 150,
			Parent = door.Trigger,
		})
	end

	local card = UiKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Cream,
		Parent = container,
	}, { UiKit.corner(18), UiKit.stroke(Theme.Gold, 5), UiKit.padding(8) })

	UiKit.label({
		Size = UDim2.fromScale(1, 0.42),
		Text = door.Letter,
		TextScaled = true,
		TextColor3 = STAGE.Color,
		Parent = card,
	}, { UiKit.textStroke(Theme.Ink, 2) })

	return UiKit.label({
		Position = UDim2.fromScale(0, 0.44),
		Size = UDim2.fromScale(1, 0.56),
		Font = Theme.FontBold,
		TextScaled = true,
		TextColor3 = Theme.Ink,
		Parent = card,
	}, { UiKit.new("UITextSizeConstraint", { MaxTextSize = 40 }) })
end

local views = {}
local checkpointColors: { [BasePart]: Color3 } = {}

for _, section in sections do
	local view = { Doors = {} }
	if section.Board then
		view.Header, view.Body = buildBoard(section.Board)
	end
	for _, door in section.Doors do
		view.Doors[door.Slot] = buildDoorCard(door)
	end
	if section.Checkpoint then
		checkpointColors[section.Checkpoint] = section.Checkpoint.Color
	end
	views[section.Index] = view
end

local function renderWorld()
	local state = currentState
	for index, view in views do
		local section = sections[index]
		local passed = state ~= nil and index < state.Section
		local isCurrent = state ~= nil and index == state.Section and state.Question ~= nil

		if view.Header then
			local title = if section.Title then ` · {section.Title}` else ""
			view.Header.Text = `🔀 Gerbang Router {index}/{#sections}{title}`
			view.Body.Text = if isCurrent
				then state.Question
				elseif passed then "✅ Gerbang ini sudah kamu lewati!"
				else "🔒 Soal muncul setelah kamu melewati gerbang sebelumnya."
		end

		for slot, answerLabel in view.Doors do
			local option = if isCurrent then state.Options[slot] else nil
			answerLabel.Text = option or (if passed then "✔" else "?")
		end

		if section.Checkpoint then
			-- Checkpoint yang sudah dicapai menyala hijau (hanya di layar siswa ini).
			section.Checkpoint.Color = if passed then Theme.Success else checkpointColors[section.Checkpoint]
		end
	end
end

--------------------------------------------------------------------------------
-- UI layar
--------------------------------------------------------------------------------
local gui = UiKit.new("ScreenGui", {
	Name = "Stage1HUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 4,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Panel soal (PC: bawah tengah; HP: kanan atas, ketuk judul untuk menciutkan)
local hud = UiKit.hudPanel(gui, STAGE.Color)
local panelHeader = hud.Header
local panelQuestion = hud.Line(1, { Font = Theme.FontBold })

local optionLayout = UiKit.new("UIListLayout", {
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
})
local optionRow = UiKit.new("Frame", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 2,
	Parent = hud.Body,
}, { optionLayout })

local function renderHud()
	local state = currentState
	local inStage = player:GetAttribute("CurrentStage") == STAGE_ID
	local hasQuestion = state ~= nil and state.Question ~= nil
	hud.Frame.Visible = inStage and hasQuestion
	if not hasQuestion then
		return
	end

	local compact = UiKit.IsCompact()
	panelHeader.Text = if compact
		then `{STAGE.ElementIcon} Gerbang Router {state.Section}/{state.Total}`
		else `{STAGE.ElementIcon} ROUTING RUNNER · Gerbang Router {state.Section}/{state.Total}`
	panelQuestion.Text = state.Question

	for _, child in optionRow:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	-- PC: pilihan berjajar ke samping. HP: tersusun ke bawah supaya teksnya tidak mengecil.
	optionLayout.FillDirection = if compact then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	optionLayout.Padding = UDim.new(0, if compact then 4 else 8)
	local count = #state.Options
	for slot, option in state.Options do
		local text = `{Stage1Map.Letter(slot)} · {option}`
		if compact then
			UiKit.label({
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 0,
				BackgroundColor3 = Theme.Cream,
				Text = text,
				Font = Theme.FontBold,
				TextSize = 16,
				TextColor3 = Theme.Ink,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = slot,
				Parent = optionRow,
			}, { UiKit.corner(8), UiKit.padding(5) })
		else
			UiKit.label({
				Size = UDim2.new(1 / count, -8 * (count - 1) / count, 0, 40),
				BackgroundTransparency = 0,
				BackgroundColor3 = Theme.Cream,
				Text = text,
				Font = Theme.FontBold,
				TextScaled = true,
				TextColor3 = Theme.Ink,
				LayoutOrder = slot,
				Parent = optionRow,
			}, {
				UiKit.corner(10),
				UiKit.padding(6),
				UiKit.new("UITextSizeConstraint", { MaxTextSize = 18 }),
			})
		end
	end
end

-- Susun ulang pilihan saat layar berganti mode (HP diputar, jendela diubah ukurannya).
UiKit.OnLayout(function()
	renderHud()
end)

local feedbackCard = UiKit.card(gui, "HasilJawaban")
local feedbackTitle = feedbackCard.Line(1, { TextSize = 34 })
local feedbackAnswer = feedbackCard.Line(2, { Font = Theme.FontBold, TextSize = 20 })
local feedbackExplanation = feedbackCard.Line(3, { Font = Theme.FontBody, TextSize = 18 })

local finishCard = UiKit.card(gui, "Finish")
finishCard.Line(1, { TextSize = 38, Text = "🏁 SELAMAT!" })
local finishSubtitle = finishCard.Line(2, { Font = Theme.FontBody, TextSize = 18 })
local finishStats = finishCard.Line(3, { Font = Theme.FontBold, TextSize = 22 })
local finishBonus = finishCard.Line(4, { TextSize = 26, TextColor3 = Theme.SuccessDark })
finishCard.Line(5, {
	Font = Theme.FontBody,
	TextSize = 16,
	TextColor3 = Theme.InkSoft,
	Text = "Injak pad 🏠 untuk kembali ke Lobby, atau masuk lagi untuk soal-soal baru!",
})

local function showFeedback(result)
	local section = sections[result.Section]
	local door = section and section.Doors[result.Slot]
	if door then
		UiKit.burst(door.Trigger.Position, if result.Correct then Theme.Success else Theme.Danger)
	end

	finishCard.Hide()
	if result.Correct then
		feedbackCard.Stroke.Color = Theme.Success
		feedbackTitle.Text = "✅ BENAR!"
		feedbackTitle.TextColor3 = Theme.SuccessDark
		feedbackAnswer.Text = if result.IsLast
			then "Semua gerbang terlewati! Lari ke garis finish 🏁"
			else "📍 Checkpoint baru tersimpan."
	else
		feedbackCard.Stroke.Color = Theme.Danger
		feedbackTitle.Text = "❌ KURANG TEPAT!"
		feedbackTitle.TextColor3 = Theme.Danger
		feedbackAnswer.Text = `Jawaban yang benar: {result.CorrectAnswer}`
	end
	local explanation = result.Explanation
	feedbackExplanation.Text = if explanation then `💡 {explanation}` else ""
	feedbackExplanation.Visible = explanation ~= nil
	feedbackCard.Show(if result.Correct then 4 else 6)
end

local function showFinish(result)
	Sfx.Play("Fanfare")
	feedbackCard.Hide()
	finishSubtitle.Text = `Hebat, {player:GetAttribute("StudentName") or player.DisplayName}! Kamu sampai di tujuan seperti paket data yang dikirim router.`
	finishStats.Text = `✅ Benar: {result.Correct}    ❌ Salah: {result.Wrong}`
	finishBonus.Text = if result.Bonus > 0 then `🎁 Bonus +{result.Bonus} Poin` else "Bonus finish sudah kamu ambil di sesi ini."
	finishBonus.TextColor3 = if result.Bonus > 0 then Theme.SuccessDark else Theme.InkSoft
	finishCard.Show(9)
end

--------------------------------------------------------------------------------
Remotes.Get("Stage1Question").OnClientEvent:Connect(function(state)
	currentState = state
	hud.Expand() -- soal baru: buka lagi panel yang diciutkan
	renderWorld()
	renderHud()
end)
Remotes.Get("Stage1Feedback").OnClientEvent:Connect(showFeedback)
Remotes.Get("Stage1Finish").OnClientEvent:Connect(showFinish)
player:GetAttributeChangedSignal("CurrentStage"):Connect(renderHud)

renderWorld()
