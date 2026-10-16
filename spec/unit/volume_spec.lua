local load = dofile("spec/helpers/load.lua")

describe("Volume", function()
  local Volume
  before_each(function() Volume = load.core().Volume end)

  describe("target", function()
    it("is full at 30 stacks", function() assert.equals(1, Volume.target(30)) end)
    it("is two thirds at 29 stacks", function() assert.near(2 / 3, Volume.target(29), 1e-9) end)
    it("is one third at 28 stacks", function() assert.near(1 / 3, Volume.target(28), 1e-9) end)
    it("is silent at 27 stacks", function() assert.equals(0, Volume.target(27)) end)
    it("is silent at 0 stacks", function() assert.equals(0, Volume.target(0)) end)
    it("clamps above 30 stacks", function() assert.equals(1, Volume.target(31)) end)
  end)

  describe("step", function()
    it("rises by at most upRate*dt", function()
      assert.near(0.1 / 15, Volume.step(0, 1, 0.1, 1 / 15, 1 / 3), 1e-9)
    end)
    it("falls by at most downRate*dt", function()
      assert.near(1 - 0.1 / 3, Volume.step(1, 0, 0.1, 1 / 15, 1 / 3), 1e-9)
    end)
    it("never overshoots rising", function() assert.equals(1, Volume.step(0.99, 1, 1, 1, 1)) end)
    it("never overshoots falling", function() assert.equals(0, Volume.step(0.01, 0, 1, 1, 1)) end)
  end)

  describe("levels", function()
    local function levels(x, music, floor)
      local d, m = Volume.levels(x, music, floor)
      return { d, m }
    end
    local function near2(expected, actual)
      assert.near(expected[1], actual[1], 1e-9)
      assert.near(expected[2], actual[2], 1e-9)
    end
    it("gives the song all of the music volume at full", function() near2({ 0.4, 0 }, levels(1, 0.4, 0)) end)
    it("gives game music all of it when silent", function() near2({ 0, 0.4 }, levels(0, 0.4, 0)) end)
    it("splits it halfway", function() near2({ 0.2, 0.2 }, levels(0.5, 0.4, 0)) end)
    it("never goes below the floor", function() near2({ 0.0004, 0.4 }, levels(0, 0.4, 0.001)) end)
  end)

  it("has the planned rates", function()
    assert.near(1 / 15, Volume.UP_RATE, 1e-12)
    assert.near(1 / 3, Volume.DOWN_RATE, 1e-12)
    assert.equals(1, Volume.FIRST_RATE)
  end)
end)
