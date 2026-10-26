# Part 1: Roblox Studio Setup Guide

Visual direction: a lush, bright, soft-shaded fantasy world in the style of Genshin Impact. All in-game text is in Indonesian. These instructions are in English.

---

## 0. Project settings (do this first)

| Where | Setting | Value | Why |
|---|---|---|---|
| Home → Game Settings → Avatar | Avatar Type | **R15** | The Videotron avatar and later glider/shooting animations use R15 |
| Home → Game Settings → Security | Enable Studio Access to API Services | **On** (only if `SaveToDataStore = true`) | Lets you test DataStore saving in Studio |
| Explorer → Workspace | `StreamingEnabled` | **Off** (recommended) | Keeps stage scripts simple, since every part is always loaded on the client. The maps are classroom-sized, so this is fine |
| Explorer → Workspace | `FallenPartsDestroyHeight` | `-500` | Players who fall from floating islands respawn quickly |
| Explorer → StarterPlayer | `CharacterWalkSpeed` / `CharacterJumpPower` | 16 / 50 (default) | Stage 1 parkour is tuned for these |

> If you prefer to keep `StreamingEnabled` **on** for low-end devices, the core scripts still work. The Videotron is forced to `Persistent` automatically.

---

## 1. Lighting: the "Genshin" look

### Fastest way: run the Command Bar script

1. **View → Command Bar**.
2. Open [`tools/SetupLighting.luau`](../tools/SetupLighting.luau), copy **all** of it, paste it into the Command Bar, and press **Enter**.
3. Check **Output**. If a property can't be set by script (for example `Technology` on some Studio versions), set it by hand using the tables below.
4. **Ctrl+S** to save.

### Manual values (same as the script)

**Lighting** (Explorer → Lighting)

| Property | Value | Notes |
|---|---|---|
| Technology | **Future** | Best PBR/specular quality. Use `ShadowMap` if school PCs struggle |
| Brightness | 2.6 | |
| ExposureCompensation | 0.1 | |
| Ambient | 86, 92, 120 | Cool shadows indoors |
| OutdoorAmbient | 150, 158, 196 | Soft bluish shadows outdoors (the anime look) |
| ColorShift_Top | 255, 232, 196 | Warm sunlight tint |
| ColorShift_Bottom | 122, 146, 210 | Cool bounce light |
| EnvironmentDiffuseScale | 1 | |
| EnvironmentSpecularScale | 0.5 | Keeps materials from looking too "wet"; stylized art likes low shine |
| GlobalShadows | true | |
| ShadowSoftness | 0.3 | Soft but readable, close to cel-shading |
| ClockTime | 14.2 | Bright afternoon |
| GeographicLatitude | 28 | Nice long shadow angle |

**Atmosphere** (Insert into Lighting)

| Density | Offset | Color | Decay | Glare | Haze |
|---|---|---|---|---|---|
| 0.3 | 0.25 | 199, 225, 255 | 128, 152, 222 | 0.35 | 1.4 |

**Sky**: `SunAngularSize` 16, `MoonAngularSize` 9, `StarCount` 3000. For a stylized skybox, insert one from Toolbox (keywords below) and **delete the old Sky** so only one remains.

**Clouds** (Insert into Workspace → Terrain): `Cover` 0.55, `Density` 0.6, `Color` 255, 255, 255.

**Post-processing effects** (Insert into Lighting)

| Effect | Settings |
|---|---|
| BloomEffect | Intensity 0.7, Size 30, Threshold 1.3 (portals, Neon, and the Videotron glow softly) |
| SunRaysEffect | Intensity 0.1, Spread 0.75 |
| ColorCorrectionEffect | Brightness 0.02, Contrast 0.12, **Saturation 0.22**, TintColor 255, 247, 238 |
| DepthOfFieldEffect *(optional)* | FarIntensity 0.12, FocusDistance 40, InFocusRadius 60, NearIntensity 0. Disable it if text looks blurry |

### Time-of-day presets (optional mood per stage)

| Mood | ClockTime | ColorShift_Top | Atmosphere Color / Decay |
|---|---|---|---|
| Bright morning | 8.5 | 255, 240, 214 | 210, 232, 255 / 150, 175, 230 |
| Afternoon (default) | 14.2 | 255, 232, 196 | 199, 225, 255 / 128, 152, 222 |
| Golden sunset | 17.6 | 255, 190, 140 | 255, 210, 180 / 150, 120, 200 |

---

## 2. Terrain and PBR materials

### Terrain (lush ground, water, and grass)

The script already sets these terrain colors:

| Material | RGB | Use |
|---|---|---|
| Grass | 118, 186, 82 | Main meadow (bright yellow-green, Mondstadt-like) |
| LeafyGrass | 88, 160, 72 | Paint patches for color variation |
| Ground | 132, 104, 74 | Paths |
| Rock / Slate | 138, 134, 128 / 112, 114, 124 | Cliffs and floating-island undersides |
| Sand | 232, 214, 166 | Shores |
| Limestone / Pavement | 226, 214, 186 / 196, 190, 178 | Plaza and ruins |

Tips:
- Turn on **Terrain → Decoration** (animated grass). The script does this.
- Use **Editor → Paint** to blend Grass, LeafyGrass, and Ground. Large single-color areas look flat, and color variation is what makes Genshin-style ground look rich.
- Water: color 42, 170, 196, Transparency 0.65, Reflectance 0.45, WaveSize 0.12. Put a pond or waterfall near the lobby.
- Build the lobby as a **floating island**: a Rock/Slate cone under a grassy top, with small floating rocks around it.

### Parts (PBR 2022 materials)

Roblox's built-in materials are PBR. Use these combinations instead of plain grey Plastic:

| Element | Material | Color (RGB) |
|---|---|---|
| Plaza floor | Pavement / Cobblestone | 226, 216, 196 |
| Ruins, pillars, arches | Marble / Limestone | 240, 234, 220 |
| Gold trims and runes | Metal (gold color) / Neon | 226, 190, 110 |
| Wooden bridges and fences | WoodPlanks | 160, 110, 70 |
| ⛰️ Earth portal (Stage 1) | Slate + gold Neon | 255, 196, 77 |
| 🔥 Fire portal (Stage 2) | Basalt / CrackedLava | 255, 102, 64 |
| ⚡ Lightning portal (Stage 3) | Glass (Transparency 0.3) + Neon | 176, 112, 255 |
| 🍃 Wind portal (Stage 4) | Marble / Ice / Glass | 88, 228, 196 |
| Videotron frame | Metal / DiamondPlate + Neon trim | 40, 44, 70 |
| Stage 3 motherboard floor | SmoothPlastic (PCB green) + Metal "copper traces" | 30, 110, 70 / 200, 130, 70 |

### Custom stylized materials (MaterialVariant)

For a hand-painted look, open **View → Material Manager**:
1. Create a **MaterialVariant** (for example based on Grass or Cobblestone), or use the **Material Generator** if your Studio version has it. Try prompts like:
   - `stylized hand-painted cobblestone, anime game style, warm tones`
   - `fantasy meadow grass, hand-painted, vibrant green`
   - `ancient white marble with gold runes, stylized`
2. Set it as the **override** for that base material so every part and terrain cell using it changes at once.

---

## 3. Toolbox asset keywords

Use **Toolbox → Creator Store → Models**. Search these keywords:

| Category | Keywords |
|---|---|
| Trees | `stylized tree`, `low poly tree pack`, `fantasy tree`, `sakura tree`, `anime tree`, `cartoon pine tree` |
| Grass, flowers, plants | `stylized grass`, `fantasy flowers`, `flower patch`, `stylized bush`, `fantasy mushroom`, `dandelion` |
| Rocks and islands | `stylized rock pack`, `floating island`, `low poly cliff`, `fantasy rocks` |
| Ruins and architecture | `ancient ruins`, `fantasy ruins`, `stone pillar ruins`, `temple ruins`, `magic arch`, `fantasy bridge`, `gazebo` |
| Portals and magic | `magic portal`, `portal ring`, `glowing portal`, `rune circle`, `magic circle`, `teleporter pad` |
| Elemental accents | `stylized crystal`, `fire torch stylized`, `lava rock`, `electric crystal`, `wind particles`, `floating lantern` |
| Particles and VFX | `fireflies`, `magic sparkles`, `falling leaves particles`, `dandelion seeds particles`, `waterfall stylized` |
| Sky | `anime skybox`, `stylized sky`, `pastel sky`, `fantasy skybox` |
| Videotron | `led screen`, `jumbotron`, `billboard screen` |
| Stage 1 (Obby) | `obby kit`, `floating platforms`, `checkpoint`, `stylized door` |
| Stage 2 (Firewall) | `stylized monster`, `slime`, `virus model`, `tower defense`, `blaster` |
| Stage 3 (Motherboard) | `motherboard`, `circuit board`, `server rack`, `router`, `network switch`, `ethernet cable`, `computer` |
| Stage 4 (Glider) | `glider`, `wind ring`, `sky islands`, `cloud pack` |

### Safety checklist for free models

Free models can contain hidden malicious scripts ("backdoors"). After inserting **any** model:
1. Expand it in Explorer and look for `Script`, `LocalScript`, or `ModuleScript`. Delete any you didn't expect. Decorative models don't need scripts.
2. Press **Ctrl+Shift+F** (Find All) and search for `require(` and `getfenv`. Delete any script that does `require(<number>)` and that you didn't write.
3. Prefer assets from **verified creators** and with many favorites.
4. For decorative meshes, set `CanCollide = false`, `CanTouch = false`, `CanQuery = false`, and `Anchored = true`, and set `CollisionFidelity = Box` (or Hull).

---

## 4. Art direction: lobby and portals

Suggested lobby layout (this is exactly what `BuildLobbySkeleton.luau` creates):

```
                       [ VIDEOTRON ]   ← north (Z = -90), screen faces the spawn
                         (Podium)       ← champion statue stands here
       🔥 Stage2                          ⚡ Stage3
  ⛰️ Stage1          ( PLAZA )               🍃 Stage4
                      SpawnLocation      ← faces the Videotron
```

- Portals form a semicircle (radius 70) around the plaza, all facing the center.
- Give each portal its element identity:
  - **⛰️ Earth (Stage 1):** floating rock shards, gold runes, `Slate`/`Basalt`.
  - **🔥 Fire (Stage 2):** braziers, ember particles, `CrackedLava` cracks on the floor.
  - **⚡ Lightning (Stage 3):** purple crystals, `Glass` + `Neon`, small arcs (Beam).
  - **🍃 Wind (Stage 4):** pale-green crystals, leaf particles, pinwheels or flags.
- Lighting accents: warm `PointLight` lanterns (255, 180, 100, Range 12) along paths. Portal lights are added automatically by `PortalService`.
- Compose in layers: flowers in the foreground, trees and ruins mid-ground, large low-detail mountains and floating islands in the background (Atmosphere haze makes them read as "far").
- Avoid flat grey Plastic, pure black, and very large single-color surfaces.

### Performance (school computers)

- Turn off `CastShadow` on grass, flowers, and small props.
- Mesh `RenderFidelity = Automatic`, `CollisionFidelity = Box` for decorations.
- Keep particle `Rate` low (10–30) and reuse a few emitters.
- Test with **File → Studio Settings → Rendering → Quality Level 3–5** to see what a weak laptop will look like.

---

## 5. Folder structure (Explorer)

Names in **bold** are required by the scripts and must match exactly. Everything else is decoration you can name freely.

```
Workspace
├── Lobby (Folder)
│   ├── SpawnLocation            ← the ONLY enabled SpawnLocation in the game
│   ├── Environment (Folder)     ← terrain props, trees, ruins (Toolbox)
│   ├── Portals (Folder)
│   │   ├── Stage1 (Model)       ← ⛰️ Earth portal
│   │   │   ├── Gate (Part)      ← REQUIRED: the surface players touch
│   │   │   ├── Glow (Part)      ← optional, any number; lights up when open
│   │   │   └── ...decoration
│   │   ├── Stage2 (Model)       ← 🔥 Fire portal
│   │   ├── Stage3 (Model)       ← ⚡ Lightning portal
│   │   └── Stage4 (Model)       ← 🍃 Wind portal
│   └── Videotron (Model)
│       ├── Screen (Part)        ← REQUIRED: 16:9 (e.g. 48 × 27 × 1); Front face toward players
│       ├── Podium (Part)        ← optional: the champion statue stands on top
│       └── ...frame / legs / trim
└── Stages (Folder)
    ├── Stage1 (Folder)
    │   ├── Spawn (Part)         ← REQUIRED: where players arrive (flat part, Front = facing direction)
    │   ├── ReturnToLobby (Part) ← optional: touching it sends the player back to the lobby
    │   └── ...map (built in the Stage 1 step)
    ├── Stage2 (Folder)
    ├── Stage3 (Folder)
    └── Stage4 (Folder)

Lighting
├── Atmosphere
├── Sky
├── Bloom (BloomEffect)
├── SunRays (SunRaysEffect)
├── ColorCorrection (ColorCorrectionEffect)
└── DepthOfField (DepthOfFieldEffect, optional)

ReplicatedStorage
├── Shared (Folder)
│   ├── GameConfig (ModuleScript)     ← ALL settings: admins, points, portals, stage names, theme
│   ├── Remotes (ModuleScript)
│   ├── UiKit (ModuleScript)
│   └── QuizBank (ModuleScript)       ← later: question bank for Stages 1–4
├── RemoteEvents (Folder)             ← created automatically at runtime, don't make it by hand
├── GameState (Folder)                ← created automatically at runtime
└── VideotronAvatar (Folder)          ← created automatically at runtime

ServerScriptService
├── Main (Script)
└── Services (Folder)
    ├── NotifyService (ModuleScript)
    ├── PointsService (ModuleScript)
    ├── SpawnService (ModuleScript)
    ├── PortalService (ModuleScript)
    ├── AdminService (ModuleScript)
    ├── VideotronService (ModuleScript)
    └── Stages (Folder)               ← every ModuleScript here starts automatically
        ├── Stage1_RoutingRunner      ← later
        ├── Stage2_FirewallDefender   ← later
        ├── Stage3_CableLabyrinth     ← later
        └── Stage4_BandwidthGlider    ← later

StarterPlayer
└── StarterPlayerScripts
    ├── HudClient (LocalScript)
    ├── AdminPanelClient (LocalScript)
    └── VideotronClient (LocalScript)
```

### Quick start for the map

Run [`tools/BuildLobbySkeleton.luau`](../tools/BuildLobbySkeleton.luau) in the Command Bar once. It builds the lobby island, plaza, spawn, the 4 portals (with `Gate` and `Glow` parts), the Videotron (`Screen` + `Podium`), and the 4 stage areas (`Spawn` + `ReturnToLobby`), all with the correct names. Then you can:
- Replace the island/plaza parts with Terrain.
- Swap portal pillars for Toolbox ruins. Keep the `Gate` part, and rename any glowing parts to `Glow`.
- Re-skin the Videotron frame. Keep `Screen` and `Podium`.
