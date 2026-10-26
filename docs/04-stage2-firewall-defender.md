# Part 4: Stage 2 · Firewall Defender (🔥 Fire Portal)

**Topic:** Keamanan Data & Virus. Covers viruses, worms, trojans, ransomware, spyware, antivirus, firewalls, strong passwords, phishing, OTP/two-step verification, encryption, backups, updates, HTTPS, spam, and protecting personal data.

**Story:** the class defends the **Inti Server** (Server Core) from a fortress protected by a wall of fire, the "firewall". Each wave, virus monsters fly out of the Virus Gates carrying answers above their heads. Students must shoot the one carrying the **correct** answer.

---

## 1. Gameplay flow

```
 ⏳ Intermission (4 s)  ──►  ❓ Question in the sky + 4 viruses fly in  ──►  📣 Reveal (8 s)  ──►  next wave
                              │ each student: first virus hit = their answer
                              └ ends when every student has answered, or the correct virus reaches the firewall
```

| Event | Result |
|---|---|
| Your **first** hit lands on the virus with the **correct** answer | **+10 Poin** plus a speed bonus of up to **+5** (it shrinks to 0 over 15 s). "🎯 TEPAT SASARAN!" card |
| Your first hit lands on a **wrong** virus | **−5 Poin**. "💢 SALAH SASARAN!" card |
| After your first hit | Your answer is **locked** for that wave ("🔒 Jawabanmu sudah terkunci") |
| Missing every virus | Doesn't count. Keep shooting until you hit one |
| Reveal | The correct virus turns green ✅, wrong ones turn red ❌, and all of them explode. Everyone sees the correct answer, the explanation, and "18 dari 25 siswa menjawab benar" |
| Fewer than **50%** of students answer correctly | 💥 The virus breaches the firewall: Inti Server loses 1 ❤️. At 0 the core is "terinfeksi", then restored |

Viruses get a little faster every wave, up to a limit.

### Design choices

- **Every student answers for themselves.** Monsters are shared, so if the first kill won the round, one fast student would take all the points. Instead your first hit is your answer, like Kahoot, and every student scores on their own.
- **No copying.** Hit results appear only on the shooter's own screen. The virus models carry no right/wrong marker; the server keeps that. Colors are random and unrelated to the answer.
- **Spraying doesn't help.** Only your first hit counts, so you have to read before you shoot.
- **Teamwork.** The shared core health bar means the class wins or loses together, which gives the teacher a natural moment to discuss the explanation.
- **The teacher can play without blocking waves.** The teacher isn't counted as a student who must answer.

---

## 2. Building the arena

The arena is **built automatically** the first time the game starts. `ServerScriptService > World > BuildStage2` (called by `World > BuildAll`) creates it in `Workspace > Stages > Stage2`. There's nothing to run.

- **To see and decorate it in edit mode:** press Stop, paste [`tools/BuildWorld.luau`](../tools/BuildWorld.luau) into the Command Bar, press **Enter**, then save with **Ctrl+S**. From then on the saved version is used and the auto-builder leaves it alone.
- **To rebuild it from scratch:** delete `Workspace > Stages > Stage2`, then press Play (or run `BuildWorld` again).
- The builder never overwrites a `Stage2` folder that contains objects you added yourself.
- Layout settings (sizes, counts, seed) are at the top of `src/server/World/BuildStage2.luau`.

What it builds:

| Area | Contents |
|---|---|
| **Benteng Firewall** (fortress, where students stand) | Wide slate fortress with a basalt parapet, **11 fires along the front edge** (the "firewall"), invisible fences so nobody falls off, the Spawn pad, and the 🏠 pad back to the lobby |
| **Inti Server** (behind the fortress) | Glowing cyan crystal in a glass shell with a ring, a floating "🛡️ INTI SERVER ❤️❤️❤️❤️❤️" health label, and 4 server racks with blinking lights |
| **Battlefield** | 110 × 170-stud basalt field with glowing lava cracks, a lava moat, obsidian spikes, 6 fire braziers, and rising embers |
| **Gerbang Virus** (virus gates) | 4 dark arches with purple swirling portals where viruses spawn |
| **Jalur virus** (lanes) | 4 winding lanes, never closer than 16 studs, so viruses don't hide behind each other |
| **SkyBoard** | 64 × 24-stud floating board above the field showing the wave, core health, question, and "Sudah menjawab: 12/25" |

The default virus is built from parts: a spiky ball with eyes, randomly colored. There's no Toolbox model to install.

### Customizing or making your own arena

```
Workspace > Stages > Stage2
├── Spawn (Part)                ← REQUIRED: Front face = direction students face (toward the viruses)
├── Lanes (Folder)              ← REQUIRED: one folder per lane (2–6 lanes; 4 recommended)
│   ├── Lane1 (Folder)
│   │   ├── 1 (Part)            ← waypoints named 1, 2, 3, ... (first = spawn, last = in front of the firewall)
│   │   ├── 2 (Part)            ← visible while editing; hidden automatically when the game runs
│   │   └── ...
│   └── Lane2 ...
├── SkyBoard (Part)             ← optional: Front face toward the students
├── Core (Model or Part)        ← optional: gets the health label and the explosion when breached
├── Monsters (Folder)           ← created automatically
├── ReturnToLobby (Part)        ← optional
└── FallZone / Lava             ← optional hazards
```

Tips:
- To reshape a lane, just move its waypoint balls. Viruses fly in straight lines between them at the waypoints' height.
- Keep lanes at least about 14 studs apart, because the invisible hit sphere around each virus is about 11 studs wide.
- **Custom virus model:** put a Model named `VirusMonster` in `ServerStorage`, with its **PrimaryPart set** and its face pointing −Z. The script removes its scripts, welds it together, and adds a hit sphere. Parts named `Body`/`Spike`/`Tip` get recolored randomly; anything else keeps its color.
- If the wand looks oddly angled in the hand, adjust `tool.Grip` in `createWand()`.

---

## 3. Scripts for this stage

| File | Studio object | Location |
|---|---|---|
| `src/server/Services/Stages/Stage2_FirewallDefender.luau` | ModuleScript `Stage2_FirewallDefender` | `ServerScriptService > Services > Stages` |
| `src/client/Stage2Client.client.luau` | LocalScript `Stage2Client` | `StarterPlayer > StarterPlayerScripts` |
| `src/server/QuizBank.luau` | *(update)* now includes `QuizBank.Stage2` | `ServerScriptService` |
| `src/shared/GameConfig.luau` | *(update)* now includes `GameConfig.Stage2` | `ReplicatedStorage > Shared` |
| `src/shared/UiKit.luau` | *(update)* gained `UiKit.card` and `UiKit.burst` | `ReplicatedStorage > Shared` |
| `src/client/Stage1Client.client.luau` | *(update)* now uses `UiKit.card`, so **replace it too** | `StarterPlayer > StarterPlayerScripts` |

`Main` starts the new stage module automatically.

### Settings (`GameConfig.Stage2`)

```lua
GameConfig.Stage2 = {
	ToolName = "TongkatFirewall",
	CorrectPoints = 10, SpeedBonusMax = 5, SpeedBonusWindow = 15, WrongPoints = -5,
	MonstersPerWave = 4,           -- 1 correct + 3 wrong
	MonsterSpeed = 7, SpeedPerWave = 0.4, MaxMonsterSpeed = 12, SpawnStagger = 1.5,
	CoreMaxHP = 5, CoreMinCorrectRatio = 0.5,
	IntermissionTime = 4, RevealTime = 8, MaxWaveTime = 60,
	FireCooldown = 0.25, MaxRange = 350,
}
```

Easier class: lower `MonsterSpeed` to 5 and `CoreMinCorrectRatio` to 0.3. Harder: `SpeedPerWave = 0.8`.

### What students see

- Entering through the 🔥 portal, they're given the **Tongkat Firewall** wand, already equipped, and the mouse becomes a crosshair.
- **Click or tap a virus** to shoot. A fire bolt flies from the wand, and the server re-checks the shot from the student's head.
- **Bottom panel:** "🔥 FIREWALL DEFENDER · Gelombang 3 · 🛡️ ❤️❤️❤️❤️🖤", the question, and their status (aim prompt, "🔒 Jawabanmu: …", or the countdown).
- **Center cards:** their own hit result right away, then the class-wide reveal with the explanation.
- Leaving the stage removes the wand.

---

## 4. Question bank

Edit `ServerScriptService > QuizBank > QuizBank.Stage2`. Same format as Stage 1, but each question needs **at least 3 wrong answers** (4 viruses per wave; with fewer, fewer viruses spawn). Keep answers short (about 22 characters or less), because they float above the viruses.

### Included questions (22)

| # | Question | ✅ Correct | ❌ Wrong |
|---|---|---|---|
| 1 | Program jahat yang dapat menggandakan diri dan merusak file di komputer disebut … | Virus komputer | Antivirus, Firewall, Browser |
| 2 | Aplikasi yang berfungsi mendeteksi dan menghapus virus disebut … | Antivirus | Malware, Spam, Trojan |
| 3 | Sistem keamanan yang menyaring lalu lintas data masuk dan keluar jaringan disebut … | Firewall | Hotspot, Spyware, Bluetooth |
| 4 | Manakah kata sandi (password) yang paling KUAT? | B3l@jar!Jarkom7 | 12345678, password, budi2012 |
| 5 | Pesan atau situs palsu yang menyamar sebagai pihak resmi untuk mencuri password disebut … | Phishing | Streaming, Browsing, Upload |
| 6 | Program jahat yang menyamar sebagai aplikasi berguna, padahal diam-diam merusak, disebut … | Trojan | Antivirus, Firewall, Driver |
| 7 | Malware yang mengunci file lalu meminta uang tebusan agar file bisa dibuka lagi disebut … | Ransomware | Freeware, Shareware, Firmware |
| 8 | Program yang diam-diam memata-matai dan mengumpulkan informasi pengguna disebut … | Spyware | Hardware, Brainware, Firmware |
| 9 | Mengubah data menjadi kode rahasia agar tidak bisa dibaca orang yang tidak berhak disebut … | Enkripsi | Kompresi, Formatting, Defragmentasi |
| 10 | Membuat salinan data penting di tempat lain agar aman jika data asli rusak disebut … | Backup | Delete, Format, Restart |
| 11 | Kode OTP yang dikirim ke ponsel saat login adalah contoh pengamanan … | Verifikasi dua langkah | Mode pesawat, Mode gelap, Hemat baterai |
| 12 | Seseorang meminta kode OTP yang masuk ke ponselmu. Apa yang harus kamu lakukan? | Jangan berikan | Berikan saja, Kirim lewat chat, Unggah ke medsos |
| 13 | Dari mana sebaiknya kita mengunduh aplikasi agar aman? | Toko aplikasi resmi | Tautan tak dikenal, Iklan pop-up, Pesan berantai |
| 14 | Malware yang menyebar sendiri ke komputer lain melalui jaringan disebut … | Worm | Mouse, Cookie, Patch |
| 15 | Manakah yang bisa menjadi tanda komputer terkena virus? | Iklan aneh terus muncul | Layar makin jernih, Baterai makin awet, Internet makin cepat |
| 16 | Memperbarui (update) sistem operasi dan aplikasi secara rutin bertujuan untuk … | Menutup celah keamanan | Menghapus semua file, Mengurangi memori, Mematikan internet |
| 17 | Manakah data pribadi yang TIDAK boleh disebarkan sembarangan? | NIK & alamat rumah | Judul lagu favorit, Warna kesukaan, Nama tokoh kartun |
| 18 | Setelah selesai memakai komputer di lab sekolah, sebaiknya kamu … | Log out dari akunmu | Biarkan akun terbuka, Tulis password di meja, Bagikan password |
| 19 | Alamat situs yang lebih aman untuk memasukkan data biasanya diawali dengan … | https:// | http://, ftp://, file:// |
| 20 | Pesan massal yang tidak diinginkan, sering berisi iklan atau tautan berbahaya, disebut … | Spam | Spreadsheet, Stiker, Server |
| 21 | Orang yang membobol sistem komputer orang lain tanpa izin untuk berbuat jahat disebut … | Cracker | Admin jaringan, Teknisi resmi, Operator sekolah |
| 22 | Cara menjaga password yang BENAR adalah … | Rahasiakan & ganti berkala | Tulis di papan kelas, Sama untuk semua akun, Bagikan ke teman |

---

## 5. Testing checklist

1. The arena builds itself when you press Play. Replace/add the scripts listed in section 3.
2. **Test → Local Server, 2 players.** Player1 (teacher) opens **Tahap 2** in the Panel Guru.
3. Player2 enters the 🔥 portal: they land on the fortress holding the wand, and after about 4 s, wave 1 starts.
4. The SkyBoard shows the question. 4 viruses leave the purple gates, each with an answer label.
5. Player2 clicks empty space: a bolt fires, nothing locks. Then Player2 clicks a virus:
   - Correct: green burst, "+10 to +15 Poin · Tepat sasaran!", and the 🎯 card.
   - Wrong: red burst, "−5 Poin", and the 💢 card.
   - Clicking again shows "🔒 Jawabanmu sudah terkunci".
6. Since Player2 is the only student, the wave ends right after their hit. In the reveal, viruses turn green/red and explode, and the card shows the correct answer, the explanation, and "1 dari 1 siswa menjawab benar".
7. Answer wrong on purpose: "💥 Virus menembus firewall!", and the core loses a heart (on the SkyBoard, the core label, and the HUD).
8. Don't shoot at all: the correct virus reaches the firewall and the wave ends by itself.
9. Step on 🏠: the wand disappears. With nobody left in Stage 2, the waves stop and the board shows "Menunggu pemain masuk…".

## 6. Troubleshooting

| Symptom | Fix |
|---|---|
| Output: `Arena belum ada` | Look for `[World]` errors above it in Output. Auto-building may have failed, or `Workspace > Stages > Stage2` holds your own objects (the builder won't overwrite them). Delete that folder and press Play again |
| No wand after entering | `Stage2_FirewallDefender` isn't in `Services > Stages`, or it failed to start (check Output for `[Main] ❌`) |
| Clicking a virus does nothing | `Stage2Client` is missing, the wave hasn't started ("Tunggu gelombang"), or the answer is already locked |
| Viruses don't move | They must be **unanchored**. A custom `VirusMonster` with anchored parts is unanchored automatically, so check it has a PrimaryPart |
| Waves never end with several students | Some students are idle. The wave still ends when the correct virus reaches the firewall (about 25 s at the starting speed) |
| `Jalur "LaneN" butuh minimal 2 titik` | Waypoints must be Parts named `1`, `2`, `3`, ... inside the lane folder |
