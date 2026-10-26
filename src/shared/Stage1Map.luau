--[[
	Stage1Map (ModuleScript)
	Lokasi: ReplicatedStorage > Shared > Stage1Map

	Membaca susunan peta Routing Runner. Dipakai server DAN client supaya
	urutan gerbang dan pintu selalu sama di keduanya. Modul ini TIDAK berisi
	kunci jawaban.

	Struktur yang dibaca:
		Workspace > Stages > Stage1
			Sections (Folder)
				Section1 (Folder/Model)   <- urutan dari Attribute "Order" atau angka di nama
					Doors (Folder)
						DoorA (Model) > Trigger (Part, WAJIB) + Sign (Part, opsional)
						DoorB, DoorC, ...       <- diurutkan menurut nama: A, B, C
					QuestionBoard (Part, opsional) <- papan soal
					Checkpoint (Part)              <- titik respawn setelah gerbang ini
]]

local Stage1Map = {}

Stage1Map.StageId = "Stage1"

export type Door = {
	Slot: number,
	Letter: string,
	Instance: Instance,
	Trigger: BasePart,
	Sign: BasePart?,
}

export type Section = {
	Index: number,
	Title: string?,
	Instance: Instance,
	Doors: { Door },
	Board: BasePart?,
	Checkpoint: BasePart?,
}

function Stage1Map.Letter(slot: number): string
	return string.char(64 + slot) -- 1 -> "A", 2 -> "B", ...
end

local function findPart(parent: Instance, name: string): BasePart?
	local found = parent:FindFirstChild(name, true)
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

local function readDoors(section: Instance): { Door }
	local doors = {}
	local doorsFolder = section:FindFirstChild("Doors")
	if not doorsFolder then
		return doors
	end
	local children = doorsFolder:GetChildren()
	table.sort(children, function(a, b)
		return a.Name < b.Name
	end)
	for _, door in children do
		local trigger = if door:IsA("BasePart") then door else findPart(door, "Trigger")
		if trigger then
			local slot = #doors + 1
			table.insert(doors, {
				Slot = slot,
				Letter = Stage1Map.Letter(slot),
				Instance = door,
				Trigger = trigger,
				Sign = if door:IsA("BasePart") then nil else findPart(door, "Sign"),
			})
		end
	end
	return doors
end

function Stage1Map.Read(stageFolder: Instance): { Section }
	local sectionsFolder = stageFolder:FindFirstChild("Sections")
	if not sectionsFolder then
		return {}
	end

	local ordered = {}
	for _, child in sectionsFolder:GetChildren() do
		local order = child:GetAttribute("Order")
		if typeof(order) ~= "number" then
			order = tonumber(string.match(child.Name, "%d+"))
		end
		if order then
			table.insert(ordered, { Order = order, Instance = child })
		end
	end
	table.sort(ordered, function(a, b)
		return a.Order < b.Order
	end)

	local sections = {}
	for index, item in ordered do
		local title = item.Instance:GetAttribute("Title")
		table.insert(sections, {
			Index = index,
			Title = if typeof(title) == "string" then title else nil,
			Instance = item.Instance,
			Doors = readDoors(item.Instance),
			Board = findPart(item.Instance, "QuestionBoard"),
			Checkpoint = findPart(item.Instance, "Checkpoint"),
		})
	end
	return sections
end

return Stage1Map
