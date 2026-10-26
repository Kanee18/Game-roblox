--[[
	SetupLighting.luau — jalankan SEKALI lewat Command Bar Roblox Studio
	(menu View > Command Bar, tempel SELURUH isi file ini, tekan Enter).

	Mengatur Lighting, Atmosphere, awan, efek pasca-proses, dan warna Terrain
	bergaya anime/fantasi cerah (ala Genshin Impact). Aman dijalankan ulang.
	Properti yang tidak bisa diubah lewat script akan dilaporkan di Output;
	atur properti itu manual di jendela Properties.
]]

local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local Terrain = workspace.Terrain

local function set(instance: Instance, props: { [string]: any })
	local target: any = instance
	for key, value in props do
		local ok, err = pcall(function()
			target[key] = value
		end)
		if not ok then
			warn(`[SetupLighting] Tidak bisa mengatur {instance.Name}.{key} — atur manual di Properties. ({err})`)
		end
	end
end

-- Untuk objek yang hanya boleh ada satu (Atmosphere, Sky, Clouds).
local function single(parent: Instance, className: string): Instance
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Parent = parent
	return instance
end

-- Untuk efek pasca-proses (dicari berdasarkan nama).
local function named(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

-- 1) LIGHTING ---------------------------------------------------------------
set(Lighting, {
	Technology = Enum.Technology.Future,
	Brightness = 2.6,
	ExposureCompensation = 0.1,
	Ambient = Color3.fromRGB(86, 92, 120),
	OutdoorAmbient = Color3.fromRGB(150, 158, 196),
	ColorShift_Top = Color3.fromRGB(255, 232, 196),
	ColorShift_Bottom = Color3.fromRGB(122, 146, 210),
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 0.5,
	GlobalShadows = true,
	ShadowSoftness = 0.3,
	ClockTime = 14.2,
	GeographicLatitude = 28,
})

-- 2) ATMOSPHERE (kabut lembut + cakrawala biru-lavender) ----------------------
set(single(Lighting, "Atmosphere"), {
	Density = 0.3,
	Offset = 0.25,
	Color = Color3.fromRGB(199, 225, 255),
	Decay = Color3.fromRGB(128, 152, 222),
	Glare = 0.35,
	Haze = 1.4,
})

-- 3) SKY (matahari besar & lembut) --------------------------------------------
set(single(Lighting, "Sky"), {
	CelestialBodiesShown = true,
	SunAngularSize = 16,
	MoonAngularSize = 9,
	StarCount = 3000,
})

-- 4) AWAN DINAMIS --------------------------------------------------------------
set(single(Terrain, "Clouds"), {
	Enabled = true,
	Cover = 0.55,
	Density = 0.6,
	Color = Color3.fromRGB(255, 255, 255),
})

-- 5) EFEK PASCA-PROSES ---------------------------------------------------------
set(named(Lighting, "BloomEffect", "Bloom"), {
	Enabled = true,
	Intensity = 0.7,
	Size = 30,
	Threshold = 1.3,
})

set(named(Lighting, "SunRaysEffect", "SunRays"), {
	Enabled = true,
	Intensity = 0.1,
	Spread = 0.75,
})

set(named(Lighting, "ColorCorrectionEffect", "ColorCorrection"), {
	Enabled = true,
	Brightness = 0.02,
	Contrast = 0.12,
	Saturation = 0.22,
	TintColor = Color3.fromRGB(255, 247, 238),
})

-- Buram halus di kejauhan. Matikan (Enabled = false) jika terasa mengganggu.
set(named(Lighting, "DepthOfFieldEffect", "DepthOfField"), {
	Enabled = true,
	FarIntensity = 0.12,
	FocusDistance = 40,
	InFocusRadius = 60,
	NearIntensity = 0,
})

-- 6) TERRAIN: air jernih + rumput yang bergoyang ------------------------------
set(Terrain, {
	WaterColor = Color3.fromRGB(42, 170, 196),
	WaterTransparency = 0.65,
	WaterReflectance = 0.45,
	WaterWaveSize = 0.12,
	WaterWaveSpeed = 8,
	Decoration = true,
})

local TERRAIN_COLORS = {
	[Enum.Material.Grass] = Color3.fromRGB(118, 186, 82),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(88, 160, 72),
	[Enum.Material.Ground] = Color3.fromRGB(132, 104, 74),
	[Enum.Material.Mud] = Color3.fromRGB(110, 86, 64),
	[Enum.Material.Rock] = Color3.fromRGB(138, 134, 128),
	[Enum.Material.Slate] = Color3.fromRGB(112, 114, 124),
	[Enum.Material.Basalt] = Color3.fromRGB(70, 68, 76),
	[Enum.Material.Sand] = Color3.fromRGB(232, 214, 166),
	[Enum.Material.Sandstone] = Color3.fromRGB(214, 170, 120),
	[Enum.Material.Limestone] = Color3.fromRGB(226, 214, 186),
	[Enum.Material.Pavement] = Color3.fromRGB(196, 190, 178),
	[Enum.Material.Cobblestone] = Color3.fromRGB(170, 162, 150),
	[Enum.Material.Snow] = Color3.fromRGB(240, 246, 255),
}
for material, color in TERRAIN_COLORS do
	local ok, err = pcall(function()
		Terrain:SetMaterialColor(material, color)
	end)
	if not ok then
		warn(`[SetupLighting] Warna terrain {material.Name} gagal diatur: {err}`)
	end
end

-- 7) MATERIAL PBR 2022 ---------------------------------------------------------
set(MaterialService, { Use2022Materials = true })

print("✅ [SetupLighting] Selesai! Simpan place (Ctrl+S). Cek jendela Output untuk properti yang perlu diatur manual.")
