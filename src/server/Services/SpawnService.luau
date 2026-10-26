--[[
	SpawnService (ModuleScript)
	Lokasi: ServerScriptService > Services > SpawnService

	Mengatur perpindahan pemain antara Lobby dan Tahap, serta titik respawn.
	Attribute pemain "CurrentStage" berisi "Lobby", "Stage1", ..., "Stage4".

	Dipakai oleh tahap-tahap game:
		SpawnService.SendToStage(player, "Stage1")
		SpawnService.SendToLobby(player)
		SpawnService.SetRespawn(player, checkpointPart) -- checkpoint Tahap 1
		SpawnService.StageChanged:Connect(function(player, areaBaru, areaLama) end)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local NotifyService = require(script.Parent.NotifyService)

local NAMES = GameConfig.Names
local LOBBY_ID = "Lobby"
local RETURN_PAD_COOLDOWN = 2

local SpawnService = {}

local stageChangedEvent = Instance.new("BindableEvent")
-- Dipicu saat pemain pindah area: (player, areaBaru, areaLama)
SpawnService.StageChanged = stageChangedEvent.Event

local respawnParts: { [Player]: BasePart } = {}
local returnPadCooldown: { [Player]: number } = {}
local initializedPlayers: { [Player]: boolean } = {}

-- Titik tengah permukaan atas sebuah part (juga untuk part yang diputar,
-- misalnya Cylinder yang direbahkan).
function SpawnService.GetTopPosition(part: BasePart): Vector3
	local cframe, size = part.CFrame, part.Size
	local halfHeight = (
		math.abs(cframe.RightVector.Y) * size.X
		+ math.abs(cframe.UpVector.Y) * size.Y
		+ math.abs(cframe.LookVector.Y) * size.Z
	) / 2
	return part.Position + Vector3.new(0, halfHeight, 0)
end

-- Arah hadap mendatar dari sisi depan (Front) sebuah part.
function SpawnService.GetFlatLook(part: BasePart): Vector3
	local look = part.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

-- Memindahkan karakter agar berdiri di atas part, menghadap sisi Front part.
function SpawnService.TeleportTo(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and root and root:IsA("BasePart")) then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local legHeight = if humanoid then math.max(humanoid.HipHeight, 2) else 2
	local position = SpawnService.GetTopPosition(part) + Vector3.new(0, legHeight + root.Size.Y / 2 + 0.5, 0)
	character:PivotTo(CFrame.lookAt(position, position + SpawnService.GetFlatLook(part)))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

function SpawnService.SetRespawn(player: Player, part: BasePart?)
	respawnParts[player] = part
end

function SpawnService.GetArea(player: Player): string
	local area = player:GetAttribute("CurrentStage")
	return if typeof(area) == "string" then area else LOBBY_ID
end

local function setArea(player: Player, areaId: string)
	local oldArea = SpawnService.GetArea(player)
	player:SetAttribute("CurrentStage", areaId)
	if oldArea ~= areaId then
		stageChangedEvent:Fire(player, areaId, oldArea)
	end
end

function SpawnService.GetStageFolder(stageId: string): Instance?
	local stages = workspace:FindFirstChild(NAMES.Stages)
	return stages and stages:FindFirstChild(stageId)
end

function SpawnService.GetStageSpawn(stageId: string): BasePart?
	local folder = SpawnService.GetStageFolder(stageId)
	local spawnPart = folder and folder:FindFirstChild(NAMES.StageSpawn, true)
	if spawnPart and spawnPart:IsA("BasePart") then
		return spawnPart
	end
	return nil
end

local function getLobbySpawn(): SpawnLocation?
	local lobby = workspace:FindFirstChild(NAMES.Lobby)
	return lobby and lobby:FindFirstChildWhichIsA("SpawnLocation", true)
end

function SpawnService.SendToStage(player: Player, stageId: string): boolean
	local spawnPart = SpawnService.GetStageSpawn(stageId)
	if not spawnPart then
		warn(`[SpawnService] Tidak ada part "{NAMES.StageSpawn}" di Workspace > {NAMES.Stages} > {stageId}`)
		return false
	end
	respawnParts[player] = spawnPart
	SpawnService.TeleportTo(player, spawnPart)
	setArea(player, stageId)
	return true
end

function SpawnService.SendToLobby(player: Player)
	respawnParts[player] = nil -- respawn kembali memakai SpawnLocation Lobby
	local lobbySpawn = getLobbySpawn()
	if lobbySpawn then
		SpawnService.TeleportTo(player, lobbySpawn)
	else
		player:LoadCharacter()
	end
	setArea(player, LOBBY_ID)
end

function SpawnService.RecallAllToLobby()
	for _, player in Players:GetPlayers() do
		SpawnService.SendToLobby(player)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local part = respawnParts[player]
	if not part then
		return
	end
	if not part:IsDescendantOf(workspace) then
		respawnParts[player] = nil
		return
	end
	character:WaitForChild("HumanoidRootPart", 5)
	task.wait() -- biarkan Roblox selesai menaruh karakter di SpawnLocation dulu
	if player.Character == character then
		SpawnService.TeleportTo(player, part)
	end
end

local function onPlayerAdded(player: Player)
	if initializedPlayers[player] then
		return
	end
	initializedPlayers[player] = true
	player:SetAttribute("CurrentStage", LOBBY_ID)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end

-- Part bernama "ReturnToLobby" di dalam Workspace > Stages mengembalikan pemain ke Lobby.
local function hookReturnPad(instance: Instance)
	if not (instance:IsA("BasePart") and instance.Name == NAMES.ReturnToLobby) then
		return
	end
	instance.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local now = os.clock()
		if (returnPadCooldown[player] or 0) > now then
			return
		end
		returnPadCooldown[player] = now + RETURN_PAD_COOLDOWN
		SpawnService.SendToLobby(player)
		NotifyService.ToPlayer(player, "🏠 Kamu kembali ke Lobby.", "info")
	end)
end

function SpawnService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		respawnParts[player] = nil
		returnPadCooldown[player] = nil
		initializedPlayers[player] = nil
	end)

	task.spawn(function()
		local stages = workspace:WaitForChild(NAMES.Stages, 15)
		if not stages then
			warn(`[SpawnService] Folder Workspace > {NAMES.Stages} belum ada. Buat dulu (lihat docs/01-studio-setup.md).`)
			return
		end
		for _, descendant in stages:GetDescendants() do
			hookReturnPad(descendant)
		end
		stages.DescendantAdded:Connect(hookReturnPad)
	end)
end

return SpawnService
