# Part 6: Stage 4 · Bandwidth Glider (🍃 Wind Portal)

**Topic:** Kecepatan Internet & Koneksi. Covers bps/Kbps/Mbps/Gbps, bit vs byte, bandwidth, latency/ping, buffering, download vs upload, data quota vs speed, 2G–5G, fiber, Wi-Fi range and sharing, satellite, Bluetooth, and speed tests.

**Story:** students launch from a sky tower and glide through 8 gates of wind rings. Their speed is shown as **"Mbps"**. Correct answers boost their bandwidth (⚡ faster), and wrong ones make the connection laggy (🐢 slower, grey "buffering" screen). It's the lesson turned into game feel.

---

## 1. Gameplay flow

```
 🗼 Tower ── step on 🪂 LaunchPad ──► glide forward automatically, gently descending
                                         │  steer: ⬅️➡️ / A D = left/right,  ⬆️⬇️ / W S = up/down  (mobile: thumbstick)
                                         ▼
                      Gate N: question floats above, rings  [ A · 100 Mbps ]  [ B · 10 Mbps ]
                         ├─ ✅ correct ring: +10 Poin, ⚡ Speed Boost (×1.7 for 3 s), wider view, wind streaks
                         ├─ ❌ wrong ring:   −5 Poin, 🐢 Slow (×0.5 for 3 s), grey "Buffering…" screen
                         └─ 📶 missed both:   0 Poin, also slowed
                                         ▼  (8 gates, about 70 s of flight)
 🏝️ Landing island ── recap card (every gate with its correct answer) + 25 bonus (once per session)
        ├─ 🗼 "Terbang lagi" pad → back to the tower for a new flight with new questions
        └─ 🏠 back to the lobby
```

### Design choices

- **Each student flies alone and gets their own questions.** The question and the A/B labels on the rings are drawn only on that student's screen. The server knows which ring is right; the rings themselves look identical.
- **Short questions, about 6–8 s per gate.** Gates are 260 studs apart at 32 studs/s, and the first gate is 200 studs from the tower so there's time to read the first question.
- **Speed is the feedback.** A boost lets you cover the next stretch faster; a slow-down gives you more time but makes the screen grey and laggy. Students *feel* "bandwidth" and "buffering", the very concepts in the questions.
- **Steering is relative to the course, not the camera.** Left is always left, and a chase camera keeps the next gate in view. This is easier for 7th graders than free flight.
- **Recap after landing.** Every gate is listed with its correct answer, so students review what they missed.

### How the flight works (for the curious)

- Stepping on `LaunchPad` makes the **server** start the flight: it sets the attribute `Gliding = true`, draws question 1, and welds a glider wing to the student's back (visible to everyone).
- `Stage4Client` sees `Gliding = true` and takes control on the student's own computer: `PlatformStand`, a `LinearVelocity` (forward + steering + downward slope), an `AlignOrientation` (lying prone, banking into turns), and a scripted chase camera. Running it on the student's device keeps the motion perfectly smooth.
- Ring `Trigger` touches are judged on the **server**. Passing a gate's plane by 25 studs without touching a ring counts as a miss. Dropping 60 studs below the landing zone, or touching the `FallZone`, sends the student back to the tower.

---

## 2. Building the course

The course is **built automatically** the first time the game starts. `ServerScriptService > World > BuildStage4` (called by `World > BuildAll`) creates it in `Workspace > Stages > Stage4`. There's nothing to run.

- **To see and decorate it in edit mode:** press Stop, paste [`tools/BuildWorld.luau`](../tools/BuildWorld.luau) into the Command Bar, press **Enter**, then save with **Ctrl+S**. From then on the saved version is used and the auto-builder leaves it alone.
- **To rebuild it from scratch:** delete `Workspace > Stages > Stage4`, then press Play (or run `BuildWorld` again).
- The builder never overwrites a `Stage4` folder that contains objects you added yourself.
- Layout settings (sizes, counts, seed) are at the top of `src/server/World/BuildStage4.luau`.

What it builds:

| Part | Contents |
|---|---|
| **Tower island** | Floating grass-and-rock island with 2 Anemo windmills, the Spawn, and a glowing **🪂 LaunchPad** at its edge |
| **8 gates** | Each has 2 glowing rings (16 neon segments plus a shimmering film) and a crystal marker. Gates weave left and right, and gates 4 and 7 stack their rings **vertically** (A top, B bottom) so students also use up/down |
| **Glide line** | Every gate sits on one straight descending line (1 stud down per 10 forward), about 2,240 studs long |
| **Landing island** | Large island with an invisible `LandingZone` volume, the 🗼 "Terbang lagi" pad, the 🏠 pad, and a windmill |
| **Sky decor** | 26 floating islands, 40 cloud clusters, and glowing wind ribbons, all kept clear of the rings |

To make it easier, raise `GATE_SPACING` (more reading time) or lower `GameConfig.Stage4.BaseSpeed`. For a longer course, raise `GATE_COUNT` and extend `GATE_SHIFT` / `GATE_LAYOUT`.

### Customizing or making your own course

```
Workspace > Stages > Stage4
├── Spawn (Part)                     ← REQUIRED: on the tower
├── LaunchPad (Part)                 ← REQUIRED: stepping on it starts the flight
├── Gates (Folder)
│   ├── Gate1 (Model)                ← order from the "Order" attribute or the number in the name
│   │   ├── RingA (Model)
│   │   │   └── Trigger (Part)       ← REQUIRED: invisible disc/cylinder in the ring opening (≈6 studs thick)
│   │   └── RingB (Model)
│   │       └── Trigger (Part)
│   └── Gate2 ...
├── LandingZone (Part)               ← REQUIRED: invisible volume at the end of the glide line
├── Relaunch (Part)                  ← optional: back to the tower
├── ReturnToLobby (Part)             ← optional
└── FallZone (Part)                  ← optional
```

Important: the flight follows a **straight line** from `LaunchPad` to `LandingZone`. Its direction and descent are computed from those two parts. Keep every gate's rings close to that line, within the reach of steering (about 20 studs/s sideways, 12 studs/s up or down).

---

## 3. Scripts for this stage

| File | Studio object | Location |
|---|---|---|
| `src/server/Services/Stages/Stage4_BandwidthGlider.luau` | ModuleScript `Stage4_BandwidthGlider` | `ServerScriptService > Services > Stages` |
| `src/shared/Stage4Map.luau` | ModuleScript `Stage4Map` | `ReplicatedStorage > Shared` |
| `src/client/Stage4Client.client.luau` | LocalScript `Stage4Client` | `StarterPlayer > StarterPlayerScripts` |
| `src/server/QuizBank.luau` | *(update)* adds `QuizBank.Stage4` | `ServerScriptService` |
| `src/shared/GameConfig.luau` | *(update)* adds `GameConfig.Stage4` | `ReplicatedStorage > Shared` |

### Settings (`GameConfig.Stage4`)

```lua
GameConfig.Stage4 = {
	CorrectPoints = 10, WrongPoints = -5,
	FinishBonus = 25, FinishBonusOncePerSession = true,
	BaseSpeed = 32,        -- shown to students as "32 Mbps"
	SteerSpeed = 20, ClimbSpeed = 12,
	BoostMultiplier = 1.7, SlowMultiplier = 0.5, EffectDuration = 3,
	MissMargin = 25,
}
```

---

## 4. Question bank

Edit `ServerScriptService > QuizBank > QuizBank.Stage4`. Same format as Stage 1, but **keep questions very short**, because students read them mid-flight. Only 2 rings exist, so one wrong answer is enough; if you list more, one is picked at random each time.

### Included questions (20)

| # | Question | ✅ Correct | ❌ Wrong (one is picked) |
|---|---|---|---|
| 1 | Satuan kecepatan internet adalah … | bps (bit per detik) | km/jam, Volt, Celsius |
| 2 | Mana yang lebih CEPAT? | 100 Mbps | 10 Mbps, 1 Mbps, 512 Kbps |
| 3 | Kapasitas maksimal data yang bisa dikirim per detik disebut … | Bandwidth | Password, Hardware, Browser |
| 4 | Video berhenti sebentar untuk memuat data disebut … | Buffering | Booting, Typing, Printing |
| 5 | Waktu tunda data pergi-pulang (dalam ms) disebut … | Ping / latensi | Bandwidth, Resolusi, Megapiksel |
| 6 | Untuk game online, ping yang lebih baik adalah … | 20 ms | 500 ms, 900 ms |
| 7 | Jaringan seluler yang paling cepat adalah … | 5G | 3G, 2G, EDGE |
| 8 | Media kabel yang paling cepat untuk internet adalah … | Fiber optik | Kabel telepon, Kabel listrik |
| 9 | Jika banyak orang memakai satu Wi-Fi bersamaan, internet jadi … | Lebih lambat | Lebih cepat, Tidak berubah |
| 10 | 1 Byte sama dengan … | 8 bit | 10 bit, 2 bit, 1000 bit |
| 11 | File 100 MB diunduh dengan internet 8 Mbps. Lamanya sekitar … | 100 detik | 1 detik, 1 jam |
| 12 | Mengambil file dari internet ke perangkat kita disebut … | Download | Upload, Restart |
| 13 | Mengirim video dari ponsel ke media sosial disebut … | Upload | Download, Format |
| 14 | Sinyal Wi-Fi paling kuat jika kita berada … | Dekat router | Di balik tembok tebal, Di ruang bawah tanah |
| 15 | Satuan yang lebih BESAR dari Mbps adalah … | Gbps | Kbps, bps |
| 16 | Kuota internet dihitung dalam satuan … | GB (gigabyte) | Mbps, Volt, Meter |
| 17 | Internet satelit paling cocok untuk daerah … | Terpencil | Pusat kota, Gedung server |
| 18 | Aplikasi untuk mengukur kecepatan internet disebut … | Speed test | Antivirus, Kalkulator |
| 19 | Video kualitas 4K butuh bandwidth yang … | Lebih besar | Lebih kecil, Nol |
| 20 | Bluetooth cocok untuk perangkat yang … | Berjarak dekat | Beda negara, Beda kota |

---

## 5. Testing checklist

1. The course builds itself when you press Play. Add the scripts and updated modules from section 3.
2. **Test → Local Server, 2 players.** Player1 (teacher) opens **Tahap 4**, and Player2 enters the 🍃 portal.
3. Player2 lands on the tower and sees "Injak pad 🪂 …" in the bottom panel.
4. Step on the 🪂 pad: a teal glider wing appears on the back, the character lies prone and flies forward, the camera follows from behind, and a "📶 32 Mbps" speedometer appears.
5. The bottom panel and the floating label at gate 1 show the question, and both rings are labeled "A · …" / "B · …".
6. Steer into a ring:
   - Correct: green burst, +10, "✅ BENAR! ⚡ Bandwidth naik!", "⚡ 54 Mbps", wider view, wind streaks.
   - Wrong: red burst, −5, "❌ SALAH! 🐢 …", grey screen, "🐢 16 Mbps · Buffering…".
   - Fly past both: "📶 Sinyal hilang!", and you're slowed.
7. At gates 4 and 7 the rings are stacked: use W/S (or the thumbstick up/down).
8. After gate 8, fly into the landing island: the glide ends, the character drops onto the island, and the recap card lists all 8 gates with correct answers, plus the +25 bonus.
9. Step on 🗼 to go back to the tower; launching again gives new questions. Try diving straight down: below the landing level you're sent back to the tower.
10. Have Player1 fly at the same time: each player's rings show different questions.

## 6. Troubleshooting

| Symptom | Fix |
|---|---|
| Output: `Lintasan belum ada` | Look for `[World]` errors above it in Output. Auto-building may have failed, or `Workspace > Stages > Stage4` holds your own objects (the builder won't overwrite them). Delete that folder and press Play again |
| Stepping on the pad does nothing | `Stage4_BandwidthGlider` failed to start (check Output for `[Main] ❌`), or the part isn't named `LaunchPad` |
| The glider wing appears but the character doesn't fly | `Stage4Client` is missing from StarterPlayerScripts |
| Character spins or tumbles | Another script is changing `PlatformStand` or the camera. Disable it during Stage 4 |
| Rings are always missed | Gates are too far from the straight LaunchPad → LandingZone line (see the note in section 2) |
| The question changes too fast to read | Raise `GATE_SPACING` in the builder, or lower `BaseSpeed` |
