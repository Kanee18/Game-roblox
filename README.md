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
- [ ] Stage 1: Routing Runner
- [ ] Stage 2: Firewall Defender
- [ ] Stage 3: Cable Labyrinth
- [ ] Stage 4: Bandwidth Glider

## Repository layout

```
default.project.json        Rojo project (optional)
src/
  shared/   → ReplicatedStorage.Shared       GameConfig, Remotes, UiKit (ModuleScripts)
  server/   → ServerScriptService             Main (Script) + Services/* (ModuleScripts)
  client/   → StarterPlayer.StarterPlayerScripts   HudClient, AdminPanelClient, VideotronClient
tools/
  SetupLighting.luau        Run once in the Studio Command Bar to set up the Genshin-style lighting
  BuildLobbySkeleton.luau   Run once in the Command Bar to build a test-ready lobby, portals, Videotron, and stages
docs/
  01-studio-setup.md
  02-core-systems.md
```

File suffix → Studio type: `*.server.luau` = Script, `*.client.luau` = LocalScript, `*.luau` = ModuleScript.

## Quick start

1. Open a new **Baseplate** in Roblox Studio and delete the default `Baseplate` and `SpawnLocation`.
2. Paste `tools/SetupLighting.luau` into the Command Bar and press Enter. Then do the same with `tools/BuildLobbySkeleton.luau`.
3. Add the scripts from `src/`, either with Rojo (`rojo serve`) or by copy-paste (see the table in `docs/02-core-systems.md`).
4. Put your UserId in `GameConfig.Admin.UserIds`.
5. Test with **Test → Local Server (2 players)**. Player1 is the teacher and Player2 is a student.
