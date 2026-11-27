local config = require("src.game.config")
local stateModule = require("src.game.state")
local prestige = require("src.game.prestige")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")

local settings = {}

local function reminderOptions()
  local options = {}
  for _, value in ipairs(config.settings.reminderOptions) do
    options[#options + 1] = { value = value, label = value == 0 and "Desactivado" or ("Cada " .. value .. " min") }
  end
  return options
end

local function capOptions()
  local options = {}
  for _, value in ipairs(config.settings.dailyCapOptions) do
    options[#options + 1] = { value = value, label = value == 0 and "Sin tope" or (value .. " huevos") }
  end
  return options
end

function settings.draw(app)
  local game = app.game
  local x = app.layout.contentX
  local y = app.layout.contentY

  theme.panel(x, y, 350, 522, {
    color = theme.colors.panel,
    borderColor = theme.colors.border,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.setFont(13)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("Ajustes", x + 12, y + 10)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Se guardan en tu partida local.", x + 12, y + 28)

  widgets.toggle(app, x + 12, y + 48, 326, 30, "Música", game.settings.music, function(value)
    stateModule.setSetting(game, "music", value)
    app:toast(value and "Música activada." or "Música silenciada.", theme.colors.textDim)
  end, { tooltip = "Música de fondo generada por el juego." })

  widgets.toggle(app, x + 12, y + 82, 326, 30, "Efectos de sonido", game.settings.sfx, function(value)
    stateModule.setSetting(game, "sfx", value)
    app:toast(value and "Efectos activados." or "Efectos silenciados.", theme.colors.textDim)
  end, { tooltip = "Crujidos de cáscara y sonido de eclosión." })

  widgets.toggle(app, x + 12, y + 116, 326, 30, "Modo tranquilo", game.settings.calm, function(value)
    stateModule.setSetting(game, "calm", value)
    app:toast(value and "Modo tranquilo activado." or "Animaciones activadas.", theme.colors.textDim)
  end, { tooltip = "Sin animaciones de apertura." })

  widgets.cycle(app, x + 12, y + 152, 326, 40, "Recordatorio de sesión", game.settings.reminder, reminderOptions(), function(value)
    stateModule.setSetting(game, "reminder", value)
    app.lastReminder = os.time()
  end, { tooltip = "Aviso discreto cada 60 o 90 minutos." })

  widgets.cycle(app, x + 12, y + 196, 326, 40, "Tope diario de huevos", game.settings.dailyCap, capOptions(), function(value)
    stateModule.setSetting(game, "dailyCap", value)
  end, { tooltip = "0 significa sin tope. Solo afecta al nido." })

  theme.setColor(theme.colors.borderSoft, 0.9)
  love.graphics.rectangle("fill", x + 12, y + 244, 326, 1)

  theme.setFont(8)
  theme.setColor(theme.colors.textDim, 1)
  local texts = {
    "El ámbar lo producen los adultos.",
    "La esencia se obtiene al liberar ejemplares.",
    "Las probabilidades del panel son las del motor.",
    "El Dinodex, el pity y el registro nunca se reinician.",
  }
  local textY = y + 256
  for _, text in ipairs(texts) do
    theme.setColor(theme.colors.gold, 0.8)
    love.graphics.rectangle("fill", x + 14, textY + 3, 4, 4)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print(text, x + 24, textY)
    textY = textY + 18
  end

  theme.panel(x + 12, y + 380, 326, 82, {
    color = theme.colors.panel2,
    borderColor = theme.colors.borderSoft,
    shadowSize = 0,
    borderWidth = 1,
  })
  theme.setFont(8)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("TRANSPARENCIA", x + 22, y + 390)
  theme.setFont(7)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Pity raro " .. (game.pity.rare or 0) .. "/" .. (config.rates.pity.rareAt - 1)
    .. " · legendario " .. (game.pity.legendary or 0) .. "/" .. (config.rates.pity.legendaryAt - 1), x + 22, y + 406)
  love.graphics.print("Mutación " .. (game.pity.mutation or 0) .. "/" .. (config.rates.pity.mutationAt - 1)
    .. " · " .. theme.fmtInt(game.stats.hatched) .. " huevos abiertos", x + 22, y + 420)
  widgets.button(app, x + 22, y + 434, 120, 20, "ABRIR REGISTRO", {
    style = "ghost",
    font = 7,
    onClick = function()
      app:goto("log")
    end,
  })

  widgets.button(app, x + 12, y + 338, 150, 32, "GUARDAR AHORA", {
    style = "secondary",
    font = 8,
    onClick = function()
      app:save()
      app:toast("Partida guardada.", theme.colors.green)
    end,
  })
  widgets.button(app, x + 174, y + 338, 164, 32, "CÓMO SE JUEGA", {
    style = "ghost",
    font = 8,
    onClick = function()
      app:openModal("help", {})
    end,
  })

  theme.setFont(7)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Versión " .. config.version .. " · Guardado v" .. config.saveVersion, x + 12, y + 470)
  love.graphics.print("Semilla " .. game.seed .. " · " .. theme.fmtInt(game.rng.count) .. " tiradas", x + 12, y + 484)
  love.graphics.print("Accesibilidad y ajustes se conservan al migrar.", x + 12, y + 498)

  -- Prestigio
  local rx = x + 366
  theme.panel(rx, y, 362, 522, {
    color = theme.colors.panel,
    borderColor = theme.colors.goldDark,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.setFont(13)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("Gran Migración", rx + 12, y + 10)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Reinicia la colonia; conserva lo permanente.", rx + 12, y + 28)

  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("PUNTOS DE LEGADO", rx + 12, y + 56)
  love.graphics.print("MULTIPLICADOR", rx + 190, y + 56)
  theme.setFont(22)
  theme.setColor(theme.colors.purple, 1)
  love.graphics.print(theme.fmtInt(game.prestige.totalLegacy), rx + 12, y + 70)
  theme.setFont(15)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("x" .. theme.fmt(prestige.multiplier(game), 2), rx + 190, y + 76)

  local can, reason = prestige.canPrestige(game)
  local gain, fromDinos, fromDex = prestige.gain(game)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("GANANCIA SI MIGRAS AHORA", rx + 12, y + 116)
  theme.setFont(18)
  theme.setColor(can and theme.colors.gold or theme.colors.muted, 1)
  love.graphics.print("+" .. theme.fmtInt(gain) .. " legado", rx + 12, y + 130)
  theme.setFont(7)
  love.graphics.print("Por ejemplares " .. fromDinos .. " · por Dinodex " .. fromDex, rx + 12, y + 152)

  if not can then
    theme.setFont(8)
    theme.setColor(theme.colors.red, 1)
    love.graphics.printf(reason, rx + 12, y + 176, 338, "left")
    local sinceLast = math.max(0, game.stats.hatched - (game.prestige.baselineHatches or 0))
    widgets.progressBar(rx + 12, y + 208, 338, 8, sinceLast / config.prestige.minHatches, theme.colors.red, {})
  else
    theme.setFont(8)
    theme.setColor(theme.colors.green, 1)
    love.graphics.printf("Listo. Elige hasta " .. config.prestige.maxFounders .. " fundadores en el siguiente paso.",
      rx + 12, y + 176, 338, "left")
  end

  theme.setColor(theme.colors.borderSoft, 0.9)
  love.graphics.rectangle("fill", rx + 12, y + 232, 338, 1)
  theme.setFont(7)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf("SE CONSERVAN: Dinodex, contadores de pity, registro, semilla, ajustes y legado.\nSE REINICIAN: ámbar, esencia, mejoras, huevos, incubadoras y ejemplares (salvo fundadores).",
    rx + 12, y + 246, 338, "left")
  widgets.button(app, rx + 12, y + 340, 338, 44, "PREPARAR GRAN MIGRACIÓN", {
    style = can and "danger" or "secondary",
    disabled = not can,
    font = 10,
    tooltip = can and "Elegir fundadores y confirmar." or reason,
    onClick = function()
      app.prestigeFounders = {}
      app:openModal("prestige", {})
    end,
  })
  theme.setFont(7)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("Se activa tras abrir " .. config.prestige.minHatches
    .. " huevos desde la última migración y resolver los resultados.",
    rx + 12, y + 394, 338, "center")

  theme.setFont(8)
  theme.setColor(theme.colors.ink, 1)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("Semilla " .. game.seed, rx + 12, y + 470)
  theme.setColor(theme.colors.muted, 1)
  theme.setFont(7)
  love.graphics.print(theme.fmtInt(game.rng.count) .. " tiradas registradas", rx + 12, y + 486)
  love.graphics.print("v" .. config.version, rx + 12, y + 500)
end

return settings
