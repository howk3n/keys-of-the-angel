# WoW Forever addon notes

Knowledge carried over from StreetCred (E:\Projects\street-cred), October 2026. "Verified" means it was checked on the
WoW Forever beta client; "Retail" means it is how modern Retail WoW behaves and still needs checking on Forever.

## Client facts (verified on the beta, build 1.60.1.70374)

| Item | Value |
|---|---|
| `.toc` interface line | `## Interface: 16001` |
| `WOW_PROJECT_ID` | `18` (`WOW_PROJECT_CAMELOT`) |
| Lua | 5.1 (no `goto`, no `//`, no integer division) |
| Engine | Modern, Retail-derived client. Midnight-era addon restrictions apply (see "Secret values") |
| Install folder | `D:\World of Warcraft\_classic_beta_\Interface\AddOns\` |
| Addon list | Not on the character-select screen: open the in-game menu (Esc) → AddOns |
| Player names | No realms. Every character has a primary and a secondary name; the pair is unique. `UnitFullName("player")` returns `(primary, secondary)` |
| Present APIs | `C_Timer`, `C_EventUtils.IsEventValid`, `Settings.RegisterCanvasLayoutCategory`, `issecretvalue`, `C_ChatInfo.*`, `UnitLevel`, `IsInInstance`, `GetInstanceInfo` |
| Present events | `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_REGEN_DISABLED/ENABLED`, `ADDON_RESTRICTION_STATE_CHANGED` |
| Addon messages | Over 255 bytes are reported as sent but silently dropped |

## Dev workflow

- **Link the repo into the game** instead of copying (Windows `cmd`, not Git Bash; the AddOns folder name must
  match the `.toc` file name):
  `mklink /J "D:\World of Warcraft\_classic_beta_\Interface\AddOns\KljuceviOdAndjela" "E:\Projects\kljucevi-od-andjela"`
- `/reload` picks up Lua and `.toc` edits. **New files** (Lua added to the `.toc`, or new sound files) need a full
  client restart before the game can see them (Retail behavior).
- LuaJIT for running Lua outside the game: `C:\Users\VenaGe\AppData\Local\Programs\LuaJIT\bin` (not on PATH in
  Claude's shell; prefix with `export PATH="/c/Users/VenaGe/AppData/Local/Programs/LuaJIT/bin:$PATH";`).
- Lint (luacheck) runs in CI only; there is no local install.
- **Probe before you build.** When an API's behavior on Forever is unknown, write a throwaway probe addon that prints
  what the client actually returns, run it in game, and paste the chat output back. Reference probe:
  `docs/reference/SCProbe.lua` (checks which APIs/events exist, prints results with a colored prefix, and keeps a log
  in SavedVariables). Delete probes from the AddOns folder when done.

## Patterns that worked

- **Addon scope:** every file starts with `local addonName, ns = ...`; share code through `ns`, create no globals
  except SavedVariables and `SLASH_*` / `SlashCmdList` entries.
- **Startup:** `ADDON_LOADED` (filter on `name == addonName`) is the place to read and migrate SavedVariables. Do
  real setup at `PLAYER_LOGIN`. Some data (our own name, for example) can still be missing then: retry on
  `PLAYER_ENTERING_WORLD` and give up after a few tries.
- **Guard every script and event handler** with `pcall` so one bug doesn't spam Lua errors or kill the addon; print
  errors only in a debug mode.
- **Settings panel:** `Settings.RegisterCanvasLayoutCategory(panel, "Name")` then `Settings.RegisterAddOnCategory`.
  Checkboxes: `CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")`, label via `cb.Text or cb.text`.
- **Saved data:** `## SavedVariables:` is account-wide, `## SavedVariablesPerCharacter:` is per character. Keep a
  schema version field and migrate on load.
- **Timers:** `C_Timer.After(sec, fn)` and `C_Timer.NewTicker(sec, fn)`. Prefer a ticker of 0.1–0.25 s or an
  `OnUpdate` with an elapsed-time throttle over per-frame work.
- **Packaging:** BigWigs packager with `.pkgmeta`; `## Version: @project-version@` in the `.toc`; code between
  `--@debug@` and `--@end-debug@` is stripped from release builds (useful for dev-only shortcuts).

## Pitfalls

- **Secret values (Midnight restrictions):** some API results can be "secret" (opaque) in restricted contexts such as
  combat or instances. Check with `issecretvalue(v)` **before** comparing or doing arithmetic on a value, or the
  comparison itself errors. Unit names were not secret in the open world; aura and combat data inside instances or
  combat is unverified.
- **Combat lockdown:** protected actions (showing/moving secure frames, some settings) fail in combat. Check
  `InCombatLockdown()` and defer to `PLAYER_REGEN_ENABLED`.
- **`string.format("%d", n)`** can overflow above ~2.1 billion on Windows builds (32-bit C `long`); use `"%.0f"` for
  large integers.
- **APIs that "succeed" but do nothing:** check return values, not only `pcall` success (the 300-byte addon message
  case above).
- Some Retail globals are gone or moved (for example `GetLootMethod` → `C_PartyInfo.GetLootMethod`). Check with the
  probe before relying on one.

## Kljucevi od Andjela probe results (verified on the beta, build 1.60.1.70425, October 2026)

Probe: `KoaProbe` (throwaway, lived in the AddOns folder).

- **Plainsrunning** is a helpful aura on the player: name `Plainsrunning`, spell ID `1299038`, `duration` 0. Read it
  with `C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")` or `C_UnitAuras.GetPlayerAuraBySpellID(1299038)`.
  `UnitAura` and `UnitBuff` are **missing**.
- **Stacks:** +1 every 5 s of running, max **30** (full speed after 150 s). Standing still drains **1 stack per
  second**. At 0 stacks the aura is gone. `applications` and `points[1]` both equal the stack count.
- **Speed:** `GetUnitSpeed("player")` returns `current, run, flight, swim`. Each stack adds 1% to run speed:
  7.00 at 0 stacks, 9.10 at 30. `current` is 0 when standing still while `run` keeps the buffed value.
- **Secret values:** speed and aura fields were **not** secret in the open world, out of combat. Combat and
  instances are untested.
- **Sound channels:** `PlaySoundFile(path, channel)` returned `willPlay true` for `Master`, `Music`, `SFX`,
  `Ambience`, `Dialog`, `Talking Head` and the made-up `TalkingHead`, so unknown channel names are silently
  accepted (probably rerouted). `Talking Head` has **no** volume CVar (`Sound_TalkingHeadVolume` and
  `Sound_EnableTalkingHead` return nil), so it can't be faded.
- **Fading:** `SetCVar` on `Sound_DialogVolume`, `Sound_AmbienceVolume` or `Sound_MusicVolume` in 0.1 s steps
  smoothly fades sounds that are already playing (out of combat, no errors).
- Defaults seen: `Sound_MusicVolume` 0.4, `Sound_AmbienceVolume` 0.6, `Sound_DialogVolume` 1.0, others 1.0.
- `C_Console.GetAllCommands` and `Enum.SoundChannel` are **missing**.
- Supported audio formats (Retail, not re-checked): `.ogg` and `.mp3` inside the addon folder.

Still open: secret values in combat and instances; whether sounds survive loading screens; aura behavior when
walking, mounting, dying or on a taxi; `PlaySoundFile` looping (Retail: it doesn't, so a loop needs the track
length and a timer).
