local addonName, ns = ...

local PLAINSRUNNING = 1299038
local TAUREN = 6
local CHANNEL = "Dialog"
local POPUP = "KEYSOFTHEANGEL_CORRUPT"

local function secret(v)
  return issecretvalue ~= nil and issecretvalue(v)
end

local function showCorruptPopup()
  StaticPopupDialogs[POPUP] = StaticPopupDialogs[POPUP] or {
    text = "Keys of the Angel is damaged. Please reinstall it: use your addon manager's reinstall option, or "
      .. "delete the " .. addonName .. " folder from Interface\\AddOns and install it again. Then restart the game.",
    button1 = OKAY,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }
  StaticPopup_Show(POPUP)
end

function ns.NewAdapter(db)
  local a = { db = db, floor = 0.001, showCorruptPopup = showCorruptPopup }

  function a.isTauren()
    return select(3, UnitRace("player")) == TAUREN
  end

  function a.stacks()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(PLAINSRUNNING)
    if aura == nil then return 0, false end
    if secret(aura) or secret(aura.applications) then return nil, true end
    return aura.applications, false
  end

  function a.getCVar(name) return GetCVar(name) end
  function a.setCVar(name, value) SetCVar(name, tostring(value)) end

  -- There is no file API; a missing file makes PlaySoundFile return no handle. Stopping in the same frame is silent.
  function a.fileExists(path)
    local willPlay, handle = PlaySoundFile(path, CHANNEL)
    if handle then StopSound(handle) end
    return (willPlay and handle) and true or false
  end

  function a.play(path)
    local willPlay, handle = PlaySoundFile(path, CHANNEL)
    if willPlay then return handle end
  end

  function a.stop(handle) StopSound(handle) end
  function a.isPlaying(handle) return C_Sound.IsPlaying(handle) == true end

  return a
end
