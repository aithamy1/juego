local config = require("src.game.config")
local genetics = require("src.game.genetics")
local rng = require("src.game.rng")

local function parent(overrides)
  local base = {
    species = "triceratops",
    rarity = "common",
    functional = { productivity = 3, fertility = 3, resilience = 3, luck = 1 },
    alleles = {
      pattern = { "rayado", "liso" },
      primaryColor = { "verde", "ocre" },
      secondaryColor = { "crema", "oliva" },
      crest = { "pequena", "ninguna" },
    },
  }
  for key, value in pairs(overrides or {}) do
    base[key] = value
  end
  return base
end

return function(t)
  t.test("monohíbrido: proporciones 25/50/25 y fenotipo 75 % dominante", function()
    local a = parent({ alleles = {
      pattern = { "rayado", "liso" },
      primaryColor = { "verde", "verde" },
      secondaryColor = { "crema", "crema" },
      crest = { "ninguna", "ninguna" },
    } })
    local b = parent({ alleles = {
      pattern = { "rayado", "liso" },
      primaryColor = { "verde", "verde" },
      secondaryColor = { "crema", "crema" },
      crest = { "ninguna", "ninguna" },
    } })
    local r = rng.new(111)
    local genotypes = { homoCrest = 0, hetero = 0, homoLiso = 0 }
    local phenotypes = { rayado = 0, liso = 0 }
    local total = 100000
    for _ = 1, total do
      local child = genetics.inherit(a, b, r)
      local pair = child.alleles.pattern
      local x, y = pair[1], pair[2]
      if x == y then
        if x == "rayado" then
          genotypes.homoCrest = genotypes.homoCrest + 1
        else
          genotypes.homoLiso = genotypes.homoLiso + 1
        end
      else
        genotypes.hetero = genotypes.hetero + 1
      end
      phenotypes[child.phenotype.pattern] = phenotypes[child.phenotype.pattern] + 1
    end
    t.assertNear(genotypes.homoCrest / total, 0.25, 0.01, "homocigoto dominante")
    t.assertNear(genotypes.hetero / total, 0.50, 0.01, "heterocigoto")
    t.assertNear(genotypes.homoLiso / total, 0.25, 0.01, "homocigoto recesivo")
    t.assertNear(phenotypes.rayado / total, 0.75, 0.01, "fenotipo dominante")
  end)

  t.test("el simulador coincide con la simulación real de genes visibles", function()
    local a = parent({ alleles = {
      pattern = { "rayado", "liso" },
      primaryColor = { "verde", "ocre" },
      secondaryColor = { "crema", "oliva" },
      crest = { "pequena", "ninguna" },
    } })
    local b = parent({ alleles = {
      pattern = { "manchas", "moteado" },
      primaryColor = { "azul", "rojo" },
      secondaryColor = { "gris", "coral" },
      crest = { "grande", "ninguna" },
    } })
    local sim = genetics.simulate(a, b)
    local r = rng.new(222)
    local total = 200000
    local counts = {}
    local marginal = {}
    for _, gene in ipairs(genetics.visibleOrder) do
      marginal[gene] = {}
    end
    for _ = 1, total do
      local child = genetics.inherit(a, b, r)
      local p = child.phenotype
      local key = table.concat({ p.pattern, p.primaryColor, p.secondaryColor, p.crest }, "|")
      counts[key] = (counts[key] or 0) + 1
      for _, gene in ipairs(genetics.visibleOrder) do
        marginal[gene][p[gene]] = (marginal[gene][p[gene]] or 0) + 1
      end
    end
    local tvd = 0
    for _, combo in ipairs(sim.combos) do
      local p = combo.phenotype
      local key = table.concat({ p.pattern, p.primaryColor, p.secondaryColor, p.crest }, "|")
      local actual = (counts[key] or 0) / total
      tvd = tvd + math.abs(actual - combo.probability)
      t.assertNear(actual, combo.probability, 0.004, "combinación " .. key)
    end
    t.assertTrue(tvd < 0.02, "distancia de variación total demasiado alta: " .. tvd)
    for _, gene in ipairs(genetics.visibleOrder) do
      for _, entry in ipairs(sim.distributions[gene]) do
        local actual = (marginal[gene][entry.value] or 0) / total
        t.assertNear(actual, entry.probability, 0.008, gene .. "=" .. entry.value)
      end
    end
    t.assertNear(sim.mutationChance, config.rates.mutationChance, 1e-9, "mutación")
  end)

  t.test("crossRarity parte de la rareza mayor y sube como máximo un nivel", function()
    local a = parent({ rarity = "epic" })
    local b = parent({ rarity = "common" })
    local r = rng.new(444)
    local counts = { epic = 0, legendary = 0 }
    local total = 100000
    for _ = 1, total do
      local rarity = genetics.crossRarity(a, b, r)
      counts[rarity] = (counts[rarity] or 0) + 1
    end
    t.assertNear(counts.epic / total, 0.88, 0.01, "épico")
    t.assertNear(counts.legendary / total, 0.12, 0.01, "legendario")
    t.assertEqual(counts.rare, nil)
  end)

  t.test("la herencia funcional queda entre 1 y 5", function()
    local a = parent({ functional = { productivity = 5, fertility = 5, resilience = 5, luck = 5 } })
    local b = parent({ functional = { productivity = 1, fertility = 1, resilience = 1, luck = 1 } })
    local r = rng.new(555)
    for _ = 1, 10000 do
      local functional = genetics.inheritFunctional(a, b, r)
      for _, gene in ipairs(config.functionalOrder) do
        t.assertTrue(functional[gene] >= 1 and functional[gene] <= 5)
      end
    end
  end)

  t.test("el Dinodex tiene 288 variantes por especie y 2016 en total", function()
    t.assertEqual(genetics.dexTotalPerSpecies(), 288)
    t.assertEqual(genetics.dexTotal(), 2016)
  end)
end
