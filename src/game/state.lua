-- Estado y acciones del juego. Lua puro: no usa love.*.
local config = require("src.game.config")
local rng = require("src.game.rng")
local genetics = require("src.game.genetics")
local hatch = require("src.game.hatch")
local economy = require("src.game.economy")
local prestige = require("src.game.prestige")

local state = {}

local function zeroUpgrades()
  local upgrades = {}
  for key in pairs(config.upgrades) do
    upgrades[key] = 0
  end
  return upgrades
end

local function zeroRarityCounts()
  local counts = {}
  for _, key in ipairs(config.rarityOrder) do
    counts[key] = 0
  end
  return counts
end

local function zeroSpeciesCounts()
  local counts = {}
  for _, key in ipairs(config.speciesOrder) do
    counts[key] = 0
  end
  return counts
end

local function copyPhenotype(pheno)
  local out = {}
  for _, gene in ipairs(genetics.visibleOrder) do
    out[gene] = pheno[gene]
  end
  return out
end

local function defaultSettings()
  return {
    calm = false,
    reminder = config.settings.defaultReminder,
    dailyCap = config.settings.defaultDailyCap,
  }
end

function state.makeEgg(s, now, kind, payload)
  local egg = {
    id = s.nextEggId,
    kind = kind or "nido",
    createdAt = now,
  }
  s.nextEggId = s.nextEggId + 1
  if payload then
    egg.child = payload
  end
  return egg
end

function state.new(seed, now)
  now = now or os.time()
  seed = seed or os.time()
  local s = {
    version = config.saveVersion,
    createdAt = now,
    lastSeen = now,
    lastTick = now,
    seed = seed,
    rng = rng.new(seed),
    amber = config.starting.amber,
    essence = config.starting.essence,
    eggs = {},
    incubators = {},
    dinos = {},
    nextEggId = 1,
    nextDinoId = 1,
    nextRevealId = 1,
    nextLogId = 1,
    pity = { rare = 0, legendary = 0, mutation = 0 },
    upgrades = zeroUpgrades(),
    stats = {
      hatched = 0,
      nestHatched = 0,
      crossHatched = 0,
      byRarity = zeroRarityCounts(),
      nestByRarity = zeroRarityCounts(),
      mutations = 0,
      guaranteedRare = 0,
      guaranteedLegendary = 0,
      guaranteedMutation = 0,
      released = 0,
      amberEarned = 0,
      prestiges = 0,
    },
    log = {},
    dinodex = {
      variants = {},
      total = 0,
      bySpecies = zeroSpeciesCounts(),
      milestones = {},
      milestoneCount = 0,
    },
    settings = defaultSettings(),
    daily = { date = economy.dayKey(now), eggs = 0 },
    nestTimer = 0,
    cross = nil,
    pendingReveals = {},
    prestige = { count = 0, totalLegacy = 0, lastGain = 0 },
    meta = { firstRun = true },
  }
  for i = 1, config.starting.incubatorSlots do
    s.incubators[i] = false
  end
  for _ = 1, config.starting.eggs do
    s.eggs[#s.eggs + 1] = state.makeEgg(s, now, "nido")
  end
  return s
end

function state.refreshAdults(s, now)
  for _, dino in ipairs(s.dinos or {}) do
    dino.adult = (dino.adultAt or 0) <= now
  end
end

local function addLog(s, entry)
  entry.id = s.nextLogId
  s.nextLogId = s.nextLogId + 1
  s.log[#s.log + 1] = entry
  while #s.log > config.stats.maxLog do
    table.remove(s.log, 1)
  end
  return entry
end

local function findLog(s, id)
  for i = #s.log, 1, -1 do
    if s.log[i].id == id then
      return s.log[i], i
    end
  end
  return nil
end

local function countRarity(s, rarity, nest)
  s.stats.byRarity[rarity] = (s.stats.byRarity[rarity] or 0) + 1
  if nest then
    s.stats.nestByRarity[rarity] = (s.stats.nestByRarity[rarity] or 0) + 1
  end
end

local function registerDiscovery(s, dino, now)
  local key = genetics.variantKey(dino.species, dino.genes, dino.mutation)
  local dex = s.dinodex
  if dex.variants[key] then
    return false, nil
  end
  dex.variants[key] = {
    species = dino.species,
    pattern = dino.genes.pattern,
    primaryColor = dino.genes.primaryColor,
    secondaryColor = dino.genes.secondaryColor,
    crest = dino.genes.crest,
    mutation = dino.mutation,
    firstAt = now,
    firstDinoId = dino.id,
  }
  dex.total = dex.total + 1
  dex.bySpecies[dino.species] = (dex.bySpecies[dino.species] or 0) + 1

  local milestone = nil
  local completion = dex.total / genetics.dexTotal()
  for i, fraction in ipairs(config.dinodex.milestoneFractions) do
    if not dex.milestones[i] and completion >= fraction then
      dex.milestones[i] = true
      dex.milestoneCount = (dex.milestoneCount or 0) + 1
      milestone = i
    end
  end
  return true, milestone
end

function state.addDino(s, data, now)
  local functional = data.functional
  local adultTime = economy.dinoAdultTime({ functional = functional })
  local dino = {
    id = s.nextDinoId,
    species = data.species,
    rarity = data.rarity,
    genes = copyPhenotype(data.genes),
    alleles = {},
    functional = {
      productivity = functional.productivity,
      fertility = functional.fertility,
      resilience = functional.resilience,
      luck = functional.luck,
    },
    mutation = data.mutation,
    bornAt = now,
    adultAt = now + adultTime,
    adult = false,
    lineage = data.lineage or {},
  }
  for _, gene in ipairs(genetics.visibleOrder) do
    local pair = data.alleles and data.alleles[gene]
    local fallback = dino.genes[gene] or genetics.geneOptions[gene][1]
    dino.alleles[gene] = {
      pair and pair[1] or fallback,
      pair and pair[2] or fallback,
    }
  end
  s.nextDinoId = s.nextDinoId + 1
  s.dinos[#s.dinos + 1] = dino

  local isNew, milestone = registerDiscovery(s, dino, now)
  dino.newDex = isNew
  return dino, isNew, milestone
end

local function bumpHatchStats(s, rarity, mutation, guaranteed, nest)
  s.stats.hatched = s.stats.hatched + 1
  if nest then
    s.stats.nestHatched = s.stats.nestHatched + 1
  else
    s.stats.crossHatched = s.stats.crossHatched + 1
  end
  countRarity(s, rarity, nest)
  if mutation then
    s.stats.mutations = s.stats.mutations + 1
  end
  if guaranteed.rare then
    s.stats.guaranteedRare = s.stats.guaranteedRare + 1
  end
  if guaranteed.legendary then
    s.stats.guaranteedLegendary = s.stats.guaranteedLegendary + 1
  end
  if guaranteed.mutation then
    s.stats.guaranteedMutation = s.stats.guaranteedMutation + 1
  end
end

local function pushReveal(s, reveal)
  reveal.id = s.nextRevealId
  s.nextRevealId = s.nextRevealId + 1
  s.pendingReveals[#s.pendingReveals + 1] = reveal
  return reveal
end

-- Abre un huevo del nido: consume pity, decide rareza, genes y mutación.
function state.rollNestReveal(s, egg, now)
  local rollStart = s.rng.count
  local rarity, guaranteedRare = hatch.rollRarity(s)
  local mutation, guaranteedMutation = hatch.rollMutation(s)
  local genotype = genetics.randomGenotype(s.rng)

  local guaranteed = {
    rare = guaranteedRare.rare,
    legendary = guaranteedRare.legendary,
    mutation = guaranteedMutation,
  }

  local species = nil
  local pendingSpecies = nil
  if rarity == "legendary" then
    pendingSpecies = hatch.legendaryChoices(s)
  else
    species = rng.pick(s.rng, config.speciesOrder)
  end

  local entry = addLog(s, {
    at = now,
    source = "nido",
    rarity = rarity,
    genes = copyPhenotype(genotype.phenotype),
    mutation = mutation,
    guaranteed = guaranteed,
    seed = s.seed,
    rollStart = rollStart,
    rollEnd = s.rng.count,
    species = species,
    pending = species == nil,
    eggId = egg.id,
  })
  bumpHatchStats(s, rarity, mutation, guaranteed, true)

  local reveal = {
    source = "nido",
    createdAt = now,
    rarity = rarity,
    genes = copyPhenotype(genotype.phenotype),
    alleles = genotype.alleles,
    functional = genotype.functional,
    mutation = mutation,
    guaranteed = guaranteed,
    species = species,
    pendingSpecies = pendingSpecies,
    logId = entry.id,
    rollStart = rollStart,
    rollEnd = s.rng.count,
  }

  if species then
    local dino, isNew, milestone = state.addDino(s, {
      species = species,
      rarity = rarity,
      genes = reveal.genes,
      alleles = reveal.alleles,
      functional = reveal.functional,
      mutation = mutation,
      lineage = {},
    }, now)
    reveal.dinoId = dino.id
    reveal.newDex = isNew
    reveal.milestone = milestone
    entry.newDex = isNew
  end

  return pushReveal(s, reveal)
end

-- Abre un huevo de cruce ya calculado al iniciar el cruce.
function state.rollCrossReveal(s, egg, now)
  local child = egg.child
  local guaranteed = {
    rare = false,
    legendary = false,
    mutation = child.mutationGuaranteed or false,
  }
  local entry = addLog(s, {
    at = now,
    source = "cruce",
    rarity = child.rarity,
    genes = copyPhenotype(child.genes),
    mutation = child.mutation,
    guaranteed = guaranteed,
    seed = s.seed,
    rollStart = child.rollStart,
    rollEnd = child.rollEnd,
    species = child.species,
    pending = false,
    eggId = egg.id,
  })
  bumpHatchStats(s, child.rarity, child.mutation, guaranteed, false)

  local dino, isNew, milestone = state.addDino(s, {
    species = child.species,
    rarity = child.rarity,
    genes = child.genes,
    alleles = child.alleles,
    functional = child.functional,
    mutation = child.mutation,
    lineage = child.lineage,
  }, now)
  entry.newDex = isNew

  return pushReveal(s, {
    source = "cruce",
    createdAt = now,
    rarity = child.rarity,
    genes = copyPhenotype(child.genes),
    alleles = child.alleles,
    functional = child.functional,
    mutation = child.mutation,
    guaranteed = guaranteed,
    species = child.species,
    dinoId = dino.id,
    newDex = isNew,
    milestone = milestone,
    logId = entry.id,
    rollStart = child.rollStart,
    rollEnd = child.rollEnd,
  })
end

function state.chooseSpecies(s, revealId, speciesKey)
  local reveal = nil
  for _, candidate in ipairs(s.pendingReveals) do
    if candidate.id == revealId then
      reveal = candidate
      break
    end
  end
  if not reveal or not reveal.pendingSpecies then
    return false, "Ese huevo ya no espera elección."
  end
  local valid = false
  for _, key in ipairs(reveal.pendingSpecies) do
    if key == speciesKey then
      valid = true
    end
  end
  if not valid then
    return false, "Especie no disponible."
  end

  local dino, isNew, milestone = state.addDino(s, {
    species = speciesKey,
    rarity = reveal.rarity,
    genes = reveal.genes,
    alleles = reveal.alleles,
    functional = reveal.functional,
    mutation = reveal.mutation,
    lineage = {},
  }, reveal.createdAt)
  reveal.species = speciesKey
  reveal.pendingSpecies = nil
  reveal.dinoId = dino.id
  reveal.newDex = isNew
  reveal.milestone = milestone

  local entry = findLog(s, reveal.logId)
  if entry then
    entry.species = speciesKey
    entry.pending = false
    entry.newDex = isNew
  end
  return true, dino
end

function state.dismissReveal(s, revealId)
  for i, reveal in ipairs(s.pendingReveals) do
    if reveal.id == revealId then
      if reveal.pendingSpecies then
        return false
      end
      table.remove(s.pendingReveals, i)
      return true
    end
  end
  return false
end

function state.dismissResolvedReveals(s)
  local kept = {}
  for _, reveal in ipairs(s.pendingReveals) do
    if reveal.pendingSpecies then
      kept[#kept + 1] = reveal
    end
  end
  s.pendingReveals = kept
end

function state.findEgg(s, eggId)
  for i, egg in ipairs(s.eggs) do
    if egg.id == eggId then
      return egg, i
    end
  end
  return nil
end

function state.findDino(s, dinoId)
  for i, dino in ipairs(s.dinos) do
    if dino.id == dinoId then
      return dino, i
    end
  end
  return nil
end

function state.freeIncubator(s)
  for i = 1, economy.incubatorSlots(s) do
    if not s.incubators[i] then
      return i
    end
  end
  return nil
end

function state.startIncubation(s, eggId, now)
  local slot = state.freeIncubator(s)
  if not slot then
    return false, "No hay incubadoras libres."
  end
  local egg, index = state.findEgg(s, eggId)
  if not egg then
    return false, "Ese huevo ya no está en el nido."
  end
  table.remove(s.eggs, index)

  local duration = economy.incubateTime(s)
  s.incubators[slot] = {
    egg = egg,
    startedAt = now,
    finishAt = now + duration,
  }
  return true, slot
end

function state.incubateAll(s, now)
  local started = 0
  while true do
    if not state.freeIncubator(s) then
      break
    end
    if #s.eggs == 0 then
      break
    end
    local ok = state.startIncubation(s, s.eggs[1].id, now)
    if not ok then
      break
    end
    started = started + 1
  end
  return started
end

function state.completeIncubation(s, slot, now)
  local egg = slot.egg
  if egg.kind == "cruce" and egg.child then
    return state.rollCrossReveal(s, egg, now)
  end
  return state.rollNestReveal(s, egg, now)
end

function state.isCrossing(s, dinoId)
  if not s.cross then
    return false
  end
  return s.cross.aId == dinoId or s.cross.bId == dinoId
end

function state.addCrossEgg(s, now)
  if not s.cross or not s.cross.finished then
    return nil
  end
  if not s.cross.child then
    s.cross = nil
    return nil
  end
  if #s.eggs >= economy.nestCapacity(s) then
    return nil
  end
  local egg = state.makeEgg(s, s.cross.finishAt or now, "cruce", s.cross.child)
  s.eggs[#s.eggs + 1] = egg
  s.cross = nil
  return egg
end

function state.canCross(s, aId, bId, now)
  local a = state.findDino(s, aId)
  local b = state.findDino(s, bId)
  if not a or not b then
    return false, "Falta uno de los progenitores."
  end
  if a.id == b.id then
    return false, "Elige dos ejemplares distintos."
  end
  if a.species ~= b.species then
    return false, "Los cruces del MVP son entre la misma especie."
  end
  if not economy.isAdult(a, now) or not economy.isAdult(b, now) then
    return false, "Ambos progenitores deben ser adultos."
  end
  if s.cross then
    return false, "Ya hay un cruce en curso."
  end
  return true
end

function state.startCross(s, aId, bId, now)
  local ok, err = state.canCross(s, aId, bId, now)
  if not ok then
    return false, err
  end
  local a = state.findDino(s, aId)
  local b = state.findDino(s, bId)
  local rollStart = s.rng.count
  local inherited = genetics.inherit(a, b, s.rng)
  local functional = genetics.inheritFunctional(a, b, s.rng)
  local rarity = genetics.crossRarity(a, b, s.rng)
  local mutation, mutationGuaranteed = hatch.rollMutation(s)
  local duration = economy.crossDuration(a, b)
  local rollEnd = s.rng.count

  s.cross = {
    aId = a.id,
    bId = b.id,
    startedAt = now,
    finishAt = now + duration,
    finished = false,
    child = {
      species = a.species,
      rarity = rarity,
      alleles = inherited.alleles,
      genes = inherited.phenotype,
      functional = functional,
      mutation = mutation,
      mutationGuaranteed = mutationGuaranteed,
      lineage = { a.id, b.id },
      rollStart = rollStart,
      rollEnd = rollEnd,
    },
  }
  return true, s.cross
end

function state.releaseDino(s, dinoId)
  if state.isCrossing(s, dinoId) then
    return false, "Ese ejemplar está en un cruce."
  end
  local dino, index = state.findDino(s, dinoId)
  if not dino then
    return false, "Ese ejemplar ya no existe."
  end
  local rarity = config.rarity[dino.rarity] or config.rarity.common
  local essence = rarity.essence
  table.remove(s.dinos, index)
  s.essence = s.essence + essence
  s.stats.released = (s.stats.released or 0) + 1
  return true, essence
end

function state.canBuyUpgrade(s, key)
  local def = config.upgrades[key]
  if not def then
    return false, "Mejora desconocida."
  end
  local level = s.upgrades[key] or 0
  if level >= def.max then
    return false, "Nivel máximo alcanzado."
  end
  local cost = economy.upgradeCost(key, level)
  local currency = def.currency == "amber" and s.amber or s.essence
  if currency < cost then
    return false, string.format("Faltan %d de %s.", math.ceil(cost - currency),
      def.currency == "amber" and "ámbar" or "esencia")
  end
  return true, cost
end

function state.buyUpgrade(s, key)
  local ok, costOrErr = state.canBuyUpgrade(s, key)
  if not ok then
    return false, costOrErr
  end
  local def = config.upgrades[key]
  local cost = costOrErr
  if def.currency == "amber" then
    s.amber = s.amber - cost
  else
    s.essence = s.essence - cost
  end
  s.upgrades[key] = (s.upgrades[key] or 0) + 1

  if key == "incubators" then
    while #s.incubators < economy.incubatorSlots(s) do
      s.incubators[#s.incubators + 1] = false
    end
  end
  return true, cost
end

function state.prestigeNow(s, founderIds, now)
  local ok, err = prestige.canPrestige(s)
  if not ok then
    return false, err
  end
  local seen = {}
  local clean = {}
  for _, id in ipairs(founderIds or {}) do
    if not seen[id] and #clean < config.prestige.maxFounders then
      local dino = state.findDino(s, id)
      if dino then
        seen[id] = true
        clean[#clean + 1] = id
      end
    end
  end
  local gain = prestige.apply(s, clean, now)
  s.eggs[#s.eggs + 1] = state.makeEgg(s, now, "nido")
  state.refreshAdults(s, now)
  return true, gain
end

function state.setSetting(s, key, value)
  if key == "calm" then
    s.settings.calm = not not value
  elseif key == "reminder" then
    local valid = false
    for _, option in ipairs(config.settings.reminderOptions) do
      if option == value then
        valid = true
      end
    end
    if valid then
      s.settings.reminder = value
    end
  elseif key == "dailyCap" then
    local valid = false
    for _, option in ipairs(config.settings.dailyCapOptions) do
      if option == value then
        valid = true
      end
    end
    if valid then
      s.settings.dailyCap = value
    end
  end
end

function state.update(s, now)
  now = now or os.time()
  if not s.lastTick or now < s.lastTick then
    s.lastTick = now
  end
  local dt = now - s.lastTick
  if dt > 0 then
    economy.ensureDaily(s, now)
    local produce = economy.totalProduction(s, now) * dt
    s.amber = s.amber + produce
    s.stats.amberEarned = (s.stats.amberEarned or 0) + produce

    for i = 1, #s.incubators do
      local slot = s.incubators[i]
      if slot and now >= slot.finishAt then
        s.incubators[i] = false
        state.completeIncubation(s, slot, slot.finishAt)
      end
    end

    if s.cross and not s.cross.finished and now >= s.cross.finishAt then
      s.cross.finished = true
    end
    if s.cross and s.cross.finished then
      state.addCrossEgg(s, now)
    end

    economy.tickNest(s, now, dt)

    state.refreshAdults(s, now)
  end
  s.lastTick = now
  s.lastSeen = now
end

function state.applyOffline(s, now)
  now = now or os.time()
  local last = s.lastSeen or now
  local actual = math.max(0, now - last)
  local credited = math.min(actual, config.time.offlineCap)
  local from = now - credited
  local summary = {
    elapsed = actual,
    credited = credited,
    capped = actual > config.time.offlineCap,
    amber = 0,
    eggs = 0,
    hatches = 0,
    crosses = 0,
  }
  if credited <= 0 then
    s.lastSeen = now
    s.lastTick = now
    return summary
  end

  for i = 1, #s.incubators do
    local slot = s.incubators[i]
    if slot and slot.finishAt <= now then
      s.incubators[i] = false
      state.completeIncubation(s, slot, slot.finishAt)
      summary.hatches = summary.hatches + 1
    end
  end

  if s.cross and not s.cross.finished and s.cross.finishAt <= now then
    s.cross.finished = true
  end
  if s.cross and s.cross.finished then
    local egg = state.addCrossEgg(s, now)
    if egg then
      summary.crosses = summary.crosses + 1
    end
  end

  summary.eggs = economy.tickNest(s, now, credited)
  summary.amber = economy.offlineProduction(s, from, now)
  s.amber = s.amber + summary.amber
  s.stats.amberEarned = (s.stats.amberEarned or 0) + summary.amber

  state.refreshAdults(s, now)
  s.lastSeen = now
  s.lastTick = now
  return summary
end

function state.normalize(s)
  if not s then
    return nil
  end
  s.version = config.saveVersion
  s.createdAt = s.createdAt or os.time()
  s.lastSeen = s.lastSeen or s.createdAt
  s.lastTick = s.lastTick or s.lastSeen
  s.seed = s.seed or os.time()
  if type(s.rng) ~= "table" then
    s.rng = rng.new(s.seed)
  else
    s.rng = rng.new(s.rng.seed or s.seed, s.rng.state, s.rng.count)
  end

  s.amber = s.amber or 0
  s.essence = s.essence or 0
  s.eggs = s.eggs or {}
  s.dinos = s.dinos or {}
  s.incubators = s.incubators or {}
  s.pendingReveals = s.pendingReveals or {}
  s.log = s.log or {}
  s.pity = s.pity or { rare = 0, legendary = 0, mutation = 0 }
  s.pity.rare = s.pity.rare or 0
  s.pity.legendary = s.pity.legendary or 0
  s.pity.mutation = s.pity.mutation or 0

  s.upgrades = s.upgrades or {}
  for key in pairs(config.upgrades) do
    s.upgrades[key] = s.upgrades[key] or 0
  end

  s.settings = s.settings or {}
  local defaults = defaultSettings()
  for key, value in pairs(defaults) do
    if s.settings[key] == nil then
      s.settings[key] = value
    end
  end

  s.stats = s.stats or {}
  local statsDefaults = {
    hatched = 0, nestHatched = 0, crossHatched = 0,
    mutations = 0, guaranteedRare = 0, guaranteedLegendary = 0,
    guaranteedMutation = 0, released = 0, amberEarned = 0, prestiges = 0,
  }
  for key, value in pairs(statsDefaults) do
    if s.stats[key] == nil then
      s.stats[key] = value
    end
  end
  s.stats.byRarity = s.stats.byRarity or {}
  s.stats.nestByRarity = s.stats.nestByRarity or {}
  for _, key in ipairs(config.rarityOrder) do
    s.stats.byRarity[key] = s.stats.byRarity[key] or 0
    s.stats.nestByRarity[key] = s.stats.nestByRarity[key] or 0
  end

  s.dinodex = s.dinodex or {}
  s.dinodex.variants = s.dinodex.variants or {}
  s.dinodex.bySpecies = s.dinodex.bySpecies or zeroSpeciesCounts()
  for _, key in ipairs(config.speciesOrder) do
    s.dinodex.bySpecies[key] = s.dinodex.bySpecies[key] or 0
  end
  s.dinodex.milestones = s.dinodex.milestones or {}
  local bySpecies = zeroSpeciesCounts()
  local dexTotal = 0
  for _, variant in pairs(s.dinodex.variants) do
    dexTotal = dexTotal + 1
    if variant.species and bySpecies[variant.species] ~= nil then
      bySpecies[variant.species] = bySpecies[variant.species] + 1
    end
  end
  s.dinodex.total = dexTotal
  s.dinodex.bySpecies = bySpecies
  local dexCompletion = dexTotal / genetics.dexTotal()
  local milestoneCount = 0
  for i, fraction in ipairs(config.dinodex.milestoneFractions) do
    if dexCompletion >= fraction then
      s.dinodex.milestones[i] = true
    end
    if s.dinodex.milestones[i] then
      milestoneCount = milestoneCount + 1
    end
  end
  s.dinodex.milestoneCount = milestoneCount

  s.daily = s.daily or { date = economy.dayKey(os.time()), eggs = 0 }
  s.nestTimer = s.nestTimer or 0
  s.prestige = s.prestige or { count = 0, totalLegacy = 0, lastGain = 0 }
  s.prestige.count = s.prestige.count or 0
  s.prestige.totalLegacy = s.prestige.totalLegacy or 0
  s.prestige.baselineHatches = s.prestige.baselineHatches or 0
  s.meta = s.meta or {}
  if s.meta.firstRun == nil then
    s.meta.firstRun = false
  end

  local maxDinoId = 0
  for _, dino in ipairs(s.dinos) do
    maxDinoId = math.max(maxDinoId, dino.id or 0)
    dino.genes = dino.genes or {}
    dino.functional = dino.functional or {
      productivity = 3, fertility = 3, resilience = 3, luck = 3,
    }
    dino.alleles = dino.alleles or {}
    for _, gene in ipairs(genetics.visibleOrder) do
      if not dino.alleles[gene] then
        local option = dino.genes[gene] or genetics.geneOptions[gene][1]
        dino.alleles[gene] = { option, option }
      end
    end
    if not dino.adultAt then
      dino.adultAt = (dino.bornAt or os.time()) + economy.dinoAdultTime(dino)
    end
    dino.adult = (dino.adultAt or 0) <= (s.lastTick or os.time())
  end
  s.nextDinoId = math.max(s.nextDinoId or 1, maxDinoId + 1)

  local maxEggId = 0
  for _, egg in ipairs(s.eggs) do
    maxEggId = math.max(maxEggId, egg.id or 0)
  end
  s.nextEggId = math.max(s.nextEggId or 1, maxEggId + 1)

  local maxLogId = 0
  for _, entry in ipairs(s.log) do
    maxLogId = math.max(maxLogId, entry.id or 0)
  end
  s.nextLogId = math.max(s.nextLogId or 1, maxLogId + 1)

  local maxRevealId = 0
  for _, reveal in ipairs(s.pendingReveals) do
    maxRevealId = math.max(maxRevealId, reveal.id or 0)
  end
  s.nextRevealId = math.max(s.nextRevealId or 1, maxRevealId + 1)

  local slots = economy.incubatorSlots(s)
  while #s.incubators < slots do
    s.incubators[#s.incubators + 1] = false
  end
  for i = slots + 1, #s.incubators do
    s.incubators[i] = nil
  end

  state.refreshAdults(s, s.lastTick or os.time())
  return s
end

return state
