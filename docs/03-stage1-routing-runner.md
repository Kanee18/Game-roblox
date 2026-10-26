# Part 3: Stage 1 · Routing Runner (⛰️ Earth Portal)

**Topic:** Dasar Jaringan & LAN/WAN. Covers what a computer network is, its benefits and components, PAN/LAN/MAN/WAN, the Internet, ISP, client–server, routers and routing, and data packets.

**Story:** the student is a *paket data* (data packet). To reach its destination it must get through 6 obstacles, and at every **Gerbang Router** (router gate) choose the correct route: the door with the right answer.

---

## 1. Gameplay flow

```
Spawn ──► Obstacle 1 ──► 🔀 Router Gate 1 ──► Checkpoint 1 ──► Obstacle 2 ──► ... ──► Gate 6 ──► 🏁 Finish ──► 🏠 Lobby
                         ┌───────────────────────────┐
                         │  Question board (per student)
                         │   [ A ]   [ B ]   [ C ]   │  ← 3 doors, answers shown above each
                         └───────────────────────────┘
```

| Event | Result |
|---|---|
| Enter the **correct** door | **+10 Poin** · "✅ BENAR!" card with an explanation · new checkpoint · next question |
| Enter a **wrong** door | **−5 Poin** · student is knocked out · "❌ KURANG TEPAT!" card shows the correct answer and an explanation · respawn at the last checkpoint with a **new** question |
| Touch `Lava` | Knocked out, respawn at checkpoint, no point loss |
| Fall off the course | Put straight back on the checkpoint (`FallZone`) |
| Touch **Finish** after all 6 gates | **+25 Poin** bonus (once per class session), summary card (correct/wrong count), announcement to the whole class |
| Leave and come back later | Resumes from the last checkpoint. After finishing, re-entering starts a new run with different questions |

### Design choices

- **Each student sees their own question.** The boards and door signs are drawn on each student's screen only. Two students standing at the same gate see different questions and different answer orders, so nobody can follow the classmate who goes first.
- **A wrong answer swaps the question.** Students can't eliminate doors by trial and error. They have to read the explanation and get the next question right.
- **The answer key never leaves the server.** `QuizBank` is in `ServerScriptService`, and the client only receives the question text and the options. A cheating tool on a student's device has nothing to read.

---

## 2. Building the course

The course is **built automatically** the first time the game starts. `ServerScriptService > World > BuildStage1` (called by `World > BuildAll`) creates it in `Workspace > Stages > Stage1`, about 650 studs long. There's nothing to run.

- **To see and decorate it in edit mode:** press Stop, paste [`tools/BuildWorld.luau`](../tools/BuildWorld.luau) into the Command Bar, press **Enter**, then save with **Ctrl+S**. From then on the saved version is used and the auto-builder leaves it alone.
- **To rebuild it from scratch:** delete `Workspace > Stages > Stage1`, then press Play (or run `BuildWorld` again).
- The builder never overwrites a `Stage1` folder that contains objects you added yourself.
- Layout settings (sizes, counts, seed) are at the top of `src/server/World/BuildStage1.luau`.

What it builds:

| # | Obstacle | Skill |
|---|---|---|
| 1 | **Batu Loncatan**: 5 zig-zag stepping stones | Basic jumps |
| 2 | **Jembatan Kabel**: 3 narrow blue "network cable" beams with gaps | Balance |
| 3 | **Tangga Sinyal**: 6 rising steps (+17.5 studs) | Climbing jumps |
| 4 | **Lantai Lava**: hop across safe tiles over lava | Precise jumps |
| 5 | **Tiang Antena**: 6 round pillar tops at different heights | Landing on small targets |
| 6 | **Jalur Paket Data**: stones, then a glowing beam with 2 lava bumps | Combination |

Each obstacle ends in a **Router Gate**: a marble wall with 3 doors (`DoorA/B/C`), a question board above, invisible side barriers so the wall can't be jumped around, and a checkpoint pad behind it. The course also gets a rules banner at the start, the finish area with trophy crystals, and about 40 floating grass islands for decoration.

All gaps are 2–4 studs, sized for the default WalkSpeed 16 and JumpPower 50, so they're manageable for 7th graders.

### Customizing or making your own course

You can restyle anything (swap stones for Toolbox rocks, add trees, change colors) or build a completely new obby. The script only needs these names:

```
Workspace > Stages > Stage1
├── Spawn (Part)                       ← start point; Front face = direction players face
├── Sections (Folder)
│   ├── Section1 (Folder or Model)     ← order comes from the "Order" attribute or the number in the name
│   │   │   Attribute "Title" (optional) = name shown on the board, e.g. "Batu Loncatan"
│   │   ├── Doors (Folder)
│   │   │   ├── DoorA (Model)
│   │   │   │   ├── Trigger (Part)     ← REQUIRED: the doorway players walk through (CanCollide is set to false automatically)
│   │   │   │   └── Sign (Part)        ← optional: answer sign; Front face toward players (else a floating label is used)
│   │   │   ├── DoorB (Model)          ← doors are lettered by name order: A, B, C (2–4 doors supported)
│   │   │   └── DoorC (Model)
│   │   ├── QuestionBoard (Part)       ← optional: Front face toward players
│   │   └── Checkpoint (Part)          ← respawn point after passing this gate
│   ├── Section2 ...
├── Finish (Part)                      ← anywhere inside Stage1
├── ReturnToLobby (Part)               ← optional
├── FallZone (Part)                    ← optional, invisible, under the course
└── any Part named "Lava"              ← optional hazards
```

Tips:
- To show text on a different face of a sign or board, add a string attribute `Face` (`Back`, `Left`, ...).
- Each gate wall must block the path completely, so the only way forward is through a door.
- Doors stay neutral-colored on purpose. Never color the correct door differently.

---

## 3. Scripts for this stage

| File | Studio object | Location |
|---|---|---|
| `src/server/QuizBank.luau` | ModuleScript `QuizBank` | `ServerScriptService` |
| `src/server/Services/Stages/Stage1_RoutingRunner.luau` | ModuleScript `Stage1_RoutingRunner` | `ServerScriptService > Services > Stages` |
| `src/shared/Stage1Map.luau` | ModuleScript `Stage1Map` | `ReplicatedStorage > Shared` |
| `src/client/Stage1Client.client.luau` | LocalScript `Stage1Client` | `StarterPlayer > StarterPlayerScripts` |

Also update `GameConfig`, `PointsService` and `SpawnService` with the new versions. They gained the `Stage1` settings, the `AllReset` event, and the `Lava`/`FallZone` hazards.

`Main` starts every ModuleScript in `Services > Stages` automatically. You don't need to edit it.

### Settings (`GameConfig.Stage1`)

```lua
GameConfig.Stage1 = {
	CorrectPoints = 10,
	WrongPoints = -5,
	FinishBonus = 25,
	FinishBonusOncePerSession = true, -- "Reset Semua Poin" also re-enables the bonus
	DoorCooldown = 1,
}
```

### What students see

- **World:** the board over their current gate shows *"🔀 Gerbang Router 2/6 · Jembatan Kabel"* plus the question, and each door sign shows **A/B/C** and an answer. Gates already passed show "✅"; gates ahead show "🔒". Checkpoints they've reached glow green on their own screen.
- **Bottom of the screen:** a question panel with chips `A · LAN` `B · WAN` `C · MAN`, so the question stays readable mid-jump.
- **Center card after each door:** green "✅ BENAR!" or red "❌ KURANG TEPAT!" with *"Jawaban yang benar: …"* and *"💡 explanation"*.
- **Finish card:** correct/wrong totals and the bonus.

---

## 4. Question bank

Edit `ServerScriptService > QuizBank`. Each question:

```lua
{
	Question = "Jaringan yang mencakup area kecil seperti rumah, lab komputer, atau satu gedung sekolah disebut …",
	Correct = "LAN",
	Wrong = { "WAN", "MAN" },          -- at least 2 for 3 doors; extras are picked at random
	Explanation = "LAN (Local Area Network) mencakup area terbatas, misalnya satu rumah, satu ruangan, atau satu gedung.",
},
```

- Keep answers short (about 25 characters or less) so they fit on door signs.
- Make wrong answers plausible and about the same length as the right one.
- Answer order is shuffled per student. Questions are dealt from a shuffled deck, so a student sees every question before any repeats.
- Six gates per run and 24 questions means a student can do about 4 runs before repeats.

### Included questions (24)

| # | Question | ✅ Correct | ❌ Wrong |
|---|---|---|---|
| 1 | Dua komputer atau lebih yang saling terhubung untuk berbagi data dan sumber daya disebut … | Jaringan komputer | Sistem operasi, Perangkat lunak, Basis data |
| 2 | Jaringan yang mencakup area kecil seperti rumah, lab komputer, atau satu gedung sekolah disebut … | LAN | WAN, MAN |
| 3 | Jaringan yang mencakup wilayah sangat luas, antarnegara bahkan antarbenua, disebut … | WAN | LAN, PAN |
| 4 | Jaringan yang mencakup satu kota, misalnya jaringan antarkantor cabang bank dalam satu kota, disebut … | MAN | LAN, PAN |
| 5 | Kepanjangan dari LAN adalah … | Local Area Network | Large Area Network, Long Access Network |
| 6 | Kepanjangan dari WAN adalah … | Wide Area Network | Wireless Area Network, World Access Network |
| 7 | Contoh jaringan WAN terbesar di dunia adalah … | Internet | Intranet sekolah, Bluetooth |
| 8 | Ponsel yang terhubung ke earphone nirkabel di sekitar tubuh kita membentuk jaringan … | PAN | MAN, WAN |
| 9 | Jaringan komputer di laboratorium komputer sekolahmu paling tepat disebut … | LAN | WAN, MAN |
| 10 | Perusahaan dengan kantor di Jakarta, Tokyo, dan London saling terhubung. Jaringan ini termasuk … | WAN | LAN, PAN |
| 11 | Semua komputer di lab bisa mencetak memakai satu printer bersama. Ini contoh manfaat jaringan, yaitu … | Berbagi sumber daya | Menambah memori, Mencegah virus |
| 12 | Berikut ini yang BUKAN manfaat jaringan komputer adalah … | Komputer kebal virus | Berbagi file dan data, Komunikasi jadi mudah |
| 13 | Perangkat yang bertugas menentukan jalur terbaik untuk mengirim data antarjaringan adalah … | Router | Printer, Proyektor |
| 14 | Proses memilih jalur yang dilalui data dari pengirim ke penerima disebut … | Routing | Printing, Scanning |
| 15 | Perusahaan yang menyediakan layanan koneksi internet bagi pelanggan disebut … | ISP | CPU, USB |
| 16 | Saat dikirim melalui jaringan, data dipecah menjadi bagian-bagian kecil yang disebut … | Paket data | Folder data, Kabel data |
| 17 | Laptop, komputer, dan smartphone yang dipakai pengguna di ujung jaringan disebut … | Perangkat akhir | Media transmisi, Perangkat lunak |
| 18 | Kabel dan gelombang radio yang menjadi jalan lewatnya data disebut … | Media transmisi | Perangkat akhir, Sistem operasi |
| 19 | Wi-Fi dan Bluetooth adalah contoh koneksi jaringan … | Nirkabel | Kabel UTP, Fiber optik |
| 20 | Kata Internet berasal dari 'interconnected network', yang artinya … | Jaringan saling terhubung | Jaringan milik pribadi, Jaringan tanpa kabel |
| 21 | Komputer yang menyediakan layanan, misalnya menyimpan halaman website, untuk komputer lain disebut … | Server | Client, Keyboard |
| 22 | Komputer yang meminta layanan atau data dari server disebut … | Client | Router, Switch |
| 23 | Urutan jenis jaringan dari cakupan PALING KECIL ke PALING LUAS adalah … | PAN – LAN – MAN – WAN | WAN – MAN – LAN – PAN, LAN – PAN – WAN – MAN |
| 24 | Jaringan Wi-Fi di rumah yang menghubungkan laptop, ponsel, dan smart TV termasuk jenis … | LAN | WAN, MAN |

---

## 5. Testing checklist

1. The course builds itself when you press Play. 2. **Test → Local Server, 2 players.**
3. As Player1 (teacher), open the Panel Guru and open **Tahap 1**. As Player2, walk into the ⛰️ portal.
4. Player2 should land on the gold Spawn facing the rules banner, with the question panel at the bottom.
5. Clear obstacle 1. The gate board and the A/B/C signs show Player2's question.
   - Walk through a **wrong** door: red burst, −5 Poin popup (or no change at 0), red card with the correct answer, respawn at the start, and the gate now shows a **different** question.
   - Walk through the **right** door: green burst, +10 Poin, the checkpoint behind the wall turns green, and the next gate shows "🔒" until you reach it.
6. Jump into the void: you're put back on your checkpoint. Touch lava: you respawn at the checkpoint.
7. Have Player1 enter Tahap 1 too (the teacher can enter closed portals). The same gate shows a **different** question for each player.
8. Finish all 6 gates and touch 🏁: +25 bonus, summary card, a class-wide toast, and the Videotron updates.
9. Step on 🏠, come back through the portal: a new run starts. Finishing again gives no bonus until the teacher presses "Reset Semua Poin".

## 6. Troubleshooting

| Symptom | Fix |
|---|---|
| Output: `Lintasan belum ada` | Look for `[World]` errors above it in Output. Auto-building may have failed, or `Workspace > Stages > Stage1` holds your own objects (the builder won't overwrite them). Delete that folder and press Play again |
| Boards and signs stay blank | `Stage1Client` is missing from StarterPlayerScripts, or `StreamingEnabled` is on and the course hasn't streamed in. Turn it off (Part 1) |
| Walking through doors does nothing | The section number doesn't match the student's progress (doors of an already-passed gate are ignored by design), or the door has no `Trigger` part |
| Text is mirrored or on the wrong side | Rotate the Sign/QuestionBoard part so its Front faces the players, or set its `Face` attribute |
| Students can get around a gate | Widen the wall or add invisible `Barrier` parts beside it (the builder adds 30-stud barriers on each side) |
| `Soal nomor N ... tidak lengkap` | That entry in `QuizBank.Stage1` is missing `Question`, `Correct`, or `Wrong` |
