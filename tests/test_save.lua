local config = require("src.game.config")
local state = require("src.game.state")
local save = require("src.game.save")

local function hatchOne(s, now)
  local egg = { id = s.nextEggId, kind = "nido", createdAt = now }
  s.nextEggId = s.nextEggId + 1
  local reveal = state.rollNestReveal(s, egg, now)
  if reveal.pendingSpecies then
    local ok = state.chooseSpecies(s, reveal.id, reveal.pendingSpecies[1])
    assert(ok)
  end
  state.dismissReveal(s, reveal.id)
  return reveal
end

local function hatchMany(s, now, count)
  for i = 1, count do
    hatchOne(s, now + i)
  end
end

local function adultPair(s, now)
  for i = 1, #s.dinos do
    for j = i + 1, #s.dinos do
      if s.dinos[i].species == s.dinos[j].species then
        s.dinos[i].adultAt = now - 100
        s.dinos[j].adultAt = now - 100
        s.dinos[i].adult = true
        s.dinos[j].adult = true
        return s.dinos[i], s.dinos[j]
      end
    end
  end
  return nil, nil
end

local function runScript(seed)
  local now = 1800000000
  local s = state.new(seed, now)
  hatchMany(s, now, 12)
  local a, b = adultPair(s, now + 100)
  assert(a and b, "hacen falta dos adultos de la misma especie")
  s.eggs = {}
  local ok = state.startCross(s, a.id, b.id, now + 100)
  assert(ok, "el cruce debe iniciarse")
  s.lastTick = now + 100
  state.update(s, now + 100 + 80)
  local crossEgg
  for _, egg in ipairs(s.eggs) do
    if egg.kind == "cruce" then
      crossEgg = egg
      break
    end
  end
  assert(crossEgg, "el cruce debe generar un huevo")
  assert(state.startIncubation(s, crossEgg.id, now + 180))
  state.update(s, now + 180 + 60)
  local pending = {}
  for i, reveal in ipairs(s.pendingReveals) do
    pending[i] = reveal
  end
  for _, reveal in ipairs(pending) do
    if reveal.pendingSpecies then
      state.chooseSpecies(s, reveal.id, reveal.pendingSpecies[1])
    end
    state.dismissReveal(s, reveal.id)
  end
  state.normalize(s)
  return s
end

return function(t)
  t.test("serializar y deserializar es idempotente", function()
    local s = runScript(424242)
    local encoded = save.encode(s)
    local decoded, err = save.decode(encoded)
    t.assertTrue(decoded ~= nil, err)
    local again = save.encode(decoded)
    t.assertEqual(again, encoded, "segundo guardado")
    t.assertEqual(decoded.version, config.saveVersion)
    t.assertEqual(#decoded.dinos, #s.dinos)
    t.assertEqual(decoded.dinodex.total, s.dinodex.total)
    t.assertEqual(#decoded.log, #s.log)
  end)

  t.test("la misma semilla y las mismas acciones dan el mismo estado", function()
    local a = runScript(777)
    local b = runScript(777)
    t.assertEqual(save.encode(a), save.encode(b), "estado determinista")
  end)

  t.test("el prestigio conserva Dinodex, pity y registro", function()
    local now = 1800000000
    local s = state.new(999, now)
    hatchMany(s, now, 20)
    local dexTotal = s.dinodex.total
    local logCount = #s.log
    local pity = {
      rare = s.pity.rare,
      legendary = s.pity.legendary,
      mutation = s.pity.mutation,
    }
    local founders = {}
    for i = 1, math.min(2, #s.dinos) do
      founders[#founders + 1] = s.dinos[i].id
    end
    local ok, gain = state.prestigeNow(s, founders, now + 100)
    t.assertTrue(ok, gain)
    t.assertTrue(gain > 0, "debe otorgar legado")
    t.assertEqual(s.dinodex.total, dexTotal)
    t.assertEqual(#s.log, logCount)
    t.assertEqual(s.pity.rare, pity.rare)
    t.assertEqual(s.pity.legendary, pity.legendary)
    t.assertEqual(s.pity.mutation, pity.mutation)
    t.assertEqual(s.amber, 0)
    t.assertEqual(s.essence, 0)
    for key in pairs(config.upgrades) do
      t.assertEqual(s.upgrades[key], 0, "mejora " .. key)
    end
    t.assertEqual(#s.dinos, #founders)
    t.assertTrue(s.prestige.totalLegacy >= gain)
    t.assertEqual(#s.eggs, 1, "huevo inicial tras migrar")
    for _, slot in ipairs(s.incubators) do
      t.assertEqual(slot, false)
    end
  end)

  t.test("los contadores de pity sobreviven a un guardado", function()
    local now = 1800000000
    local s = state.new(123, now)
    hatchMany(s, now, 10)
    s.pity.rare = 17
    s.pity.legendary = 42
    s.pity.mutation = 90
    local decoded, err = save.decode(save.encode(s))
    t.assertTrue(decoded ~= nil, err)
    t.assertEqual(decoded.pity.rare, 17)
    t.assertEqual(decoded.pity.legendary, 42)
    t.assertEqual(decoded.pity.mutation, 90)
  end)

  t.test("un guardado corrupto o futuro no se acepta", function()
    local bad, err = save.decode("{esto no es json")
    t.assertEqual(bad, nil)
    t.assertTrue(err ~= nil)
    local future, err2 = save.decode('{"version":999}')
    t.assertEqual(future, nil)
    t.assertTrue(err2 ~= nil)
  end)

  t.test("la migración desde un guardado sin versión funciona", function()
    local now = 1800000000
    local s = state.new(456, now)
    s.version = nil
    local encoded = save.encode(s)
    encoded = encoded:gsub('"version":1,', "")
    local decoded, err = save.decode(encoded)
    t.assertTrue(decoded ~= nil, err)
    t.assertEqual(decoded.version, config.saveVersion)
    t.assertEqual(#decoded.eggs, 1)
  end)
end
