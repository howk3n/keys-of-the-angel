-- Loads addon source files into one namespace table, exactly as WoW does:
-- every file is called with (addonName, ns). Files that don't exist yet are skipped.
local M = {}

M.CORE = {
  "src/core/volume.lua",
  "src/core/engine.lua",
}

local function exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

function M.files(list)
  local ns = {}
  for _, path in ipairs(list) do
    if exists(path) then
      local chunk = assert(loadfile(path))
      chunk("KeysOfTheAngel", ns)
    end
  end
  return ns
end

function M.core()
  return M.files(M.CORE)
end

return M
