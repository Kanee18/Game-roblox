# Petualangan Jaringan Komputer (Roblox)

A multiplayer educational Roblox game for **Informatika Kelas 7 SMP**, covering the topic *Jaringan Komputer dan Internet*. All in-game text is in Indonesian.

Students meet in a lush fantasy lobby (Genshin Impact–style). The teacher opens one of four **elemental portals**, each leading to a quiz mini-game. Points are tracked globally, and the top student is shown on a giant **Videotron** with their 3D avatar.

| Portal | Stage | Material |
|---|---|---|
| ⛰️ Tanah | 1 · Routing Runner (obby) | Dasar Jaringan & LAN/WAN |
| 🔥 Api | 2 · Firewall Defender (shooter) | Keamanan Data & Virus |
| ⚡ Petir | 3 · Cable Labyrinth (maze) | Perangkat Keras Jaringan |
| 🍃 Angin | 4 · Bandwidth Glider (glide) | Kecepatan Internet & Koneksi |

## Progress

- [x] **Part 1: Studio setup.** Lighting, materials, Toolbox keywords, folder structure → [`docs/01-studio-setup.md`](docs/01-studio-setup.md)
- [x] **Part 2: Core systems.** Points/leaderstats, Teacher Panel + portals, Videotron → [`docs/02-core-systems.md`](docs/02-core-systems.md)
- [x] **Stage 1: Routing Runner.** Obby + per-student router-gate quiz, 24 questions → [`docs/03-stage1-routing-runner.md`](docs/03-stage1-routing-runner.md)
- [x] **Stage 2: Firewall Defender.** Wave shooter where your first hit is your answer, plus a shared Server Core, 22 questions → [`docs/04-stage2-firewall-defender.md`](docs/04-stage2-firewall-defender.md)
- [x] **Stage 3: Cable Labyrinth.** Motherboard maze: identify the device from its function, find it, and deliver it; 11 built-in 3D devices, 22 requests → [`docs/05-stage3-cable-labyrinth.md`](docs/05-stage3-cable-labyrinth.md)
- [x] **Stage 4: Bandwidth Glider.** Glide through A/B wind rings; correct = ⚡ speed boost, wrong = 🐢 buffering; 20 questions → [`docs/06-stage4-bandwidth-glider.md`](docs/06-stage4-bandwidth-glider.md)

## Repository layout

```
default.project.json        Rojo project (optional)
src/
  shared/   → ReplicatedStorage.Shared       GameConfig, Remotes, UiKit, Stage1Map, Stage4Map (ModuleScripts)
  server/   → ServerScriptService             Main (Script), QuizBank, Services/*, Services/Stages/*
  client/   → StarterPlayer.StarterPlayerScripts   HudClient, AdminPanelClient, VideotronClient, Stage1Client … Stage4Client
tools/
  SetupLighting.luau        Run once in the Studio Command Bar to set up the Genshin-style lighting
  BuildLobbySkeleton.luau   Run once in the Command Bar to build a test-ready lobby, portals, Videotron, and stages
  BuildStage1.luau          Run once in the Command Bar to build the Routing Runner course
  BuildStage2.luau          Run once in the Command Bar to build the Firewall Defender arena
  BuildStage3.luau          Run once in the Command Bar to build the Cable Labyrinth maze
  BuildStage4.luau          Run once in the Command Bar to build the Bandwidth Glider sky course
docs/
  01-studio-setup.md
  02-core-systems.md
  03-stage1-routing-runner.md
  04-stage2-firewall-defender.md
  05-stage3-cable-labyrinth.md
  06-stage4-bandwidth-glider.md
```

File suffix → Studio type: `*.server.luau` = Script, `*.client.luau` = LocalScript, `*.luau` = ModuleScript.

## Quick start

1. Open a new **Baseplate** in Roblox Studio and delete the default `Baseplate` and `SpawnLocation`.
2. Paste `tools/SetupLighting.luau` into the Command Bar and press Enter. Then do the same with `tools/BuildLobbySkeleton.luau`, then `tools/BuildStage1.luau` through `tools/BuildStage4.luau`.
3. Add the scripts from `src/`, either with Rojo (`rojo serve`) or by copy-paste (see the table in `docs/02-core-systems.md`).
4. Put your UserId in `GameConfig.Admin.UserIds`.
5. Test with **Test → Local Server (2 players)**. Player1 is the teacher and Player2 is a student.

## Running a class session

1. **Publish** the place, then start a server for the class: a **private server**, or the public game with *Max Players* set to your class size (Game Settings → Places).
2. Join first with the teacher account. You'll see **🛠️ Panel Guru** (press **G**) and the ⭐ GURU tag.
3. Students join and gather in the lobby. Everyone can see the Videotron and the 4 locked portals.
4. Open **one portal at a time** from the Panel Guru, in lesson order: ⛰️ Tahap 1 → 🔥 Tahap 2 → ⚡ Tahap 3 → 🍃 Tahap 4. Opening one closes the others.
5. Between stages, use **🏠 Panggil Semua ke Lobby** and **📢 Pengumuman** to discuss the explanations, then open the next portal.
6. At the end, the Videotron shows the class champion. Use **♻️ Reset Semua Poin** to start fresh next lesson (unless `SaveToDataStore` is on).

Question banks for all stages are in one file: `src/server/QuizBank.luau` (`ServerScriptService > QuizBank`). Edit it to match your own lesson.
