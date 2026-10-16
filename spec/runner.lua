-- Minimal busted-style test runner for Lua 5.1 / LuaJIT.
-- Usage: luajit spec/runner.lua spec/unit/*_spec.lua spec/sim/*_spec.lua
local passed, failed, failures = 0, 0, {}
local stack = {}

local function label(name)
  local parts = {}
  for _, block in ipairs(stack) do parts[#parts + 1] = block.name end
  parts[#parts + 1] = name
  return table.concat(parts, " > ")
end

function describe(name, fn)
  stack[#stack + 1] = { name = name, before = {}, after = {} }
  fn()
  stack[#stack] = nil
end

function before_each(fn) table.insert(stack[#stack].before, fn) end
function after_each(fn) table.insert(stack[#stack].after, fn) end

function it(name, fn)
  local ok, err = pcall(function()
    for _, block in ipairs(stack) do
      for _, b in ipairs(block.before) do b() end
    end
    fn()
  end)
  for i = #stack, 1, -1 do
    for _, a in ipairs(stack[i].after) do
      local aok, aerr = pcall(a)
      if not aok then
        failed = failed + 1
        failures[#failures + 1] = label(name) .. " (after_each)\n    " .. tostring(aerr)
      end
    end
  end
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    failures[#failures + 1] = label(name) .. "\n    " .. tostring(err)
  end
end

local function show(v, depth)
  depth = depth or 0
  if type(v) == "string" then return string.format("%q", v) end
  if type(v) ~= "table" or depth > 3 then return tostring(v) end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local out = {}
  for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. show(v[k], depth + 1) end
  return "{" .. table.concat(out, ", ") .. "}"
end

local function deepEqual(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

local A = {}
function A.equals(expected, actual)
  if expected ~= actual then error("expected " .. show(expected) .. " but got " .. show(actual), 2) end
end
function A.same(expected, actual)
  if not deepEqual(expected, actual) then
    error("expected " .. show(expected) .. "\n    but got  " .. show(actual), 2)
  end
end
function A.is_true(v) if v ~= true then error("expected true but got " .. show(v), 2) end end
function A.is_false(v) if v ~= false then error("expected false but got " .. show(v), 2) end end
function A.is_nil(v) if v ~= nil then error("expected nil but got " .. show(v), 2) end end
function A.not_nil(v) if v == nil then error("expected a value but got nil", 2) end end
function A.near(expected, actual, tol)
  if type(actual) ~= "number" or math.abs(expected - actual) > tol then
    error("expected " .. show(expected) .. " +/- " .. tol .. " but got " .. show(actual), 2)
  end
end
function A.has_error(fn)
  if pcall(fn) then error("expected an error but none was raised", 2) end
end
assert = setmetatable(A, {
  __call = function(_, v, msg, ...)
    if not v then error(msg or "assertion failed", 2) end
    return v, msg, ...
  end,
})

for _, path in ipairs(arg) do
  local chunk, loadErr = loadfile(path)
  if not chunk then
    failed = failed + 1
    failures[#failures + 1] = path .. "\n    " .. tostring(loadErr)
  else
    stack = { { name = path, before = {}, after = {} } }
    local ok, err = pcall(chunk)
    if not ok then
      failed = failed + 1
      failures[#failures + 1] = path .. " (top level)\n    " .. tostring(err)
    end
  end
end

for _, f in ipairs(failures) do print("FAIL " .. f) end
print(string.format("%d passed, %d failed", passed, failed))
if passed + failed == 0 then
  print("no tests ran: check the spec paths passed to the runner")
  os.exit(1)
end
os.exit(failed == 0 and 0 or 1)
