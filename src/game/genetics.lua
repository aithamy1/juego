-- Genética pura: alelos, fenotipo, herencia mendeliana y simulador de cruces.
local config = require("src.game.config")
local rngModule = require("src.game.rng")

local genetics = {}

local function rngInt(r, min, max)
  return rngModule.int(r, min, max)
end

genetics.visibleOrder = { "pattern", "primaryColor", "secondaryColor", "crest" }

genetics.geneDefs = {
  pattern = config.patterns,
  primaryColor = config.colors,
  secondaryColor = config.secondaryColors,
  crest = config.crests,
}

genetics.geneOptions = {
  pattern = config.patternOrder,
  primaryColor = config.colorOrder,
  secondaryColor = config.secondaryColorOrder,
  crest = config.crestOrder,
}

genetics.geneLabels = {
  pattern = "Patrón",
  primaryColor = "Color primario",
  secondaryColor = "Color secundario",
  crest = "Cresta",
}

function genetics.dominance(gene, allele)
  local def = genetics.geneDefs[gene]
  local entry = def and def[allele]
  return entry and entry.dominance or 0
end

function genetics.phenotype(alleles)
  local pheno = {}
  for _, gene in ipairs(genetics.visibleOrder) do
    local pair = alleles[gene]
    local a = pair and pair[1]
    local b = pair and pair[2]
    if a and b then
      if genetics.dominance(gene, a) >= genetics.dominance(gene, b) then
        pheno[gene] = a
      else
        pheno[gene] = b
      end
    elseif a then
      pheno[gene] = a
    elseif b then
      pheno[gene] = b
    else
      pheno[gene] = genetics.geneOptions[gene][1]
    end
  end
  return pheno
end

function genetics.randomGenotype(r, species)
  local alleles = {}
  for _, gene in ipairs(genetics.visibleOrder) do
    local options = genetics.geneOptions[gene]
    alleles[gene] = {
      options[rngInt(r, 1, #options)],
      options[rngInt(r, 1, #options)],
    }
  end
  local functional = {}
  for _, gene in ipairs(config.functionalOrder) do
    functional[gene] = rngInt(r, 1, 5)
  end
  return {
    alleles = alleles,
    functional = functional,
    phenotype = genetics.phenotype(alleles),
    species = species,
  }
end

-- Se reutiliza la misma primitiva que usa el RNG global para no depender de él aquí.
-- (Se recibe la tabla RNG y se delega en src/game/rng.)
function genetics.inherit(parentA, parentB, r)
  local alleles = {}
  for _, gene in ipairs(genetics.visibleOrder) do
    local aPair = parentA.alleles and parentA.alleles[gene]
    local bPair = parentB.alleles and parentB.alleles[gene]
    local a = aPair and aPair[rngInt(r, 1, 2)] or genetics.geneOptions[gene][1]
    local b = bPair and bPair[rngInt(r, 1, 2)] or genetics.geneOptions[gene][1]
    alleles[gene] = { a, b }
  end
  return {
    alleles = alleles,
    phenotype = genetics.phenotype(alleles),
  }
end

local function clamp(value, low, high)
  if value < low then
    return low
  end
  if value > high then
    return high
  end
  return value
end

function genetics.inheritFunctional(parentA, parentB, r)
  local functional = {}
  for _, gene in ipairs(config.functionalOrder) do
    local a = (parentA.functional and parentA.functional[gene]) or 3
    local b = (parentB.functional and parentB.functional[gene]) or 3
    local base = math.floor((a + b) / 2 + 0.5)
    functional[gene] = clamp(base + rngInt(r, -1, 1), 1, 5)
  end
  return functional
end

function genetics.rarityUpgradeChance(a, b)
  local luckA = (a.functional and a.functional.luck) or 1
  local luckB = (b.functional and b.functional.luck) or 1
  local chance = config.time.crossRarityUpgradeChance
    + config.time.crossRarityLuckBonus * (luckA + luckB)
  chance = math.min(chance, config.time.crossRarityUpgradeCap)
  return chance
end

function genetics.crossRarity(a, b, r)
  local indexA = 1
  local indexB = 1
  for i, key in ipairs(config.rarityOrder) do
    if key == a.rarity then
      indexA = i
    end
    if key == b.rarity then
      indexB = i
    end
  end
  local index = math.max(indexA, indexB)
  if rngModule.chance(r, genetics.rarityUpgradeChance(a, b)) then
    index = math.min(#config.rarityOrder, index + 1)
  end
  return config.rarityOrder[index]
end

-- Distribución exacta de cada gen visible en un cruce.
local function geneDistribution(gene, aPair, bPair)
  local counts = {}
  local options = genetics.geneOptions[gene]
  for _, alleleA in ipairs(aPair) do
    for _, alleleB in ipairs(bPair) do
      local pheno
      if genetics.dominance(gene, alleleA) >= genetics.dominance(gene, alleleB) then
        pheno = alleleA
      else
        pheno = alleleB
      end
      counts[pheno] = (counts[pheno] or 0) + 0.25
    end
  end
  local out = {}
  for _, option in ipairs(options) do
    if counts[option] and counts[option] > 0 then
      out[#out + 1] = { value = option, probability = counts[option] }
    end
  end
  return out
end

function genetics.simulate(parentA, parentB)
  local distributions = {}
  for _, gene in ipairs(genetics.visibleOrder) do
    local aPair = parentA.alleles[gene]
    local bPair = parentB.alleles[gene]
    distributions[gene] = geneDistribution(gene, aPair, bPair)
  end

  local combos = {}
  local function walk(geneIndex, pheno, probability)
    if geneIndex > #genetics.visibleOrder then
      local key = table.concat({
        pheno.pattern,
        pheno.primaryColor,
        pheno.secondaryColor,
        pheno.crest,
      }, "|")
      if combos[key] then
        combos[key].probability = combos[key].probability + probability
      else
        combos[key] = { phenotype = pheno, probability = probability }
      end
      return
    end
    local gene = genetics.visibleOrder[geneIndex]
    for _, entry in ipairs(distributions[gene]) do
      local nextPheno = {}
      for k, v in pairs(pheno) do
        nextPheno[k] = v
      end
      nextPheno[gene] = entry.value
      walk(geneIndex + 1, nextPheno, probability * entry.probability)
    end
  end
  walk(1, {}, 1)

  local comboList = {}
  for _, combo in pairs(combos) do
    comboList[#comboList + 1] = combo
  end
  table.sort(comboList, function(a, b)
    if a.probability == b.probability then
      local ak = table.concat({
        a.phenotype.pattern,
        a.phenotype.primaryColor,
        a.phenotype.secondaryColor,
        a.phenotype.crest,
      }, "|")
      local bk = table.concat({
        b.phenotype.pattern,
        b.phenotype.primaryColor,
        b.phenotype.secondaryColor,
        b.phenotype.crest,
      }, "|")
      return ak < bk
    end
    return a.probability > b.probability
  end)

  return {
    distributions = distributions,
    combos = comboList,
    mutationChance = config.rates.mutationChance,
  }
end

function genetics.variantKey(species, phenotype, mutation)
  return table.concat({
    species,
    phenotype.pattern,
    phenotype.primaryColor,
    phenotype.crest,
    mutation or "ninguna",
  }, "|")
end

function genetics.speciesCount()
  return #config.speciesOrder
end

function genetics.dexTotalPerSpecies()
  return #config.patternOrder
    * #config.colorOrder
    * #config.crestOrder
    * (#config.mutationOrder + 1)
end

function genetics.dexTotal()
  return genetics.dexTotalPerSpecies() * #config.speciesOrder
end

return genetics
