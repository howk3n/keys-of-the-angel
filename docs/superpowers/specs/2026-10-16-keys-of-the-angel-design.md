# Keys of the Angel: design

Date: 2026-10-16. Status: awaiting author approval.

## Intent

A public World of Warcraft: Forever addon for Tauren players. When the Tauren Plainsrunning passive builds to full
speed, the author's own original song starts playing and crossfades with the game's music; as the player slows, the
song fades out and the zone music comes back. It is a fun, flavor addon: the joy is the song kicking in mid-sprint, so
it must feel seamless and need no setup.

The song is the author's original work, so it ships inside the addon and the addon can be published on CurseForge.

## Goals

- Song starts the first time the player reaches 30 Plainsrunning stacks in a session, then follows the stack count.
- Song volume and game music volume crossfade smoothly with no audible steps.
- Any song file loops fully (start to finish, no cut-off, at most a short pause before it restarts) whatever its
  length, including a file a player swaps in.
- The player's own sound settings are never left changed: not after logout, not after a crash.
- Works out of the box: install, play a Tauren, run.

## Non-goals

- No settings panel, no options, no slash commands for players. To turn it off, players disable the addon in the
  AddOns list.
- No song picker or in-game import. Swapping the song is a file replacement described in the README.
- Nothing for non-Tauren characters.

## Anti-goals (failure even if it technically works)

- The player's Music or Dialog volume left wrong after logout or a crash.
- Audible stepping, clicks or abrupt cuts in volume during normal play.
- A swapped-in song that gets cut off, or pauses longer than about a quarter second before looping.
- Lua error spam, or two copies of the song playing at once.
- Bundling any music the author doesn't hold the rights to.

## Verified facts this design rests on

See `docs/wow-forever-addon-notes.md`, section "Keys of the Angel probe results". In short:

- Plainsrunning is a player aura, spell ID `1299038`. `applications` is the stack count, 0 to 30. No aura means 0.
- Stacks build +1 per 5 s of running (30 stacks after 150 s) and drain 1 per second standing still.
- `PlaySoundFile(path, "Dialog")` plays an addon file; changing `Sound_DialogVolume` and `Sound_MusicVolume` with
  `SetCVar` in 0.1 s steps fades already-playing sound smoothly, out of combat.
- `Talking Head` has no volume CVar, so it is not usable. `UnitAura`/`UnitBuff` are missing; use `C_UnitAuras`.

## Behavior

### The volume rule (decided by the author)

Let `s` be the current Plainsrunning stack count (0 when the aura is absent).

- **Before the first trigger** in a session the addon does nothing audible and touches no settings.
- **First trigger:** the first time `s` reaches 30 in a session, the song starts.
- **Target song volume** `x = clamp((s - 27) / 3, 0, 1)`: 30 stacks = 100%, 29 ≈ 67%, 28 ≈ 33%, 27 or fewer = 0%.
- **Glide:** the actual volume moves smoothly toward the target instead of jumping a third per stack.
- **After the first trigger** the song never stops for the rest of the session. Below 27 stacks it keeps playing at
  volume 0, so when stacks climb back it fades in mid-song, wherever the song is.
- **Crossfade:** game music plays at `(1 - x)` of the player's own music volume.
- **No grace period** (author's decision): the song is special, only for maximum and near-maximum speed. Standing
  still drains 1 stack per second, so a 3-second stop at full speed fades it out, and it takes 15 s of running
  (27 → 30) to come back. That is intended.
- **Session** means since login or the last UI reload. After a reload the player must reach 30 stacks again.

### Sound mechanics (decided with the author)

- The song is treated as music: its full volume follows the player's **Music** slider (author's decision), so at full
  speed it is exactly as loud as zone music was.
- It plays on the **Dialog** channel, so it can fade separately: `Sound_DialogVolume = x * userMusic`.
- Game music stays on the **Music** channel: `Sound_MusicVolume = (1 - x) * userMusic`.
- `userDialog` and `userMusic` are the player's real settings, captured before the addon first changes them.
- Accepted side effect (author approved): while the song is faded down, all other Dialog sounds (NPC voice lines and
  greetings) are quiet too.

### Restoring settings

- The captured values (`userDialog`, `userMusic`, and the Dialog enable toggle) are saved in SavedVariables the
  moment the addon takes over.
- On logout the addon writes them back.
- On login, if saved values are still present (a crash or forced quit skipped the logout), restore them before
  anything else.
- If the player moves the Music or Dialog slider while the addon is in control, treat the new value as their new real
  setting (my call).
- The addon keeps fading even while the Sound settings panel is open (author's decision), so the sliders show the
  faded values. The README warns about this: the sliders move on their own while the addon is active, and the real
  values come back on logout.
- Caveat: WoW writes SavedVariables only on logout or `/reload`, never on a crash, so the crash path only helps if a
  reload happened after takeover. Whether a crash leaves faded volumes behind depends on when the client writes sound
  CVars to `WTF\Config.wtf`. That is a gating probe (see "Verify first"); if faded values survive a crash, stop and
  bring it back to the author before building around it.

### Never quite zero (my call)

If the probe shows that volume 0 stops a playing sound, or that zone music doesn't come back after Music volume sits
at 0, fade to a tiny inaudible floor (for example 0.1% of the player's setting) instead of exactly 0.

### Looping

Every song file must loop fully. The addon must know when the song finishes, with no length typed in by anyone.
Candidate mechanisms, to be verified on Forever (see "Verify first"):

1. The `SOUNDKIT_FINISHED` event (Retail fires it with the sound handle when a sound ends).
2. Polling `C_Sound.IsPlaying(handle)` if that API exists.

The author accepts a short pause at the loop point (up to about a quarter second), so restarting the song when the
end is detected is fine; no gapless trickery is needed.

If neither works, stop and bring it back to the author. A length typed into a file is **not** an acceptable fallback
(the author ruled it out).

### Unusual situations (my calls, author reviewed)

- **Mounting, taxis, death, swimming:** the song follows whatever the Plainsrunning aura does. Aura gone = 0 stacks =
  fade out; it fades back in as stacks return.
- **Combat and instances:** if the aura or its fields come back secret (`issecretvalue`), hold the current volume
  until readable values return. No errors, no sudden cut.
- **Loading screens:** if the game stops the song during a load, restart it quietly at the volume the current stacks
  call for (it restarts from the beginning; there is no seek).
- **Non-Tauren characters:** the addon stays dormant (race ID 6 is Tauren).
- **Game music turned off** (`Sound_EnableMusic` 0, the "Enable Music" checkbox or Ctrl+M): the song **still plays**
  at the Music slider level (author's decision: installing the addon is the choice to hear the song). Zone music stays
  off. Only a Music slider at 0 silences the song; the README says so.
- **Dialog channel turned off** (`Sound_EnableDialog` 0): by the same logic, turn it on while the addon controls the
  channel and restore it with the other settings (my call). While in control, the player's own Dialog slider is
  ignored; NPC voices play at the song's current level.
- **All sound off** (`Sound_EnableAllSound` 0 or Master at 0): respect it; nothing plays.
- **First start crossfade:** at the first trigger, music fades out and the song in over about a second rather than
  cutting instantly (my call).

## The song file

- Bundled song: the author's original, as an `.mp3`, so `.mp3` must work. Until the author supplies it, build and test
  with a placeholder tone.
- Location and name: `media/song.mp3` or `media/song.ogg`. Both formats must be supported (author's decision), which
  relies on Forever letting the addon tell a missing file apart (see "Verify first"; if it can't, bring it back to the
  author).
- **Both present means a corrupted install** (author's decision): if both `song.mp3` and `song.ogg` exist, the addon
  does not work at all (plays nothing, touches no settings) and shows a popup at every login until fixed, roughly:
  "Keys of the Angel is damaged. Please reinstall it: use your addon manager's reinstall option, or delete the
  `KeysOfTheAngel` folder from `Interface\AddOns` and install it again. Then restart the game." It does not explain
  which file to delete. (A manual unzip over the old folder would not remove the extra file, hence the wording.)
- **Neither present** is treated the same way: corrupted, same popup (my call).
- The addon can only check these two names; it cannot list or delete files. The README's swap instructions say to
  replace the file so only one song file exists.
- **README instructions for swapping** (no other user-facing configuration exists):
  1. Replace the file in the addon's `media` folder with yours, same name.
  2. Fully restart the game (WoW only sees new files after a restart).
  3. Updating the addon puts the original song back; re-copy yours after each update.
  4. The song's loudness follows the Music slider (even with game music turned off); a Music slider at 0 silences it.

## Verify first (probe before building)

Run a throwaway probe like `KoaProbe` (still in the AddOns folder) and record results in the notes doc:

1. `SOUNDKIT_FINISHED` exists and fires for `PlaySoundFile` handles; or `C_Sound.IsPlaying` exists and works.
2. `PlaySoundFile` on a missing file: does `willPlay` come back false/nil? Can a file's existence be checked at
   startup without an audible blip (e.g. play and `StopSound` in the same frame)?
3. Does a `PlaySoundFile` sound survive a loading screen? A `/reload`? (If it survives a reload, the addon must stop
   the old copy, e.g. by saving the handle in SavedVariables, to avoid two copies.)
4. Are aura fields or `GetUnitSpeed` secret in combat and in instances?
5. Aura behavior when walking, mounting, dying, on a taxi.
6. Does a `SetCVar` made in `PLAYER_LOGOUT` persist to the next session?
7. Does `SetCVar` on sound CVars still work in combat?
8. **Gating:** kill the client (Task Manager) mid-fade, then inspect `WTF\Config.wtf`: did the faded
   `Sound_DialogVolume`/`Sound_MusicVolume` values get written?
9. Does a sound keep playing (and keep its position) at `Sound_DialogVolume` 0? Does zone music return when
   `Sound_MusicVolume` rises after sitting at 0 for a while?

Any answer that breaks a goal above goes back to the author before building around it.

## Constraints

- WoW: Forever, `## Interface: 16001`, Lua 5.1. Conventions in `CLAUDE.md` (addon scope via `local addonName, ns`,
  `pcall`-guarded handlers, `issecretvalue` checks, lines ≤ 120, luacheck in CI).
- Addon folder and `.toc` name: `KeysOfTheAngel`. SavedVariables: `KeysOfTheAngelDB` (account-wide).
- Packaging: BigWigs packager via the existing `.pkgmeta`; published on CurseForge.

## License

MIT for the whole repository, the song included (author's decision: no separate song rights). A `LICENSE` file at
the root, copyright holder `howk3n` (my call, from the GitHub account; the author may prefer a real name).

## Scope of the work

The work runs all the way to a public CurseForge release: the working addon, the README, and a tag-triggered release
workflow. The first release waits for the author's song file; nothing ships with the placeholder tone.

- **CurseForge only** (author's decision), in its "Forever" game flavor (it exists: thousands of projects tagged for
  client 1.60.1).
- Pushing a tag like `v1.0.0` runs a GitHub Actions workflow with the BigWigs packager, which uploads to CurseForge.
- The author creates the CurseForge project, supplies its project ID (for `## X-Curse-Project-ID` in the `.toc`), and
  stores a CurseForge API token as a GitHub repository secret.
- First release `v1.0.0`, after the real mp3 is in and an in-game test passes.
- Repository: https://github.com/howk3n/keys-of-the-angel

## Left to the builder

- The exact glide (rate or easing), as long as there are no audible steps, full volume arrives within about 5 s of
  reaching 30 stacks, and slowing down is heard within about a second.
- Update cadence (ticker vs. `UNIT_AURA`), file layout, and whether a debug-only slash command is useful (strip it
  from releases with `--@debug@`).
- Whether to unit-test the volume rule and state logic with StreetCred's `spec/runner.lua` (it's real logic, so
  likely yes).
- README wording.
- Cleaning leftovers from earlier ideas, such as `PlayMusic`/`StopMusic` in `.luacheckrc`.
