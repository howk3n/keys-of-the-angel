# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

Kljucevi od Andjela is a World of Warcraft: Forever addon (`## Interface: 16001`, Lua 5.1). It plays a music track
on a loop when the Tauren Plainsrunning passive reaches maximum speed, and stops when speed decays below 75% of
maximum.

WoW Forever knowledge (verified client facts, dev workflow, patterns, pitfalls, open questions):
`docs/wow-forever-addon-notes.md`. Read it before touching addon code. Reference probe addon:
`docs/reference/SCProbe.lua`.

## Install for testing

```
mklink /J "D:\World of Warcraft\_classic_beta_\Interface\AddOns\KljuceviOdAndjela" "E:\Projects\kljucevi-od-andjela"
```

Run from Windows `cmd`. `/reload` for code changes; restart the client after adding new files (Lua or audio).

## Conventions

- Every Lua file starts with `local addonName, ns = ...`; no globals except SavedVariables and slash commands.
- When an API's behavior on Forever is unknown, probe it in game first; don't guess from Retail docs.
- Check `issecretvalue` before comparing values that may be secret; guard event and script handlers with `pcall`.
- Keep it simple: this is a small addon. Add a test runner only if real logic appears (StreetCred's vendored
  `spec/runner.lua` can be copied).
- Lines ≤ 120 characters. Lint (luacheck) runs in CI.
- No comments unless the WHY is non-obvious.
- Commit messages: plain conventional commits, no Co-Authored-By lines.
