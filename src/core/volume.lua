local _, ns = ...

local Volume = {}
ns.Volume = Volume

-- Rates are per second. Rising at 1/15 spreads each third-of-volume stack step across the 5 s until the next
-- stack, so the fade in is continuous; falling at 1/3 tracks the 1 stack/s drain.
Volume.UP_RATE = 1 / 15
Volume.DOWN_RATE = 1 / 3
Volume.FIRST_RATE = 1

local FADE_FROM, MAX_STACKS = 27, 30

function Volume.target(stacks)
  local x = (stacks - FADE_FROM) / (MAX_STACKS - FADE_FROM)
  if x < 0 then return 0 end
  if x > 1 then return 1 end
  return x
end

function Volume.step(current, target, dt, upRate, downRate)
  if target > current then
    return math.min(target, current + upRate * dt)
  end
  return math.max(target, current - downRate * dt)
end

function Volume.levels(x, userMusic, floor)
  return math.max(x, floor) * userMusic, math.max(1 - x, floor) * userMusic
end
