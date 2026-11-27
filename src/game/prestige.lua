-- Prestigio "Gran Migración": cálculo y reinicio conservando lo permanente.
local config = require("src.game.config")
local genetics = require("src.game.genetics")

local prestige = {}

function prestige.completion(state)
  local discovered = (state.dinodex and state.dinodex.total) or 0
  local total = genetics.dexTotal()
  if total <= 0 then
    return 0
  end
  return discovered / total
end

function prestige.gain(state)
  local fromDinos = 0
  for _, dino in ipairs(state.dinos or {}) do
    local rarity = config.rarity[dino.rarity] or config.rarity.common
    fromDinos = fromDinos + rarity.legacy
  end
  local fromDex = math.floor(prestige.completion(state) * config.prestige.completionBonus)
  local tree = (state.prestige and state.prestige.tree and state.prestige.tree.legado) or 0
  local multiplier = 1 + tree * config.prestigeTree.legado.perLevel
  fromDinos = math.floor(fromDinos * multiplier)
  fromDex = math.floor(fromDex * multiplier)
  return fromDinos + fromDex, fromDinos, fromDex
end

function prestige.nodeCost(key, level)
  local def = config.prestigeTree[key]
  if not def then
    return nil
  end
  return def.baseCost + def.costStep * (level or 0)
end

function prestige.treeLevel(state, key)
  return (state.prestige and state.prestige.tree and state.prestige.tree[key]) or 0
end

function prestige.canBuyNode(state, key)
  local def = config.prestigeTree[key]
  if not def then
    return false, "Nodo no válido."
  end
  local level = prestige.treeLevel(state, key)
  if level >= def.max then
    return false, "Nivel máximo."
  end
  if def.requires then
    local required = prestige.treeLevel(state, def.requires.key)
    if required < def.requires.level then
      return false, "Requiere " .. config.prestigeTree[def.requires.key].name
        .. " nivel " .. def.requires.level .. "."
    end
  end
  local points = (state.prestige and state.prestige.points) or 0
  local cost = prestige.nodeCost(key, level)
  if points < cost then
    return false, "Faltan " .. (cost - points) .. " puntos de legado."
  end
  return true
end

function prestige.multiplier(state)
  local total = (state.prestige and state.prestige.totalLegacy) or 0
  return 1 + config.prestige.legacyMultiplier * total
end

function prestige.canPrestige(state)
  local hatched = (state.stats and state.stats.hatched) or 0
  local baseline = (state.prestige and state.prestige.baselineHatches) or 0
  local sinceLast = math.max(0, hatched - baseline)
  if sinceLast < config.prestige.minHatches then
    return false, string.format("Necesitas %d huevos abiertos desde la última migración (llevas %d).",
      config.prestige.minHatches, sinceLast)
  end
  if state.pendingReveals and #state.pendingReveals > 0 then
    return false, "Resuelve los huevos abiertos antes de migrar."
  end
  if state.cross then
    return false, "Termina o espera el cruce en curso."
  end
  return true
end

function prestige.apply(state, founderIds, now)
  local gain = prestige.gain(state)
  local keep = {}
  for _, id in ipairs(founderIds or {}) do
    keep[id] = true
  end
  local founders = {}
  for _, dino in ipairs(state.dinos or {}) do
    if keep[dino.id] and #founders < config.prestige.maxFounders then
      dino.adult = true
      dino.adultAt = math.min(dino.adultAt or now, now)
      founders[#founders + 1] = dino
    end
  end

  state.dinos = founders
  state.amber = 0
  state.essence = 0
  state.eggs = {}
  state.incubators = {}
  local slots = math.min(4, config.starting.incubatorSlots + ((state.prestige.tree and state.prestige.tree.nido) or 0))
  for i = 1, slots do
    state.incubators[i] = false
  end
  state.cross = nil
  state.nestTimer = 0
  for key in pairs(config.upgrades) do
    state.upgrades[key] = 0
  end

  state.prestige.count = (state.prestige.count or 0) + 1
  state.prestige.totalLegacy = (state.prestige.totalLegacy or 0) + gain
  state.prestige.points = (state.prestige.points or 0) + gain
  state.prestige.lastGain = gain
  state.prestige.lastAt = now
  state.prestige.baselineHatches = state.stats.hatched or 0
  state.stats.prestiges = (state.stats.prestiges or 0) + 1

  return gain, #founders
end

return prestige
