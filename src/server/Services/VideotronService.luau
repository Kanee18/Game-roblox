--[[
	VideotronService (ModuleScript)
	Lokasi: ServerScriptService > Services > VideotronService

	Menghitung papan peringkat dan menyiapkan avatar 3D juara 1.
	  * Data peringkat  -> Attribute "Leaderboard" (JSON) di ReplicatedStorage > GameState
	  * Avatar juara    -> Model di ReplicatedStorage > VideotronAvatar
	                       (ditampilkan VideotronClient di layar lewat ViewportFrame)
	  * Patung juara    -> berdiri di atas Part "Podium" (opsional) di dalam Videotron

	Struktur di Explorer:
		Workspace > Lobby > Videotron (Model)
			Screen (Part)          <- WAJIB: layar 16:9, sisi Front menghadap pemain
			Podium (Part, opsional) <- patung juara muncul di atasnya
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(ReplicatedStorage.Shared.UiKit)
local PointsService = require(script.Parent.PointsService)
local SpawnService = require(script.Parent.SpawnService)

local NAMES = GameConfig.Names
local CONFIG = GameConfig.Videotron

local VideotronService = {}

local state = Remotes.GetState()

local avatarFolder = ReplicatedStorage:FindFirstChild("VideotronAvatar")
if not avatarFolder then
	avatarFolder = Instance.new("Folder")
	avatarFolder.Name = "VideotronAvatar"
	avatarFolder.Parent = ReplicatedStorage
end

local avatarCache: { [number]: Model } = {} -- UserId -> model avatar siap pakai
local championUserId: number? = nil
local buildToken = 0
local podiumStatue: Model? = nil
local dirty = true

local function getVideotron(): Instance?
	local lobby = workspace:FindFirstChild(NAMES.Lobby)
	return lobby and lobby:FindFirstChild(NAMES.Videotron)
end

local function markDirty()
	dirty = true
end

local function getDescription(player: Player): HumanoidDescription
	-- 1) Penampilan karakter yang sedang dipakai (juga berhasil untuk pemain uji Studio).
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local ok, description = pcall(humanoid.GetAppliedDescription, humanoid)
		if ok and description then
			return description
		end
	end
	-- 2) Penampilan dari profil Roblox.
	if player.UserId > 0 then
		local ok, description = pcall(Players.GetHumanoidDescriptionFromUserId, Players, player.UserId)
		if ok and description then
			return description
		end
	end
	-- 3) Avatar bawaan.
	return Instance.new("HumanoidDescription")
end

-- Membuat model avatar R15 statis (semua part di-anchor, tanpa script).
local function getAvatarTemplate(player: Player): Model?
	local cached = avatarCache[player.UserId]
	if cached then
		return cached
	end

	local ok, model = pcall(Players.CreateHumanoidModelFromDescription, Players, getDescription(player), Enum.HumanoidRigType.R15)
	if not ok or not model then
		warn(`[VideotronService] Gagal membuat avatar {player.Name}:`, model)
		return nil
	end
	if player.Parent == nil then
		model:Destroy()
		return nil
	end

	model.Name = "Avatar_" .. player.UserId
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end

	avatarCache[player.UserId] = model
	return model
end

local function statueName(entry): string
	return `👑 {entry.DisplayName} · {UiKit.formatNumber(entry.Points)} Poin`
end

local function updatePodium(template: Model?, entry)
	if podiumStatue then
		podiumStatue:Destroy()
		podiumStatue = nil
	end
	local videotron = getVideotron()
	local podium = videotron and videotron:FindFirstChild(NAMES.VideotronPodium, true)
	if not (template and podium and podium:IsA("BasePart")) then
		return
	end

	local statue = template:Clone()
	statue.Name = "PatungJuara"
	local humanoid = statue:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = statueName(entry)
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		humanoid.NameDisplayDistance = 90
	end

	-- Berdiri tepat di atas podium, menghadap sisi Front podium.
	local boxCFrame, boxSize = statue:GetBoundingBox()
	local pivotFromBox = boxCFrame:ToObjectSpace(statue:GetPivot())
	local center = SpawnService.GetTopPosition(podium) + Vector3.new(0, boxSize.Y / 2, 0)
	local targetBox = CFrame.lookAt(center, center + SpawnService.GetFlatLook(podium))
	statue:PivotTo(targetBox * pivotFromBox)
	statue.Parent = videotron
	podiumStatue = statue
end

local function setChampion(entry)
	buildToken += 1
	local token = buildToken

	if not entry then
		avatarFolder:ClearAllChildren()
		updatePodium(nil, nil)
		return
	end

	task.spawn(function()
		local template = getAvatarTemplate(entry.Player) -- bisa menunggu beberapa detik
		if token ~= buildToken then
			return -- juara sudah berganti lagi selama menunggu
		end
		avatarFolder:ClearAllChildren()
		if template then
			local copy = template:Clone()
			copy.Name = "Juara"
			copy:SetAttribute("UserId", entry.UserId)
			copy.Parent = avatarFolder
		end
		updatePodium(template, entry)
	end)
end

local function refresh()
	local board = PointsService.GetLeaderboard(CONFIG.ShowTop)

	local payload = {}
	for _, entry in board do
		if entry.Points > 0 then
			table.insert(payload, {
				UserId = entry.UserId,
				Name = entry.Name,
				DisplayName = entry.DisplayName,
				Points = entry.Points,
			})
		end
	end
	state:SetAttribute("Leaderboard", HttpService:JSONEncode(payload))

	local champion = board[1]
	if champion and champion.Points <= 0 then
		champion = nil
	end
	local newChampionId = if champion then champion.UserId else nil

	if newChampionId ~= championUserId then
		championUserId = newChampionId
		setChampion(champion)
	elseif champion and podiumStatue then
		local humanoid = podiumStatue:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayName = statueName(champion)
		end
	end
end

local function watchPlayer(player: Player)
	player:GetAttributeChangedSignal("IsAdmin"):Connect(markDirty)
	markDirty()
end

function VideotronService.Start()
	state:SetAttribute("Leaderboard", "[]")

	PointsService.Changed:Connect(markDirty)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local cached = avatarCache[player.UserId]
		if cached then
			cached:Destroy()
			avatarCache[player.UserId] = nil
		end
		markDirty()
	end)

	-- Videotron selalu dimuat di client walaupun StreamingEnabled aktif.
	task.spawn(function()
		local lobby = workspace:WaitForChild(NAMES.Lobby, 15)
		local videotron = lobby and lobby:WaitForChild(NAMES.Videotron, 15)
		if not videotron then
			warn(`[VideotronService] Model Workspace > {NAMES.Lobby} > {NAMES.Videotron} tidak ditemukan.`)
			return
		end
		if videotron:IsA("Model") then
			pcall(function()
				videotron.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
			end)
		end
	end)

	task.spawn(function()
		while true do
			if dirty then
				dirty = false
				local ok, err = pcall(refresh)
				if not ok then
					warn("[VideotronService] Gagal memperbarui papan peringkat:", err)
				end
			end
			task.wait(CONFIG.RefreshInterval)
		end
	end)
end

return VideotronService
