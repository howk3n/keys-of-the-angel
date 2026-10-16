# Keys of the Angel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A WoW: Forever addon that plays the author's song once Plainsrunning reaches 30 stacks, fades it with the
stack count, crossfades the game music, and ships to CurseForge.

**Architecture:** A pure Lua core (`src/core/`) holds the volume math and a state machine (`Engine`) that talks to
the game only through an injected adapter table, so all behavior is unit-tested outside the game with a fake adapter.
A thin WoW layer (`src/wow/`) implements the adapter with real APIs and wires events and a 0.1 s ticker. Unknown
client behavior is settled first by an in-game probe round.

**Tech Stack:** Lua 5.1, WoW: Forever client API, LuaJIT + StreetCred's minimal busted-style runner for tests,
luacheck, GitHub Actions, BigWigs packager, CurseForge.

**Spec:** `docs/superpowers/specs/2026-10-16-keys-of-the-angel-design.md` (read it; this plan argues from it).
Client facts: `docs/wow-forever-addon-notes.md`.

## Global Constraints

- `## Interface: 16001`, Lua 5.1 (no `goto`, no `//`). Lines ≤ 120 characters; luacheck must pass.
- Every Lua file starts with `local addonName, ns = ...`. No globals except `KeysOfTheAngelDB`.
- Addon folder / `.toc` name `KeysOfTheAngel`; SavedVariables `KeysOfTheAngelDB` (account-wide).
- Plainsrunning spell ID `1299038`; stack count is the aura's `applications`; aura absent = 0 stacks.
- Target volume `x = clamp((s - 27) / 3, 0, 1)`. Song starts the first time `s` reaches 30 in a session.
- Song on channel `"Dialog"`: `Sound_DialogVolume = x * userMusic`; `Sound_MusicVolume = (1 - x) * userMusic`.
- Nothing is touched before the first trigger. Captured settings are restored on logout and after a crash.
- Song files: `media/song.mp3` or `media/song.ogg`, exactly one. Both or neither = corrupted: no sound, no settings
  touched, popup at every login.
- Tauren only (race ID 6). No settings UI, no slash commands. Guard every handler with `pcall`; check
  `issecretvalue` before comparing aura fields.
- Commit messages: plain conventional commits, **no Co-Authored-By lines**.
- Run tests: `export PATH="/c/Users/VenaGe/AppData/Local/Programs/LuaJIT/bin:$PATH"; luajit spec/runner.lua
  spec/unit/*_spec.lua` (Git Bash).

## Review Focus

1. **Player moves the Music slider mid-session** → the new value becomes their real setting, keeps scaling the song,
   and is what logout restores (test in Task 3: `adopts slider changes`).
2. **Game crashes after takeover** → next login restores the saved originals before anything else and clears them
   (Task 3: `restores leftover settings at start`).
3. **Logout or reload before the first trigger** → no CVar is ever written (Task 3: `shutdown before trigger touches
   nothing`).
4. **Song ends, or a stale/duplicate finish signal arrives** → exactly one copy keeps playing, including while
   silent (Task 4: `ignores finish for stale handles`, `never two copies`).
5. **Aura data goes secret mid-fade (combat, instances)** → volume holds, no errors (Task 3: `holds volume while
   stacks are secret`).

---

### Task 1: Probe round 2 (gating, needs the author in game)

Settles every "Verify first" item in the spec. **Stop after this task** and bring back to the author: no
song-end signal at all, faded volumes surviving a crash, or no way to detect a missing file.

**Files:**
- Modify: `D:\World of Warcraft\_classic_beta_\Interface\AddOns\KoaProbe\KoaProbe.lua` (throwaway, not in the repo)
- Create: `D:\...\AddOns\KoaProbe\sweep.ogg`: 60 s sine sweep 200 → 1000 Hz, so playback position is audible
  (`ffmpeg -f lavfi -i "aevalsrc=0.3*sin(2*PI*(200*t+(800/120)*t*t)):s=44100:d=60" -c:a libvorbis sweep.ogg`)
- Modify: `docs/wow-forever-addon-notes.md` (probe results section)

- [ ] **Step 1: Add probe commands** (each logs through the existing `out()`; keep the restore-on-login safety):
  - `finish`: play `sweep.ogg` on Dialog; log `SOUNDKIT_FINISHED` args with `GetTime()`; in parallel poll
    `C_Sound.IsPlaying(handle)` (if present) every 0.1 s and log when it turns false. Also log existence of
    `C_Sound`, `C_Sound.IsPlaying`, `StaticPopupDialogs`, `StaticPopup_Show`.
  - `exists`: `PlaySoundFile` + immediate `StopSound` on `test.ogg`, `nope.ogg`, `nope.mp3`; log `willPlay`/handle.
  - `zero`: play `sweep.ogg`, set `Sound_DialogVolume` 0 for 10 s, then restore (author listens: did the sweep
    resume at a higher pitch, i.e. keep its position?).
  - `musiczero`: set `Sound_MusicVolume` 0 for 30 s, then restore (does zone music come back?).
  - `persist`: set `Sound_DialogVolume` 0.5 and a flag; on `PLAYER_LOGOUT` restore the original; next login logs
    the value (`SetCVar` in logout persists?).
  - `crashset`: set `Sound_DialogVolume` 0.5 and `Sound_MusicVolume` 0.1 and leave them.
  - `play`: play `sweep.ogg`, store the handle in `KoaProbeDB.handle` (for the loading screen / reload checks).
- [ ] **Step 2: Author runs the session** (fully restart the client first; new file):
  `/koaprobe finish` (wait 65 s) → `/koaprobe exists` (note any audible blip) → `/koaprobe zero` →
  `/koaprobe musiczero` → `/koaprobe watch` while walking, mounting, dying, taking a taxi, in combat, in an instance
  → `/koaprobe fade Sound_DialogVolume Dialog` in combat → `/koaprobe play` then take a loading screen (portal or
  instance) → `/koaprobe play` then `/reload` → `/koaprobe persist` then log out and back in → `/koaprobe crashset`
  then kill `Wow.exe` in Task Manager and search `WTF\Config.wtf` for `Sound_DialogVolume` / `Sound_MusicVolume`.
- [ ] **Step 3: Read the log** from `WTF\Account\100089090#1\SavedVariables\KoaProbe.lua` (it resets each login, so
  read after each relog) and record every answer in the notes doc's probe section, replacing "Still open".
- [ ] **Step 4: Fix the decisions this task produces** in the notes doc (later tasks read them from there):
  - `FINISH_SIGNAL`: `"event"` (`SOUNDKIT_FINISHED`) or `"poll"` (`C_Sound.IsPlaying`).
  - `FILE_CHECK`: how `adapter.fileExists` works silently.
  - `FLOOR`: `0` if sound keeps position at 0 and zone music returns; else `0.001`.
  - `RELOAD_SURVIVES`: whether a sound survives `/reload` (then Task 4's leftover-handle step applies).
  - `LOAD_SCREEN`: whether a load stops the sound and whether that fires the finish signal.
  - Combat `SetCVar` works? Aura secret in combat/instances?
- [ ] **Step 5: Commit** `docs: record probe round 2 results`.

---

### Task 2: Test harness, volume math, CI tests

**Files:**
- Create: `spec/runner.lua` (copy verbatim from `E:\Projects\street-cred\spec\runner.lua`)
- Create: `spec/helpers/load.lua` (like StreetCred's: loads files in order, calling each with
  `("KeysOfTheAngel", ns)`, returns `ns`; `M.CORE = { "src/core/volume.lua", "src/core/engine.lua" }`, skip missing)
- Create: `src/core/volume.lua`, `spec/unit/volume_spec.lua`
- Modify: `.github/workflows/ci.yml` (add a `test` job: install `luajit` via apt, run the runner; lint args
  `src spec`), `.luacheckrc` (`files["spec/"] = { std = "+busted" }`; drop `SLASH_*` and `PlayMusic`/`StopMusic`;
  `globals = { "KeysOfTheAngelDB" }`)

**Interfaces:**
- Produces `ns.Volume`:
  - `Volume.target(stacks: number) -> number` in [0, 1]
  - `Volume.step(current, target, dt, upRate, downRate) -> number`: moves toward `target` by at most
    `upRate * dt` (rising) or `downRate * dt` (falling), never overshooting
  - `Volume.levels(x, userMusic, floor) -> dialog, music`: `max(x, floor) * userMusic`,
    `max(1 - x, floor) * userMusic`
  - Constants: `Volume.UP_RATE = 1 / 15`, `Volume.DOWN_RATE = 1 / 3`, `Volume.FIRST_RATE = 1` (per second).
    These make the rise continuous across 5 s stack steps (full volume exactly 5 s after 30 stacks), the fall track
    the 1 stack/s drain, and the first start a ~1 s crossfade.

- [ ] **Step 1: Write `spec/unit/volume_spec.lua`:**
  - `target`: `30 → 1`, `29 → 2/3` (near, 1e-9), `28 → 1/3`, `27 → 0`, `0 → 0`, `31 → 1`
  - `step rises by at most upRate*dt`: `step(0, 1, 0.1, 1/15, 1/3)` near `0.1/15`
  - `step falls by at most downRate*dt`: `step(1, 0, 0.1, 1/15, 1/3)` near `1 - 0.1/3`
  - `step never overshoots`: `step(0.99, 1, 1, 1, 1) == 1`; `step(0.01, 0, 1, 1, 1) == 0`
  - `levels`: `levels(1, 0.4, 0)` → `0.4, 0`; `levels(0, 0.4, 0)` → `0, 0.4`; `levels(0.5, 0.4, 0)` → `0.2, 0.2`;
    `levels(0, 0.4, 0.001)` → `0.0004, 0.4`
- [ ] **Step 2: Run tests**, expect failures (`ns.Volume` nil).
- [ ] **Step 3: Implement `src/core/volume.lua`** (exposes `ns.Volume`).
- [ ] **Step 4: Run tests**, expect all pass. Update CI/luacheck as listed.
- [ ] **Step 5: Commit** `feat: add volume math and test harness`.

---

### Task 3: Engine: trigger, fading, settings capture and restore

**Files:**
- Create: `src/core/engine.lua`, `spec/helpers/fake_adapter.lua`, `spec/unit/engine_spec.lua`

**Interfaces:**
- Consumes: `ns.Volume` (Task 2).
- Adapter contract (the fake and the real adapter implement exactly this):
  - `a.isTauren() -> boolean`
  - `a.stacks() -> number|nil, secret: boolean` (absent aura → `0, false`; secret → `nil, true`)
  - `a.getCVar(name) -> string|nil`, `a.setCVar(name, value)` (value is a number or `"0"`/`"1"`)
  - `a.fileExists(path) -> boolean`
  - `a.play(path) -> handle|nil` (always on `"Dialog"`), `a.stop(handle)`
  - `a.showCorruptPopup()`
  - `a.db`: the SavedVariables table (never nil; main.lua creates it)
  - `a.floor`: number (Task 1's `FLOOR`)
- Produces `ns.Engine`:
  - `Engine.new(adapter) -> engine`; `engine.state` is `"dormant" | "corrupt" | "waiting" | "active"`
  - `engine:start()`: restore leftover `db.saved` first; then race check (`"dormant"`); then `"waiting"`
    (file checks arrive in Task 5; until then `engine.songPath` is the `song.mp3` path)
  - `engine:tick(dt)`; `engine:shutdown()`; `engine:onSoundFinished(handle)` (Task 4)
  - `db.saved = { dialog = number, music = number, enableDialog = "0"|"1" }` while active, `nil` otherwise
- Fake adapter: `cvars` table (defaults `Sound_DialogVolume "1.0"`, `Sound_MusicVolume "0.4"`,
  `Sound_EnableDialog "1"`), `setCalls` log, `played` list of `{path, handle}`, `active` set of playing handles,
  `stopped` list, settable `stackCount`/`secret`/`tauren`/`files` (default: only the mp3 path exists), `popups`
  counter, `db = {}`, `floor = 0`.

- [ ] **Step 1: Write `spec/unit/engine_spec.lua`** (helper `run(engine, seconds)` ticks in 0.1 s steps):
  - `touches nothing before first trigger`: stacks 29 for 200 s → `#setCalls == 0`, `#played == 0`
  - `starts song at 30 stacks`: one `play`, `db.saved` same as `{dialog=1.0, music=0.4, enableDialog="1"}`
  - `first start crossfades over about a second`: after 0.5 s Dialog near 0.2, Music near 0.2 (tol 0.03); after
    1.1 s Dialog 0.4, Music 0
  - `fades out within about 3 s of stopping`: active at 30, then stacks drop 1/s → Dialog 0 by 3.2 s
  - `full volume 5 s after reaching 30 again`: from 27 rising 1 stack per 5 s → Dialog 0.4 within 5.2 s of 30
  - `keeps playing at volume 0`: active, stacks 0 for 60 s → `#stopped == 0`
  - `enables Dialog channel on takeover`: `Sound_EnableDialog "0"` before → `"1"` while active, `"0"` after shutdown
  - `adopts slider changes`: active, set `cvars.Sound_MusicVolume = "0.8"` externally → `db.saved.music == 0.8`,
    at 30 stacks Dialog 0.8; shutdown restores Music 0.8
  - `restores on shutdown`: originals written back, `db.saved == nil`
  - `restores leftover settings at start`: `db.saved = {dialog=0.7, music=0.3, enableDialog="0"}` before `start()`
    → first three `setCalls` restore those, `db.saved == nil`, state `"waiting"`
  - `shutdown before trigger touches nothing`: `#setCalls == 0`
  - `holds volume while stacks are secret`: active at 30, `secret = true`, 10 s → Dialog unchanged, no error
  - `dormant for non-Tauren`: `tauren = false`, stacks 30 → state `"dormant"`, no play, no setCalls
- [ ] **Step 2: Run tests**, expect failures.
- [ ] **Step 3: Implement `src/core/engine.lua`.** Slider detection: each tick compare `tonumber(getCVar(...))` with
  the value last written (tolerance 0.001); a difference on Music updates `userMusic`, on Dialog updates the saved
  `dialog` (restored at logout; the song still follows Music). Write `db.saved` the moment of takeover. Use
  `Volume.FIRST_RATE` for both directions until the first crossfade completes, then `UP_RATE`/`DOWN_RATE`.
- [ ] **Step 4: Run tests**, expect all pass; luacheck clean.
- [ ] **Step 5: Commit** `feat: add engine with fading and settings restore`.

---

### Task 4: Engine: looping and restarts

**Files:**
- Modify: `src/core/engine.lua`, `spec/helpers/fake_adapter.lua` (`finish(handle)` helper removes it from `active`
  and calls `engine:onSoundFinished(handle)`), `spec/unit/engine_spec.lua`

**Interfaces:**
- Consumes: Task 3's engine and adapter.
- Produces: `engine:onSoundFinished(handle)` restarts the song when `handle` is the current one; ignores others.
  If Task 1 found `LOAD_SCREEN` stops sound **without** a finish signal, also `engine:onLoadingScreenEnd()`, which
  stops the old handle and plays again. If `RELOAD_SURVIVES`, store the handle in `db.handle` and stop it in
  `start()`.

- [ ] **Step 1: Write tests:**
  - `restarts the song when it finishes`: active, `finish(h1)` → second `play`, new handle current
  - `restarts even while silent`: stacks 0, `finish(current)` → replayed
  - `ignores finish for stale handles`: `finish(oldHandle)` after a restart → no extra `play`
  - `never two copies`: after any sequence above, `#active == 1`
  - Conditional per Task 1: `restarts after a loading screen` / `stops a copy left over from reload`
- [ ] **Step 2: Run tests**, expect failures. **Step 3: Implement.** **Step 4: Run tests**, expect pass.
- [ ] **Step 5: Commit** `feat: loop the song and recover from restarts`.

---

### Task 5: Engine: song file detection and corrupted installs

**Files:**
- Modify: `src/core/engine.lua`, `spec/unit/engine_spec.lua`

**Interfaces:**
- Consumes: `a.fileExists`, `a.showCorruptPopup`.
- Produces: `start()` checks `"Interface\\AddOns\\" .. addonName .. "\\media\\song.mp3"` and `...song.ogg` **before**
  the race check (a broken install is reported on every character). Exactly one → `engine.songPath`; both or
  neither → state `"corrupt"`, one popup per `start()`.

- [ ] **Step 1: Write tests:**
  - `uses mp3 when only mp3 exists` / `uses ogg when only ogg exists`: `play` gets that path
  - `both files means corrupt`: state `"corrupt"`, `popups == 1`, stacks 30 for 60 s → no `play`, no `setCalls`
  - `no file means corrupt`: same assertions
  - `corrupt still restores leftover settings`: `db.saved` preset → restored even though corrupt
- [ ] **Step 2–4:** fail, implement, pass.
- [ ] **Step 5: Commit** `feat: detect corrupted song files`.

---

### Task 6: WoW layer, .toc, placeholder song, in-game test

**Files:**
- Create: `KeysOfTheAngel.toc` (repo root, so the junction works):
  `## Interface: 16001`, `## Title: Keys of the Angel`,
  `## Notes: Plays a song when Plainsrunning reaches full speed.`, `## Author: howk3n`,
  `## Version: @project-version@`, `## SavedVariables: KeysOfTheAngelDB`, then `src/core/volume.lua`,
  `src/core/engine.lua`, `src/wow/adapter.lua`, `src/wow/main.lua`
- Create: `src/wow/adapter.lua` (`ns.NewAdapter(db) -> adapter`), `src/wow/main.lua`
- Create: `media/song.mp3`: placeholder, a 90 s sine sweep 200 → 1000 Hz (same `aevalsrc` formula as Task 1 with
  `800/180` and `d=90`, encoded with `-c:a libmp3lame -q:a 4`); record its SHA-256 in
  `.github/placeholder-song.sha256`

**Interfaces:**
- Adapter implementation: `stacks` via `C_UnitAuras.GetPlayerAuraBySpellID(1299038)` (nil → 0; `issecretvalue` on
  `applications` → `nil, true`); `isTauren` = `select(3, UnitRace("player")) == 6`; `play` = `PlaySoundFile(path,
  "Dialog")` returning the handle only when `willPlay`; `fileExists` per Task 1's `FILE_CHECK`;
  `showCorruptPopup` via `StaticPopupDialogs["KEYSOFTHEANGEL_CORRUPT"]` (text from the spec, one OK button) or a
  plain frame if Task 1 found StaticPopup missing; `floor` from Task 1.
- main.lua: `ADDON_LOADED` (own name) → `KeysOfTheAngelDB = KeysOfTheAngelDB or {}`; `PLAYER_LOGIN` → build
  adapter + engine, `start()`, start a `C_Timer.NewTicker(0.1)` passing real elapsed time (`GetTime()` delta);
  `PLAYER_LOGOUT` → `shutdown()`; finish signal per Task 1 (`SOUNDKIT_FINISHED` or polling) →
  `onSoundFinished`. Every handler and tick wrapped in `pcall`; errors swallowed (no chat spam).

- [ ] **Step 1: Write the files**; `luajit -bl` each Lua file for syntax; tests and luacheck still pass.
- [ ] **Step 2: Link and restart:** `mklink /J` per `CLAUDE.md` (from `cmd`), full client restart, disable `KoaProbe`.
- [ ] **Step 3: Author's in-game checklist**, each must hold:
  - Nothing changes until 30 stacks; then the sweep starts and zone music fades out within ~1 s
  - Stop for 3 s → song silent, zone music back; run 15 s → song back at full, mid-sweep (not restarted)
  - Moving the Music slider changes the song's loudness; log out and in → sliders show the real values
  - Song loops after 90 s with at most a short pause
  - Second song file `media/song.ogg` (copy) + restart → popup, no sound; remove it → normal
  - A non-Tauren character hears nothing
- [ ] **Step 4: Commit** `feat: wire the addon into the game`.

---

### Task 7: README, LICENSE, packaging

**Files:**
- Create: `README.md`, `LICENSE` (MIT, `Copyright (c) 2026 howk3n`)
- Modify: `.pkgmeta` (add `spec` to `ignore`; `README.md` and `LICENSE` stay in the package)

- [ ] **Step 1: README** covers: what it does (30 stacks, fades between 27 and 30, crossfade); loudness follows the
  Music slider, plays even with game music off, a Music slider at 0 silences it; NPC voices go quiet while the song
  is faded down (Dialog channel); **warning:** Music and Dialog sliders move on their own while active, real values
  return on logout; swapping the song (replace with `song.mp3` or `song.ogg` so exactly one exists, full restart,
  re-copy after every update); the "damaged" popup means reinstall via the addon manager or delete the folder first;
  license MIT.
- [ ] **Step 2: Commit** `docs: add README and MIT license`.

---

### Task 8: Release workflow

**Files:**
- Create: `.github/workflows/release.yml`
- Modify: `KeysOfTheAngel.toc` (`## X-Curse-Project-ID: <id from the author>`)

- [ ] **Step 1: Check BigWigs packager supports Forever** (`## Interface: 16001` → CurseForge "Forever" flavor) in
  its README/issues. If it doesn't, stop and tell the author; fallback is uploading the packaged zip by hand.
- [ ] **Step 2: Write `release.yml`:** on push of tags `v*`; steps: checkout (`fetch-depth: 0`), **guard**: fail if
  `sha256sum media/song.mp3` matches `.github/placeholder-song.sha256`, or if `media/song.ogg` exists; run tests;
  `BigWigsMods/packager@v2` with `CF_API_KEY: ${{ secrets.CF_API_KEY }}`, `GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}`.
- [ ] **Step 3: Author steps** (walk them through): create the CurseForge project (Forever flavor, MIT), send the
  project ID, create an API token at CurseForge and save it as repository secret `CF_API_KEY` on GitHub.
- [ ] **Step 4: Commit** `ci: add CurseForge release workflow`.

---

### Task 9: First release (waits for the author's mp3)

- [ ] **Step 1:** Author's song replaces `media/song.mp3`. Rerun Task 6's in-game checklist with it.
- [ ] **Step 2: Commit** `feat: add the song`; push; confirm CI green.
- [ ] **Step 3:** With the author's go-ahead, `git tag v1.0.0 && git push origin v1.0.0`; confirm the workflow
  uploads and the file appears on CurseForge under Forever.
- [ ] **Step 4:** Remove `KoaProbe` and the old `SCProbe` from the AddOns folder (ask the author first).
