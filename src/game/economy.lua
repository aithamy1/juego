-- Economía pura: producción, mejoras, nido e incubación.
local config = require("src.game.config")

local economy = {}

local function treeLevel(state, key)
  return (state.prestige and state.prestige.tree and state.prestige.tree[key]) or 0
end

local function hasDecoration(state, key)
  return state.habitats and state.habitats[key] and state.habitats[key].decor
end

function economy.eggInterval(state)
  local level = (state.upgrades and state.upgrades.generator) or 0
  local def = config.upgrades.generator
  return math.max(def.min, config.time.eggInterval * (def.factor ^ level))
end

function economy.incubateTime(state)
  local level = (state.upgrades and state.upgrades.incubation) or 0
  local def = config.upgrades.incubation
  local base = math.max(def.min, config.time.incubateTime * (def.factor ^ level))
  local now = state.lastTick or os.time()
  local incubators = 0
  local costa = 0
  for _, dino in ipairs(state.dinos or {}) do
    if economy.isAdult(dino, now) then
      if dino.role == "incubador" then
        incubators = incubators + 1
      end
      if dino.habitat == "costa" then
        costa = costa + 1
      end
    end
  end
  local reduction = math.min(config.roles.incubador.incubationCap,
      incubators * config.roles.incubador.incubationPerDino)
    + math.min(config.habitats.costa.incubationCap,
      costa * config.habitats.costa.incubationPerResident)
    + (hasDecoration(state, "costa") and config.habitats.costa.decor.incubationBonus or 0)
    + treeLevel(state, "incubacion") * config.prestigeTree.incubacion.perLevel
  return math.max(3, base * (1 - math.min(0.55, reduction)))
end

function economy.incubatorSlots(state)
  local slots = config.starting.incubatorSlots
    + ((state.upgrades and state.upgrades.incubators) or 0)
    + treeLevel(state, "nido")
  return math.min(4, slots)
end

function economy.nestCapacity(state)
  return config.time.nestCapacity
    + ((state.upgrades and state.upgrades.capacity) or 0) * config.upgrades.capacity.plus
    + treeLevel(state, "capacidad") * config.prestigeTree.capacidad.perLevel
end

function economy.milestoneCount(state)
  return (state.dinodex and state.dinodex.milestoneCount) or 0
end

function economy.productionMultiplier(state)
  local prodLevel = (state.upgrades and state.upgrades.production) or 0
  local legacy = (state.prestige and state.prestige.totalLegacy) or 0
  local milestones = economy.milestoneCount(state)
  return (1 + config.upgrades.production.perLevel * prodLevel)
    * (1 + config.dinodex.milestoneBonus * milestones)
    * (1 + config.prestige.legacyMultiplier * legacy)
    * (1 + treeLevel(state, "produccion") * config.prestigeTree.produccion.perLevel)
end

function economy.dinoAdultTime(dino)
  local resilience = (dino.functional and dino.functional.resilience) or 1
  local reduction = config.time.adultTimeResilienceReduction * resilience
  return math.max(config.time.adultTimeMin, config.time.adultTime * (1 - reduction))
end

function economy.isAdult(dino, now)
  return (dino.adultAt or 0) <= now
end

function economy.dinoRate(dino, state)
  local rarity = config.rarity[dino.rarity] or config.rarity.common
  local productivity = (dino.functional and dino.functional.productivity) or 1
  local mutationMult = 1
  if dino.mutation and config.mutations[dino.mutation] then
    mutationMult = config.mutations[dino.mutation].production
  end
  local rate = rarity.amberPerSec
    * (1 + 0.12 * productivity)
    * mutationMult
  if dino.role == "recolector" then
    rate = rate * (1 + config.roles.recolector.productionBonus)
  end
  if dino.habitat == "bosque" then
    local bonus = config.habitats.bosque.productionBonus
    if hasDecoration(state, "bosque") then
      bonus = bonus + config.habitats.bosque.decor.productionBonus
    end
    rate = rate * (1 + bonus)
  end
  return rate * economy.productionMultiplier(state)
end

function economy.roleCount(state, role)
  local now = state.lastTick or os.time()
  local count = 0
  for _, dino in ipairs(state.dinos or {}) do
    if dino.role == role and economy.isAdult(dino, now) then
      count = count + 1
    end
  end
  return count
end

function economy.habitatCount(state, key)
  local now = state.lastTick or os.time()
  local count = 0
  for _, dino in ipairs(state.dinos or {}) do
    if dino.habitat == key and economy.isAdult(dino, now) then
      count = count + 1
    end
  end
  return count
end

function economy.totalProduction(state, now)
  local total = 0
  for _, dino in ipairs(state.dinos or {}) do
    if economy.isAdult(dino, now) then
      total = total + economy.dinoRate(dino, state)
    end
  end
  return total
end

-- Producción exacta en una ventana, contando la maduración dentro de ella.
function economy.offlineProduction(state, from, to)
  local total = 0
  if to <= from then
    return 0
  end
  for _, dino in ipairs(state.dinos or {}) do
    local startAt = math.max(from, dino.adultAt or 0)
    if startAt < to then
      total = total + economy.dinoRate(dino, state) * (to - startAt)
    end
  end
  return total
end

function economy.upgradeCost(key, level)
  local def = config.upgrades[key]
  if not def or level >= def.max then
    return nil
  end
  return math.floor(def.baseCost * (def.growth ^ level))
end

function economy.dayKey(now)
  return os.date("%Y-%m-%d", now)
end

function economy.ensureDaily(state, now)
  local key = economy.dayKey(now)
  if not state.daily or state.daily.date ~= key then
    state.daily = { date = key, eggs = 0 }
    return true
  end
  return false
end

function economy.dailyCap(state)
  return (state.settings and state.settings.dailyCap) or 0
end

function economy.dailyCapReached(state, now)
  economy.ensureDaily(state, now)
  local cap = economy.dailyCap(state)
  return cap > 0 and state.daily.eggs >= cap
end

function economy.newNestEgg(state, now, kind)
  local egg = {
    id = state.nextEggId,
    kind = kind or "nido",
    createdAt = now,
  }
  state.nextEggId = state.nextEggId + 1
  return egg
end

-- Añade huevos del nido según el tiempo transcurrido. Devuelve cuántos añadió.
function economy.tickNest(state, now, elapsed)
  economy.ensureDaily(state, now)
  if elapsed <= 0 then
    return 0
  end
  local interval = economy.eggInterval(state)
  local capacity = economy.nestCapacity(state)
  local cap = economy.dailyCap(state)
  local added = 0

  if #state.eggs >= capacity then
    state.nestTimer = math.min(state.nestTimer + elapsed, interval)
    return 0
  end

  state.nestTimer = state.nestTimer + elapsed
  while state.nestTimer >= interval
    and #state.eggs < capacity
    and (cap == 0 or state.daily.eggs < cap) do
    state.nestTimer = state.nestTimer - interval
    local egg = economy.newNestEgg(state, now, "nido")
    state.eggs[#state.eggs + 1] = egg
    state.daily.eggs = state.daily.eggs + 1
    added = added + 1
  end

  if #state.eggs >= capacity or (cap > 0 and state.daily.eggs >= cap) then
    state.nestTimer = math.min(state.nestTimer, interval)
  end

  return added
end

function economy.crossDuration(a, b)
  local fertilityA = (a.functional and a.functional.fertility) or 1
  local fertilityB = (b.functional and b.functional.fertility) or 1
  local avg = (fertilityA + fertilityB) / 2
  local duration = config.time.crossTime
    * (1 - config.time.crossTimeFertilityReduction * avg)
  return math.max(config.time.crossTimeMin, duration)
end

function economy.upgradeEffect(key, state)
  local level = (state.upgrades and state.upgrades[key]) or 0
  if key == "generator" then
    return string.format("Huevo cada %.0f s", economy.eggInterval(state))
  elseif key == "incubators" then
    local slots = economy.incubatorSlots(state)
    return slots == 1 and "1 hueco" or string.format("%d huecos", slots)
  elseif key == "incubation" then
    return string.format("Incubación %.0f s", economy.incubateTime(state))
  elseif key == "capacity" then
    return string.format("Capacidad %d", economy.nestCapacity(state))
  elseif key == "luck" then
    return string.format("+%d %% peso raro+", math.floor(level * config.rates.luckPerLevel * 100))
  elseif key == "production" then
    return string.format("+%d %% ámbar", math.floor(level * config.upgrades.production.perLevel * 100))
  end
  return ""
end

return economy
