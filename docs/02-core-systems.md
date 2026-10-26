# Part 2: Core Systems

The core systems are global points (leaderstats), the Teacher Panel that controls the 4 elemental portals, and the Videotron leaderboard.

```
                ┌──────────────────────── SERVER ────────────────────────┐
 Teacher clicks │ AdminService ──► PortalService ──► SpawnService         │
 "Buka" in the  │      │                 │  (teleport to Stages/StageN)   │
 Teacher Panel ─┼──────┘                 ▼                                │
 (RemoteEvent)  │                 GameState attributes ──────────────────┼──► Teacher Panel status
                │ PointsService ──► Changed ──► VideotronService          │
                │   (leaderstats)                 │ JSON + avatar model ──┼──► VideotronClient (screen)
                │                                 └► champion statue on Podium
                │ NotifyService ──────────────────────────────────────────┼──► HudClient (toasts, +Poin)
                └─────────────────────────────────────────────────────────┘
```

---

## 1. Installing the scripts

### Option A: Rojo (recommended if you use VS Code)
1. Install [Rojo](https://rojo.space) (VS Code extension + Studio plugin).
2. In this repo folder run `rojo serve`, then click **Connect** in the Studio Rojo plugin.
3. Everything in `src/` syncs into the right place (see `default.project.json`).

### Option B: copy-paste by hand
File suffixes tell you which object type to create:

| File | Create in Studio | Name |
|---|---|---|
| `src/shared/GameConfig.luau` | **ModuleScript** in `ReplicatedStorage > Shared` (Folder) | `GameConfig` |
| `src/shared/Remotes.luau` | **ModuleScript** in `ReplicatedStorage > Shared` | `Remotes` |
| `src/shared/UiKit.luau` | **ModuleScript** in `ReplicatedStorage > Shared` | `UiKit` |
| `src/server/Main.server.luau` | **Script** in `ServerScriptService` | `Main` |
| `src/server/Services/*.luau` | **ModuleScript** in `ServerScriptService > Services` (Folder) | same as file name |
| `src/server/Services/Stages/` | **Folder** in `ServerScriptService > Services` | `Stages` |
| `src/server/Services/Stages/*.luau` | **ModuleScript** in `ServerScriptService > Services > Stages` | same as file name, e.g. `Stage1_RoutingRunner` |
| `src/server/QuizBank.luau` | **ModuleScript** directly in `ServerScriptService` | `QuizBank` |
| `src/shared/Stage1Map.luau` | **ModuleScript** in `ReplicatedStorage > Shared` | `Stage1Map` |
| `src/client/*.client.luau` | **LocalScript** in `StarterPlayer > StarterPlayerScripts` | `HudClient`, `AdminPanelClient`, `VideotronClient`, `Stage1Client`, `Stage2Client`, `Stage3Client` |

Rule of thumb: `.server.luau` → Script, `.client.luau` → LocalScript, plain `.luau` → ModuleScript. Names must match exactly (without the extension).

---

## 2. Making yourself the Teacher (admin)

Open `GameConfig` and add your Roblox UserId (the number in your profile URL `roblox.com/users/<UserId>/profile`):

```lua
GameConfig.Admin = {
	UserIds = {
		123456789, -- Bu/Pak Guru
	},
	CreatorIsAdmin = true,       -- the account that published the game is admin automatically
	GroupId = 0,                 -- or: group game + minimum rank
	GroupMinRank = 254,
	StudioTestAdminIds = { -1 }, -- in "Local Server" tests, Player1 is the teacher
	ExcludeFromLeaderboard = true,
}
```

In Studio **Play Solo**, your own account is always admin, so you can test the panel immediately.

---

## 3. What each system does

### 3.1 Points: `PointsService`
- Creates `leaderstats > Poin` (IntValue) for every player, which shows in the Roblox player list.
- Points are changed **only on the server**, so they can't be cheated from the client.
- Points never go below 0 (`AllowNegative = false`).
- If a student disconnects and rejoins the same server, their points are restored (session cache).
- Optional permanent saving: set `SaveToDataStore = true`.
- Every change can show a popup on the student's screen, for example **"+10 Poin · Jawaban benar!"**.

**API for the stage scripts:**
```lua
local PointsService = require(game.ServerScriptService.Services.PointsService)

PointsService.Add(player, 10, "Jawaban benar!")   -- green "+10 Poin · Jawaban benar!"
PointsService.Add(player, -5, "Jawaban salah")    -- red "-5 Poin · Jawaban salah"
PointsService.Get(player)                         --> number
PointsService.GetLeaderboard(5)                   --> sorted list
PointsService.Changed:Connect(function(player, newPoints, delta) end)
PointsService.AllReset:Connect(function() end)    -- teacher pressed "Reset Semua Poin"
```

### 3.2 Teacher Panel + portals: `AdminService`, `PortalService`, `AdminPanelClient`
- The panel appears **only** for admins (button **🛠️ Panel Guru** on the left, or press **G**).
- Panel features:
  - **Buka / Tutup** each of the 4 portals (Earth, Fire, Lightning, Wind). With `OnlyOneOpen = true`, opening one closes the others, so the teacher decides which game everyone plays.
  - **🔒 Tutup Semua Portal**
  - **🏠 Panggil Semua ke Lobby** teleports every student back to the lobby.
  - **♻️ Reset Semua Poin** requires a second click to confirm.
  - **📢 Pengumuman** shows a big announcement banner on every screen. The text is filtered with `TextService`, as Roblox requires.
- A closed portal is a grey, solid ForceField wall. Touching it shows *"🔒 Portal ini masih terkunci. Tunggu instruksi dari Guru, ya!"*
- An open portal glows in its element color, with sparkles, a light, and its `Glow` parts set to Neon. Touching it teleports the student to `Workspace > Stages > StageN > Spawn`.
- The teacher can still enter a closed portal to preview a stage (touching the gate teleports them). Students can't.
- A "⭐ GURU" tag floats above the teacher's head.
- Every command is **re-validated on the server**. A student who fires the RemoteEvent manually is ignored and logged.

**API (`SpawnService`) for the stage scripts:**
```lua
SpawnService.SendToStage(player, "Stage1")
SpawnService.SendToLobby(player)
SpawnService.SetRespawn(player, checkpointPart)   -- Stage 1 checkpoints use this
SpawnService.GetArea(player)                      --> "Lobby" | "Stage1" | ...
SpawnService.ReturnToCheckpoint(player)           -- put back on the checkpoint without dying
SpawnService.StageChanged:Connect(function(player, newArea, oldArea) end)
```

Parts named `ReturnToLobby`, `Lava`, or `FallZone` anywhere under `Workspace > Stages` work automatically (see the table in Part 1).

### 3.3 Videotron: `VideotronService` + `VideotronClient`
- The server sorts players by points (ties go to whoever reached the score first), excludes the teacher, and publishes the top 5 as JSON in `ReplicatedStorage > GameState` (attribute `Leaderboard`).
- When the #1 player changes, the server builds an R15 avatar with `Players:CreateHumanoidModelFromDescription` from the player's **current outfit** (`Humanoid:GetAppliedDescription`, which also works for Studio test players). The avatar is:
  1. Copied to `ReplicatedStorage > VideotronAvatar`. Each client shows it in a **ViewportFrame** on the screen, with the camera swaying gently.
  2. Cloned as a **statue** standing on `Podium`, with a floating name tag: *"👑 Nama · 120 Poin"*.
- Screen layout (1600×900 canvas):
  - Title **🏆 JUARA SEMENTARA 🏆**
  - Left: 3D avatar card with a "👑 JUARA 1" badge
  - Right: display name, @username, and points in large gold digits, plus ranks #2–#5
  - Bottom: a scrolling **"💡 Tahukah kamu?"** ticker of network facts (edit `GameConfig.Videotron.Facts`)
- Before anyone scores: *"Belum ada juara. Jawab soal dengan benar untuk tampil di sini!"*

---

## 4. Testing checklist

1. Run `tools/SetupLighting.luau` and `tools/BuildLobbySkeleton.luau` in the Command Bar (see Part 1).
2. Install the scripts (section 1), then **Ctrl+S**.
3. **Test → Clients and Servers → Local Server, 2 players → Start.**
   - **Player1** = teacher (UserId -1). You should see "🛠️ Panel Guru" and the ⭐ GURU tag.
   - **Player2** = student. No panel.
4. As Player2, walk into a portal: you get the "terkunci" message and bump into the wall.
5. As Player1, open **Tahap 1**: every player gets the "Portal Tanah DIBUKA!" toast, and the portal glows.
6. As Player2, walk into the portal: you're teleported to Stage 1. Step on the white pad to return.
7. Give test points from the **Server** window's Command Bar:
   ```lua
   require(game.ServerScriptService.Services.PointsService).Add(game.Players.Player2, 50, "Tes Poin")
   ```
   Player2 sees "+50 Poin · Tes Poin". Within a few seconds the Videotron shows Player2's avatar and points, and the statue appears on the podium.
8. Try **Pengumuman**, **Panggil Semua ke Lobby**, and **Reset Semua Poin** (click twice).

## 5. Troubleshooting

| Symptom | Fix |
|---|---|
| Output: `Portal "Stage1" tidak ditemukan` | The model must be named `Stage1` (or have attribute `StageId = "Stage1"`) inside `Workspace > Lobby > Portals` |
| Output: `belum punya Part bernama "Gate"` | Add a Part named exactly `Gate` inside the portal model |
| Portal opens but teleport fails ("Peta tahap ini belum siap") | Create `Workspace > Stages > Stage1 > Spawn` (a Part) |
| No Teacher Panel | Add your UserId to `GameConfig.Admin.UserIds`. In Local Server tests, use Player1 |
| Videotron is blank | Check the `Screen` part exists, then set its `Face` attribute (`Front`, `Back`, ...) to the side that faces the players |
| Videotron text appears mirrored | The wrong face is used. Change the `Face` attribute or rotate the Screen part 180° |
| Statue faces the wrong way | Rotate `Podium` so its **Front** face points at the players |
| Announcement "gagal dikirim" in a live game | Roblox text filtering was temporarily unavailable. Try again |
| DataStore warnings in Studio | Enable *Studio Access to API Services*, or keep `SaveToDataStore = false` |
