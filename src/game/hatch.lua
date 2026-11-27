-- Tiradas de rareza, garantías (pity) y mutaciones. Lua puro.
local config = require("src.game.config")
local rng = require("src.game.rng")

local hatch = {}

local function normalized(weights)
  local total = 0
  for _, key in ipairs(config.rarityOrder) do
    total = total + (weights[key] or 0)
  end
  if total <= 0 then
    total = 1
  end
  local out = {}
  for _, key in ipairs(config.rarityOrder) do
    out[key] = (weights[key] or 0) / total
  end
  return out
end

function hatch.baseWeights()
  return normalized(config.rates.rarity)
end

-- Pesos efectivos: mejora de suerte y pity suave de legendario.
function hatch.effectiveWeights(state)
  local weights = {}
  for _, key in ipairs(config.rarityOrder) do
    weights[key] = config.rates.rarity[key]
  end

  local luckLevel = (state.upgrades and state.upgrades.luck) or 0
  local now = state.lastTick or os.time()
  local explorers = 0
  local volcan = 0
  for _, dino in ipairs(state.dinos or {}) do
    if (dino.adultAt or 0) <= now then
      if dino.role == "explorador" then
        explorers = explorers + 1
      end
      if dino.habitat == "volcan" then
        volcan = volcan + 1
      end
    end
  end
  local treeLuck = (state.prestige and state.prestige.tree and state.prestige.tree.suerte) or 0
  local decorLuck = state.habitats and state.habitats.volcan and state.habitats.volcan.decor
    and config.habitats.volcan.decor.luckBonus or 0
  local luckBonus = config.rates.luckPerLevel * luckLevel
    + math.min(config.roles.explorador.luckCap, explorers * config.roles.explorador.luckPerDino)
    + math.min(config.habitats.volcan.luckCap, volcan * config.habitats.volcan.luckPerResident)
    + decorLuck
    + treeLuck * config.prestigeTree.suerte.perLevel
  local luckMultiplier = 1 + math.min(1.50, luckBonus)
  for _, key in ipairs(config.rarityOrder) do
    if key ~= "common" and key ~= "uncommon" then
      weights[key] = weights[key] * luckMultiplier
    end
  end

  local counter = (state.pity and state.pity.legendary) or 0
  local softStart = config.rates.pity.legendarySoftStart
  local hardAt = config.rates.pity.legendaryAt
  if counter >= softStart then
    local t = math.min(1, (counter - softStart + 1) / (hardAt - softStart))
    weights.legendary = weights.legendary
      * (1 + config.rates.pity.legendarySoftBoost * t)
  end

  return normalized(weights)
end

function hatch.rarityIndex(rarity)
  for i, key in ipairs(config.rarityOrder) do
    if key == rarity then
      return i
    end
  end
  return 1
end

function hatch.mutationProbability(state)
  local pity = state.pity or {}
  if (pity.mutation or 0) >= config.rates.pity.mutationAt - 1 then
    return 1
  end
  return config.rates.mutationChance
end

function hatch.rollRarity(state)
  local pity = state.pity
  local guaranteedRare = (pity.rare or 0) >= config.rates.pity.rareAt - 1
  local guaranteedLegendary = (pity.legendary or 0) >= config.rates.pity.legendaryAt - 1
  local weights = hatch.effectiveWeights(state)
  local rarity
  local rareWasForced = false

  if guaranteedLegendary then
    rarity = "legendary"
  else
    local entries = {}
    for _, key in ipairs(config.rarityOrder) do
      entries[#entries + 1] = { value = key, weight = weights[key] }
    end
    rarity = rng.weighted(state.rng, entries)

    if guaranteedRare and hatch.rarityIndex(rarity) < hatch.rarityIndex("rare") then
      rareWasForced = true
      local highEntries = {}
      for _, key in ipairs(config.rarityOrder) do
        if hatch.rarityIndex(key) >= hatch.rarityIndex("rare") then
          highEntries[#highEntries + 1] = { value = key, weight = weights[key] }
        end
      end
      rarity = rng.weighted(state.rng, highEntries)
    end
  end

  if rarity == "legendary" then
    pity.legendary = 0
    pity.rare = 0
  elseif hatch.rarityIndex(rarity) >= hatch.rarityIndex("rare") then
    pity.rare = 0
    pity.legendary = (pity.legendary or 0) + 1
  else
    pity.rare = (pity.rare or 0) + 1
    pity.legendary = (pity.legendary or 0) + 1
  end

  return rarity, {
    rare = rareWasForced,
    legendary = guaranteedLegendary,
  }
end

function hatch.rollMutation(state)
  local pity = state.pity
  local guaranteed = (pity.mutation or 0) >= config.rates.pity.mutationAt - 1
  local mutation = nil
  if guaranteed or rng.chance(state.rng, config.rates.mutationChance) then
    mutation = rng.pick(state.rng, config.mutationOrder)
    pity.mutation = 0
  else
    pity.mutation = (pity.mutation or 0) + 1
  end
  return mutation, guaranteed
end

function hatch.legendaryChoices(state)
  local pool = {}
  for _, key in ipairs(config.speciesOrder) do
    pool[#pool + 1] = key
  end
  local first = rng.pick(state.rng, pool)
  local second = first
  while second == first do
    second = rng.pick(state.rng, pool)
  end
  return { first, second }
end

function hatch.mutationTable(state)
  local base = config.rates.mutationChance / #config.mutationOrder
  local guaranteed = hatch.mutationProbability(state) >= 1
  local out = {}
  for _, key in ipairs(config.mutationOrder) do
    out[#out + 1] = {
      key = key,
      name = config.mutations[key].name,
      desc = config.mutations[key].desc,
      production = config.mutations[key].production,
      chance = guaranteed and (1 / #config.mutationOrder) or base,
      guaranteed = guaranteed,
    }
  end
  return out
end

function hatch.snapshot(state)
  local base = hatch.baseWeights()
  local effective = hatch.effectiveWeights(state)
  local pity = state.pity or {}
  return {
    base = base,
    effective = effective,
    luckLevel = (state.upgrades and state.upgrades.luck) or 0,
    pity = {
      rare = pity.rare or 0,
      legendary = pity.legendary or 0,
      mutation = pity.mutation or 0,
      rareIn = math.max(1, config.rates.pity.rareAt - (pity.rare or 0)),
      legendaryIn = math.max(1, config.rates.pity.legendaryAt - (pity.legendary or 0)),
      mutationIn = math.max(1, config.rates.pity.mutationAt - (pity.mutation or 0)),
      rareGuaranteed = (pity.rare or 0) >= config.rates.pity.rareAt - 1,
      legendaryGuaranteed = (pity.legendary or 0) >= config.rates.pity.legendaryAt - 1,
      mutationGuaranteed = (pity.mutation or 0) >= config.rates.pity.mutationAt - 1,
    },
    mutationChance = hatch.mutationProbability(state),
    mutations = hatch.mutationTable(state),
  }
end

return hatch
