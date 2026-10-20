local addonName, ns = ...

local TICK = 0.1

local engine, lastTime

local function tick()
  local now = GetTime()
  local dt = now - lastTime
  lastTime = now
  engine:tick(dt)
end

local function login()
  engine = ns.Engine.new(ns.NewAdapter(KeysOfTheAngelDB))
  if not pcall(engine.start, engine) then
    engine.state = "off"
    return
  end
  lastTime = GetTime()
  C_Timer.NewTicker(TICK, function() pcall(tick) end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(_, event, arg1)
  pcall(function()
    if event == "ADDON_LOADED" and arg1 == addonName then
      KeysOfTheAngelDB = KeysOfTheAngelDB or {}
    elseif event == "PLAYER_LOGIN" then
      login()
    elseif event == "PLAYER_LOGOUT" and engine then
      engine:shutdown()
    end
  end)
end)
