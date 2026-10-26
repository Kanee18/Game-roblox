# Part 5: Stage 3 · Cable Labyrinth (⚡ Lightning Portal)

**Topic:** Perangkat Keras Jaringan (network hardware): Router, Switch, Hub, Modem, Access Point, Kabel UTP, Konektor RJ-45, Fiber Optik, NIC, Kabel Coaxial, and Server.

**Story:** students are inside a giant **motherboard**. The **Mesin Pusat** (central machine, a huge glowing CPU) needs hardware, but it only describes *what the device does*. Students work out which device that is, find it in the maze, and carry it back.

---

## 1. Gameplay flow

```
 🖥️ Machine: "Bawakan perangkat yang memancarkan sinyal Wi-Fi…"   (each student gets their own request)
        │
        ▼  student thinks: "that's an Access Point!"
 🧭 Explore the maze ─► touch the 📶 Access Point pedestal ─► the item floats above their head
        │
        ▼
 ⚡ Step on the glowing floor around the machine to deliver
        ├─ ✅ Correct: +15 Poin, next request
        └─ ❌ Wrong:  −5 Poin, "Kamu membawa Switch: Switch menghubungkan…", "Yang diminta: Access Point", new request
 🏆 6 correct deliveries = mission complete, +25 bonus (once per class session); students can keep playing for more points
```

| Rule | Detail |
|---|---|
| Carry one item at a time | Touching another pedestal swaps the item |
| Pedestals never run out | Each of the 11 devices sits on **2 pedestals**; any number of students can take copies |
| Personal requests | The machine billboard and HUD show *your* request only; the class is spread across different requests |
| Dying or leaving | The carried item disappears; the request is kept |

### Design choices

- **Describe, don't name.** A request like "bring the Router" would only test reading. Instead the request describes a function or feature ("…menentukan jalur terbaik untuk data"), and the student must connect it to the device's name. That's the real learning goal of the topic.
- **Wrong answers explain both devices.** The student learns what the device they brought actually does and which device was needed.
- **No contention.** Pedestals are infinite and requests are personal, so 30 students can play at once without fighting over items.
- **Navigation help without spoilers.** Each pedestal has a light beam and a name label above the maze walls. Students can see where a device is but still have to find the path, while the machine's billboard stays visible from anywhere as a landmark home.

---

## 2. Building the maze

1. Make sure Part 1 is done (lighting, `BuildLobbySkeleton.luau`, core scripts).
2. **View → Command Bar**, paste all of [`tools/BuildStage3.luau`](../tools/BuildStage3.luau), and press **Enter**.
   - It replaces the placeholder platform in `Workspace > Stages > Stage3`.
   - It refuses to run if `Stage3` already has a maze or anything you added yourself.
3. **Ctrl+S**.

What it builds:

| Part | Contents |
|---|---|
| **PCB** | 166 × 166-stud green circuit board with copper traces following every corridor and copper "vias" in each cell |
| **Maze** | 9 × 9 cells (18 studs each). Walls are black **chips** (with glowing tops), green **RAM sticks** (gold trim), and silver **heatsinks**, with **capacitors** at every corner. Walls are 10 studs tall, too high to jump over. About 12% extra openings create loops so corridors don't jam |
| **Plaza** (center 3 × 3 cells) | The **Mesin Pusat**: a giant CPU with gold pins, a glowing cyan core and data cables, on a glowing cyan **DeliverySlot** floor. One exit on each side. Spawn and 🏠 pad |
| **22 pedestals** | 11 devices × 2, placed first in dead ends and then the cells farthest from the center. Each has a colored light beam |

The maze comes from a fixed `SEED`, so it's the same every time. Change `SEED` in the script for a different maze, or `GRID`/`CELL` for a bigger or smaller one.

### The 3D devices

There are no Toolbox assets to install. The server builds each device from parts:

| Device | Model |
|---|---|
| 📡 Router | Dark box, 3 antennas, green LEDs |
| 🔀 Switch | Wide blue-metal box, 8 ports with LEDs |
| 🔘 Hub | Smaller beige box, 4 ports, amber LEDs |
| 📟 Modem | Upright white box with a blue LED column |
| 📶 Access Point | White disc with a glowing blue ring |
| 🔵 Kabel UTP | Coiled blue cable with a clear plug |
| 🔌 Konektor RJ-45 | Clear connector with 8 gold pins |
| 💡 Kabel Fiber Optik | Orange cable with glowing strands fanning out |
| 💳 NIC | Green circuit card, gold edge, metal bracket, LAN port |
| 📺 Kabel Coaxial | Coiled black cable, silver connector, copper core |
| 🗄️ Server | Black tower with blue light strips |

They spin slowly on their pedestals, and a smaller copy floats above a student's head while it's being carried.

**Using your own models:** create a Folder `ServerStorage > Stage3Items` and put Models in it named exactly with the item Id (`Router`, `Switch`, `AccessPoint`, `KabelUTP`, `RJ45`, `FiberOptik`, `NIC`, `Coaxial`, `Server`, `Hub`, `Modem`). Any Id without a custom model keeps the built-in one.

### Customizing or making your own maze

```
Workspace > Stages > Stage3
├── Spawn (Part)                      ← REQUIRED
├── Machine (Model)                   ← REQUIRED: its PrimaryPart is where the request billboard floats
│   └── DeliverySlot (Part)           ← REQUIRED: touching it while carrying = delivery (can be anywhere in Stage3)
├── Stations (Folder)
│   └── ItemStation (Part) ×N         ← name must be "ItemStation", with String attribute ItemId = "Router", ...
│       └── Beacon (Part, optional)   ← recolored to the device color
├── Walls, Board ...                  ← anything you like
├── ReturnToLobby (Part)              ← optional
└── FallZone (Part)                   ← optional
```

To add a pedestal, duplicate an `ItemStation`, move it, and change its `ItemId` attribute. To add a new device type, add it to `GameConfig.Stage3.Items`, `QuizBank.Stage3Info`, and at least one request in `QuizBank.Stage3`. Without a builder in `BUILDERS`, the new device shows as a colored cube.

---

## 3. Scripts for this stage

| File | Studio object | Location |
|---|---|---|
| `src/server/Services/Stages/Stage3_CableLabyrinth.luau` | ModuleScript `Stage3_CableLabyrinth` | `ServerScriptService > Services > Stages` |
| `src/client/Stage3Client.client.luau` | LocalScript `Stage3Client` | `StarterPlayer > StarterPlayerScripts` |
| `src/server/QuizBank.luau` | *(update)* adds `QuizBank.Stage3` + `QuizBank.Stage3Info` | `ServerScriptService` |
| `src/shared/GameConfig.luau` | *(update)* adds `GameConfig.Stage3` (settings + item catalog) | `ReplicatedStorage > Shared` |

### Settings (`GameConfig.Stage3`)

```lua
GameConfig.Stage3 = {
	CorrectPoints = 15, -- deliveries take walking, so they're worth a bit more
	WrongPoints = -5,
	MissionGoal = 6,
	MissionBonus = 25,
	MissionBonusOncePerSession = true,
	PickupCooldown = 1,
	Items = { { Id = "Router", Name = "Router", Icon = "📡", Color = ... }, ... },
}
```

### What students see

- A large billboard above the machine: **"🖥️ MESIN PUSAT MEMINTA:"** plus their own request. It's visible from anywhere in the maze.
- **Bottom panel:** "⚡ CABLE LABYRINTH · Misi 2/6", the request, and "🎒 Kamu membawa: 📡 Router…" or "🎒 Tanganmu kosong…".
- Toasts when picking up or swapping, then a ✅/❌ card after each delivery and a 🏆 card at 6/6.

---

## 4. Requests and device info

Edit `ServerScriptService > QuizBank`:

```lua
QuizBank.Stage3 = {
	{
		Question = "Bawakan perangkat yang memancarkan sinyal Wi-Fi agar laptop dan ponsel bisa terhubung tanpa kabel!",
		Correct = "AccessPoint",   -- must be an Id from GameConfig.Stage3.Items
		Explanation = "Access Point memancarkan sinyal nirkabel (Wi-Fi) …",
	},
}
QuizBank.Stage3Info = { AccessPoint = "Access Point memancarkan sinyal Wi-Fi …", ... } -- shown after a wrong delivery
```

No wrong answers are needed: every other device in the maze is a distractor. A request whose `Correct` isn't a known Id is skipped with a warning in Output.

### Included requests (22, two per device)

| # | Request (shown by the machine) | ✅ Device |
|---|---|---|
| 1 | Bawakan perangkat yang menghubungkan dua jaringan berbeda dan menentukan jalur terbaik untuk data! | Router |
| 2 | Bawakan perangkat yang menghubungkan banyak komputer dalam satu LAN dan mengirim data HANYA ke komputer tujuan! | Switch |
| 3 | Bawakan perangkat yang mengubah sinyal digital menjadi analog (dan sebaliknya) agar rumah bisa tersambung ke Internet! | Modem |
| 4 | Bawakan perangkat yang memancarkan sinyal Wi-Fi agar laptop dan ponsel bisa terhubung tanpa kabel! | Access Point |
| 5 | Bawakan kabel jaringan berisi 4 pasang kabel tembaga yang dipilin, yang paling sering dipakai di LAN! | Kabel UTP |
| 6 | Bawakan konektor kotak bening dengan 8 pin yang dipasang di ujung kabel UTP! | Konektor RJ-45 |
| 7 | Bawakan kabel yang mengirim data menggunakan CAHAYA, sangat cepat, dan bisa menjangkau jarak sangat jauh! | Kabel Fiber Optik |
| 8 | Bawakan kartu yang dipasang di dalam komputer agar komputer punya port dan bisa terhubung ke jaringan! | NIC (Kartu Jaringan) |
| 9 | Bawakan kabel dengan inti tembaga di tengah dan pelindung logam, yang biasa dipakai untuk antena TV! | Kabel Coaxial |
| 10 | Bawakan komputer bertenaga besar yang menyediakan layanan, misalnya website atau penyimpanan file, untuk komputer lain! | Server |
| 11 | Bawakan perangkat penghubung sederhana yang mengirim data ke SEMUA port sekaligus! | Hub |
| 12 | Di rumah, perangkat ini biasanya dipasang oleh penyedia internet (ISP) untuk menyambungkan jaringan rumah ke Internet. Bawakan! | Modem |
| 13 | Ujung kabel UTP harus dipasangi benda ini sebelum dicolokkan ke switch atau komputer. Bawakan benda itu! | Konektor RJ-45 |
| 14 | Kamu ingin menghubungkan 20 komputer lab dalam satu LAN berkabel. Bawakan perangkat pusat yang paling tepat! | Switch |
| 15 | Jaringan antarpulau dan bawah laut memakai kabel ini karena sangat cepat dan tahan gangguan listrik. Bawakan! | Kabel Fiber Optik |
| 16 | Tanpa perangkat ini, komputer tidak punya 'pintu' untuk masuk ke jaringan. Bawakan! | NIC (Kartu Jaringan) |
| 17 | Sekolah membagi koneksi internet ke jaringan lab dan jaringan kantor guru. Bawakan perangkat 'polisi lalu lintas' datanya! | Router |
| 18 | Agar siswa bisa memakai Wi-Fi di perpustakaan yang jauh dari ruang server, sekolah memasang perangkat ini. Bawakan! | Access Point |
| 19 | Website sekolah disimpan dan dijalankan pada perangkat ini agar bisa diakses dari mana saja. Bawakan! | Server |
| 20 | Bawakan kabel yang memiliki pasangan warna oranye, hijau, biru, dan cokelat yang saling dipilin! | Kabel UTP |
| 21 | Bawakan kabel bulat hitam dengan konektor logam berulir yang sering ditemukan di belakang televisi! | Kabel Coaxial |
| 22 | Bawakan perangkat lama yang mirip switch, tetapi membuat jaringan lebih lambat karena data dikirim ke semua komputer! | Hub |

---

## 5. Testing checklist

1. Run `tools/BuildStage3.luau` and save. Add the scripts and updated modules from section 3.
2. **Test → Local Server, 2 players.** Player1 (teacher) opens **Tahap 3**, and Player2 enters the ⚡ portal.
3. Player2 spawns in the plaza facing the giant CPU. The billboard above it and the bottom panel show a request, and the light beams with name labels poke above the maze walls.
4. Walk into the maze and touch a pedestal: a small copy of the device floats above your head, and the panel says "🎒 Kamu membawa: …".
5. Touch a different pedestal: the item swaps, with a "🔄 … kamu tukar dengan …" toast.
6. Step on the glowing cyan floor around the CPU:
   - Correct device: green burst, +15 Poin, ✅ card, new request.
   - Wrong device: red burst, −5 Poin, ❌ card explaining both devices, new request.
7. After 6 correct deliveries: 🏆 card, +25 bonus, and a class-wide toast. A 7th correct delivery gives no extra bonus.
8. Step on 🏠: the carried item disappears. Re-entering keeps your request and mission progress.

## 6. Troubleshooting

| Symptom | Fix |
|---|---|
| Output: `Labirin belum dibangun` | Run `tools/BuildStage3.luau`, or check `Workspace > Stages > Stage3 > Machine` exists |
| A pedestal shows nothing | Its `ItemId` attribute doesn't match any Id in `GameConfig.Stage3.Items` (see the Output warning) |
| Delivering does nothing | You're not carrying anything, the part isn't named `DeliverySlot`, or it has `CanTouch` off |
| No request billboard | `Stage3Client` is missing, or `Machine` has no PrimaryPart or parts |
| Maze too hard | Use a smaller `GRID` (7) or higher `LOOP_CHANCE` (0.25) in the builder, then rebuild |
| Students get lost | The billboard over the machine is visible from everywhere, so tell them to "walk toward the screen" |
