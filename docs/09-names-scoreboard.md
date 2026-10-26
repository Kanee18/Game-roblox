# Part 9: Student Names & Class Points Board

## 1. Students type their name

When a student joins, a **"👋 Selamat Datang!"** screen asks for their name before they can play. The teacher is never asked.

The name is used in four places:
- the **Videotron** (big name, with the Roblox `@username` underneath)
- the **Papan Poin Kelas** (points board)
- the **Nama** column in the Roblox player list
- above the character's head

Finish messages (e.g. *"🏁 Budi berhasil menyelesaikan Routing Runner!"*) also use it.

### Rules (checked on the server)

| Rule | Message the student sees |
|---|---|
| 2–20 characters | *Nama terlalu pendek / panjang* |
| Letters, digits, spaces, `.` `-` `'` only, at least 2 letters | *Pakai huruf, angka, spasi, titik, atau tanda hubung saja.* |
| Not already used by a classmate (case-insensitive) | *Nama "Budi" sudah dipakai temanmu. Tambahkan inisial, misalnya "Budi A".* |
| Passes Roblox text filtering | *Nama itu tidak bisa dipakai. Coba nama lain, ya.* |

- **Auto-tidy:** extra spaces are removed and each word gets a capital letter (`budi  santoso` → `Budi Santoso`).
- **Filtering:** Roblox requires text typed by a player and shown to others to be filtered. A name the filter would turn into `###` is rejected instead of shown. The filter doesn't run in Studio.
- **No changing it yourself:** a student can't rename themselves after this, so they can't impersonate a classmate. Only the teacher can ask for a new name (section 2).
- **Rejoining:** a student who leaves and rejoins the same server keeps their name.
- **Portals:** a student without a name can't enter a portal. They get *"✏️ Tulis namamu dulu sebelum masuk portal, ya!"* and the name screen reopens.

Settings are in `GameConfig.StudentNames`:

```lua
GameConfig.StudentNames = {
	Enabled = true,           -- false = don't ask (use the Roblox display name)
	MinLength = 2,
	MaxLength = 20,
	RequiredForPortal = true,
	ShowInPlayerList = true,  -- "Nama" column in the Roblox player list
	ShowAboveHead = true,
	StatName = "Nama",
}
```

## 2. Papan Poin Kelas (class points board)

The Teacher Panel has a new section, **🏆 Papan Poin Kelas**. It contains:

- A summary, e.g. *"👥 24 siswa di kelas · ✅ Sudah selesai: ⛰️ 18 🔥 10 ⚡ 4 🍃 0"*. It shows how many students have finished each stage.
- **Urutkan papan menurut:** `Total` · `⛰️ 1` · `🔥 2` · `⚡ 3` · `🍃 4`. This chooses which points decide the ranking.
- **👁️ Lihat Papan Poin (hanya Guru):** opens the board on your screen only, so you can check it first.
- **📊 Tampilkan ke Semua Siswa:** shows the board on every student's screen with a fanfare. Press **🙈 Sembunyikan dari Siswa** to hide it again. Students can also close it themselves with ✕.

### What the board shows

| # | Nama | ⛰️ 1 | 🔥 2 | ⚡ 3 | 🍃 4 | Total |
|---|---|---|---|---|---|---|
| 🥇 | Budi Santoso | ✅85 | ✅40 | 30 | – | 155 |
| 🥈 | Siti | ✅70 | 25 | – | – | 95 |

- Each stage column has the points earned **in that stage**. ✅ means the stage is finished, `–` means not played yet.
- Each student sees their own row highlighted, and their rank in the summary line.
- Students who left the game stay on the board in grey with *(keluar)* until **Reset Semua Poin**.
- On your (teacher's) board, the **✏️** button on a row asks that student to type their name again. Use it for typos or inappropriate names.

### When is a stage "finished" (✅)?

| Stage | Finished when |
|---|---|
| ⛰️ 1 Routing Runner | The student reaches the finish line |
| 🔥 2 Firewall Defender | The student has answered `GameConfig.Stage2.WavesToComplete` waves (default 5). It has no finish line, so this counts as finishing. The student and class get a toast when it happens |
| ⚡ 3 Cable Labyrinth | The mission is complete (6 correct deliveries) |
| 🍃 4 Bandwidth Glider | The student lands on the island |

### Suggested use in class

- **After Stage 1:** wait until the summary shows ⛰️ close to the class size. Pick **⛰️ 1**, then **📊 Tampilkan ke Semua Siswa**, and discuss the Stage 1 winners and the questions.
- **After Stage 3 (or at the end):** pick **Total** and show the board to celebrate the overall ranking. The Videotron shows the champion at the same time.
- **Reset Semua Poin** clears the board, including ✅ marks.

## 3. Testing in Studio

**Play Solo** makes you the teacher, so you won't see the name screen. Use **Test → Local Server (2 players)** instead.

1. **Player2 (student):** the name screen appears. Try these names:
   - `a`: too short
   - `Budi!`: invalid character
   - `budi santoso`: accepted as "Budi Santoso"
2. **Player1 (teacher):** open **Panel Guru**. The summary now shows the student.
3. **Server window → Command Bar:** give Player2 test points while they are inside Stage 1. Points earned in the Lobby only count toward Total.
   ```lua
   require(game.ServerScriptService.Services.PointsService).Add(game.Players.Player2, 20, "Tes")
   ```
4. **Player1:** press **👁️ Lihat Papan Poin**, then **📊 Tampilkan ke Semua Siswa**. The board appears on Player2's screen.
5. **Player1:** press **✏️** on Player2's row. Player2 gets the *"✏️ Ganti Nama"* screen.

## Files (for copy-paste installs)

| File | Studio location |
|---|---|
| `src/server/Services/NameService.luau`, `ProgressService.luau` (**new**) | ModuleScript in `ServerScriptService > Services` |
| `src/client/NameClient.client.luau`, `ScoreboardClient.client.luau` (**new**) | LocalScript in `StarterPlayer > StarterPlayerScripts` |
| `Main`, `AdminService`, `PointsService`, `PortalService`, `VideotronService`, the 4 stage modules, `GameConfig`, `AdminPanelClient`, `Stage1Client`, `Stage3Client` | Re-paste (changed) |
