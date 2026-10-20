local load = dofile("spec/helpers/load.lua")
local Fake = dofile("spec/helpers/fake_adapter.lua")

local DIALOG, MUSIC, ENABLE = "Sound_DialogVolume", "Sound_MusicVolume", "Sound_EnableDialog"

local function run(engine, seconds)
  for _ = 1, math.floor(seconds * 10 + 0.5) do engine:tick(0.1) end
end

describe("Engine", function()
  local ns, a, e
  before_each(function()
    ns = load.core()
    a = Fake.new()
    e = ns.Engine.new(a)
  end)

  local function activeAtFull()
    e:start()
    a.stackCount = 30
    run(e, 1.1)
  end

  it("touches nothing before first trigger", function()
    e:start()
    a.stackCount = 29
    run(e, 200)
    assert.equals(0, #a.setCalls)
    assert.equals(0, #a.played)
  end)

  it("starts song at 30 stacks", function()
    e:start()
    a.stackCount = 30
    run(e, 0.1)
    assert.equals(1, #a.played)
    assert.equals(Fake.MP3, a.played[1].path)
    assert.same({ dialog = 1.0, music = 0.4, enableDialog = "1" }, a.db.saved)
    assert.equals("active", e.state)
  end)

  it("first start crossfades over about a second", function()
    e:start()
    a.stackCount = 30
    run(e, 0.5)
    assert.near(0.2, a.num(DIALOG), 0.03)
    assert.near(0.2, a.num(MUSIC), 0.03)
    run(e, 0.6)
    assert.near(0.4, a.num(DIALOG), 1e-6)
    assert.near(0, a.num(MUSIC), 1e-6)
  end)

  it("fades out within about 3 s of the first stack lost", function()
    activeAtFull()
    a.stackCount = 29
    run(e, 1)
    a.stackCount = 28
    run(e, 1)
    a.stackCount = 27
    run(e, 1.2)
    assert.near(0, a.num(DIALOG), 1e-6)
    assert.near(0.4, a.num(MUSIC), 1e-6)
  end)

  it("reaches full volume 5 s after reaching 30 again", function()
    activeAtFull()
    a.stackCount = 27
    run(e, 5)
    assert.near(0, a.num(DIALOG), 1e-6)
    a.stackCount = 28
    run(e, 5)
    a.stackCount = 29
    run(e, 5)
    a.stackCount = 30
    run(e, 5.2)
    assert.near(0.4, a.num(DIALOG), 1e-6)
    assert.near(0, a.num(MUSIC), 1e-6)
  end)

  it("keeps playing at volume 0", function()
    activeAtFull()
    a.stackCount = 0
    run(e, 60)
    assert.equals(0, #a.stopped)
    assert.equals(1, a.activeCount())
  end)

  it("enables Dialog channel on takeover", function()
    a.cvars[ENABLE] = "0"
    activeAtFull()
    assert.equals("1", a.cvars[ENABLE])
    e:shutdown()
    assert.equals("0", a.cvars[ENABLE])
  end)

  it("adopts slider changes", function()
    activeAtFull()
    a.cvars[MUSIC] = "0.8"
    run(e, 0.1)
    assert.equals(0.8, a.db.saved.music)
    assert.near(0.8, a.num(DIALOG), 1e-6)
    e:shutdown()
    assert.near(0.8, a.num(MUSIC), 1e-6)
  end)

  it("does not mistake the game rounding volumes for a slider move", function()
    a.decimals = 2
    activeAtFull()
    a.stackCount = 27
    run(e, 5)
    a.stackCount = 30
    run(e, 20)
    assert.equals(0.4, a.db.saved.music)
    assert.equals(1.0, a.db.saved.dialog)
    assert.near(0.4, a.num(DIALOG), 0.01)
    e:shutdown()
    assert.near(0.4, a.num(MUSIC), 1e-6)
  end)

  it("restores on shutdown", function()
    activeAtFull()
    e:shutdown()
    assert.near(1.0, a.num(DIALOG), 1e-6)
    assert.near(0.4, a.num(MUSIC), 1e-6)
    assert.equals("1", a.cvars[ENABLE])
    assert.is_nil(a.db.saved)
  end)

  it("restores leftover settings at start", function()
    a.db.saved = { dialog = 0.7, music = 0.3, enableDialog = "0" }
    e:start()
    assert.same({ DIALOG, MUSIC, ENABLE }, { a.setCalls[1].name, a.setCalls[2].name, a.setCalls[3].name })
    assert.near(0.7, a.num(DIALOG), 1e-6)
    assert.near(0.3, a.num(MUSIC), 1e-6)
    assert.equals("0", a.cvars[ENABLE])
    assert.is_nil(a.db.saved)
    assert.equals("waiting", e.state)
  end)

  it("shutdown before trigger touches nothing", function()
    e:start()
    a.stackCount = 20
    run(e, 5)
    e:shutdown()
    assert.equals(0, #a.setCalls)
  end)

  it("holds volume while stacks are secret", function()
    activeAtFull()
    a.secret = true
    a.stackCount = 0
    run(e, 10)
    assert.near(0.4, a.num(DIALOG), 1e-6)
  end)

  it("does not trigger while stacks are secret", function()
    e:start()
    a.secret = true
    run(e, 10)
    assert.equals(0, #a.played)
  end)

  describe("looping", function()
    it("restarts the song when it finishes", function()
      activeAtFull()
      local h1 = a.played[1].handle
      a.finish(e, h1)
      assert.equals(2, #a.played)
      assert.equals(Fake.MP3, a.played[2].path)
      assert.equals(a.played[2].handle, e.handle)
    end)

    it("restarts even while silent", function()
      activeAtFull()
      a.stackCount = 0
      run(e, 10)
      a.finish(e, e.handle)
      assert.equals(2, #a.played)
    end)

    it("ignores finish for stale handles", function()
      activeAtFull()
      local h1 = a.played[1].handle
      a.finish(e, h1)
      e:onSoundFinished(h1)
      assert.equals(2, #a.played)
    end)

    it("never two copies", function()
      activeAtFull()
      local h1 = a.played[1].handle
      a.finish(e, h1)
      e:onSoundFinished(h1)
      a.finish(e, e.handle)
      run(e, 5)
      assert.equals(1, a.activeCount())
    end)

    it("retries on the next tick when play fails", function()
      activeAtFull()
      local play = a.play
      a.play = function() return nil end
      a.finish(e, e.handle)
      assert.is_nil(e.handle)
      a.play = play
      run(e, 0.1)
      assert.not_nil(e.handle)
      assert.equals(1, a.activeCount())
    end)

    it("restarts when the game stops the song", function()
      activeAtFull()
      a.active[e.handle] = nil
      run(e, 0.1)
      assert.equals(2, #a.played)
      assert.equals(1, a.activeCount())
    end)

    it("remembers the playing handle for after a reload", function()
      activeAtFull()
      a.finish(e, e.handle)
      assert.equals(e.handle, a.db.handle)
    end)

    it("stops a copy left over from a reload", function()
      a.db.handle = 55
      a.active[55] = true
      e:start()
      assert.same({ 55 }, a.stopped)
      assert.is_nil(a.db.handle)
      assert.equals(0, a.activeCount())
    end)

    it("stops the song on shutdown", function()
      activeAtFull()
      local h = e.handle
      e:shutdown()
      assert.same({ h }, a.stopped)
      assert.equals(0, a.activeCount())
    end)

    it("ignores finish signals before the first trigger", function()
      e:start()
      e:onSoundFinished(5)
      run(e, 1)
      assert.equals(0, #a.played)
    end)
  end)

  describe("song file", function()
    it("uses mp3 when only mp3 exists", function()
      activeAtFull()
      assert.equals(Fake.MP3, a.played[1].path)
    end)

    it("uses ogg when only ogg exists", function()
      a.files = { [Fake.OGG] = true }
      activeAtFull()
      assert.equals(Fake.OGG, a.played[1].path)
    end)

    local function assertCorrupt()
      e:start()
      assert.equals("corrupt", e.state)
      assert.equals(1, a.popups)
      a.stackCount = 30
      run(e, 60)
      e:onSoundFinished(101)
      e:shutdown()
      assert.equals(0, #a.played)
      assert.equals(0, #a.setCalls)
    end

    it("both files means corrupt", function()
      a.files = { [Fake.MP3] = true, [Fake.OGG] = true }
      assertCorrupt()
    end)

    it("no file means corrupt", function()
      a.files = {}
      assertCorrupt()
    end)

    it("corrupt still restores leftover settings", function()
      a.files = {}
      a.db.saved = { dialog = 0.7, music = 0.3, enableDialog = "1" }
      e:start()
      assert.equals("corrupt", e.state)
      assert.near(0.7, a.num(DIALOG), 1e-6)
      assert.is_nil(a.db.saved)
    end)

    it("waits for game sound before checking files", function()
      a.cvars.Sound_EnableAllSound = "0"
      e:start()
      a.stackCount = 30
      run(e, 5)
      assert.equals(0, a.popups)
      assert.equals(0, #a.played)
      a.cvars.Sound_EnableAllSound = "1"
      run(e, 1.2)
      assert.equals(0, a.popups)
      assert.equals(Fake.MP3, a.played[#a.played].path)
      assert.equals("active", e.state)
    end)

    it("reports a broken install once game sound is on", function()
      a.files = {}
      a.cvars.Sound_EnableAllSound = "0"
      e:start()
      assert.equals(0, a.popups)
      a.cvars.Sound_EnableAllSound = "1"
      run(e, 0.1)
      assert.equals(1, a.popups)
      assert.equals("corrupt", e.state)
    end)

    it("reports corruption on non-Tauren characters too", function()
      a.files = {}
      a.tauren = false
      e:start()
      assert.equals("corrupt", e.state)
      assert.equals(1, a.popups)
    end)
  end)

  it("dormant for non-Tauren", function()
    a.tauren = false
    e:start()
    a.stackCount = 30
    run(e, 10)
    assert.equals("dormant", e.state)
    assert.equals(0, #a.played)
    assert.equals(0, #a.setCalls)
  end)
end)
