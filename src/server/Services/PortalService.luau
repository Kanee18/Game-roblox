--[[
	PortalService (ModuleScript)
	Lokasi: ServerScriptService > Services > PortalService

	Mengatur 4 portal elemen di Lobby. Hanya Guru (lewat AdminService) yang
	bisa membuka/menutup portal. Siswa yang menyentuh portal terbuka akan
	dipindahkan ke tahap tersebut.

	Struktur yang dibutuhkan di Explorer:
		Workspace > Lobby > Portals > Stage1 (Model)
			Gate (Part)          <- WAJIB: bidang portal yang disentuh pemain
			Glow (Part, opsional) <- boleh banyak; menyala saat portal terbuka
		... begitu juga Stage2, Stage3, Stage4

	Script ini otomatis menambahkan partikel, cahaya, dan papan nama portal.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(ReplicatedStorage.Shared.UiKit)
local NotifyService = require(script.Parent.NotifyService)
local SpawnService = require(script.Parent.SpawnService)

local NAMES = GameConfig.Names
local CONFIG = GameConfig.Portals
local Theme = GameConfig.Theme

local PortalService = {}

type PortalEntry = {
	Stage: any,
	Gate: BasePart,
	Glows: { BasePart },
	Particles: ParticleEmitter,
	Light: PointLight,
	StatusLabel: TextLabel,
}

local state = Remotes.GetState()
local openState: { [string]: boolean } = {}
local entries: { [string]: PortalEntry } = {}
local touchCooldown: { [Player]: number } = {}

local function makeParticles(stage, gate: BasePart): ParticleEmitter
	return UiKit.new("ParticleEmitter", {
		Name = "PortalSparkles",
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(stage.Color, Color3.new(1, 1, 1)),
		LightEmission = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(1.2, 2.2),
		Rate = 30,
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		RotSpeed = NumberRange.new(-90, 90),
		Parent = gate,
	})
end

local function makeLight(stage, gate: BasePart): PointLight
	return UiKit.new("PointLight", {
		Name = "PortalLight",
		Color = stage.Color,
		Range = 18,
		Brightness = 2,
		Shadows = false,
		Parent = gate,
	})
end

-- Papan nama melayang di atas portal. Mengembalikan label status.
local function makeBillboard(stage, gate: BasePart): TextLabel
	local old = gate:FindFirstChild("PortalInfo")
	if old then
		old:Destroy()
	end

	-- Attribute "LabelHeight" pada Gate (opsional) = jarak papan nama di atas Gate, dalam stud.
	local labelHeight = gate:GetAttribute("LabelHeight")
	if typeof(labelHeight) ~= "number" then
		labelHeight = 10
	end

	local billboard = UiKit.new("BillboardGui", {
		Name = "PortalInfo",
		Adornee = gate,
		-- Ukuran campuran (stud + piksel): papan portal yang jauh ikut mengecil sehingga
		-- keempat papan tidak saling menumpuk di layar HP.
		Size = UDim2.new(10, 110, 4, 46),
		StudsOffsetWorldSpace = Vector3.new(0, SpawnService.GetTopPosition(gate).Y - gate.Position.Y + labelHeight, 0),
		MaxDistance = 160,
		LightInfluence = 0,
		AlwaysOnTop = false,
		Parent = gate,
	})

	local card = UiKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Night,
		BackgroundTransparency = 0.2,
		Parent = billboard,
	}, {
		UiKit.corner(UDim.new(0.1, 0)),
		UiKit.stroke(stage.Color, 2),
		UiKit.new("UIPadding", { PaddingLeft = UDim.new(0.04, 0), PaddingRight = UDim.new(0.04, 0) }),
	})

	-- Semua baris memakai posisi persen + TextScaled supaya ikut menyesuaikan ukuran papan.
	local function line(props: { [string]: any }, maxTextSize: number): TextLabel
		props.TextScaled = true
		props.Parent = card
		return UiKit.label(props, { UiKit.new("UITextSizeConstraint", { MaxTextSize = maxTextSize }) })
	end

	local title = line({
		Text = `{stage.ElementIcon} PORTAL {string.upper(stage.Element)}`,
		Position = UDim2.fromScale(0, 0.04),
		Size = UDim2.fromScale(1, 0.26),
		TextColor3 = stage.Color,
	}, 28)
	UiKit.textStroke(Theme.Night, 2).Parent = title

	line({
		Text = `Tahap {stage.Number} · {stage.Title}`,
		Position = UDim2.fromScale(0, 0.31),
		Size = UDim2.fromScale(1, 0.18),
	}, 20)

	line({
		Text = `📘 {stage.Materi}`,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 0.16),
		Font = Theme.FontBody,
		TextColor3 = Theme.Cream,
	}, 15)

	return line({
		Name = "Status",
		Position = UDim2.fromScale(0, 0.7),
		Size = UDim2.fromScale(1, 0.24),
	}, 22)
end

local function applyVisual(stageId: string)
	local entry = entries[stageId]
	if not entry then
		return
	end
	local isOpen = openState[stageId] == true
	local color = if isOpen then entry.Stage.Color else CONFIG.ClosedColor

	local gate = entry.Gate
	gate.Material = Enum.Material.ForceField
	gate.Color = color
	gate.Transparency = if isOpen then 0 else 0.35
	gate.CanCollide = not isOpen -- portal tertutup menjadi dinding
	gate.CanTouch = true

	for _, glow in entry.Glows do
		glow.Color = color
		glow.Material = if isOpen then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end

	entry.Particles.Enabled = isOpen
	entry.Light.Enabled = isOpen
	entry.StatusLabel.Text = if isOpen then "✨ TERBUKA — Ayo masuk!" else "🔒 TERKUNCI"
	entry.StatusLabel.TextColor3 = if isOpen then Theme.Success else Theme.Danger
end

local function setState(stageId: string, isOpen: boolean)
	openState[stageId] = isOpen
	state:SetAttribute(GameConfig.PortalStatePrefix .. stageId, isOpen)
	applyVisual(stageId)
end

local function onGateTouched(stage, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not (character and player) then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()
	if (touchCooldown[player] or 0) > now then
		return
	end

	local isOpen = openState[stage.Id] == true
	local isTeacher = player:GetAttribute("IsAdmin") == true

	if not isOpen and not isTeacher then
		touchCooldown[player] = now + 3
		NotifyService.ToPlayer(player, "🔒 Portal ini masih terkunci. Tunggu instruksi dari Guru, ya!", "error")
		return
	end

	touchCooldown[player] = now + CONFIG.TouchCooldown
	if SpawnService.SendToStage(player, stage.Id) then
		NotifyService.ToPlayer(player, `{stage.ElementIcon} Selamat datang di Tahap {stage.Number}: {stage.Title}!`, "portal")
		NotifyService.ToPlayer(player, stage.Description, "info")
		if not isOpen then
			NotifyService.ToPlayer(player, "👀 Mode Guru: portal ini masih tertutup untuk siswa.", "info")
		end
	else
		NotifyService.ToPlayer(player, "🚧 Peta tahap ini belum siap. Beri tahu Guru, ya!", "error")
	end
end

local function findPortalModel(portalsFolder: Instance, stageId: string): Instance?
	local byName = portalsFolder:FindFirstChild(stageId)
	if byName then
		return byName
	end
	for _, child in portalsFolder:GetChildren() do
		if child:GetAttribute("StageId") == stageId then
			return child
		end
	end
	return nil
end

local function setupPortal(stage, portalsFolder: Instance)
	local model = findPortalModel(portalsFolder, stage.Id)
	if not model then
		warn(`[PortalService] Portal "{stage.Id}" tidak ditemukan di Workspace > {NAMES.Lobby} > {NAMES.Portals}`)
		return
	end
	local gate = model:FindFirstChild(NAMES.PortalGate, true)
	if not (gate and gate:IsA("BasePart")) then
		warn(`[PortalService] Portal "{stage.Id}" belum punya Part bernama "{NAMES.PortalGate}"`)
		return
	end

	local glows = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == NAMES.PortalGlow then
			table.insert(glows, descendant)
		end
	end

	entries[stage.Id] = {
		Stage = stage,
		Gate = gate,
		Glows = glows,
		Particles = makeParticles(stage, gate),
		Light = makeLight(stage, gate),
		StatusLabel = makeBillboard(stage, gate),
	}

	gate.Touched:Connect(function(hit)
		onGateTouched(stage, hit)
	end)
	applyVisual(stage.Id)
end

function PortalService.IsOpen(stageId: string): boolean
	return openState[stageId] == true
end

function PortalService.SetOpen(stageId: string, isOpen: boolean): boolean
	local stage = GameConfig.StageById[stageId]
	if not stage then
		return false
	end
	if openState[stageId] == isOpen then
		return true
	end

	if isOpen and CONFIG.OnlyOneOpen then
		for otherId, otherOpen in openState do
			if otherId ~= stageId and otherOpen then
				setState(otherId, false)
			end
		end
	end
	setState(stageId, isOpen)

	if isOpen then
		NotifyService.ToAll(
			`{stage.ElementIcon} Portal {stage.Element} DIBUKA! Tahap {stage.Number}: {stage.Title} — Materi: {stage.Materi}`,
			"portal"
		)
	else
		NotifyService.ToAll(`🔒 Portal {stage.Element} (Tahap {stage.Number}) ditutup oleh Guru.`, "info")
	end
	return true
end

function PortalService.CloseAll()
	for _, stage in GameConfig.Stages do
		setState(stage.Id, false)
	end
	NotifyService.ToAll("🔒 Semua portal ditutup oleh Guru.", "info")
end

function PortalService.Start()
	for _, stage in GameConfig.Stages do
		setState(stage.Id, CONFIG.StartOpen)
	end

	Players.PlayerRemoving:Connect(function(player)
		touchCooldown[player] = nil
	end)

	task.spawn(function()
		local lobby = workspace:WaitForChild(NAMES.Lobby, 15)
		local portalsFolder = lobby and lobby:WaitForChild(NAMES.Portals, 15)
		if not portalsFolder then
			warn(`[PortalService] Folder Workspace > {NAMES.Lobby} > {NAMES.Portals} tidak ditemukan.`)
			return
		end
		for _, stage in GameConfig.Stages do
			setupPortal(stage, portalsFolder)
		end
	end)
end

return PortalService
