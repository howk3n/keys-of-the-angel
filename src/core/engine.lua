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
  if a.db.saved then
    restore(a, a.db.saved)
    a.db.saved = nil
  end
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
  self.written = {}
  self.current = 0
  self.firstFade = true
  self.handle = a.play(self.songPath)
  self.state = "active"
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

function Engine:write(name, key, value)
  local w = self.written
  if w[key] == nil or math.abs(w[key] - value) > WRITE_EPSILON then
    self.a.setCVar(name, value)
    w[key] = value
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
  if not self.handle then self.handle = self.a.play(self.songPath) end
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
  self.handle = self.a.play(self.songPath)
end

function Engine:shutdown()
  if self.state ~= "active" then return end
  self:adoptSliderChanges()
  restore(self.a, self.saved)
  self.a.db.saved = nil
end
