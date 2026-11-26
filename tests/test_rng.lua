local rng = require("src.game.rng")

return function(t)
  t.test("misma semilla y mismo estado dan la misma secuencia", function()
    local a = rng.new(123456)
    local b = rng.new(123456)
    for i = 1, 10000 do
      t.assertEqual(rng.next(a), rng.next(b), "tirada " .. i)
    end
    t.assertEqual(a.count, b.count)
  end)

  t.test("el estado guardado reanuda la secuencia exactamente", function()
    local a = rng.new(98765)
    for _ = 1, 500 do
      rng.next(a)
    end
    local b = rng.new(a.seed, a.state, a.count)
    for i = 1, 500 do
      t.assertEqual(rng.next(a), rng.next(b), "reanudación " .. i)
    end
  end)

  t.test("next devuelve valores en [0, 1)", function()
    local r = rng.new(42)
    for _ = 1, 100000 do
      local value = rng.next(r)
      t.assertTrue(value >= 0 and value < 1, "fuera de rango: " .. tostring(value))
    end
  end)

  t.test("int respeta límites", function()
    local r = rng.new(7)
    local seen = {}
    for _ = 1, 20000 do
      local value = rng.int(r, 3, 7)
      t.assertTrue(value >= 3 and value <= 7)
      seen[value] = true
    end
    for i = 3, 7 do
      t.assertTrue(seen[i], "falta el valor " .. i)
    end
  end)

  t.test("weighted respeta los pesos", function()
    local r = rng.new(2024)
    local entries = {
      { value = "a", weight = 0.7 },
      { value = "b", weight = 0.2 },
      { value = "c", weight = 0.1 },
    }
    local counts = { a = 0, b = 0, c = 0 }
    for _ = 1, 100000 do
      local value = rng.weighted(r, entries)
      counts[value] = counts[value] + 1
    end
    t.assertNear(counts.a / 100000, 0.7, 0.01, "peso a")
    t.assertNear(counts.b / 100000, 0.2, 0.01, "peso b")
    t.assertNear(counts.c / 100000, 0.1, 0.01, "peso c")
  end)
end
