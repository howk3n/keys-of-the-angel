-- In-memory implementation of the engine's adapter contract (see src/core/engine.lua).
local M = {}

M.MP3 = "Interface\\AddOns\\KeysOfTheAngel\\media\\song.mp3"
M.OGG = "Interface\\AddOns\\KeysOfTheAngel\\media\\song.ogg"

function M.new()
  local a = {
    cvars = { Sound_DialogVolume = "1.0", Sound_MusicVolume = "0.4", Sound_EnableDialog = "1" },
    setCalls = {}, played = {}, active = {}, stopped = {},
    stackCount = 0, secret = false, tauren = true, files = { [M.MP3] = true },
    popups = 0, db = {}, floor = 0, nextHandle = 100,
  }
  function a.isTauren() return a.tauren end
  function a.stacks()
    if a.secret then return nil, true end
    return a.stackCount, false
  end
  function a.getCVar(name) return a.cvars[name] end
  function a.setCVar(name, value)
    a.cvars[name] = tostring(value)
    a.setCalls[#a.setCalls + 1] = { name = name, value = value }
  end
  function a.fileExists(path) return a.files[path] == true end
  function a.play(path)
    a.nextHandle = a.nextHandle + 1
    local h = a.nextHandle
    a.played[#a.played + 1] = { path = path, handle = h }
    a.active[h] = true
    return h
  end
  function a.stop(h)
    a.active[h] = nil
    a.stopped[#a.stopped + 1] = h
  end
  function a.showCorruptPopup() a.popups = a.popups + 1 end
  -- Simulates the game reporting that a sound ended.
  function a.finish(engine, h)
    a.active[h] = nil
    engine:onSoundFinished(h)
  end
  function a.activeCount()
    local n = 0
    for _ in pairs(a.active) do n = n + 1 end
    return n
  end
  function a.num(name) return tonumber(a.cvars[name]) end
  return a
end

return M
