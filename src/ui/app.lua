-- Aplicación de interfaz: cabecera, pestañas, escenas, modales y avisos.
local config = require("src.game.config")
local stateModule = require("src.game.state")
local economy = require("src.game.economy")
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
  { key = "nest", label = "Nido", hotkey = "1" },
  { key = "breeding", label = "Criadero", hotkey = "2" },
  { key = "cross", label = "Cruces", hotkey = "3" },
  { key = "upgrades", label = "Mejoras", hotkey = "4" },
  { key = "dinodex", label = "Dinodex", hotkey = "5" },
  { key = "log", label = "Registro", hotkey = "6" },
  { key = "settings", label = "Ajustes", hotkey = "7" },
}

function app.new(game)
  local self = setmetatable({}, app)
  self.game = game
  self.scene = "nest"
  self.now = os.time()
  self.mouse = { x = -1, y = -1, hand = false }
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

function app:closeModal()
  if self.modal and self.modal.kind == "help" then
    self.game.meta.firstRun = false
    self:save()
  end
  self.modal = nil
  self.click = nil
  self.tooltip = nil
end

function app:save()
  if self.saveCallback then
    local ok, err = self.saveCallback()
    self.saveStatus = ok and "Guardado" or ("Error al guardar: " .. tostring(err))
    self.statusTime = love.timer.getTime()
  end
end

function app:update(dt, now)
  self.now = now
  stateModule.update(self.game, now)

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

  if not self.modal and self.game.pendingReveals[1] then
    self:openModal("reveal", {
      reveal = self.game.pendingReveals[1],
      revealStart = love.timer.getTime(),
      skipped = self.game.settings.calm,
    })
  end

  local reminder = self.game.settings.reminder or 0
  if reminder > 0 and not self.modal then
    if now - self.lastReminder >= reminder * 60 then
      self.lastReminder = now
      self:toast("Llevas " .. reminder .. " minutos jugando. Puedes parar cuando quieras.", theme.colors.essence)
    end
  end
end

function app:drawResource(x, y, w, currency, value, sub, tooltip)
  local hover = widgets.hover(self, x, y, w, 42)
  if hover then
    self.tooltip = tooltip
  end
  theme.drawIcon(currency, x + 14, y + 20, 7)
  theme.setFont(17)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(value, x + 30, y + 7)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print(sub, x + 30, y + 28)
end

function app:drawHeader()
  theme.setColor(theme.colors.bg2, 0.98)
  love.graphics.rectangle("fill", 0, 0, 1280, 56)
  theme.setColor(theme.colors.border, 0.7)
  love.graphics.setLineWidth(1)
  love.graphics.line(0, 56, 1280, 56)

  render.egg(34, 27, 0.34, {})
  theme.setFont(19)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("CRIADERO DE ÁMBAR", 58, 8)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Cría, colecciona y migra", 59, 32)

  local game = self.game
  local production = economy.totalProduction(game, self.now or os.time())
  self.productionRate = production
  self:drawResource(736, 6, 154, "amber", theme.fmtInt(game.amber),
    "+" .. theme.fmtRate(production) .. "/s", "Ámbar: moneda principal. Lo producen los adultos.")
  self:drawResource(898, 6, 146, "essence", theme.fmtInt(game.essence),
    "Esencia", "Esencia: se obtiene al liberar ejemplares.")
  self:drawResource(1052, 6, 200, "legacy", "x" .. theme.fmt(1 + config.prestige.legacyMultiplier * (game.prestige.totalLegacy or 0), 2),
    "Legado permanente", "Multiplicador permanente de ámbar por la Gran Migración.")

end

function app:drawTabs()
  theme.setColor(theme.colors.bg, 0.7)
  love.graphics.rectangle("fill", 0, 57, 1280, 52)
  local gap = 5
  local width = 158
  local total = #tabs * width + (#tabs - 1) * gap
  local startX = (1280 - total) / 2
  for i, tab in ipairs(tabs) do
    local x = startX + (i - 1) * (width + gap)
    local selected = self.scene == tab.key
    widgets.button(self, x, 63, width, 39, tab.label, {
      style = "tab",
      selected = selected,
      font = 14,
      tooltip = "Atajo: " .. tab.hotkey,
      onClick = function()
        self:goto(tab.key)
      end,
    })
    if selected then
      theme.setColor(theme.colors.amber, 1)
      love.graphics.rectangle("fill", x + 18, 100, width - 36, 2, 1, 1)
    end
  end
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
  local w = 360
  local h = 38
  local x = 360
  local y = 9
  theme.setColor(theme.colors.bg2, 0.97 * fade)
  love.graphics.rectangle("fill", x, y, w, h, 9, 9)
  theme.setColor(latest.color, 0.9 * fade)
  love.graphics.rectangle("fill", x, y, 4, h, 2, 2)
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
  self:drawTabs()

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
