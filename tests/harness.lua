-- Runner mínimo de tests, sin LÖVE.
local harness = { tests = {}, passed = 0, failed = 0 }

function harness.test(name, fn)
  harness.tests[#harness.tests + 1] = { name = name, fn = fn }
end

local function fail(message, level)
  error(message, (level or 2) + 1)
end

function harness.assertEqual(actual, expected, message)
  if actual ~= expected then
    fail(string.format("%s: se esperaba %s, se obtuvo %s",
      message or "assertEqual", tostring(expected), tostring(actual)))
  end
end

function harness.assertNear(actual, expected, tolerance, message)
  if math.abs(actual - expected) > tolerance then
    fail(string.format("%s: se esperaba %s ± %s, se obtuvo %s",
      message or "assertNear", tostring(expected), tostring(tolerance), tostring(actual)))
  end
end

function harness.assertTrue(value, message)
  if not value then
    fail(message or "assertTrue")
  end
end

function harness.assertFalse(value, message)
  if value then
    fail(message or "assertFalse")
  end
end

function harness.assertLessOrEqual(actual, limit, message)
  if actual > limit then
    fail(string.format("%s: %s supera el límite %s",
      message or "assertLessOrEqual", tostring(actual), tostring(limit)))
  end
end

function harness.assertTableEqual(a, b, message)
  local function walk(x, y, path)
    if type(x) ~= type(y) then
      fail(string.format("%s: tipo distinto en %s (%s vs %s)",
        message or "assertTableEqual", path, type(x), type(y)))
    end
    if type(x) ~= "table" then
      if x ~= y then
        fail(string.format("%s: valor distinto en %s (%s vs %s)",
          message or "assertTableEqual", path, tostring(x), tostring(y)))
      end
      return
    end
    for key, value in pairs(x) do
      walk(value, y[key], path .. "." .. tostring(key))
    end
    for key in pairs(y) do
      if x[key] == nil then
        fail(string.format("%s: falta la clave %s", message or "assertTableEqual", path .. "." .. tostring(key)))
      end
    end
  end
  walk(a, b, "raíz")
end

function harness.run()
  local start = os.clock()
  for _, entry in ipairs(harness.tests) do
    local ok, err = pcall(entry.fn)
    if ok then
      harness.passed = harness.passed + 1
      io.write("  ok   " .. entry.name .. "\n")
    else
      harness.failed = harness.failed + 1
      io.write("  FAIL " .. entry.name .. "\n         " .. tostring(err) .. "\n")
    end
  end
  local elapsed = os.clock() - start
  io.write(string.format("\n%d tests: %d correctos, %d fallos (%.2f s)\n",
    #harness.tests, harness.passed, harness.failed, elapsed))
  if harness.failed > 0 then
    os.exit(1)
  end
end

return harness
