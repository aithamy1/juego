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

  t.test("los campos nuevos se rellenan al normalizar un guardado antiguo", function()
    local now = 1800000000
    local s = state.new(35, now)
    s.habitats = nil
    s.prestige.tree = nil
    s.prestige.points = nil
    s.dinos = {}
    local dino = addDino(s, now)
    dino.role = "rol_inventado"
    dino.habitat = "habitat_inventado"
    state.normalize(s)
    t.assertTrue(s.habitats ~= nil)
    t.assertTrue(s.habitats.bosque ~= nil)
    t.assertTrue(s.prestige.tree ~= nil)
    t.assertEqual(s.prestige.tree.nido, 0)
    t.assertFalse(s.prestige.points ~= nil and s.prestige.points < 0)
    t.assertTrue(dino.role == nil)
    t.assertTrue(dino.habitat == nil)
  end)
end
