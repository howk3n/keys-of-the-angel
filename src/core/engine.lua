local addonName, ns = ...

local Volume = ns.Volume

local Engine = {}
Engine.__index = Engine
ns.Engine = Engine

local DIALOG, MUSIC, ENABLE_DIALOG = "Sound_DialogVolume", "Sound_MusicVolume", "Sound_EnableDialog"
local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\media\\"
local TRIGGER_STACKS = 30
-- A slider moved by the player differs from what we last wrote by more than this.
local SLIDER_TOLERANCE = 0.001
local WRITE_EPSILON = 1e-4

function Engine.new(adapter)
  return setmetatable({ a = adapter, state = "waiting", current = 0, songPath = MEDIA .. "song.mp3" }, Engine)
end

local function restore(a, saved)
  a.setCVar(DIALOG, saved.dialog)
  a.setCVar(MUSIC, saved.music)
  a.setCVar(ENABLE_DIALOG, saved.enableDialog)
end

function Engine:start()
  local a = self.a
  -- A sound keeps playing through /reload, so the previous session's copy is still running.
  if a.db.handle then
    a.stop(a.db.handle)
    a.db.handle = nil
  end
  if a.db.saved then
    restore(a, a.db.saved)
    a.db.saved = nil
  end
  local mp3, ogg = MEDIA .. "song.mp3", MEDIA .. "song.ogg"
  local hasMp3, hasOgg = a.fileExists(mp3), a.fileExists(ogg)
  if hasMp3 == hasOgg then
    self.state = "corrupt"
    a.showCorruptPopup()
    return
  end
  self.songPath = hasMp3 and mp3 or ogg
  if not a.isTauren() then
    self.state = "dormant"
    return
  end
  self.state = "waiting"
end

function Engine:readStacks()
  local stacks, secret = self.a.stacks()
  if secret or type(stacks) ~= "number" then return nil end
  return stacks
end

function Engine:takeOver()
  local a = self.a
  self.saved = {
    dialog = tonumber(a.getCVar(DIALOG)) or 1,
    music = tonumber(a.getCVar(MUSIC)) or 0.4,
    enableDialog = a.getCVar(ENABLE_DIALOG) or "1",
  }
  a.db.saved = self.saved
  a.setCVar(ENABLE_DIALOG, "1")
  self.written, self.asked = {}, {}
  self.current = 0
  self.firstFade = true
  self:play()
  self.state = "active"
end

function Engine:play()
  self.handle = self.a.play(self.songPath)
  self.a.db.handle = self.handle
end

function Engine:adoptSliderChanges()
  local a, w = self.a, self.written
  local music, dialog = tonumber(a.getCVar(MUSIC)), tonumber(a.getCVar(DIALOG))
  if w.music and music and math.abs(music - w.music) > SLIDER_TOLERANCE then
    self.saved.music = music
  end
  if w.dialog and dialog and math.abs(dialog - w.dialog) > SLIDER_TOLERANCE then
    self.saved.dialog = dialog
  end
end

-- The game rounds stored volumes, so remember what it reports back, not what we asked for; otherwise the rounding
-- looks like a slider move.
function Engine:write(name, key, value)
  local asked, w = self.asked, self.written
  if asked[key] == nil or math.abs(asked[key] - value) > WRITE_EPSILON then
    self.a.setCVar(name, value)
    asked[key] = value
    w[key] = tonumber(self.a.getCVar(name)) or value
  end
end

function Engine:apply()
  local dialog, music = Volume.levels(self.current, self.saved.music, self.a.floor)
  self:write(DIALOG, "dialog", dialog)
  self:write(MUSIC, "music", music)
end

function Engine:tick(dt)
  if self.state == "waiting" then
    local stacks = self:readStacks()
    if not stacks or stacks < TRIGGER_STACKS then return end
    self:takeOver()
  end
  if self.state ~= "active" then return end
  if not self.handle then
    self:play()
  elseif not self.a.isPlaying(self.handle) then
    self:onSoundFinished(self.handle)
  end
  self:adoptSliderChanges()
  local stacks = self:readStacks()
  if stacks then
    local target = Volume.target(stacks)
    if self.firstFade and target < self.current then self.firstFade = false end
    local up, down = Volume.UP_RATE, Volume.DOWN_RATE
    if self.firstFade then up, down = Volume.FIRST_RATE, Volume.FIRST_RATE end
    self.current = Volume.step(self.current, target, dt, up, down)
    if self.current >= 1 then self.firstFade = false end
  end
  self:apply()
end

function Engine:onSoundFinished(handle)
  if self.state ~= "active" or handle == nil or handle ~= self.handle then return end
  self:play()
end

function Engine:shutdown()
  if self.state ~= "active" then return end
  if self.handle then self.a.stop(self.handle) end
  self:adoptSliderChanges()
  restore(self.a, self.saved)
  self.a.db.saved = nil
end
