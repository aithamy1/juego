local config = require("src.game.config")
local state = require("src.game.state")
local economy = require("src.game.economy")

local function adultDino(now)
  return {
    id = 1,
    species = "triceratops",
    rarity = "common",
    genes = {
      pattern = "rayado",
      primaryColor = "verde",
      secondaryColor = "crema",
      crest = "ninguna",
    },
    alleles = {
      pattern = { "rayado", "liso" },
      primaryColor = { "verde", "verde" },
      secondaryColor = { "crema", "crema" },
      crest = { "ninguna", "ninguna" },
    },
    functional = { productivity = 3, fertility = 3, resilience = 3, luck = 1 },
    mutation = nil,
    bornAt = now - 100000,
    adultAt = now - 100000,
    adult = true,
    lineage = {},
  }
end

return function(t)
  t.test("el progreso offline se limita a 8 horas", function()
    local now = 1800000000
    local s = state.new(1, now)
    s.dinos = { adultDino(now) }
    s.lastSeen = now - 20 * 3600
    s.lastTick = s.lastSeen
    local summary = state.applyOffline(s, now)
    t.assertTrue(summary.capped, "debe marcar el tope")
    t.assertNear(summary.credited, config.time.offlineCap, 1e-9, "tiempo acreditado")
    local rate = economy.dinoRate(s.dinos[1], s)
    t.assertNear(summary.amber, rate * config.time.offlineCap, 0.01, "ámbar offline")
    t.assertTrue(summary.eggs > 0, "debe generar huevos offline")
  end)

  t.test("la producción offline respeta la maduración", function()
    local now = 1800000000
    local s = state.new(1, now)
    local dino = adultDino(now)
    dino.adultAt = now - 3600
    s.dinos = { dino }
    s.lastSeen = now - 7200
    s.lastTick = s.lastSeen
    local summary = state.applyOffline(s, now)
    local rate = economy.dinoRate(dino, s)
    t.assertNear(summary.amber, rate * 3600, 0.01, "solo la hora adulta")
  end)

  t.test("cada adulto pone un huevo en su propio intervalo", function()
    local now = 1800000000
    local s = state.new(1, now)
    local dino = adultDino(now)
    dino.eggTimer = 0
    s.dinos = { dino }
    local interval = economy.layInterval(dino, s)
    local added = economy.tickDinoEggs(s, now + interval + 0.1, now)
    t.assertEqual(added, 1)
    t.assertEqual(#s.eggs, 2, "1 inicial + 1 puesto")
    t.assertTrue(interval > 0)
  end)

  t.test("un dinosaurio bebé no pone huevos", function()
    local now = 1800000000
    local s = state.new(1, now)
    local dino = adultDino(now)
    dino.adultAt = now + 3600
    dino.eggTimer = 0
    s.dinos = { dino }
    t.assertEqual(economy.tickDinoEggs(s, now + 600, now), 0)
    t.assertEqual(#s.eggs, 1)
  end)

  t.test("el nido respeta la capacidad", function()
    local now = 1800000000
    local s = state.new(1, now)
    local dino = adultDino(now)
    dino.eggTimer = 0
    s.dinos = { dino }
    while #s.eggs < economy.nestCapacity(s) do
      s.eggs[#s.eggs + 1] = state.makeEgg(s, now, "nido")
    end
    economy.tickDinoEggs(s, now + 3600, now)
    t.assertEqual(#s.eggs, economy.nestCapacity(s))
  end)

  t.test("el tope diario detiene la generación", function()
    local now = 1800000000
    local s = state.new(1, now)
    local dino = adultDino(now)
    dino.eggTimer = 0
    s.dinos = { dino }
    s.settings.dailyCap = 5
    economy.tickDinoEggs(s, now + 100000, now)
    t.assertLessOrEqual(s.daily.eggs, 5, "huevos del día")
  end)

  t.test("el intervalo de puesta varía por especie, rareza y genética", function()
    local now = 1800000000
    local s = state.new(1, now)
    local a = adultDino(now)
    local b = adultDino(now)
    b.id = 99
    b.species = "velociraptor"
    b.rarity = "epic"
    b.functional.fertility = 5
    local ia = economy.layInterval(a, s)
    local ib = economy.layInterval(b, s)
    t.assertTrue(ia ~= ib, "los intervalos deben ser distintos")
    t.assertTrue(ib < ia, "el épico y fértil debe poner antes")
    local s2 = state.new(2, now)
    s2.dinos = { a }
    local solo = economy.layInterval(a, s2)
    s2.dinos = { a, b }
    local colonia = economy.layInterval(a, s2)
    t.assertTrue(colonia > solo, "la colonia grande debe alargar la puesta")
  end)

  t.test("los costes de mejora crecen y se detienen en el máximo", function()
    t.assertEqual(economy.upgradeCost("generator", 0), 35)
    t.assertEqual(economy.upgradeCost("generator", 1), math.floor(35 * config.upgrades.generator.growth))
    t.assertEqual(economy.upgradeCost("generator", config.upgrades.generator.max), nil)
  end)

  t.test("comprar incubadoras amplía los huecos", function()
    local now = 1800000000
    local s = state.new(1, now)
    s.amber = 1000
    t.assertEqual(economy.incubatorSlots(s), 1)
    local ok = state.buyUpgrade(s, "incubators")
    t.assertTrue(ok)
    t.assertEqual(economy.incubatorSlots(s), 2)
    t.assertEqual(#s.incubators, 2)
    t.assertEqual(s.incubators[2], false)
  end)

  t.test("incubar mueve el huevo y completa con el temporizador", function()
    local now = 1800000000
    local s = state.new(1, now)
    local eggId = s.eggs[1].id
    local ok = state.startIncubation(s, eggId, now)
    t.assertTrue(ok)
    t.assertEqual(#s.eggs, 0)
    t.assertTrue(s.incubators[1] ~= false)
    state.update(s, now + economy.incubateTime(s) + 1)
    t.assertEqual(s.incubators[1], false)
    t.assertTrue(#s.pendingReveals >= 1, "debe haber un resultado")
  end)

  t.test("madurez y producción dependen de los genes funcionales", function()
    local dino = adultDino(1800000000)
    local base = economy.dinoAdultTime(dino)
    dino.functional.resilience = 5
    local fast = economy.dinoAdultTime(dino)
    t.assertTrue(fast < base, "resistencia debe acelerar la madurez")
    local now = 1800000000
    local s = state.new(1, now)
    s.dinos = { dino }
    dino.adultAt = now + 100
    t.assertEqual(economy.totalProduction(s, now), 0)
    t.assertTrue(economy.totalProduction(s, now + 1000) > 0)
  end)
end
