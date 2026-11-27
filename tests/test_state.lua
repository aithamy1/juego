local config = require("src.game.config")
local state = require("src.game.state")
local economy = require("src.game.economy")
local prestige = require("src.game.prestige")

local function makeAdult(s, now, species)
  local dino = state.addDino(s, {
    species = species or "triceratops",
    rarity = "rare",
    genes = {
      pattern = "rayado",
      primaryColor = "verde",
      secondaryColor = "crema",
      crest = "pequena",
    },
    alleles = {
      pattern = { "rayado", "liso" },
      primaryColor = { "verde", "ocre" },
      secondaryColor = { "crema", "oliva" },
      crest = { "pequena", "ninguna" },
    },
    functional = { productivity = 3, fertility = 3, resilience = 3, luck = 2 },
    mutation = nil,
    lineage = {},
  }, now)
  dino.adultAt = now - 100
  dino.adult = true
  return dino
end

return function(t)
  t.test("un legendario del nido ofrece dos especies y espera la elección", function()
    local now = 1800000000
    local s = state.new(555, now)
    s.pity.legendary = config.rates.pity.legendaryAt - 1
    local egg = { id = s.nextEggId, kind = "nido", createdAt = now }
    s.nextEggId = s.nextEggId + 1
    local reveal = state.rollNestReveal(s, egg, now)
    t.assertEqual(reveal.rarity, "legendary")
    t.assertEqual(reveal.eggId, egg.id)
    t.assertTrue(reveal.pendingSpecies ~= nil)
    t.assertEqual(#reveal.pendingSpecies, 2)
    t.assertTrue(reveal.pendingSpecies[1] ~= reveal.pendingSpecies[2])
    t.assertEqual(#s.dinos, 0, "no debe crear el dinosaurio antes de elegir")
    local chosen = reveal.pendingSpecies[2]
    local ok = state.chooseSpecies(s, reveal.id, chosen)
    t.assertTrue(ok)
    t.assertEqual(#s.dinos, 1)
    t.assertEqual(s.dinos[1].species, chosen)
    t.assertEqual(reveal.species, chosen)
    t.assertTrue(state.isDinoPending(s, reveal.dinoId))
    t.assertTrue(state.dismissReveal(s, reveal.id))
    t.assertFalse(state.isDinoPending(s, reveal.dinoId))
  end)

  t.test("el cruce genera un huevo con la especie de los padres", function()
    local now = 1800000000
    local s = state.new(666, now)
    s.eggs = {}
    local a = makeAdult(s, now, "triceratops")
    local b = makeAdult(s, now, "triceratops")
    local ok = state.startCross(s, a.id, b.id, now)
    t.assertTrue(ok)
    t.assertTrue(s.cross ~= nil)
    t.assertEqual(s.cross.child.species, "triceratops")
    t.assertTrue(s.cross.child.alleles.pattern ~= nil)
    s.lastTick = now
    state.update(s, now + 120)
    local crossEgg = nil
    for _, egg in ipairs(s.eggs) do
      if egg.kind == "cruce" then
        crossEgg = egg
      end
    end
    t.assertTrue(crossEgg ~= nil, "el huevo de cruce debe llegar al nido")
    t.assertEqual(s.cross, nil)
    t.assertEqual(crossEgg.child.species, "triceratops")
  end)

  t.test("el huevo de cruce tiene prioridad si el nido se llena", function()
    local now = 1800000000
    local s = state.new(667, now)
    s.eggs = {}
    local a = makeAdult(s, now, "triceratops")
    local b = makeAdult(s, now, "triceratops")
    assert(state.startCross(s, a.id, b.id, now))
    s.lastTick = now
    while #s.eggs < economy.nestCapacity(s) do
      s.eggs[#s.eggs + 1] = state.makeEgg(s, now, "nido")
    end
    s.cross.finished = true
    state.update(s, now + 1)
    for _, egg in ipairs(s.eggs) do
      t.assertTrue(egg.kind ~= "cruce", "no debe entrar con el nido lleno")
    end
    table.remove(s.eggs, 1)
    state.update(s, now + 2)
    local found = false
    for _, egg in ipairs(s.eggs) do
      if egg.kind == "cruce" then
        found = true
      end
    end
    t.assertTrue(found, "el cruce debe ocupar el hueco antes que el nido")
  end)

  t.test("no se puede migrar dos veces sin abrir huevos nuevos", function()
    local now = 1800000000
    local s = state.new(901, now)
    for i = 1, config.prestige.minHatches do
      local egg = { id = s.nextEggId, kind = "nido", createdAt = now + i }
      s.nextEggId = s.nextEggId + 1
      local reveal = state.rollNestReveal(s, egg, now + i)
      if reveal.pendingSpecies then
        state.chooseSpecies(s, reveal.id, reveal.pendingSpecies[1])
      end
      state.dismissReveal(s, reveal.id)
    end
    local ok, gain = state.prestigeNow(s, {}, now + 100)
    t.assertTrue(ok, gain)
    local can, reason = prestige.canPrestige(s)
    t.assertFalse(can, "no debe permitir migrar de inmediato")
    t.assertTrue(reason ~= nil)
  end)

  t.test("liberar devuelve esencia y elimina al ejemplar", function()
    local now = 1800000000
    local s = state.new(777, now)
    local dino = makeAdult(s, now, "stegosaurus")
    local before = s.essence
    local ok, essence = state.releaseDino(s, dino.id)
    t.assertTrue(ok)
    t.assertEqual(essence, config.rarity.rare.essence)
    t.assertEqual(s.essence, before + essence)
    t.assertEqual(state.findDino(s, dino.id), nil)
  end)

  t.test("el Dinodex concede el hito del 25 % y el bonus se aplica", function()
    local now = 1800000000
    local s = state.new(888, now)
    local target = math.ceil(#config.speciesOrder
      * #config.patternOrder
      * #config.colorOrder
      * #config.crestOrder
      * (#config.mutationOrder + 1) * 0.25)
    local made = 0
    local mutations = { false }
    for _, key in ipairs(config.mutationOrder) do
      mutations[#mutations + 1] = key
    end
    for _, mutation in ipairs(mutations) do
      for _, species in ipairs(config.speciesOrder) do
        for _, pattern in ipairs(config.patternOrder) do
          for _, color in ipairs(config.colorOrder) do
            for _, crest in ipairs(config.crestOrder) do
              if made < target then
                state.addDino(s, {
                  species = species,
                  rarity = "common",
                  genes = {
                    pattern = pattern,
                    primaryColor = color,
                    secondaryColor = "crema",
                    crest = crest,
                  },
                  alleles = {
                    pattern = { pattern, pattern },
                    primaryColor = { color, color },
                    secondaryColor = { "crema", "crema" },
                    crest = { crest, crest },
                  },
                  functional = { productivity = 3, fertility = 3, resilience = 3, luck = 1 },
                  mutation = mutation or nil,
                }, now)
                made = made + 1
              end
            end
          end
        end
      end
    end
    t.assertTrue(s.dinodex.total >= target)
    t.assertEqual(s.dinodex.milestoneCount, 1)
    t.assertTrue(s.dinodex.milestones[1])
    t.assertNear(economy.productionMultiplier(s), 1 + config.dinodex.milestoneBonus, 1e-9)
  end)

  t.test("los ajustes de música y efectos se guardan y se rellenan al cargar", function()
    local now = 1800000000
    local s = state.new(987, now)
    t.assertTrue(s.settings.music)
    t.assertTrue(s.settings.sfx)
    state.setSetting(s, "music", false)
    state.setSetting(s, "sfx", false)
    t.assertFalse(s.settings.music)
    t.assertFalse(s.settings.sfx)
    s.settings.music = nil
    s.settings.sfx = nil
    state.normalize(s)
    t.assertTrue(s.settings.music)
    t.assertTrue(s.settings.sfx)
  end)
end
