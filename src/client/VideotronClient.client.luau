--[[
	VideotronClient (LocalScript)
	Lokasi: StarterPlayer > StarterPlayerScripts > VideotronClient

	Menggambar layar raksasa di Lobby (SurfaceGui pada Part "Screen"):
	  * Avatar 3D juara 1 yang berputar pelan (ViewportFrame)
	  * Nama, @username, dan Poin juara 1
	  * Peringkat 2 sampai 5
	  * Teks berjalan "Tahukah kamu?" berisi fakta Jaringan Komputer
	Data dikirim oleh VideotronService (server).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UiKit = require(Shared:WaitForChild("UiKit"))

local NAMES = GameConfig.Names
local CONFIG = GameConfig.Videotron
local Theme = GameConfig.Theme

local CANVAS_SIZE = Vector2.new(1600, 900) -- layar 16:9
local OTHER_RANKS = math.clamp(CONFIG.ShowTop - 1, 0, 4)
local RANK_COLORS = {
	Color3.fromRGB(214, 224, 240), -- #2 perak
	Color3.fromRGB(232, 162, 112), -- #3 perunggu
}

local player = Players.LocalPlayer
local state = Remotes.GetState()
local avatarFolder = ReplicatedStorage:WaitForChild("VideotronAvatar")

local lobby = workspace:WaitForChild(NAMES.Lobby)
local videotron = lobby:WaitForChild(NAMES.Videotron)
local screen = videotron:WaitForChild(NAMES.VideotronScreen)

-- Attribute "Face" pada Part Screen (opsional): Front/Back/Left/Right/Top/Bottom
local function getFace(): Enum.NormalId
	local faceName = screen:GetAttribute("Face")
	if typeof(faceName) == "string" then
		for _, item in Enum.NormalId:GetEnumItems() do
			if item.Name == faceName then
				return item
			end
		end
	end
	return Enum.NormalId.Front
end

local surface = UiKit.new("SurfaceGui", {
	Name = "VideotronGui",
	Adornee = screen,
	Face = getFace(),
	SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
	CanvasSize = CANVAS_SIZE,
	LightInfluence = 0,
	Brightness = 1.3, -- sedikit berpendar bersama efek Bloom
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local root = UiKit.new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Theme.White,
	BorderSizePixel = 0,
	Parent = surface,
}, { UiKit.gradient(Color3.fromRGB(26, 34, 78), Color3.fromRGB(78, 42, 116), 35) })

--------------------------------------------------------------------------------
-- Judul
--------------------------------------------------------------------------------
UiKit.label({
	Text = CONFIG.Title,
	Position = UDim2.fromOffset(0, 18),
	Size = UDim2.new(1, 0, 0, 84),
	TextSize = 76,
	TextColor3 = Theme.GoldBright,
	TextWrapped = false,
	Parent = root,
}, { UiKit.textStroke(Theme.Night, 4) })

UiKit.label({
	Text = CONFIG.Subtitle,
	Position = UDim2.fromOffset(0, 100),
	Size = UDim2.new(1, 0, 0, 36),
	Font = Theme.FontBold,
	TextSize = 30,
	TextColor3 = Theme.Cream,
	TextWrapped = false,
	Parent = root,
})

--------------------------------------------------------------------------------
-- Kartu avatar juara 1 (kiri)
--------------------------------------------------------------------------------
local avatarCard = UiKit.new("Frame", {
	Position = UDim2.fromOffset(50, 155),
	Size = UDim2.fromOffset(640, 620),
	BackgroundColor3 = Theme.White,
	Parent = root,
}, {
	UiKit.corner(28),
	UiKit.stroke(Theme.GoldBright, 6),
	UiKit.gradient(Color3.fromRGB(255, 238, 196), Color3.fromRGB(148, 206, 255), 90),
})

UiKit.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromOffset(470, 470),
	BackgroundColor3 = Theme.White,
	BackgroundTransparency = 0.45,
	Parent = avatarCard,
}, { UiKit.corner(UDim.new(0.5, 0)) })

local viewport = UiKit.new("ViewportFrame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(200, 200, 215),
	LightColor = Color3.fromRGB(255, 244, 228),
	LightDirection = Vector3.new(0.4, -0.7, 1),
	Parent = avatarCard,
})
local worldModel = UiKit.new("WorldModel", { Parent = viewport })
local camera = UiKit.new("Camera", { FieldOfView = 32, Parent = viewport })
viewport.CurrentCamera = camera

local placeholder = UiKit.label({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromOffset(520, 300),
	Text = "❔\nBelum ada juara.\nJawab soal dengan benar\nuntuk tampil di sini!",
	TextSize = 44,
	TextColor3 = Theme.Ink,
	Parent = avatarCard,
})

local crown = UiKit.label({
	Position = UDim2.fromOffset(24, 24),
	Size = UDim2.fromOffset(230, 64),
	BackgroundTransparency = 0,
	BackgroundColor3 = Theme.GoldBright,
	Text = "👑 JUARA 1",
	TextSize = 36,
	TextColor3 = Theme.Ink,
	Visible = false,
	Parent = avatarCard,
}, { UiKit.corner(32), UiKit.stroke(Theme.Night, 3) })

--------------------------------------------------------------------------------
-- Panel info (kanan)
--------------------------------------------------------------------------------
local infoPanel = UiKit.new("Frame", {
	Position = UDim2.fromOffset(730, 155),
	Size = UDim2.fromOffset(820, 620),
	BackgroundColor3 = Theme.Night,
	BackgroundTransparency = 0.35,
	Parent = root,
}, {
	UiKit.corner(28),
	UiKit.stroke(Theme.Gold, 3, 0.3),
	UiKit.padding(30),
})

local nameLabel = UiKit.label({
	Size = UDim2.new(1, 0, 0, 100),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = infoPanel,
}, { UiKit.new("UITextSizeConstraint", { MaxTextSize = 84 }) })

local usernameLabel = UiKit.label({
	Position = UDim2.fromOffset(0, 100),
	Size = UDim2.new(1, 0, 0, 40),
	Font = Theme.FontBold,
	TextSize = 32,
	TextColor3 = Theme.Cream,
	TextTransparency = 0.2,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = false,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Parent = infoPanel,
})

local pointsLabel = UiKit.label({
	Position = UDim2.fromOffset(0, 145),
	Size = UDim2.new(1, 0, 0, 120),
	TextSize = 110,
	TextColor3 = Theme.GoldBright,
	TextWrapped = false,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = infoPanel,
}, { UiKit.textStroke(Theme.Night, 4) })
local pointsScale = UiKit.new("UIScale", { Parent = pointsLabel })

UiKit.new("Frame", {
	Position = UDim2.fromOffset(0, 275),
	Size = UDim2.new(1, 0, 0, 4),
	BackgroundColor3 = Theme.Gold,
	BackgroundTransparency = 0.4,
	BorderSizePixel = 0,
	Parent = infoPanel,
})

UiKit.label({
	Text = "🏅 Peringkat Berikutnya",
	Position = UDim2.fromOffset(0, 290),
	Size = UDim2.new(1, 0, 0, 40),
	TextSize = 34,
	TextColor3 = Theme.Cream,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = infoPanel,
})

local rows = {}
for index = 1, OTHER_RANKS do
	local row = UiKit.new("Frame", {
		Position = UDim2.fromOffset(0, 340 + (index - 1) * 52),
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Theme.White,
		BackgroundTransparency = 0.9,
		Parent = infoPanel,
	}, { UiKit.corner(12) })

	UiKit.label({
		Text = `#{index + 1}`,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(0, 70, 1, 0),
		TextSize = 32,
		TextColor3 = RANK_COLORS[index] or Theme.Cream,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		Parent = row,
	})
	local rowName = UiKit.label({
		Position = UDim2.fromOffset(90, 0),
		Size = UDim2.new(1, -340, 1, 0),
		Font = Theme.FontBold,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	local rowPoints = UiKit.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 0),
		Size = UDim2.new(0, 230, 1, 0),
		TextSize = 30,
		TextColor3 = Theme.GoldBright,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		Parent = row,
	})
	rows[index] = { Name = rowName, Points = rowPoints }
end

--------------------------------------------------------------------------------
-- Teks berjalan "Tahukah kamu?"
--------------------------------------------------------------------------------
local tickerHolder = UiKit.new("Frame", {
	Position = UDim2.fromOffset(50, 800),
	Size = UDim2.fromOffset(1500, 70),
	BackgroundColor3 = Theme.Night,
	BackgroundTransparency = 0.3,
	ClipsDescendants = true,
	Parent = root,
}, { UiKit.corner(35) })

local tickerLabel = UiKit.label({
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(1, 0, 0.5, 0),
	Size = UDim2.new(0, 1000, 1, 0),
	Font = Theme.FontBold,
	TextSize = 34,
	TextColor3 = Theme.Cream,
	TextWrapped = false,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = tickerHolder,
})

task.spawn(function()
	local facts = CONFIG.Facts
	if #facts == 0 then
		tickerHolder.Visible = false
		return
	end
	local index = 0
	while true do
		index = index % #facts + 1
		local text = CONFIG.TickerPrefix .. facts[index]
		local width = TextService:GetTextSize(text, tickerLabel.TextSize, tickerLabel.Font, Vector2.new(20000, 100)).X + 40
		tickerLabel.Text = text
		tickerLabel.Size = UDim2.new(0, width, 1, 0)
		tickerLabel.Position = UDim2.new(1, 0, 0.5, 0)
		local travel = tickerHolder.Size.X.Offset + width
		UiKit.tween(tickerLabel, travel / CONFIG.TickerSpeed, {
			Position = UDim2.new(0, -width, 0.5, 0),
		}, Enum.EasingStyle.Linear).Completed:Wait()
		task.wait(0.5)
	end
end)

--------------------------------------------------------------------------------
-- Avatar 3D juara 1
--------------------------------------------------------------------------------
local currentAvatar: Model? = nil
local focus = Vector3.zero
local cameraDistance = 12
local avatarQueued = false

local function showAvatar()
	if currentAvatar then
		currentAvatar:Destroy()
		currentAvatar = nil
	end
	local source = avatarFolder:FindFirstChildWhichIsA("Model")
	placeholder.Visible = source == nil
	crown.Visible = source ~= nil
	if not source then
		return
	end

	local model = source:Clone()
	model:PivotTo(CFrame.new()) -- avatar menghadap -Z di titik (0, 0, 0)
	model.Parent = worldModel
	local boxCFrame, boxSize = model:GetBoundingBox()
	focus = boxCFrame.Position + Vector3.new(0, boxSize.Y * 0.04, 0)
	cameraDistance = (boxSize.Y / 2) / math.tan(math.rad(camera.FieldOfView / 2)) * 1.25
	currentAvatar = model
end

local function queueAvatar()
	if avatarQueued then
		return
	end
	avatarQueued = true
	task.defer(function()
		avatarQueued = false
		showAvatar()
	end)
end

avatarFolder.ChildAdded:Connect(queueAvatar)
avatarFolder.ChildRemoved:Connect(queueAvatar)
showAvatar()

-- Kamera bergoyang pelan ke kiri-kanan di depan avatar.
local elapsed = 0
RunService.RenderStepped:Connect(function(deltaTime)
	if not currentAvatar then
		return
	end
	elapsed += deltaTime
	local angle = math.sin(elapsed * 0.7) * math.rad(40)
	local offset = Vector3.new(math.sin(angle), 0.08, -math.cos(angle)) * cameraDistance
	camera.CFrame = CFrame.lookAt(focus + offset, focus)
end)

--------------------------------------------------------------------------------
-- Data papan peringkat
--------------------------------------------------------------------------------
local lastChampionKey: string? = nil

local function render()
	local board = {}
	local raw = state:GetAttribute("Leaderboard")
	if typeof(raw) == "string" then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if ok and typeof(decoded) == "table" then
			board = decoded
		end
	end

	local champion = board[1]
	if champion then
		nameLabel.Text = champion.DisplayName
		usernameLabel.Text = `@{champion.Name}`
		pointsLabel.Text = `{UiKit.formatNumber(champion.Points)} Poin`
	else
		nameLabel.Text = "Belum ada juara"
		usernameLabel.Text = "Ayo kumpulkan Poin di setiap tahap!"
		pointsLabel.Text = "0 Poin"
	end

	for index, row in rows do
		local entry = board[index + 1]
		row.Name.Text = if entry then entry.DisplayName else "—"
		row.Points.Text = if entry then `{UiKit.formatNumber(entry.Points)} Poin` else ""
	end

	local championKey = if champion then `{champion.UserId}:{champion.Points}` else nil
	if championKey ~= lastChampionKey then
		lastChampionKey = championKey
		pointsScale.Scale = 1.12
		UiKit.tween(pointsScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

state:GetAttributeChangedSignal("Leaderboard"):Connect(render)
render()
