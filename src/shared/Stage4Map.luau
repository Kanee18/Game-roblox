--[[
	Stage4Map (ModuleScript)
	Lokasi: ReplicatedStorage > Shared > Stage4Map

	Membaca susunan peta Bandwidth Glider. Dipakai server DAN client supaya
	urutan gerbang, cincin A/B, dan arah terbang selalu sama. Tidak berisi
	kunci jawaban.

	Struktur yang dibaca:
		Workspace > Stages > Stage4
			LaunchPad (Part)            <- injak untuk mulai terbang
			LandingZone (Part)          <- volume tak terlihat di ujung lintasan
			Gates (Folder)
				Gate1 (Model)           <- urutan dari Attribute "Order" atau angka di nama
					RingA (Model) > Trigger (Part, WAJIB)
					RingB (Model) > Trigger (Part, WAJIB)
				Gate2 ...
]]

local Stage4Map = {}

Stage4Map.StageId = "Stage4"
Stage4Map.LaunchHeight = 3 -- tinggi badan pemain di atas LaunchPad saat mulai terbang

export type Ring = {
	Slot: number,
	Letter: string,
	Instance: Instance,
	Trigger: BasePart,
}

export type Gate = {
	Index: number,
	Instance: Instance,
	Center: Vector3,
	Rings: { Ring },
}

export type Map = {
	Gates: { Gate },
	LaunchPad: BasePart?,
	Landing: BasePart?,
	Forward: Vector3, -- arah terbang mendatar
	Slope: number, -- turun berapa stud untuk setiap 1 stud maju
}

function Stage4Map.Letter(slot: number): string
	return string.char(64 + slot)
end

local function findPart(parent: Instance, name: string): BasePart?
	local found = parent:FindFirstChild(name, true)
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

local function readRings(gate: Instance): { Ring }
	local children = {}
	for _, child in gate:GetChildren() do
		if string.sub(child.Name, 1, 4) == "Ring" then
			table.insert(children, child)
		end
	end
	table.sort(children, function(a, b)
		return a.Name < b.Name
	end)
	local rings = {}
	for _, child in children do
		local trigger = if child:IsA("BasePart") then child else findPart(child, "Trigger")
		if trigger then
			local slot = #rings + 1
			table.insert(rings, {
				Slot = slot,
				Letter = Stage4Map.Letter(slot),
				Instance = child,
				Trigger = trigger,
			})
		end
	end
	return rings
end

function Stage4Map.Read(stageFolder: Instance): Map
	local launchPad = findPart(stageFolder, "LaunchPad")
	local landing = findPart(stageFolder, "LandingZone")

	local forward = Vector3.new(0, 0, -1)
	local slope = 0.1
	if launchPad and landing then
		local offset = landing.Position - launchPad.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude > 1 then
			forward = flat.Unit
			local launchY = launchPad.Position.Y + launchPad.Size.Y / 2 + Stage4Map.LaunchHeight
			slope = math.max(0, (launchY - landing.Position.Y) / flat.Magnitude)
		end
	end

	local ordered = {}
	local gatesFolder = stageFolder:FindFirstChild("Gates")
	if gatesFolder then
		for _, child in gatesFolder:GetChildren() do
			local order = child:GetAttribute("Order")
			if typeof(order) ~= "number" then
				order = tonumber(string.match(child.Name, "%d+"))
			end
			if order then
				table.insert(ordered, { Order = order, Instance = child })
			end
		end
	end
	table.sort(ordered, function(a, b)
		return a.Order < b.Order
	end)

	local gates = {}
	for _, item in ordered do
		local rings = readRings(item.Instance)
		if #rings > 0 then
			local center = Vector3.zero
			for _, ring in rings do
				center += ring.Trigger.Position
			end
			table.insert(gates, {
				Index = #gates + 1,
				Instance = item.Instance,
				Center = center / #rings,
				Rings = rings,
			})
		end
	end

	return {
		Gates = gates,
		LaunchPad = launchPad,
		Landing = landing,
		Forward = forward,
		Slope = slope,
	}
end

return Stage4Map
