-- Aplicación de interfaz: marco de escritorio, catálogo, mejoras y escenas.
local config = require("src.game.config")
local stateModule = require("src.game.state")
local economy = require("src.game.economy")
local genetics = require("src.game.genetics")
local prestige = require("src.game.prestige")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local render = require("src.render.dino")

local app = {}
app.__index = app

local scenes = {
  nest = require("src.ui.scenes.nest"),
  breeding = require("src.ui.scenes.breeding"),
  cross = require("src.ui.scenes.cross"),
  upgrades = require("src.ui.scenes.upgrades"),
  dinodex = require("src.ui.scenes.dinodex"),
  log = require("src.ui.scenes.log"),
  settings = require("src.ui.scenes.settings"),
}
local modals = require("src.ui.modals")

local tabs = {
  { key = "nest", label = "Nido", hotkey = "1", icon = "nest" },
  { key = "breeding", label = "Criadero", hotkey = "2", icon = "breeding" },
  { key = "cross", label = "Cruces", hotkey = "3", icon = "cross" },
  { key = "upgrades", label = "Mejoras", hotkey = "4", icon = "upgrade" },
  { key = "dinodex", label = "Dinodex", hotkey = "5", icon = "dex" },
  { key = "log", label = "Registro", hotkey = "6", icon = "log" },
  { key = "settings", label = "Ajustes", hotkey = "7", icon = "settings" },
}

local sceneMeta = {
  nest = { title = "Nido", subtitle = "Huevos, incubadoras y garantías del motor.", icon = "nest" },
  breeding = { title = "Criadero", subtitle = "Tus ejemplares, sus genes y su producción.", icon = "breeding" },
  cross = { title = "Cruces", subtitle = "Herencia mendeliana, simulador y resultados.", icon = "cross" },
  upgrades = { title = "Mejoras", subtitle = "Invierte ámbar y esencia en la colonia.", icon = "upgrade" },
  dinodex = { title = "Dinodex", subtitle = "Cada patrón, color, cresta y mutación descubiertos.", icon = "dex" },
  log = { title = "Registro", subtitle = "Cada huevo queda anotado con su semilla y sus tiradas.", icon = "log" },
  settings = { title = "Ajustes", subtitle = "Tu ritmo, accesibilidad y la Gran Migración.", icon = "settings" },
}

local quickUpgrades = { "generator", "incubators", "incubation", "production" }

app.layout = {
  headerH = 64,
  leftX = 12,
  leftY = 76,
  leftW = 228,
  leftH = 624,
  boardX = 252,
  boardY = 76,
  boardW = 776,
  boardH = 624,
  rightX = 1048,
  rightY = 76,
  rightW = 220,
  rightH = 624,
  contentX = 276,
  contentY = 154,
  contentW = 728,
  contentH = 522,
}

function app.new(game)
  local self = setmetatable({}, app)
  self.game = game
  self.pendingCount = #game.pendingReveals
  self.openingAll = false
  self.displayDirty = false
  self.gamepadCursor = false
  self.compareA = nil
  self.compareB = nil
  self.pastureHabitat = "todos"
  self.scene = "nest"
  self.now = os.time()
  self.mouse = { x = -1, y = -1, hand = false, down = false }
  self.click = nil
  self.wheel = nil
  self.scroll = {}
  self.modal = nil
  self.toasts = {}
  self.tooltip = nil
  self.blocked = false
  self.tabs = tabs
  self.crossSelect = { a = nil, b = nil }
  self.filters = {
    species = "todas",
    rarity = "todas",
    mutation = "todas",
    sort = "reciente",
  }
  self.logFilter = "todos"
  self.dexSpecies = nil
  self.dexMutation = "todas"
  self.prestigeFounders = {}
  self.selectedDino = nil
  self.crossWasActive = false
  self.crossFinishedNotified = false
  self.lastReminder = os.time()
  self.saveCallback = nil
  self.saveStatus = "Guardado automático"
  self.statusTime = love.timer.getTime()
  return self
end

function app:goto(scene)
  if scenes[scene] then
    self.scene = scene
    self.tooltip = nil
  end
end

function app:cycleTab(delta)
  if self.modal then
    return
  end
  local current = 1
  for index, tab in ipairs(tabs) do
    if tab.key == self.scene then
      current = index
    end
  end
  local nextIndex = ((current - 1 + (delta or 1)) % #tabs) + 1
  self:goto(tabs[nextIndex].key)
end

function app:toast(message, color)
  self.toasts[#self.toasts + 1] = {
    message = message,
    color = color or theme.colors.text,
    at = love.timer.getTime(),
  }
  while #self.toasts > 4 do
    table.remove(self.toasts, 1)
  end
end

function app:openModal(kind, data)
  data = data or {}
  data.kind = kind
  data.startedAt = love.timer.getTime()
  self.modal = data
  self.click = nil
  self.tooltip = nil
end

function app:openNextReveal(eggId, fromQueue)
  if self.modal then
    return false
  end
  if not fromQueue then
    self.openingAll = false
  end
  local reveal = nil
  if eggId then
    for _, candidate in ipairs(self.game.pendingReveals) do
      if candidate.eggId == eggId then
        reveal = candidate
        break
      end
    end
  end
  reveal = reveal or self.game.pendingReveals[1]
  if not reveal then
    self:toast("No hay huevos listos para abrir.", theme.colors.muted)
    return false
  end
  self:openModal("reveal", {
    reveal = reveal,
    revealStart = love.timer.getTime(),
    skipped = self.game.settings.calm,
  })
  return true
end

function app:openAllReveals()
  if #self.game.pendingReveals == 0 then
    self:toast("No hay huevos listos para abrir.", theme.colors.muted)
    return false
  end
  self.openingAll = #self.game.pendingReveals > 1
  return self:openNextReveal(nil, true)
end

function app:closeModal()
  local wasReveal = self.modal and self.modal.kind == "reveal"
  if self.modal and self.modal.kind == "help" then
    self.game.meta.firstRun = false
    self:save()
  end
  self.modal = nil
  self.click = nil
  self.tooltip = nil
  if wasReveal and self.openingAll then
    if #self.game.pendingReveals > 0 then
      self:openNextReveal(nil, true)
    else
      self.openingAll = false
      self:toast("Has abierto todos los huevos pendientes.", theme.colors.gold)
    end
  end
end

function app:save()
  if self.saveCallback then
    local ok, err = self.saveCallback()
    self.saveStatus = ok and "Guardado" or ("Error al guardar: " .. tostring(err))
    self.statusTime = love.timer.getTime()
  end
end

function app:backupSave()
  if not self.backupCallback then
    self:toast("No se pudo crear la copia.", theme.colors.red)
    return
  end
  local ok, err = self.backupCallback()
  if ok then
    self:toast("Copia guardada como save-backup.json.", theme.colors.green)
  else
    self:toast("No se pudo crear la copia: " .. tostring(err), theme.colors.red)
  end
end

function app:restoreBackup()
  if not self.restoreCallback then
    self:toast("No hay una copia disponible.", theme.colors.red)
    return
  end
  local ok, err = self.restoreCallback()
  if not ok then
    self:toast(err or "No se pudo restaurar la copia.", theme.colors.red)
  end
end

function app:update(dt, now)
  self.now = now
  stateModule.update(self.game, now)
  local goalEvents = stateModule.evaluateGoals(self.game)
  for _, event in ipairs(goalEvents) do
    local label = event.kind == "achievement" and "Logro" or "Objetivo"
    self:toast(label .. ": " .. event.name .. (event.reward and (" · " .. event.reward) or ""), theme.colors.gold)
  end

  local crossJob = self.game.cross
  if crossJob then
    if crossJob.finished and not self.crossFinishedNotified then
      self.crossFinishedNotified = true
      self:toast("El cruce terminó, pero el nido está lleno. Incuba o libera espacio.", theme.colors.amber)
    end
    self.crossWasActive = true
  elseif self.crossWasActive then
    self.crossWasActive = false
    self.crossFinishedNotified = false
    self:toast("El huevo de cruce está listo en el nido.", theme.colors.essence)
  end

  local pending = #self.game.pendingReveals
  if pending > self.pendingCount and not self.modal then
    self:toast("Huevo listo. Pulsa ABRIR HUEVOS en el Nido.", theme.colors.amber)
  end
  self.pendingCount = pending

  local reminder = self.game.settings.reminder or 0
  if reminder > 0 and not self.modal then
    if now - self.lastReminder >= reminder * 60 then
      self.lastReminder = now
      self:toast("Llevas " .. reminder .. " minutos jugando. Puedes parar cuando quieras.", theme.colors.essence)
    end
  end

  modals.update(self, dt)
end

-- Cabecera
function app:drawHeader()
  local game = self.game
  theme.setColor(theme.colors.bg2, 1)
  love.graphics.rectangle("fill", 0, 0, 1280, 64)
  theme.setColor(theme.colors.bgPattern, 0.35)
  for x = 0, 1279, 16 do
    if (x / 16) % 2 == 0 then
      love.graphics.rectangle("fill", x, 0, 8, 64)
    end
  end
  theme.setColor(theme.colors.sectionDark, 1)
  love.graphics.rectangle("fill", 0, 60, 1280, 4)

  local production = economy.totalProduction(game, self.now or os.time())

  -- Ámbar: tarjeta dorada principal
  theme.panel(12, 8, 212, 46, {
    color = theme.colors.gold,
    borderColor = theme.colors.goldDark,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.iconAmber(30, 31, 11)
  theme.setFont(20)
  theme.setColor(theme.colors.ink, 1)
  love.graphics.print(theme.fmtCompact(game.amber), 48, 10)
  theme.setFont(9)
  theme.setColor(theme.colors.ink, 0.78)
  love.graphics.print("ÁMBAR", 49, 33)
  theme.setColor(theme.colors.ink, 0.9)
  love.graphics.printf("+" .. theme.fmtRate(production) .. "/s", 80, 34, 130, "right")

  theme.panel(234, 8, 144, 46, {
    color = theme.colors.panel2,
    borderColor = theme.colors.teal,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.iconEssence(252, 31, 9)
  theme.setFont(15)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(theme.fmtCompact(game.essence), 268, 15)
  theme.setFont(9)
  theme.setColor(theme.colors.teal, 1)
  love.graphics.print("ESENCIA", 269, 34)

  theme.panel(386, 8, 160, 46, {
    color = theme.colors.panel2,
    borderColor = theme.colors.purple,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.iconLegacy(404, 31, 8)
  theme.setFont(15)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("x" .. theme.fmt(1 + config.prestige.legacyMultiplier * (game.prestige.totalLegacy or 0), 2), 420, 15)
  theme.setFont(9)
  theme.setColor(theme.colors.purple, 1)
  love.graphics.print("LEGADO", 421, 34)

  theme.setFont(14, true)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("CRIADERO DE ÁMBAR", 556, 11)
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("v" .. config.version, 557, 30)

  local trophyX, trophyY = 1168, 10
  local trophyHover = widgets.hover(self, trophyX, trophyY, 44, 44)
  if trophyHover then
    self.tooltip = "Objetivos y logros."
    self.mouse.hand = true
  end
  if widgets.click(self, trophyX, trophyY, 44, 44) then
    self:openModal("goals", {})
  end
  theme.panel(trophyX, trophyY, 44, 44, {
    color = trophyHover and theme.colors.panel3 or theme.colors.panel2,
    borderColor = theme.colors.gold,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.drawTrophy(trophyX + 22, trophyY + 22, 11, theme.colors.goldLight)

  local gearX, gearY = 1222, 10
  local hover = widgets.hover(self, gearX, gearY, 44, 44)
  if hover then
    self.tooltip = "Ajustes y Gran Migración."
    self.mouse.hand = true
  end
  if widgets.click(self, gearX, gearY, 44, 44) then
    self:goto("settings")
  end
  theme.panel(gearX, gearY, 44, 44, {
    color = hover and theme.colors.panel3 or theme.colors.panel2,
    borderColor = theme.colors.border,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.drawGear(gearX + 22, gearY + 22, 12, theme.colors.textDim)
end

-- Acción recomendada: una sola cosa que hacer ahora mismo.
function app:recommendedAction()
  local game = self.game
  local now = self.now or os.time()
  local pending = #(game.pendingReveals or {})
  if pending > 0 then
    return {
      label = "ABRIR HUEVOS (" .. pending .. ")",
      action = "open",
      color = theme.colors.gold,
      tooltip = "Hay " .. pending .. " huevo" .. (pending > 1 and "s" or "") .. " listo" .. (pending > 1 and "s" or "") .. " para abrir.",
    }
  end
  if game.cross and game.cross.finished then
    return {
      label = "RECOGER CRUCE",
      action = "nest",
      color = theme.colors.essence,
      tooltip = "El cruce terminó. Recoge el huevo en el Nido.",
    }
  end
  local freeSlots = 0
  for index = 1, economy.incubatorSlots(game) do
    if not game.incubators[index] then
      freeSlots = freeSlots + 1
    end
  end
  if #game.eggs > 0 and freeSlots > 0 then
    local count = math.min(#game.eggs, freeSlots)
    return {
      label = "INCUBAR " .. count .. " HUEVO" .. (count > 1 and "S" or ""),
      action = "incubate",
      color = theme.colors.amber,
      tooltip = "Hay " .. #game.eggs .. " en el nido y " .. freeSlots .. " incubadora" .. (freeSlots > 1 and "s" or "") .. " libre" .. (freeSlots > 1 and "s" or "") .. ".",
    }
  end
  local unassigned = 0
  local firstUnassigned = nil
  for _, dino in ipairs(game.dinos or {}) do
    if not stateModule.isDinoPending(game, dino.id)
      and not stateModule.isCrossing(game, dino.id)
      and (not dino.role or not dino.habitat) then
      unassigned = unassigned + 1
      firstUnassigned = firstUnassigned or dino.id
    end
  end
  if unassigned > 0 then
    return {
      label = "ASIGNAR ROLES",
      action = "breeding",
      target = firstUnassigned,
      color = theme.colors.teal,
      tooltip = unassigned .. " ejemplar" .. (unassigned > 1 and "es" or "") .. " sin rol o hábitat. Asignarlos mejora la colonia.",
    }
  end
  for _, key in ipairs(config.upgradesOrder) do
    local def = config.upgrades[key]
    local level = game.upgrades[key] or 0
    local cost = economy.upgradeCost(key, level)
    if cost and (game[def.currency] or 0) >= cost then
      return {
        label = "MEJORAR COLONIA",
        action = "upgrades",
        color = theme.colors.green,
        tooltip = "Puedes comprar " .. def.name .. " por " .. theme.fmtInt(cost) .. (def.currency == "amber" and " ámbar." or " esencia."),
      }
    end
  end
  return {
    label = "TODO AL DÍA",
    action = nil,
    color = theme.colors.green,
    tooltip = "No hay acciones urgentes. Sigue criando y abriendo huevos.",
  }
end

function app:drawRecommendedAction(x, y, w, h)
  local action = self:recommendedAction()
  local hover = action.action and widgets.hover(self, x, y, w, h)
  if hover then
    self.tooltip = action.tooltip
    self.mouse.hand = true
  end
  if hover and widgets.click(self, x, y, w, h) then
    if action.action == "open" then
      self:openNextReveal()
    elseif action.action == "incubate" then
      local started = stateModule.incubateAll(self.game, self.now or os.time())
      if started > 0 then
        self:toast("Incubando " .. started .. " huevo" .. (started > 1 and "s" or "") .. ".", theme.colors.amber)
      end
    elseif action.action then
      if action.target then
        self.selectedDino = action.target
      end
      self:goto(action.action)
    end
  end
  local fill = hover and theme.colors.panel3 or theme.colors.panel2
  theme.panel(x, y, w, h, {
    color = fill,
    borderColor = action.color,
    shadowSize = 2,
    borderWidth = 2,
  })
  theme.setColor(action.color, 0.95)
  love.graphics.rectangle("fill", x + 2, y + 2, 3, h - 4)
  theme.setFont(7)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("SIGUIENTE", x + 12, y + 3)
  theme.setFont(9, true)
  theme.setColor(action.action and theme.colors.text or theme.colors.textDim, 1)
  love.graphics.print(action.label, x + 12, y + 14)
  if action.action then
    theme.setFont(12, true)
    theme.setColor(action.color, 1)
    love.graphics.printf(">", x, y + 8, w - 10, "right")
  else
    theme.setColor(theme.colors.green, 1)
    love.graphics.rectangle("fill", x + w - 16, y + 12, 6, 6)
  end
end

-- Navegación izquierda
function app:navInfo(key)
  local game = self.game
  local now = self.now
  if key == "nest" then
    local capacity = economy.nestCapacity(game)
    local pending = #game.pendingReveals
    local sub = #game.eggs .. " / " .. capacity .. " huevos"
    if pending > 0 then
      sub = pending .. " huevo" .. (pending > 1 and "s" or "") .. " listo" .. (pending > 1 and "s" or "")
    end
    return {
      title = "Nido",
      sub = sub,
      bar = #game.eggs / capacity,
      barColor = pending > 0 and theme.colors.gold or theme.colors.amber,
      icon = "nest",
    }
  elseif key == "breeding" then
    local adults = 0
    local visible = 0
    local pending = 0
    for _, dino in ipairs(game.dinos) do
      if stateModule.isDinoPending(game, dino.id) then
        pending = pending + 1
      else
        visible = visible + 1
        if now >= (dino.adultAt or 0) then
          adults = adults + 1
        end
      end
    end
    local total = math.max(1, visible)
    local sub = visible .. (visible == 1 and " ejemplar" or " ejemplares")
      .. " · " .. adults .. (adults == 1 and " adulto" or " adultos")
    if pending > 0 then
      sub = visible .. (visible == 1 and " ejemplar" or " ejemplares")
        .. " · " .. pending .. " por abrir"
    end
    return {
      title = "Criadero",
      sub = sub,
      bar = adults / total,
      barColor = theme.colors.green,
      icon = "breeding",
    }
  elseif key == "cross" then
    local sub = "Sin cruce"
    local bar = 0
    if game.cross then
      sub = game.cross.finished and "Huevo esperando espacio" or ("En curso · " .. theme.fmtTime(math.max(0, game.cross.finishAt - now)))
      bar = math.min(1, (now - game.cross.startedAt) / math.max(1, game.cross.finishAt - game.cross.startedAt))
    end
    return {
      title = "Cruces",
      sub = sub,
      bar = bar,
      barColor = theme.colors.essence,
      icon = "cross",
    }
  elseif key == "upgrades" then
    local levels = 0
    local maxLevels = 0
    for _, upgradeKey in ipairs(config.upgradesOrder) do
      levels = levels + (game.upgrades[upgradeKey] or 0)
      maxLevels = maxLevels + config.upgrades[upgradeKey].max
    end
    return {
      title = "Mejoras",
      sub = "Nivel total " .. levels,
      bar = levels / maxLevels,
      barColor = theme.colors.gold,
      icon = "upgrade",
    }
  elseif key == "dinodex" then
    local total = genetics.dexTotal()
    return {
      title = "Dinodex",
      sub = game.dinodex.total .. " / " .. total .. " · " .. theme.fmtPct(game.dinodex.total / total, 1),
      bar = game.dinodex.total / total,
      barColor = theme.colors.purple,
      icon = "dex",
    }
  elseif key == "log" then
    return {
      title = "Registro",
      sub = theme.fmtInt(game.stats.hatched) .. " huevos abiertos",
      bar = math.min(1, game.stats.hatched / 100),
      barColor = theme.colors.blue,
      icon = "log",
    }
  end
  local motionLabel = "Animaciones"
  if game.settings.calm then
    motionLabel = "Modo tranquilo"
  elseif game.settings.reduceMotion then
    motionLabel = "Mov. reducido"
  end
  local settingsSub = motionLabel
  if not game.settings.calm and not game.settings.reduceMotion then
    settingsSub = settingsSub .. " · Tope "
      .. (game.settings.dailyCap == 0 and "sin límite" or tostring(game.settings.dailyCap))
  end
  return {
    title = "Ajustes",
    sub = settingsSub,
    bar = 0,
    barColor = theme.colors.muted,
    icon = "settings",
  }
end

function app:drawLeftSidebar()
  local x = self.layout.leftX
  theme.sectionBar(x, self.layout.leftY, self.layout.leftW, 30, "CATÁLOGO", { font = 14, icon = "dex" })
  local y = self.layout.leftY + 38
  for index, tab in ipairs(tabs) do
    local info = self:navInfo(tab.key)
    local active = self.scene == tab.key
    local hover = widgets.hover(self, x, y, self.layout.leftW, 64)
    if hover then
      self.mouse.hand = true
    end
    if widgets.click(self, x, y, self.layout.leftW, 64) then
      self:goto(tab.key)
    end
    theme.panel(x, y, self.layout.leftW, 64, {
      color = active and theme.colors.panel3 or (hover and theme.colors.panel2 or theme.colors.panel),
      borderColor = active and theme.colors.border or theme.colors.borderSoft,
      shadowSize = 3,
      borderWidth = active and 3 or 1,
    })
    theme.insetPanel(x + 7, y + 9, 34, 34, {
      color = active and theme.colors.panel2 or theme.colors.bg,
      borderColor = active and theme.colors.border or theme.colors.borderSoft,
    })
    theme.drawNavIcon(info.icon, x + 24, y + 26, 12, active and theme.colors.text or theme.colors.textDim)
    theme.setFont(12)
    theme.setColor(active and theme.colors.text or theme.colors.text, 1)
    love.graphics.print(info.title, x + 49, y + 8)
    theme.setFont(9)
    theme.setColor(active and theme.colors.textDim or theme.colors.muted, 1)
    love.graphics.print(info.sub, x + 49, y + 27)
    widgets.progressBar(x + 49, y + 45, 158, 5, info.bar or 0, info.barColor, {})
    local keyX, keyY = x + self.layout.leftW - 25, y + 8
    theme.panel(keyX, keyY, 17, 17, {
      color = active and theme.colors.panel2 or theme.colors.bg,
      borderColor = active and theme.colors.border or theme.colors.borderSoft,
      shadow = false,
      borderWidth = 1,
    })
    theme.setFont(9, true)
    theme.setColor(active and theme.colors.text or theme.colors.textDim, 1)
    love.graphics.printf(tab.hotkey, keyX, keyY + 4, 17, "center")
    y = y + 68
  end

  local bottomY = 604
  theme.panel(x, bottomY, self.layout.leftW, 92, {
    color = theme.colors.panel,
    borderColor = theme.colors.purple,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.iconLegacy(x + 20, bottomY + 20, 7)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("LEGADO PERMANENTE", x + 36, bottomY + 10)
  theme.setFont(15)
  theme.setColor(theme.colors.purple, 1)
  love.graphics.print("x" .. theme.fmt(prestige.multiplier(self.game), 2), x + 36, bottomY + 23)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Semilla " .. self.game.seed, x + 12, bottomY + 52)
  love.graphics.print(theme.fmtInt(self.game.rng.count) .. " tiradas · v" .. config.version, x + 12, bottomY + 68)
end

function app:drawRightContext(x, y, w, h)
  local game = self.game
  local now = self.now or os.time()
  theme.panel(x, y, w, h, {
    color = theme.colors.panel,
    borderColor = theme.colors.borderSoft,
    shadowSize = 3,
    borderWidth = 2,
  })
  local title, subtitle = "RESUMEN", "El estado de la colonia."
  if self.scene == "cross" then
    title, subtitle = "CRUCE ACTUAL", "Padres, tiempo y fertilidad."
  elseif self.scene == "upgrades" then
    title, subtitle = "RESUMEN", "Lo que produce la colonia ahora."
  elseif self.scene == "dinodex" then
    title, subtitle = "COLECCIÓN", "Tu progreso permanente."
  elseif self.scene == "log" then
    title, subtitle = "REGISTRO", "Últimas aperturas y rarezas."
  elseif self.scene == "settings" then
    title, subtitle = "CONTROLES", "Atajos y ayuda rápida."
  end
  theme.setFont(11, true)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(title, x + 10, y + 8)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf(subtitle, x + 10, y + 24, w - 20, "left")

  local rowY = y + 48
  local function row(label, value, color)
    theme.setFont(9)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print(label, x + 10, rowY)
    theme.setFont(11)
    theme.setColor(color or theme.colors.text, 1)
    love.graphics.printf(value, x + 10, rowY - 1, w - 20, "right")
    rowY = rowY + 28
  end

  if self.scene == "cross" then
    if game.cross then
      local a = stateModule.findDino(game, game.cross.aId)
      local b = stateModule.findDino(game, game.cross.bId)
      local remaining = math.max(0, game.cross.finishAt - now)
      row("Estado", game.cross.finished and "Listo" or "En curso", game.cross.finished and theme.colors.green or theme.colors.essence)
      row("Ejemplar A", a and config.species[a.species].short or "—")
      row("Ejemplar B", b and config.species[b.species].short or "—")
      row("Tiempo", game.cross.finished and "Recoger" or theme.fmtTime(remaining), theme.colors.amber)
      local progress = math.min(1, (now - game.cross.startedAt) / math.max(1, game.cross.finishAt - game.cross.startedAt))
      widgets.progressBar(x + 10, rowY + 2, w - 20, 6, progress, theme.colors.essence, {})
      theme.setFont(8)
      theme.setColor(theme.colors.muted, 1)
      love.graphics.printf(game.cross.finished
        and "El cruce terminó. Recoge el huevo en el Nido."
        or "Puedes seguir criando mientras termina el cruce.", x + 10, y + h - 46, w - 20, "left")
    else
      row("Estado", "Sin cruce", theme.colors.muted)
      row("Consejo", "Misma especie", theme.colors.textDim)
      row("Requisito", "Adultos", theme.colors.textDim)
      theme.setFont(8)
      theme.setColor(theme.colors.muted, 1)
      love.graphics.printf("Elige A y B en la lista de adultos de abajo.", x + 10, y + h - 46, w - 20, "left")
    end
  elseif self.scene == "upgrades" then
    local adults = 0
    for _, dino in ipairs(game.dinos) do
      if now >= (dino.adultAt or 0) then
        adults = adults + 1
      end
    end
    local free = 0
    for index = 1, economy.incubatorSlots(game) do
      if not game.incubators[index] then
        free = free + 1
      end
    end
    local remaining = economy.nextEggInfo(game, now)
    local nestFull = #game.eggs >= economy.nestCapacity(game)
    row("Producción", "+" .. theme.fmtRate(economy.totalProduction(game, now)) .. "/s", theme.colors.amber)
    row("Adultos", adults .. " / " .. #game.dinos)
    row("Huevos", #game.eggs .. " / " .. economy.nestCapacity(game))
    row("Incubadoras", free .. " libres", free > 0 and theme.colors.green or theme.colors.muted)
    row("Próximo huevo", nestFull and "Nido lleno" or (remaining and theme.fmtTime(math.max(0, remaining)) or "—"),
      nestFull and theme.colors.amber or theme.colors.gold)
    theme.setFont(8)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf("Compra mejoras en el panel central. El legado y el Dinodex se conservan.", x + 10, y + h - 46, w - 20, "left")
  elseif self.scene == "dinodex" then
    local discovered = 0
    for _, key in ipairs(config.speciesOrder) do
      if (game.dinodex.bySpecies[key] or 0) > 0 then
        discovered = discovered + 1
      end
    end
    local total = genetics.dexTotal()
    row("Completitud", theme.fmtPct(game.dinodex.total / total, 1), theme.colors.purple)
    row("Variantes", game.dinodex.total .. " / " .. total)
    row("Especies", discovered .. " / " .. #config.speciesOrder, theme.colors.teal)
    row("Mutaciones", tostring(game.stats.mutations or 0), theme.colors.purple)
    row("Hitos", (game.dinodex.milestoneCount or 0) .. " / 4", theme.colors.green)
    theme.setFont(8)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf("Cada variante nueva suma al bonus permanente de producción.", x + 10, y + h - 46, w - 20, "left")
  elseif self.scene == "log" then
    local rarePlus = (game.stats.byRarity.rare or 0) + (game.stats.byRarity.epic or 0) + (game.stats.byRarity.legendary or 0)
    row("Abiertos", tostring(game.stats.opened or 0))
    row("Raros+", tostring(rarePlus), theme.colors.blue)
    row("Legendarios", tostring(game.stats.byRarity.legendary or 0), theme.colors.gold)
    row("Mutaciones", tostring(game.stats.mutations or 0), theme.colors.purple)
    row("Entradas", #game.log .. " / " .. config.stats.maxLog)
    theme.setFont(8)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf("Se conservan las últimas 2.000 aperturas; las estadísticas son de toda la partida.", x + 10, y + h - 46, w - 20, "left")
  else
    row("Pestañas", "1 – 7")
    row("Guardar", "F5")
    row("Volver", "Esc")
    row("Saltar apertura", "Espacio")
    row("Mando", "Stick + A", theme.colors.teal)
    widgets.button(self, x + 10, y + h - 44, w - 20, 30, "CÓMO SE JUEGA", {
      style = "secondary",
      font = 9,
      onClick = function()
        self:openModal("help", {})
      end,
    })
  end
end

-- Mejoras rápidas y prestigio a la derecha
function app:drawRightSidebar()
  local game = self.game
  local x = self.layout.rightX
  local contextual = self.scene ~= "nest" and self.scene ~= "breeding"
  local rightTitles = {
    cross = "CRUCE",
    upgrades = "RESUMEN",
    dinodex = "COLECCIÓN",
    log = "REGISTRO",
    settings = "AYUDA",
  }
  local rightIcons = {
    cross = "cross",
    upgrades = "upgrade",
    dinodex = "dex",
    log = "log",
    settings = "settings",
  }
  theme.tealBar(x, self.layout.rightY, self.layout.rightW, 30,
    contextual and (rightTitles[self.scene] or "RESUMEN") or "MEJORAS",
    { font = 14, icon = contextual and (rightIcons[self.scene] or "upgrade") or "upgrade" })

  local y = self.layout.rightY + 38
  if contextual then
    self:drawRightContext(x, y, self.layout.rightW, 314)
    y = y + 322
  end
  for _, key in ipairs(contextual and {} or quickUpgrades) do
    local def = config.upgrades[key]
    local level = game.upgrades[key] or 0
    local maxed = level >= def.max
    local cost = economy.upgradeCost(key, level)
    local canBuy, reason = stateModule.canBuyUpgrade(game, key)
    local hover = widgets.hover(self, x, y, self.layout.rightW, 74)
    if hover then
      self.mouse.hand = true
      if maxed then
        self.tooltip = def.desc .. " Nivel máximo."
      else
        local missing = math.max(0, cost - (game[def.currency] or 0))
        self.tooltip = def.desc .. " Coste: " .. theme.fmtInt(cost)
          .. (def.currency == "amber" and " ámbar." or " esencia.")
          .. (canBuy and "" or (" Faltan " .. theme.fmtInt(missing) .. "."))
      end
    end
    if widgets.click(self, x, y, self.layout.rightW, 74) and not maxed then
      local ok, value = stateModule.buyUpgrade(game, key)
      if ok then
        self:toast(def.name .. " · nivel " .. game.upgrades[key] .. " por " .. theme.fmtInt(value), theme.colors.gold)
      else
        self:toast(value or "No se pudo comprar.", theme.colors.red)
      end
    end
    theme.panel(x, y, self.layout.rightW, 74, {
      color = hover and theme.colors.panel3 or theme.colors.panel2,
      borderColor = maxed and theme.colors.green or theme.colors.borderSoft,
      shadowSize = 3,
      borderWidth = 2,
    })
    if canBuy and not maxed then
      theme.setColor(theme.colors.green, 0.95)
      love.graphics.rectangle("fill", x, y, 3, 74)
    end
    theme.insetPanel(x + 7, y + 8, 26, 26, {
      color = theme.colors.bg,
      borderColor = theme.colors.borderSoft,
    })
    theme.drawUpgradeIcon(key, x + 20, y + 21, 9, theme.colors.gold)
    theme.setFont(11)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(def.name, x + 40, y + 7)
    theme.setFont(9)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print("Nivel " .. level .. " / " .. def.max, x + 40, y + 23)
    if maxed then
      theme.setFont(9)
      theme.setColor(theme.colors.green, 1)
      love.graphics.print("MÁXIMO", x + 40, y + 39)
    else
      theme.drawIcon(def.currency, x + 46, y + 46, 4)
      theme.setFont(10)
      theme.setColor(canBuy and theme.colors.goldLight or theme.colors.muted, 1)
      love.graphics.print(theme.fmtInt(cost), x + 55, y + 37)
      theme.setFont(9)
      if canBuy then
        theme.setColor(theme.colors.green, 1)
        love.graphics.print("LISTO", x + 55, y + 51)
      else
        local missing = math.max(0, cost - (game[def.currency] or 0))
        theme.setColor(theme.colors.muted, 1)
        love.graphics.print("faltan " .. theme.fmtInt(missing), x + 55, y + 51)
      end
    end
    widgets.progressBar(x + 8, y + 64, self.layout.rightW - 16, 4, level / def.max,
      maxed and theme.colors.green or (canBuy and theme.colors.teal or theme.colors.border), {})
    y = y + 80
  end

  if not contextual then
    widgets.button(self, x, y, self.layout.rightW, 30, "VER TODAS", {
      style = "ghost",
      font = 10,
      onClick = function()
        self:goto("upgrades")
      end,
    })
  end

  local prestigeY = y + 38
  local can, reason = prestige.canPrestige(game)
  local gain = prestige.gain(game)
  local hoverP = widgets.hover(self, x, prestigeY, self.layout.rightW, 52)
  if hoverP then
    self.mouse.hand = true
    self.tooltip = can and ("Ganarías " .. gain .. " de legado permanente.") or reason
  end
  if widgets.click(self, x, prestigeY, self.layout.rightW, 52) then
    if can then
      self.prestigeFounders = {}
      self:openModal("prestige", {})
    else
      self:goto("settings")
      self:toast(reason or "La Gran Migración aún no está disponible.", theme.colors.amber)
    end
  end
  theme.panel(x, prestigeY, self.layout.rightW, 52, {
    color = can and theme.colors.tealDark or theme.colors.panel,
    borderColor = can and theme.colors.teal or theme.colors.borderSoft,
    shadowSize = 4,
    borderWidth = 2,
  })
  theme.iconLegacy(x + 20, prestigeY + 20, 7)
  theme.setFont(14)
  theme.setColor(can and theme.colors.text or theme.colors.muted, 1)
  love.graphics.print("PRESTIGIO", x + 36, prestigeY + 9)
  theme.setFont(8)
  theme.setColor(can and theme.colors.green or theme.colors.muted, 1)
  love.graphics.print(can and ("+" .. gain .. " legado · disponible") or "aún bloqueado", x + 37, prestigeY + 28)

  local statsY = prestigeY + 64
  theme.panel(x, statsY, self.layout.rightW, 146, {
    color = theme.colors.panel,
    borderColor = theme.colors.borderSoft,
    shadowSize = 3,
    borderWidth = 1,
  })
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("COLONIA", x + 10, statsY + 9)
  theme.setFont(19)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("+" .. theme.fmtRate(economy.totalProduction(game, self.now)) .. "/s", x + 10, statsY + 25)
  theme.setFont(8)
  theme.setColor(theme.colors.textDim, 1)
  local adults = 0
  for _, dino in ipairs(game.dinos) do
    if self.now >= (dino.adultAt or 0) then
      adults = adults + 1
    end
  end
  love.graphics.print("Adultos", x + 10, statsY + 54)
  love.graphics.print("Huevos", x + 110, statsY + 54)
  theme.setFont(11)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(adults .. " / " .. #game.dinos, x + 10, statsY + 66)
  love.graphics.print(#game.eggs .. " / " .. economy.nestCapacity(game), x + 110, statsY + 66)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Pity raro", x + 10, statsY + 92)
  theme.setColor(theme.colors.blue, 1)
  love.graphics.print((game.pity.rare or 0) .. " / " .. (config.rates.pity.rareAt - 1), x + 10, statsY + 104)
  theme.setColor(theme.colors.amber, 1)
  theme.setFont(8)
  love.graphics.print("Legendario", x + 110, statsY + 92)
  theme.setColor(theme.colors.amber, 1)
  love.graphics.print((game.pity.legendary or 0) .. " / " .. (config.rates.pity.legendaryAt - 1), x + 110, statsY + 104)
  theme.setFont(7)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Sin conexión · guardado local", x + 10, statsY + 128)
end

-- Tablero de madera
function app:drawBoard()
  local layout = self.layout
  theme.woodBoard(layout.boardX, layout.boardY, layout.boardW, layout.boardH)
  theme.phone(886, 80, 1.12)
  local meta = sceneMeta[self.scene] or sceneMeta.nest
  theme.sectionBar(276, 90, 596, 44, meta.title, {
    font = 18,
    icon = meta.icon,
  })
  self:drawRecommendedAction(676, 97, 186, 30)
  theme.setFont(10)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf(meta.subtitle, 276, 138, 596, "left")
  theme.drawTicket(292, 681, 38, 15, 0.05)
  theme.drawTicket(344, 682, 38, 15, -0.04)
  theme.drawTicket(704, 681, 38, 15, 0.03)
  theme.drawTicket(756, 682, 38, 15, -0.05)
  theme.drawTicket(922, 681, 38, 15, 0.04)
end

function app:drawToasts()
  local time = love.timer.getTime()
  local latest = nil
  for _, toast in ipairs(self.toasts) do
    if time - toast.at < 4.8 then
      latest = toast
    end
  end
  if not latest then
    return
  end
  local fade = math.min(1, (4.8 - (time - latest.at)) / 0.5)
  local w = 430
  local h = 40
  local x = 760
  local y = 10
  theme.panel(x, y, w, h, {
    color = theme.colors.panel,
    borderColor = theme.colors.goldDark,
    shadowSize = 3,
    borderWidth = 2,
    alpha = 0.98 * fade,
  })
  theme.setColor(latest.color, 0.95 * fade)
  love.graphics.rectangle("fill", x, y, 5, h)
  theme.setFont(10)
  theme.setColor(theme.colors.text, fade)
  love.graphics.printf(latest.message, x + 14, y + 8, w - 24, "left")
end

function app:draw()
  theme.background()
  self.mouse.hand = false
  self.tooltip = nil

  local hasModal = self.modal ~= nil
  self.blocked = hasModal
  self:drawHeader()
  self:drawLeftSidebar()
  self:drawRightSidebar()
  self:drawBoard()

  self.blocked = hasModal
  local scene = scenes[self.scene]
  if scene then
    scene.draw(self)
  end

  self.blocked = false
  if self.modal then
    modals.draw(self, self.modal)
  end

  self:drawToasts()
  widgets.drawTooltip(self)

  self.click = nil
  self.wheel = nil
end

function app:hotkey(key)
  for _, tab in ipairs(tabs) do
    if tab.hotkey == key then
      if not self.modal then
        self:goto(tab.key)
      end
      return true
    end
  end
  return false
end

return app
