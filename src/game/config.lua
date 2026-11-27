-- Fuente única de verdad de la economía, probabilidades y contenido.
-- Ningún otro módulo debe repetir porcentajes, costes ni tiempos.
local config = {}

config.title = "Criadero de Ámbar"
config.subtitle = "Cría, colecciona y migra"
config.version = "2.2.0"
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

config.roleOrder = { "recolector", "incubador", "explorador" }
config.roles = {
  recolector = {
    name = "Recolector",
    short = "REC",
    desc = "+25 % de ámbar propio.",
    productionBonus = 0.25,
  },
  incubador = {
    name = "Incubador",
    short = "INC",
    desc = "-2 % de incubación por adulto, hasta -10 %.",
    incubationPerDino = 0.02,
    incubationCap = 0.10,
  },
  explorador = {
    name = "Explorador",
    short = "EXP",
    desc = "+1 % de peso raro+ por adulto, hasta +10 %.",
    luckPerDino = 0.01,
    luckCap = 0.10,
  },
}

config.habitatOrder = { "bosque", "volcan", "costa" }
config.habitats = {
  bosque = {
    name = "Bosque de helechos",
    short = "Bosque",
    desc = "+15 % de producción a sus residentes.",
    capacity = 3,
    color = { 0.28, 0.58, 0.32 },
    productionBonus = 0.15,
    decor = {
      key = "sendero",
      name = "Sendero de piedra",
      desc = "+10 % de producción a los residentes.",
      currency = "amber",
      cost = 90,
      productionBonus = 0.10,
    },
  },
  volcan = {
    name = "Caldera de obsidiana",
    short = "Volcán",
    desc = "+1 % de peso raro+ por residente, hasta +3 %.",
    capacity = 3,
    color = { 0.58, 0.26, 0.22 },
    luckPerResident = 0.01,
    luckCap = 0.03,
    decor = {
      key = "mirador",
      name = "Mirador de obsidiana",
      desc = "+1 % de peso raro+ global.",
      currency = "essence",
      cost = 8,
      luckBonus = 0.01,
    },
  },
  costa = {
    name = "Costa de ámbar",
    short = "Costa",
    desc = "-2 % de incubación por residente, hasta -6 %.",
    capacity = 3,
    color = { 0.25, 0.48, 0.62 },
    incubationPerResident = 0.02,
    incubationCap = 0.06,
    decor = {
      key = "termas",
      name = "Termas minerales",
      desc = "-2 % de incubación global.",
      currency = "amber",
      cost = 120,
      incubationBonus = 0.02,
    },
  },
}

config.prestigeTreeOrder = { "nido", "produccion", "suerte", "capacidad", "incubacion", "legado" }
config.prestigeTree = {
  nido = {
    name = "Vivero extra",
    desc = "Empiezas cada migración con una incubadora extra.",
    max = 1,
    baseCost = 20,
    costStep = 0,
    effect = "incubators",
    row = 1,
    col = 1,
  },
  produccion = {
    name = "Dieta ancestral",
    desc = "+5 % de producción por nivel.",
    max = 5,
    baseCost = 20,
    costStep = 10,
    effect = "production",
    perLevel = 0.05,
    row = 1,
    col = 2,
  },
  suerte = {
    name = "Instinto de manada",
    desc = "+1 % de peso raro+ por nivel.",
    max = 5,
    baseCost = 20,
    costStep = 10,
    effect = "luck",
    perLevel = 0.01,
    row = 1,
    col = 3,
  },
  capacidad = {
    name = "Nido amplio",
    desc = "+1 hueco de nido por nivel.",
    max = 3,
    baseCost = 25,
    costStep = 15,
    effect = "capacity",
    perLevel = 1,
    row = 2,
    col = 1,
    requires = { key = "nido", level = 1 },
  },
  incubacion = {
    name = "Calor heredado",
    desc = "-3 % de incubación por nivel.",
    max = 5,
    baseCost = 25,
    costStep = 15,
    effect = "incubation",
    perLevel = 0.03,
    row = 2,
    col = 2,
    requires = { key = "produccion", level = 1 },
  },
  legado = {
    name = "Memoria de la colonia",
    desc = "+10 % de puntos de legado por nivel.",
    max = 3,
    baseCost = 30,
    costStep = 20,
    effect = "legacy",
    perLevel = 0.10,
    row = 2,
    col = 3,
    requires = { key = "suerte", level = 1 },
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
  uiScaleOptions = { 1, 1.25, 1.5 },
  defaultReminder = 0,
  defaultDailyCap = 0,
  defaultMusic = true,
  defaultSfx = true,
  defaultMusicVolume = 100,
  defaultSfxVolume = 100,
  defaultColorblind = false,
  defaultLargeText = false,
  defaultFullscreen = false,
  defaultUiScale = 1,
}

config.achievementOrder = {
  "primer_huevo",
  "criador",
  "veterano",
  "primer_cruce",
  "cruces_10",
  "primera_mutacion",
  "mutaciones_5",
  "primer_legendario",
  "coleccionista",
  "explorador_genetico",
  "decorador",
  "habitats_llenos",
  "legado",
  "migracion",
}
config.achievements = {
  primer_huevo = {
    name = "Primer latido",
    desc = "Abre tu primer huevo.",
    metric = "opened",
    target = 1,
    reward = { amber = 25 },
  },
  criador = {
    name = "Criador constante",
    desc = "Abre 10 huevos.",
    metric = "opened",
    target = 10,
    reward = { amber = 80 },
  },
  veterano = {
    name = "Veterano de cáscara",
    desc = "Abre 50 huevos.",
    metric = "opened",
    target = 50,
    reward = { essence = 10 },
  },
  primer_cruce = {
    name = "Primera mezcla",
    desc = "Completa un cruce.",
    metric = "crosses",
    target = 1,
    reward = { amber = 50 },
  },
  cruces_10 = {
    name = "Laboratorio de campo",
    desc = "Completa 10 cruces.",
    metric = "crosses",
    target = 10,
    reward = { essence = 10 },
  },
  primera_mutacion = {
    name = "Cambio inesperado",
    desc = "Descubre una mutación.",
    metric = "mutations",
    target = 1,
    reward = { amber = 60 },
  },
  mutaciones_5 = {
    name = "Colección extraña",
    desc = "Descubre 5 mutaciones.",
    metric = "mutations",
    target = 5,
    reward = { essence = 15 },
  },
  primer_legendario = {
    name = "Leyenda del nido",
    desc = "Obtén un ejemplar legendario.",
    metric = "legendaries",
    target = 1,
    reward = { points = 10 },
  },
  coleccionista = {
    name = "Coleccionista",
    desc = "Registra 25 variantes en el Dinodex.",
    metric = "dinodex",
    target = 25,
    reward = { essence = 15 },
  },
  explorador_genetico = {
    name = "Explorador genético",
    desc = "Registra 100 variantes en el Dinodex.",
    metric = "dinodex",
    target = 100,
    reward = { amber = 300, essence = 10 },
  },
  decorador = {
    name = "Decorador de biomas",
    desc = "Compra 2 decoraciones.",
    metric = "decorations",
    target = 2,
    reward = { amber = 100 },
  },
  habitats_llenos = {
    name = "Tres ecosistemas",
    desc = "Llena los tres hábitats.",
    metric = "habitatsFull",
    target = 3,
    reward = { essence = 20 },
  },
  legado = {
    name = "Raíces profundas",
    desc = "Compra 3 nodos del árbol de legado.",
    metric = "treeNodes",
    target = 3,
    reward = { points = 10 },
  },
  migracion = {
    name = "Otra era",
    desc = "Completa una Gran Migración.",
    metric = "prestiges",
    target = 1,
    reward = { points = 15 },
  },
}

config.objectiveOrder = {
  "abre_5",
  "abre_15",
  "cruza_2",
  "descubre_5",
  "libera_5",
  "compra_decoracion",
  "llena_habitat",
  "sube_arbol",
}
config.objectives = {
  abre_5 = {
    name = "Cinco cáscaras",
    desc = "Abre 5 huevos.",
    metric = "opened",
    target = 5,
    reward = { amber = 50 },
  },
  abre_15 = {
    name = "Ritmo de nido",
    desc = "Abre 15 huevos.",
    metric = "opened",
    target = 15,
    reward = { amber = 140 },
  },
  cruza_2 = {
    name = "Dos mezclas",
    desc = "Completa 2 cruces.",
    metric = "crosses",
    target = 2,
    reward = { amber = 60, essence = 2 },
  },
  descubre_5 = {
    name = "Cinco variantes",
    desc = "Registra 5 variantes nuevas en el Dinodex.",
    metric = "dinodex",
    target = 5,
    reward = { essence = 4 },
  },
  libera_5 = {
    name = "Espacio para crecer",
    desc = "Libera 5 ejemplares.",
    metric = "released",
    target = 5,
    reward = { essence = 3 },
  },
  compra_decoracion = {
    name = "Un toque personal",
    desc = "Compra una decoración.",
    metric = "decorations",
    target = 1,
    reward = { amber = 80 },
  },
  llena_habitat = {
    name = "Hábitat completo",
    desc = "Llena un hábitat con 3 residentes.",
    metric = "habitatsFull",
    target = 1,
    reward = { amber = 70 },
  },
  sube_arbol = {
    name = "Una rama más",
    desc = "Compra un nodo del árbol de legado.",
    metric = "treeNodes",
    target = 1,
    reward = { amber = 80 },
  },
}

config.stats = {
  maxLog = 2000,
}

return config
