std = "lua51"
max_line_length = 120
exclude_files = { ".release/", "libs/", "docs/", ".superpowers/" }
ignore = { "212/_" } -- unused argument named "_"

files["spec/"] = {
  globals = { "describe", "it", "before_each", "after_each", "assert", "arg" },
}

-- The WoW layer may use the game API; the core may not.
local wow = {
  "CreateFrame", "C_Timer", "C_UnitAuras", "C_Sound", "GetTime", "GetCVar", "SetCVar", "C_CVar", "PlaySoundFile",
  "StopSound", "UnitRace", "issecretvalue", "StaticPopup_Show", "UIParent", "OKAY",
}
files["src/wow/"] = { read_globals = wow, globals = { "KeysOfTheAngelDB", "StaticPopupDialogs" } }
