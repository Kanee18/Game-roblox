# Part 7: Background Music & Sound Effects

All audio settings are in one place: `GameConfig.Audio` (`ReplicatedStorage > Shared > GameConfig`).

| What | Where it comes from | Works out of the box? |
|---|---|---|
| **Sound effects** | Built-in sound files that ship with every Roblox client (`rbxasset://sounds/...`) | ✅ Yes, no IDs needed |
| **Background music** | Audio IDs from the Roblox Creator Store that **you paste in** | Until you add IDs, a soft built-in **music-box melody** plays (a different tune per area) |

Why music isn't pre-filled: since Roblox's 2022 audio privacy update, a game can only play audio that is public in the Creator Store (for example Roblox's licensed music library) or that you uploaded yourself. Old ID lists online are full of dead tracks, so pick tracks you've previewed in Studio and paste their IDs (5 minutes, steps below).

---

## 1. Adding background music (one track per area)

1. In Studio: **View → Toolbox**, then switch the category dropdown to **Audio** and the type to **Music**.
2. Search with these keywords (all in English):

   | Area | Mood | Search keywords |
   |---|---|---|
   | `Lobby` | Calm, fantasy village | `fantasy village`, `peaceful adventure`, `calm orchestral` |
   | `Stage1` (⛰️ Routing Runner) | Upbeat, platformer | `adventure upbeat`, `platformer`, `happy journey` |
   | `Stage2` (🔥 Firewall Defender) | Tense, battle | `epic battle`, `action drums`, `boss fight` |
   | `Stage3` (⚡ Cable Labyrinth) | Electronic, puzzle | `electronic puzzle`, `synth mystery`, `techno ambient` |
   | `Stage4` (🍃 Bandwidth Glider) | Airy, uplifting | `uplifting sky`, `flying orchestral`, `wind ambient` |

   Tracks published by **Roblox** (its licensed APM / Monstercat music library) are free to use in any experience. Roblox's own help page says licensed music is royalty-free on the platform, up to 250 licensed tracks per game.
3. Press ▶ in the Toolbox to preview. When you like one, **right-click → Copy Asset ID**.
4. Paste it into `GameConfig.Audio.Music`:

   ```lua
   Music = {
   	Lobby = "rbxassetid://1234567890", -- or just the number: 1234567890
   	Stage1 = "",                       -- still empty = music-box melody
   	...
   },
   ```
5. **Play** and listen. If a track can't be loaded, **Output** shows
   `[Audio] Musik area "Lobby" gagal dimuat (...)` and that area falls back to the music box. Pick another track.

Uploading your own music is also possible (Creator Hub → Development Items → Audio). You must own the rights, and uploads have a monthly limit.

### Music behavior

- The track changes automatically when a student moves between the lobby and a stage, with a 1.5 s crossfade.
- **🔊 / 🔇 button** next to the points counter: each student can mute music for themselves.
- **Panel Guru → "🎵 Musik semua siswa: NYALA/MATI"** turns music off or on for the whole class. Useful while explaining. Sound effects stay on.
- `FallbackMusic = false` makes areas without an ID silent instead of playing the music box.
- Volumes: `MusicVolume = 0.35`, `SfxVolume = 0.7`.

---

## 2. Sound effects

Played only on the student's own computer, so a class of 30 doesn't become a wall of noise.

| Name in `Sfx` | When it plays | Default sound (built-in) |
|---|---|---|
| `Correct` | Points gained (any correct answer, bonuses) | `electronicpingshort.wav`, pitched up |
| `Wrong` | Points lost (wrong answer) | `collide.wav`, pitched down |
| `Notify` / `Error` | Toast messages / "portal locked" and other errors | `clickfast.wav` / `button.wav` |
| `PortalOpen` | A portal opens, or you enter a stage | `Rocket whoosh 01.wav` |
| `Teleport` | Moving between lobby and stages | `swoosh.wav` |
| `Announcement` | Teacher announcement banner | `electronicpingshort.wav`, low |
| `Click` | Teacher panel and music buttons | `clickfast.wav` |
| `Fanfare` | Stage 1 finish, Stage 3 mission complete, Stage 4 landing | `victory.wav` |
| `Shoot` | Stage 2: firing the Tongkat Firewall | `Rocket shot.wav`, short and high |
| `Success` / `CoreHit` | Stage 2 wave reveal: firewall held / core damaged | ping / deep `collide.wav` |
| `Pickup` | Stage 3: picking up a device | `unsheath.wav`, pitched up |
| `Launch`, `WindLoop`, `Land` | Stage 4: take-off, wind while gliding, landing | `swoosh.wav`, `action_falling.mp3`, `action_jump_land.mp3` |
| `Boost` / `Slow` | Stage 4: ⚡ speed boost / 🐢 lag | `Rocket whoosh 01.wav` / deep `collide.wav` |
| `Chime` | Notes of the music-box melody | `electronicpingshort.wav` |

Virus explosions in Stage 2 use Roblox's built-in explosion sound automatically.

To replace any effect, change its `Id` to a Creator Store sound (`"rbxassetid://..."`). Search the Toolbox with **Audio → Sound Effect** and keywords like `correct answer`, `wrong buzzer`, `magic whoosh`, `level complete`, `laser shot`, `item pickup`. `Volume` and `Speed` (pitch) can be tuned per effect.

---

## 3. Scripts

| File | Studio object | Location |
|---|---|---|
| `src/shared/Sfx.luau` | ModuleScript `Sfx` | `ReplicatedStorage > Shared` |
| `src/client/AudioClient.client.luau` | LocalScript `AudioClient` | `StarterPlayer > StarterPlayerScripts` |
| *(updated)* `GameConfig`, `AdminService`, `HudClient`, `AdminPanelClient`, `Stage1Client` … `Stage4Client` | | replace with the new versions |

Using a sound from your own scripts:

```lua
local Sfx = require(game.ReplicatedStorage.Shared.Sfx)
Sfx.Play("Correct")                -- once
Sfx.Play("Chime", 1.5)             -- with a different pitch
local wind = Sfx.Loop("WindLoop")  -- looping; stop with wind:Destroy()
```

## 4. Troubleshooting

| Symptom | Fix |
|---|---|
| Output: `[Audio] Efek suara gagal dimuat: rbxasset://sounds/...` | That built-in file isn't in your Roblox version. Replace that one `Id` with a Creator Store sound |
| Output: `[Audio] Musik area "X" gagal dimuat` | The track is private or deleted. Choose another one in the Toolbox |
| No music at all | Check the 🔊 button and the teacher's 🎵 switch. Also check the in-game **Settings → Volume** and the Windows/phone volume |
| Music box too quiet or loud | Change `Chime.Volume` in `GameConfig.Audio.Sfx` |
| Too many sounds while explaining | Teacher: **🎵 Musik semua siswa: MATI** in the Panel Guru |
