-- Economía pura: producción, mejoras, nido e incubación.
local config = require("src.game.config")

local economy = {}

function economy.eggInterval(state)
  local level = (state.upgrades and state.upgrades.generator) or 0
  local def = config.upgrades.generator
  return math.max(def.min, config.time.eggInterval * (def.factor ^ level))
end

function economy.incubateTime(state)
  local level = (state.upgrades and state.upgrades.incubation) or 0
  local def = config.upgrades.incubation
  return math.max(def.min, config.time.incubateTime * (def.factor ^ level))
end

function economy.incubatorSlots(state)
  return config.starting.incubatorSlots
    + ((state.upgrades and state.upgrades.incubators) or 0)
end

function economy.nestCapacity(state)
  return config.time.nestCapacity
    + ((state.upgrades and state.upgrades.capacity) or 0) * config.upgrades.capacity.plus
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
  return rarity.amberPerSec
    * (1 + 0.12 * productivity)
    * mutationMult
    * economy.productionMultiplier(state)
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
