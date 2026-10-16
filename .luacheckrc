std = "lua51"
max_line_length = 120
exclude_files = { ".release/", "libs/", "docs/" }
ignore = { "212/_" } -- unused argument named "_"

-- Add each WoW API global the addon reads here.
read_globals = {
  "CreateFrame", "UIParent", "C_Timer", "C_UnitAuras", "GetUnitSpeed", "PlayMusic", "StopMusic", "PlaySoundFile",
  "StopSound", "InCombatLockdown", "IsMounted", "UnitOnTaxi", "issecretvalue", "Settings", "DEFAULT_CHAT_FRAME",
}
globals = { "KeysOfTheAngelDB", "SlashCmdList", "SLASH_KEYSOFTHEANGEL1" }
