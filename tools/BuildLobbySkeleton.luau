--[[
	BuildLobbySkeleton.luau — jalankan SEKALI lewat Command Bar Roblox Studio
	(menu View > Command Bar, tempel SELURUH isi file ini, tekan Enter).

	Membuat kerangka siap-uji:
		Workspace > Lobby      (pulau, plaza, SpawnLocation, 4 portal, Videotron + Podium)
		Workspace > Stages     (Stage1..Stage4: platform, Spawn, ReturnToLobby)

	Semua nama sudah cocok dengan script inti. Setelah itu hias dengan Terrain
	dan aset Toolbox (lihat docs/01-studio-setup.md). Bentuk boleh diganti
	sesukamu, asalkan nama part penting (Gate, Screen, Spawn, dll) tetap sama.
]]

if workspace:FindFirstChild("Lobby") or workspace:FindFirstChild("Stages") then
	warn("[Skeleton] Workspace sudah punya 'Lobby' atau 'Stages'. Ganti nama/hapus dulu jika ingin membuat ulang.")
	return
end

local STAGES = {
	{ Id = "Stage1", Title = "⛰️ Tahap 1 · Routing Runner", Color = Color3.fromRGB(255, 196, 77), Base = Enum.Material.Slate, Angle = -75, Area = Vector3.new(1500, 60, 0) },
	{ Id = "Stage2", Title = "🔥 Tahap 2 · Firewall Defender", Color = Color3.fromRGB(255, 102, 64), Base = Enum.Material.Basalt, Angle = -35, Area = Vector3.new(-1500, 60, 0) },
	{ Id = "Stage3", Title = "⚡ Tahap 3 · Cable Labyrinth", Color = Color3.fromRGB(176, 112, 255), Base = Enum.Material.DiamondPlate, Angle = 35, Area = Vector3.new(0, 60, 1500) },
	{ Id = "Stage4", Title = "🍃 Tahap 4 · Bandwidth Glider", Color = Color3.fromRGB(88, 228, 196), Base = Enum.Material.Marble, Angle = 75, Area = Vector3.new(0, 400, -1500) },
}

local MARBLE = Color3.fromRGB(240, 234, 220)
local DARK_STONE = Color3.fromRGB(70, 74, 92)
local NIGHT = Color3.fromRGB(22, 26, 46)

local function make(className: string, props: { [string]: any }): any
	local instance: any = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

local function block(props: { [string]: any }): Part
	props.Anchored = true
	props.TopSurface = Enum.SurfaceType.Smooth
	props.BottomSurface = Enum.SurfaceType.Smooth
	return make("Part", props)
end

-- Silinder pipih yang rebah di tanah. cframe = titik tengah, permukaan menghadap atas.
local function disc(props: { [string]: any }, cframe: CFrame, height: number, diameter: number): Part
	local part = block(props)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
	return part
end

local function sign(parent: Instance, text: string, color: Color3, height: number, width: number?)
	local billboard = make("BillboardGui", {
		Name = "Label",
		Size = UDim2.fromOffset(width or 280, 64),
		StudsOffset = Vector3.new(0, height, 0),
		LightInfluence = 0,
		MaxDistance = 250,
		Parent = parent,
	})
	local label = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = NIGHT,
		BackgroundTransparency = 0.25,
		Text = text,
		TextColor3 = color,
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		Parent = billboard,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 12), Parent = label })
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = label })
end

--------------------------------------------------------------------------------
-- LOBBY
--------------------------------------------------------------------------------
local lobby = make("Folder", { Name = "Lobby", Parent = workspace })
local environment = make("Folder", { Name = "Environment", Parent = lobby })

-- Permukaan atas pulau di Y = 0, plaza di Y = 0.5
disc({ Name = "Island", Material = Enum.Material.Grass, Color = Color3.fromRGB(118, 186, 82), Parent = environment }, CFrame.new(0, -3, 0), 6, 320)
disc({ Name = "Plaza", Material = Enum.Material.Pavement, Color = Color3.fromRGB(226, 216, 196), Parent = environment }, CFrame.new(0, 0.25, 0), 0.5, 120)
disc({ Name = "PlazaRing", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 212, 110), Parent = environment }, CFrame.new(0, 0.2, 0), 0.4, 123)

make("SpawnLocation", {
	Name = "SpawnLocation",
	Anchored = true,
	Neutral = true,
	Duration = 0, -- tanpa ForceField
	Size = Vector3.new(12, 1, 12),
	CFrame = CFrame.lookAt(Vector3.new(0, 1, 45), Vector3.new(0, 1, 0)), -- menghadap Videotron
	Material = Enum.Material.Marble,
	Color = Color3.fromRGB(255, 226, 150),
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
	Parent = lobby,
})

-- 4 portal membentuk setengah lingkaran menghadap pusat plaza (berdiri di rumput, Y = 0)
local portals = make("Folder", { Name = "Portals", Parent = lobby })
local RADIUS = 70
for _, stage in STAGES do
	local angle = math.rad(stage.Angle)
	local position = Vector3.new(RADIUS * math.sin(angle), 0, -RADIUS * math.cos(angle))
	local base = CFrame.lookAt(position, Vector3.new(0, 0, 0))

	local model = make("Model", { Name = stage.Id, Parent = portals })
	model:SetAttribute("StageId", stage.Id)

	local pedestal = disc({ Name = "Pedestal", Material = stage.Base, Color = DARK_STONE, Parent = model }, base * CFrame.new(0, 0.5, 0), 1, 20)
	disc({ Name = "Glow", Material = Enum.Material.Neon, Color = stage.Color, Parent = model }, base * CFrame.new(0, 0.2, 0), 0.4, 23)
	for _, side in { -1, 1 } do
		block({ Name = "Pillar", Size = Vector3.new(3, 20, 3), CFrame = base * CFrame.new(side * 8.5, 11, 0), Material = Enum.Material.Marble, Color = MARBLE, Parent = model })
		block({ Name = "Glow", Size = Vector3.new(3.4, 0.8, 3.4), CFrame = base * CFrame.new(side * 8.5, 18, 0), Material = Enum.Material.Neon, Color = stage.Color, Parent = model })
	end
	block({ Name = "Lintel", Size = Vector3.new(21, 3, 4), CFrame = base * CFrame.new(0, 22.5, 0), Material = Enum.Material.Marble, Color = MARBLE, Parent = model })
	block({ Name = "Glow", Size = Vector3.new(3, 3, 3), CFrame = base * CFrame.new(0, 27.5, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Material = Enum.Material.Neon, Color = stage.Color, Parent = model })
	block({ Name = "Gate", Size = Vector3.new(14, 19.5, 0.6), CFrame = base * CFrame.new(0, 10.75, 0), Material = Enum.Material.ForceField, Color = stage.Color, Parent = model })
	model.PrimaryPart = pedestal
end

-- Videotron raksasa di utara plaza, layar menghadap SpawnLocation (+Z)
local videotron = make("Model", { Name = "Videotron", Parent = lobby })
local screenCenter = Vector3.new(0, 25, -90)
local screenCFrame = CFrame.lookAt(screenCenter, screenCenter + Vector3.new(0, 0, 1))

local screen = block({ Name = "Screen", Size = Vector3.new(48, 27, 1), CFrame = screenCFrame, Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(10, 12, 24), Parent = videotron })
screen:SetAttribute("Face", "Front")
block({ Name = "Frame", Size = Vector3.new(52, 31, 1.5), CFrame = screenCFrame * CFrame.new(0, 0, 1), Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 44, 70), Parent = videotron })
block({ Name = "Trim", Size = Vector3.new(53.5, 32.5, 0.6), CFrame = screenCFrame * CFrame.new(0, 0, 1.9), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 212, 110), Parent = videotron })
for _, side in { -1, 1 } do
	block({ Name = "Leg", Size = Vector3.new(4, 9.5, 4), CFrame = CFrame.new(side * 18, 4.75, -91), Material = Enum.Material.Marble, Color = MARBLE, Parent = videotron })
end
-- Patung juara 1 akan berdiri di atas Podium ini (sisi Front menghadap +Z)
disc({ Name = "Podium", Material = Enum.Material.Marble, Color = Color3.fromRGB(255, 226, 150), Parent = videotron }, CFrame.new(0, 2, -72) * CFrame.Angles(0, math.pi, 0), 4, 10)
videotron.PrimaryPart = screen

--------------------------------------------------------------------------------
-- STAGES (area sementara; diisi pada langkah Tahap 1-4)
--------------------------------------------------------------------------------
local stagesFolder = make("Folder", { Name = "Stages", Parent = workspace })
for _, stage in STAGES do
	local folder = make("Folder", { Name = stage.Id, Parent = stagesFolder })
	local center = stage.Area

	local platform = block({ Name = "Platform", Size = Vector3.new(80, 2, 80), CFrame = CFrame.new(center), Material = stage.Base, Color = Color3.fromRGB(90, 96, 120), Parent = folder })
	sign(platform, `{stage.Title}\n🚧 Area ini dibangun di langkah berikutnya`, stage.Color, 8, 420)

	-- Spawn menghadap -Z (ke arah tengah platform)
	block({ Name = "Spawn", Size = Vector3.new(10, 1, 10), CFrame = CFrame.new(center + Vector3.new(0, 1.5, 28)), Material = Enum.Material.Neon, Color = stage.Color, Parent = folder })

	local returnPad = block({ Name = "ReturnToLobby", Size = Vector3.new(10, 1, 10), CFrame = CFrame.new(center + Vector3.new(0, 1.5, -28)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 255, 255), Parent = folder })
	sign(returnPad, "🏠 Kembali ke Lobby", Color3.fromRGB(255, 255, 255), 4)
end

pcall(function()
	game:GetService("Selection"):Set({ lobby })
end)
print("✅ [Skeleton] Kerangka Lobby, 4 Portal, Videotron, dan Stages selesai dibuat. Simpan place (Ctrl+S)!")
