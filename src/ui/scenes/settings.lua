local config = require("src.game.config")
local stateModule = require("src.game.state")
local prestige = require("src.game.prestige")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")

local settings = {}

local function reminderOptions()
  local options = {}
  for _, value in ipairs(config.settings.reminderOptions) do
    options[#options + 1] = {
      value = value,
      label = value == 0 and "Desactivado" or ("Cada " .. value .. " min"),
    }
  end
  return options
end

local function capOptions()
  local options = {}
  for _, value in ipairs(config.settings.dailyCapOptions) do
    options[#options + 1] = {
      value = value,
      label = value == 0 and "Sin tope" or (value .. " huevos"),
    }
  end
  return options
end

function settings.draw(app)
  local game = app.game
  widgets.sectionTitle("Ajustes y prestigio", "El juego no te mete prisa. Puedes desactivar animaciones, poner un tope diario y migrar cuando quieras.", 28, 120, 900)

  theme.panel(28, 170, 596, 520, { color = theme.colors.panel })
  theme.setFont(17)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Ajustes", 48, 188)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("Todo se guarda en el archivo local del juego.", 48, 212, 540, "left")

  widgets.toggle(app, 48, 244, 556, 36, "Modo tranquilo (sin animaciones de apertura)", game.settings.calm, function(value)
    stateModule.setSetting(game, "calm", value)
    app:toast(value and "Modo tranquilo activado." or "Animaciones activadas.", theme.colors.textDim)
  end, { tooltip = "La apertura de huevos se muestra de inmediato, sin animación." })

  widgets.cycle(app, 48, 296, 270, 54, "Recordatorio de sesión", game.settings.reminder, reminderOptions(), function(value)
    stateModule.setSetting(game, "reminder", value)
    app.lastReminder = os.time()
  end, { tooltip = "Un aviso discreto cada 60 o 90 minutos. Nunca bloquea el juego." })

  widgets.cycle(app, 334, 296, 270, 54, "Tope diario de huevos", game.settings.dailyCap, capOptions(), function(value)
    stateModule.setSetting(game, "dailyCap", value)
  end, { tooltip = "Limita los huevos que genera el nido cada día. 0 significa sin tope." })

  theme.setColor(theme.colors.borderSoft, 0.8)
  love.graphics.line(48, 370, 604, 370)

  theme.setFont(12)
  theme.setColor(theme.colors.textDim, 1)
  local texts = {
    "El ámbar lo producen los adultos de forma pasiva.",
    "La esencia se obtiene al liberar ejemplares.",
    "Las probabilidades del panel son las que usa el motor, no una copia.",
    "El Dinodex, el pity y el registro nunca se reinician.",
  }
  local textY = 386
  for _, text in ipairs(texts) do
    theme.setColor(theme.colors.amber, 0.8)
    love.graphics.circle("fill", 52, textY + 7, 2)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print(text, 64, textY)
    textY = textY + 22
  end

  widgets.button(app, 48, 500, 170, 36, "Guardar ahora", {
    style = "secondary",
    onClick = function()
      app:save()
      app:toast("Partida guardada.", theme.colors.green)
    end,
  })
  widgets.button(app, 228, 500, 170, 36, "Cómo se juega", {
    style = "ghost",
    onClick = function()
      app:openModal("help", {})
    end,
  })
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("Versión " .. config.version .. " · Guardado v" .. config.saveVersion
    .. " · Semilla " .. game.seed .. " · " .. theme.fmtInt(game.rng.count) .. " tiradas",
    48, 610, 556, "left")
  love.graphics.printf("Los ajustes de accesibilidad se conservan entre migraciones.",
    48, 630, 556, "left")

  -- Prestigio
  theme.panel(648, 170, 604, 520, { color = theme.colors.panel })
  theme.setFont(17)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Gran Migración", 668, 188)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("Reinicia la colonia y conserva lo que hace único tu Dinodex.", 668, 212, 560, "left")

  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Puntos de legado", 668, 246)
  love.graphics.print("Multiplicador permanente", 858, 246)
  theme.setFont(24)
  theme.setColor(theme.colors.purple, 1)
  love.graphics.print(theme.fmtInt(game.prestige.totalLegacy), 668, 264)
  theme.setFont(18)
  theme.setColor(theme.colors.amber, 1)
  love.graphics.print("x" .. theme.fmt(prestige.multiplier(game), 2), 858, 270)

  local can, reason = prestige.canPrestige(game)
  local gain, fromDinos, fromDex = prestige.gain(game)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Ganancia si migras ahora", 668, 314)
  theme.setFont(20)
  theme.setColor(can and theme.colors.purple or theme.colors.muted, 1)
  love.graphics.print("+" .. theme.fmtInt(gain) .. " legado", 668, 332)
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print(fromDinos .. " por ejemplares · " .. fromDex .. " por Dinodex", 668, 358)

  if not can then
    theme.setFont(10)
    theme.setColor(theme.colors.red, 1)
    love.graphics.printf(reason, 668, 386, 560, "left")
    local sinceLast = math.max(0, game.stats.hatched - (game.prestige.baselineHatches or 0))
    widgets.progressBar(668, 406, 560, 8, sinceLast / config.prestige.minHatches, theme.colors.red)
  else
    theme.setFont(10)
    theme.setColor(theme.colors.green, 1)
    love.graphics.printf("Listo para migrar. Elige hasta " .. config.prestige.maxFounders .. " fundadores en el siguiente paso.",
      668, 386, 560, "left")
  end

  theme.setColor(theme.colors.borderSoft, 0.8)
  love.graphics.line(668, 430, 1232, 430)
  theme.setFont(10)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf("Se conservan: Dinodex, contadores de pity, registro de huevos, semilla, ajustes y puntos de legado.\nSe reinician: ámbar, esencia, mejoras, huevos, incubadoras y ejemplares (salvo fundadores).",
    668, 446, 560, "left")
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("La semilla y el registro permiten auditar cada tirada de la partida.", 668, 496)

  widgets.button(app, 668, 530, 560, 46, "Preparar Gran Migración", {
    style = can and "primary" or "secondary",
    disabled = not can,
    tooltip = can and "Elegir fundadores y confirmar el reinicio." or reason,
    onClick = function()
      app.prestigeFounders = {}
      app:openModal("prestige", {})
    end,
  })
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("El botón se activa tras abrir " .. config.prestige.minHatches .. " huevos desde la última migración y resolver todos los resultados.",
    668, 586, 560, "center")
end

return settings
