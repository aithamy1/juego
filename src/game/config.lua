-- Fuente única de verdad de la economía, probabilidades y contenido.
-- Ningún otro módulo debe repetir porcentajes, costes ni tiempos.
local config = {}

config.title = "Criadero de Ámbar"
config.subtitle = "Cría, colecciona y migra"
config.version = "1.9.0"
config.saveVersion = 1

config.window = {
  width = 1280,
  height = 720,
  minWidth = 960,
  minHeight = 540,
}

config.time = {
  eggInterval = 20,          -- segundos entre huevos del nido (nivel 0)
  incubateTime = 30,         -- segundos de incubación (nivel 0)
  crossTime = 45,            -- segundos que tarda un cruce
  nestCapacity = 6,          -- huevos sin incubar (nivel 0)
  adultTime = 45,            -- segundos hasta la edad adulta
  offlineCap = 8 * 3600,     -- tope de progreso offline
  autosave = 10,             -- segundos entre autoguardados
  revealDuration = 2.35,     -- animación de apertura completa (se puede saltar)
  revealResult = 2.00,       -- momento en que aparece el resultado
  revealBurst = 1.35,        -- rotura de la cáscara y salida del dinosaurio
  revealCracks = { 0.32, 0.52, 0.75, 0.98, 1.18 },
  crossRarityUpgradeChance = 0.10,
  crossRarityLuckBonus = 0.01,
  crossRarityUpgradeCap = 0.40,
  crossTimeFertilityReduction = 0.06,
  crossTimeMin = 15,
  adultTimeResilienceReduction = 0.04,
  adultTimeMin = 15,
}

config.starting = {
  amber = 25,
  essence = 0,
  eggs = 1,
  incubatorSlots = 1,
}

config.rates = {
  rarity = {
    common = 0.60,
    uncommon = 0.25,
    rare = 0.10,
    epic = 0.04,
    legendary = 0.01,
  },
  pity = {
    rareAt = 30,
    legendaryAt = 100,
    mutationAt = 150,
    legendarySoftStart = 60,
    legendarySoftBoost = 2.0, -- multiplicador extra al llegar al umbral
  },
  mutationChance = 0.012,
  luckPerLevel = 0.06,
}

config.rarityOrder = { "common", "uncommon", "rare", "epic", "legendary" }

config.rarity = {
  common = {
    name = "Común",
    color = { 0.76, 0.80, 0.68 },
    essence = 1,
    amberPerSec = 0.12,
    legacy = 1,
  },
  uncommon = {
    name = "Poco común",
    color = { 0.42, 0.84, 0.44 },
    essence = 2,
    amberPerSec = 0.28,
    legacy = 2,
  },
  rare = {
    name = "Raro",
    color = { 0.35, 0.66, 1.00 },
    essence = 4,
    amberPerSec = 0.65,
    legacy = 4,
  },
  epic = {
    name = "Épico",
    color = { 0.82, 0.46, 0.98 },
    essence = 9,
    amberPerSec = 1.50,
    legacy = 8,
  },
  legendary = {
    name = "Legendario",
    color = { 1.00, 0.74, 0.20 },
    essence = 22,
    amberPerSec = 4.00,
    legacy = 16,
  },
}

config.speciesOrder = {
  "triceratops",
  "velociraptor",
  "parasaurolophus",
  "pteranodon",
  "stegosaurus",
  "ankylosaurus",
}

config.species = {
  triceratops = {
    name = "Triceratops",
    short = "Triceratops",
    desc = "Herbívoro robusto, con gola ósea y tres cuernos.",
    bodyScale = 1.05,
  },
  velociraptor = {
    name = "Velociraptor",
    short = "Velociraptor",
    desc = "Cazador ligero, plumado y de cola larga.",
    bodyScale = 1.0,
  },
  parasaurolophus = {
    name = "Parasaurolophus",
    short = "Parasaurolophus",
    desc = "Pico de pato y cresta tubular hacia atrás.",
    bodyScale = 1.0,
  },
  pteranodon = {
    name = "Pteranodon",
    short = "Pteranodon",
    desc = "Alas enormes, cresta ósea y pico afilado.",
    bodyScale = 0.96,
  },
  stegosaurus = {
    name = "Stegosaurus",
    short = "Stegosaurus",
    desc = "Placas alternas en el lomo y cola con púas.",
    bodyScale = 1.02,
  },
  ankylosaurus = {
    name = "Ankylosaurus",
    short = "Ankylosaurus",
    desc = "Coraza de placas y una maza al final de la cola.",
    bodyScale = 1.04,
  },
}

-- Genes visibles: el alelo con mayor dominancia se muestra.
config.patternOrder = { "liso", "moteado", "rayado", "manchas" }
config.patterns = {
  liso = { name = "Liso", dominance = 1, desc = "Piel sin marcas." },
  moteado = { name = "Moteado", dominance = 2, desc = "Motas pequeñas y dispersas." },
  rayado = { name = "Rayado", dominance = 3, desc = "Rayas diagonales." },
  manchas = { name = "Manchas", dominance = 4, desc = "Manchas amplias e irregulares." },
}

config.colorOrder = { "verde", "ocre", "azul", "rojo" }
config.colors = {
  verde = { name = "Verde", dominance = 1, rgb = { 0.36, 0.63, 0.36 } },
  ocre = { name = "Ocre", dominance = 2, rgb = { 0.78, 0.58, 0.26 } },
  azul = { name = "Azul", dominance = 3, rgb = { 0.31, 0.52, 0.73 } },
  rojo = { name = "Rojo", dominance = 4, rgb = { 0.74, 0.33, 0.28 } },
}

config.secondaryColorOrder = { "crema", "oliva", "gris", "coral" }
config.secondaryColors = {
  crema = { name = "Crema", dominance = 1, rgb = { 0.91, 0.82, 0.62 } },
  oliva = { name = "Oliva", dominance = 2, rgb = { 0.56, 0.57, 0.32 } },
  gris = { name = "Gris", dominance = 3, rgb = { 0.63, 0.65, 0.62 } },
  coral = { name = "Coral", dominance = 4, rgb = { 0.84, 0.53, 0.45 } },
}

config.crestOrder = { "ninguna", "pequena", "grande" }
config.crests = {
  ninguna = { name = "Ninguna", dominance = 1, desc = "Sin cresta." },
  pequena = { name = "Pequeña", dominance = 2, desc = "Una cresta discreta." },
  grande = { name = "Grande", dominance = 3, desc = "Una cresta llamativa." },
}

config.mutationOrder = {
  "bioluminiscente",
  "albino",
  "melanico",
  "gigante",
  "fantasma",
}
config.mutations = {
  bioluminiscente = {
    name = "Bioluminiscente",
    desc = "Brilla en la oscuridad.",
    production = 1.15,
  },
  albino = {
    name = "Albino",
    desc = "Pigmentación muy clara.",
    production = 1.10,
  },
  melanico = {
    name = "Melánico",
    desc = "Pigmentación casi negra.",
    production = 1.10,
  },
  gigante = {
    name = "Gigante",
    desc = "Un ejemplar de gran tamaño.",
    production = 1.25,
  },
  fantasma = {
    name = "Fantasma",
    desc = "Translúcido y espectral.",
    production = 1.20,
  },
}

config.functionalOrder = { "productivity", "fertility", "resilience", "luck" }
config.functional = {
  productivity = {
    name = "Productividad",
    short = "PRO",
    desc = "+12 % de ámbar por punto.",
  },
  fertility = {
    name = "Fertilidad",
    short = "FER",
    desc = "Cruces un 6 % más rápidos por punto.",
  },
  resilience = {
    name = "Resistencia",
    short = "RES",
    desc = "Madurez un 4 % más rápida por punto.",
  },
  luck = {
    name = "Suerte",
    short = "SUE",
    desc = "+1 % de mejora de rareza en cruces por punto.",
  },
}

config.upgradesOrder = {
  "generator",
  "incubators",
  "incubation",
  "capacity",
  "luck",
  "production",
}

config.upgrades = {
  generator = {
    name = "Ritmo del nido",
    desc = "Reduce un 12 % el tiempo entre huevos.",
    currency = "amber",
    baseCost = 35,
    growth = 1.70,
    max = 12,
    kind = "interval",
    factor = 0.88,
    min = 5,
  },
  incubators = {
    name = "Hueco de incubadora",
    desc = "Añade un hueco de incubación, hasta 4.",
    currency = "amber",
    baseCost = 90,
    growth = 2.60,
    max = 3,
    kind = "slots",
  },
  incubation = {
    name = "Calor estable",
    desc = "Reduce un 14 % el tiempo de incubación.",
    currency = "amber",
    baseCost = 55,
    growth = 1.65,
    max = 12,
    kind = "interval",
    factor = 0.86,
    min = 8,
  },
  capacity = {
    name = "Ampliación del nido",
    desc = "Añade 2 huecos al nido.",
    currency = "essence",
    baseCost = 6,
    growth = 1.85,
    max = 8,
    kind = "capacity",
    plus = 2,
  },
  luck = {
    name = "Feng shui del nido",
    desc = "Aumenta un 6 % el peso de Raro o superior.",
    currency = "essence",
    baseCost = 12,
    growth = 2.00,
    max = 10,
    kind = "luck",
    perLevel = 0.06,
  },
  production = {
    name = "Dieta de ámbar",
    desc = "Aumenta un 15 % la producción de ámbar.",
    currency = "amber",
    baseCost = 70,
    growth = 1.65,
    max = 15,
    kind = "production",
    perLevel = 0.15,
  },
}

config.prestige = {
  minHatches = 15,
  maxFounders = 3,
  completionBonus = 100,
  legacyMultiplier = 0.02,
}

config.dinodex = {
  milestoneFractions = { 0.25, 0.50, 0.75, 1.00 },
  milestoneBonus = 0.03,
}

config.settings = {
  reminderOptions = { 0, 60, 90 },
  dailyCapOptions = { 0, 25, 50, 100, 200 },
  defaultReminder = 0,
  defaultDailyCap = 0,
  defaultMusic = true,
  defaultSfx = true,
}

config.stats = {
  maxLog = 2000,
}

return config
