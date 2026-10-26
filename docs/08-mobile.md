# Part 8: Playing on Phones

Most students play on a phone, so the UI switches to a **compact layout** automatically. Nothing needs to be configured.

**When the compact layout is used:**
- the device is touch-only (a phone, or a tablet without a keyboard), or
- the game window is short (less than 500 px tall).

Rotating the phone or resizing the window switches the layout live (`UiKit.OnLayout`).

## What changes on a phone

| Element | PC | Phone |
|---|---|---|
| ⭐ Points + 🔊 music button | Top center | Top left, smaller |
| Notifications (toasts) | Top center, up to 4 | Bottom center (between the joystick and the jump button), up to 2 |
| Stage panel (question, options, status) | Bottom center | **Top right**, 90% size, so it never covers the joystick, the jump button, or your character. **Tap the panel title (▾/▸) to collapse it.** It opens again by itself when a new question arrives |
| Result cards (✅ BENAR / ❌ SALAH, finish) | Center | Center, 80% size. **Tap a card to close it** ("Ketuk untuk menutup") |
| 📢 Teacher announcement | Upper middle | Top, 80% size, tap to close |
| Stage 1 answer options | One row | Stacked (text stays large) |
| Stage 2 shooting | Click the virus | **Aim assist**: a tap up to 90 px from a virus *or its answer label* still hits it. The panel also lists the answers as **chips in the same color as their virus**, so a far-away label is easy to match |
| Stage 4 speedometer | Bottom right | Top left, under the points |
| Stage 4 gate result card | Upper middle | Bottom center (the top right shows the next question) |
| Stage 4 control hint | Arrow keys / WASD | "🕹️ Joystick: kiri/kanan = belok, atas/bawah = naik/turun" |
| Teacher Panel button | "🛠️ Panel Guru" | "🛠️ Guru". The panel uses the full screen height and scrolls |
| Depth-of-field blur | On | Off on this phone only (faster, and distant text stays sharp) |

**Labels above things in the world** shrink with distance (a mix of studs + pixels), so they no longer pile on top of each other on a small screen. They never shrink below a readable minimum. This covers portal boards, Stage 2 virus labels and the Server Core label, Stage 3 device signs and the Central Machine board, and Stage 4 gate questions and ring labels. The panel always repeats the question, so reading the 3D labels is optional.

## Settings

In `GameConfig.Stage2`:

```lua
LabelHeight = 7,       -- height of the answer label above a virus (studs)
AimAssistTouch = 90,   -- aim assist radius on phones (pixels). 0 = off
AimAssistMouse = 40,   -- aim assist radius for mouse clicks on PC
```

The server still re-checks every shot (a ray from the student's head to the virus), so aim assist can't be abused to hit something out of range.

## Testing the phone layout in Studio

1. Open the **Test** tab, then click **Device** (Device Emulator).
2. Pick a phone (e.g. *iPhone 14*, *Samsung Galaxy S22*) and choose **landscape**.
3. Press **Play**. Check the following:
   - The points are at the top left.
   - In a stage, the panel is at the top right and collapses when you tap its title.
   - Cards close when you tap them.
   - In Stage 2, tapping next to a virus label still shoots it.
4. Switch back to **Actual resolution** to check the PC layout.

## Tips for class

- Ask students to play in **landscape** (phone rotated sideways). Portrait works, but there is very little room.
- On older phones, lowering **Settings → Graphics Quality** in the Roblox menu makes the game smoother. The game already turns off blur on phones.
- If a student taps the panel title by accident, the panel collapses to one line. Tap the title again, or wait for the next question, to open it.

## Files changed (for copy-paste installs)

Re-paste these files if you installed by hand (Rojo users: just sync):

| File | Studio location |
|---|---|
| `src/shared/UiKit.luau`, `src/shared/GameConfig.luau` | `ReplicatedStorage > Shared` |
| `src/client/HudClient`, `AudioClient`, `AdminPanelClient`, `Stage1Client` … `Stage4Client` (`.client.luau`) | `StarterPlayer > StarterPlayerScripts` |
| `src/server/Services/PortalService.luau` | `ServerScriptService > Services` |
| `src/server/Services/Stages/Stage2_FirewallDefender.luau`, `Stage3_CableLabyrinth.luau` | `ServerScriptService > Services > Stages` |
