local config = require("src.game.config")
local state = require("src.game.state")
local economy = require("src.game.economy")
local hatch = require("src.game.hatch")
local prestige = require("src.game.prestige")

local function addDino(s, now, role, habitat)
  local dino = state.addDino(s, {
    species = "triceratops",
    rarity = "rare",
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
    functional = { productivity = 5, fertility = 5, resilience = 5, luck = 5 },
    mutation = nil,
    lineage = {},
  }, now)
  dino.adultAt = now - 100
  dino.adult = true
  dino.role = role
  dino.habitat = habitat
  return dino
end

return function(t)
  t.test("los roles modifican producción, incubación y suerte", function()
    local now = 1800000000
    local s = state.new(31, now)
    s.lastTick = now
    s.dinos = {}
    local dino = addDino(s, now)
    local baseRate = economy.dinoRate(dino, s)
    local baseIncubation = economy.incubateTime(s)
    local baseWeights = hatch.effectiveWeights(s)

    dino.role = "recolector"
    t.assertNear(economy.dinoRate(dino, s), baseRate * (1 + config.roles.recolector.productionBonus), 1e-9)

    dino.role = "incubador"
    t.assertNear(economy.incubateTime(s), baseIncubation * (1 - config.roles.incubador.incubationPerDino), 1e-9)

    dino.role = "explorador"
    local weights = hatch.effectiveWeights(s)
    t.assertTrue(weights.rare > baseWeights.rare, "el explorador debe subir el peso raro")
  end)

  t.test("los hábitats respetan la capacidad y aplican su bonus", function()
    local now = 1800000000
    local s = state.new(32, now)
    s.lastTick = now
    s.dinos = {}
    local first = addDino(s, now)
    local baseRate = economy.dinoRate(first, s)
    t.assertTrue(state.setDinoHabitat(s, first.id, "bosque"))
    t.assertNear(economy.dinoRate(first, s), baseRate * (1 + config.habitats.bosque.productionBonus), 1e-9)

    local second = addDino(s, now)
    local third = addDino(s, now)
    local fourth = addDino(s, now)
    t.assertTrue(state.setDinoHabitat(s, second.id, "bosque"))
    t.assertTrue(state.setDinoHabitat(s, third.id, "bosque"))
    local ok, reason = state.setDinoHabitat(s, fourth.id, "bosque")
    t.assertFalse(ok)
    t.assertTrue(reason ~= nil)
    t.assertEqual(state.habitatCount(s, "bosque"), 3)
  end)

  t.test("las decoraciones se compran una vez y aplican su bonus", function()
    local now = 1800000000
    local s = state.new(33, now)
    s.lastTick = now
    s.dinos = {}
    local dino = addDino(s, now)
    local baseRate = economy.dinoRate(dino, s)
    t.assertTrue(state.setDinoHabitat(s, dino.id, "bosque"))
    local before = economy.dinoRate(dino, s)
    t.assertNear(before, baseRate * (1 + config.habitats.bosque.productionBonus), 1e-9)
    s.amber = 1000
    local ok, cost = state.buyDecoration(s, "bosque")
    t.assertTrue(ok)
    t.assertEqual(cost, config.habitats.bosque.decor.cost)
    t.assertEqual(s.amber, 1000 - cost)
    t.assertTrue(s.habitats.bosque.decor)
    t.assertNear(economy.dinoRate(dino, s),
      baseRate * (1 + config.habitats.bosque.productionBonus + config.habitats.bosque.decor.productionBonus), 1e-9)
    t.assertFalse(state.buyDecoration(s, "bosque"))
  end)

  t.test("el árbol de legado compra nodos, respeta requisitos y conserva puntos", function()
    local now = 1800000000
    local s = state.new(34, now)
    s.prestige.points = 100
    local ok, cost = state.buyPrestigeNode(s, "nido")
    t.assertTrue(ok)
    t.assertEqual(cost, config.prestigeTree.nido.baseCost)
    t.assertEqual(s.prestige.tree.nido, 1)
    t.assertEqual(s.prestige.points, 100 - cost)
    t.assertEqual(economy.incubatorSlots(s), config.starting.incubatorSlots + 1)

    t.assertTrue(state.buyPrestigeNode(s, "capacidad"))
    t.assertEqual(s.prestige.tree.capacidad, 1)
    t.assertEqual(economy.nestCapacity(s), config.time.nestCapacity + config.prestigeTree.capacidad.perLevel)

    local beforeGain = prestige.gain(s)
    local beforePoints = s.prestige.points
    prestige.apply(s, {}, now)
    t.assertEqual(s.prestige.points, beforePoints + beforeGain)
    t.assertEqual(s.prestige.tree.nido, 1, "el árbol debe conservarse")
    t.assertEqual(s.prestige.tree.capacidad, 1, "el árbol debe conservarse")
  end)

  t.test("los logros y objetivos dan recompensas una sola vez", function()
    local now = 1800000000
    local s = state.new(36, now)
    s.dinos = {}
    local events = state.evaluateGoals(s)
    t.assertEqual(#events, 0)
    t.assertEqual(#s.goals.active, 3)
    s.stats.opened = 1
    events = state.evaluateGoals(s)
    t.assertTrue(s.achievements.unlocked.primer_huevo)
    t.assertTrue(s.amber >= 25)
    local amber = s.amber
    state.evaluateGoals(s)
    t.assertEqual(s.amber, amber, "el logro no debe pagarse dos veces")
    s.goals.active = { { id = "abre_5", start = 0 } }
    s.goals.completed = {}
    s.stats.opened = 5
    events = state.evaluateGoals(s)
    t.assertTrue(s.goals.completed.abre_5)
    t.assertEqual(#events, 1)
    t.assertTrue(s.amber > amber, "el objetivo debe pagar ámbar")
  end)

  t.test("los favoritos no se pueden liberar y los duplicados se detectan", function()
    local now = 1800000000
    local s = state.new(37, now)
    s.dinos = {}
    local first = addDino(s, now)
    local second = addDino(s, now)
    local third = addDino(s, now)
    state.setDinoFavorite(s, first.id, true)
    local ok = state.releaseDino(s, first.id)
    t.assertFalse(ok)
    local plan, essence = state.duplicatePlan(s)
    t.assertEqual(#plan, 1, "solo el duplicado no favorito entra en el plan")
    t.assertTrue(essence > 0)
    local count, value = state.releaseDuplicates(s)
    t.assertEqual(count, 1)
    t.assertTrue(value > 0)
    t.assertTrue(state.findDino(s, first.id) ~= nil)
    t.assertTrue(state.findDino(s, second.id) ~= nil or state.findDino(s, third.id) ~= nil)
    t.assertTrue(state.findDino(s, second.id) == nil or state.findDino(s, third.id) == nil)
  end)

  t.test("los volúmenes se limitan entre 0 y 100", function()
    local now = 1800000000
    local s = state.new(38, now)
    state.setSetting(s, "musicVolume", 150)
    state.setSetting(s, "sfxVolume", -10)
    t.assertEqual(s.settings.musicVolume, 100)
    t.assertEqual(s.settings.sfxVolume, 0)
  end)
end
