--[[
	Stage1Client (LocalScript)
	Lokasi: StarterPlayer > StarterPlayerScripts > Stage1Client

	Tampilan Tahap 1 · Routing Runner untuk siswa ini saja:
	  * Papan soal & papan pintu A/B/C di dunia (setiap siswa melihat soalnya sendiri)
	  * Panel soal di bawah layar
	  * Kartu hasil: Benar/Salah + jawaban benar + penjelasan
	  * Kartu finish berisi rekap jawaban
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

-- Panel soal (bawah tengah)
local questionPanel = UiKit.new("Frame", {
	Name = "PanelSoal",
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
	Parent = questionPanel,
})

local panelQuestion = UiKit.label({
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Font = Theme.FontBold,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 2,
	Parent = questionPanel,
})

local optionRow = UiKit.new("Frame", {
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundTransparency = 1,
	LayoutOrder = 3,
	Parent = questionPanel,
}, {
	UiKit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local function renderHud()
	local state = currentState
	local inStage = player:GetAttribute("CurrentStage") == STAGE_ID
	local hasQuestion = state ~= nil and state.Question ~= nil
	questionPanel.Visible = inStage and hasQuestion
	if not hasQuestion then
		return
	end

	panelHeader.Text = `{STAGE.ElementIcon} ROUTING RUNNER · Gerbang Router {state.Section}/{state.Total}`
	panelQuestion.Text = state.Question

	for _, child in optionRow:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local count = #state.Options
	for slot, option in state.Options do
		UiKit.label({
			Size = UDim2.new(1 / count, -8 * (count - 1) / count, 1, 0),
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.Cream,
			Text = `{Stage1Map.Letter(slot)} · {option}`,
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

-- Kartu pop-up di tengah layar (dipakai untuk hasil jawaban dan finish)
local function createCard(name: string)
	local stroke = UiKit.stroke(Theme.Gold, 4)
	local frame = UiKit.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(0.5, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Cream,
		Visible = false,
		Parent = gui,
	}, {
		UiKit.corner(18),
		stroke,
		UiKit.padding(16),
		UiKit.new("UISizeConstraint", { MinSize = Vector2.new(300, 0), MaxSize = Vector2.new(560, math.huge) }),
		UiKit.new("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})
	local card = {
		Frame = frame,
		Stroke = stroke,
		Scale = UiKit.new("UIScale", { Parent = frame }),
		Token = 0,
	}
	function card.Line(order: number, props: { [string]: any }): TextLabel
		local defaults = {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextColor3 = Theme.Ink,
			LayoutOrder = order,
			Parent = frame,
		}
		for key, value in props do
			defaults[key] = value
		end
		return UiKit.label(defaults)
	end
	function card.Show(duration: number)
		card.Token += 1
		local token = card.Token
		frame.Visible = true
		card.Scale.Scale = 0.85
		UiKit.tween(card.Scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(duration, function()
			if card.Token == token then
				frame.Visible = false
			end
		end)
	end
	function card.Hide()
		card.Token += 1
		frame.Visible = false
	end
	return card
end

local feedbackCard = createCard("HasilJawaban")
local feedbackTitle = feedbackCard.Line(1, { TextSize = 34 })
local feedbackAnswer = feedbackCard.Line(2, { Font = Theme.FontBold, TextSize = 20 })
local feedbackExplanation = feedbackCard.Line(3, { Font = Theme.FontBody, TextSize = 18 })

local finishCard = createCard("Finish")
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

-- Percikan partikel di pintu yang dipilih
local function burst(part: BasePart, color: Color3)
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	local emitter = UiKit.new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(color),
		LightEmission = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.2),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 0,
		Parent = attachment,
	})
	emitter:Emit(50)
	Debris:AddItem(attachment, 2)
end

local function showFeedback(result)
	local section = sections[result.Section]
	local door = section and section.Doors[result.Slot]
	if door then
		burst(door.Trigger, if result.Correct then Theme.Success else Theme.Danger)
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
	feedbackCard.Hide()
	finishSubtitle.Text = `Hebat, {player.DisplayName}! Kamu sampai di tujuan seperti paket data yang dikirim router.`
	finishStats.Text = `✅ Benar: {result.Correct}    ❌ Salah: {result.Wrong}`
	finishBonus.Text = if result.Bonus > 0 then `🎁 Bonus +{result.Bonus} Poin` else "Bonus finish sudah kamu ambil di sesi ini."
	finishBonus.TextColor3 = if result.Bonus > 0 then Theme.SuccessDark else Theme.InkSoft
	finishCard.Show(9)
end

--------------------------------------------------------------------------------
Remotes.Get("Stage1Question").OnClientEvent:Connect(function(state)
	currentState = state
	renderWorld()
	renderHud()
end)
Remotes.Get("Stage1Feedback").OnClientEvent:Connect(showFeedback)
Remotes.Get("Stage1Finish").OnClientEvent:Connect(showFinish)
player:GetAttributeChangedSignal("CurrentStage"):Connect(renderHud)

renderWorld()
