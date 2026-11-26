local config = require("src.game.config")
local stateModule = require("src.game.state")
local economy = require("src.game.economy")
local hatch = require("src.game.hatch")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local render = require("src.render.dino")

local nest = {}

local function pityRow(app, x, y, w, label, counter, threshold, color, remaining)
  theme.setFont(9)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(label, x, y)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("en " .. remaining, x + w - 42, y + 1)
  widgets.progressBar(x, y + 15, w, 6, counter / math.max(1, threshold - 1), color, {})
  theme.setFont(7)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print(counter .. " / " .. threshold - 1, x, y + 24)
end

function nest.draw(app)
  local game = app.game
  local now = app.now
  local snap = hatch.snapshot(game)
  local interval = economy.eggInterval(game)
  local capacity = economy.nestCapacity(game)
  local x = app.layout.contentX
  local y = app.layout.contentY

  -- Generador
  theme.panel(x, y, 454, 76, {
    color = theme.colors.panel2,
    borderColor = theme.colors.border,
    shadowSize = 3,
    borderWidth = 2,
  })
  render.egg(x + 28, y + 38, 0.46, {})
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("PRÓXIMO HUEVO", x + 54, y + 10)
  theme.setFont(18)
  theme.setColor(theme.colors.gold, 1)
  local remaining = math.max(0, interval - game.nestTimer)
  love.graphics.print(theme.fmtTime(remaining), x + 54, y + 23)
  widgets.progressBar(x + 54, y + 51, 230, 7, game.nestTimer / interval, theme.colors.amber, {})

  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("NIDO", x + 300, y + 12)
  theme.setFont(13)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(#game.eggs .. " / " .. capacity, x + 300, y + 26)

  local canIncubate = #game.eggs > 0 and stateModule.freeIncubator(game) ~= nil
  widgets.button(app, x + 336, y + 20, 102, 34, "INCUBAR", {
    style = canIncubate and "primary" or "secondary",
    disabled = not canIncubate,
    font = 10,
    onClick = function()
      local started = stateModule.incubateAll(game, now)
      if started > 0 then
        app:toast("Incubando " .. started .. " huevo" .. (started > 1 and "s" or "") .. ".", theme.colors.amber)
      end
    end,
  })

  -- Huevos: tarjeta central
  theme.panel(x, y + 86, 454, 222, {
    color = theme.colors.panel,
    borderColor = theme.colors.border,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.setFont(12)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Huevos sin incubar", x + 12, y + 94)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Clic para incubar", x + 160, y + 97)
  if #game.eggs > 8 then
    theme.setFont(8)
    theme.setColor(theme.colors.gold, 1)
    love.graphics.printf("rueda ↓", x + 380, y + 97, 62, "right")
  end

  local columns = 4
  local cardW = 106
  local cardH = 88
  local gap = 10
  local rows = math.max(1, math.ceil(math.max(1, #game.eggs) / columns))
  widgets.scroll(app, "nest_eggs", x, y + 108, 454, 194, rows * (cardH + gap), function(offset)
    if #game.eggs == 0 then
      widgets.emptyState(x, y + 120, 454, 120, "No hay huevos en el nido",
        "El siguiente aparece en " .. theme.fmtTime(remaining) .. ".")
      return
    end
    for index, egg in ipairs(game.eggs) do
      local row = math.floor((index - 1) / columns)
      local col = (index - 1) % columns
      local ex = x + col * (cardW + gap)
      local ey = y + 108 + row * (cardH + gap) - offset
      if ey + cardH >= y + 108 and ey <= y + 302 then
        local hover = widgets.hover(app, ex, ey, cardW, cardH)
        local free = stateModule.freeIncubator(game)
        if hover then
          app.mouse.hand = true
          app.tooltip = free and "Poner este huevo a incubar." or "No hay incubadoras libres."
        end
        if widgets.click(app, ex, ey, cardW, cardH) and free then
          local ok, message = stateModule.startIncubation(game, egg.id, now)
          if ok then
            app:toast("Huevo en la incubadora.", theme.colors.amber)
          else
            app:toast(message or "No se pudo incubar.", theme.colors.red)
          end
        end
        theme.panel(ex, ey, cardW, cardH, {
          color = hover and theme.colors.panel3 or theme.colors.panel2,
          borderColor = egg.kind == "cruce" and theme.colors.essence or theme.colors.borderSoft,
          shadowSize = 2,
          borderWidth = 1,
        })
        render.egg(ex + 26, ey + 44, 0.34, { cross = egg.kind == "cruce" })
        theme.setFont(10)
        theme.setColor(theme.colors.text, 1)
        love.graphics.print(egg.kind == "cruce" and "Cruce" or "Huevo", ex + 48, ey + 14)
        theme.setFont(8)
        theme.setColor(free and theme.colors.gold or theme.colors.muted, 1)
        love.graphics.print(free and "Incubar" or "Sin hueco", ex + 48, ey + 31)
        theme.setColor(theme.colors.muted, 1)
        love.graphics.print("#" .. egg.id, ex + 48, ey + 45)
      end
    end
  end)

  -- Incubadoras
  theme.setFont(12)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Incubadoras", x, y + 314)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("El resultado se muestra al terminar.", x + 94, y + 317)

  local totalSlots = 4
  local slotW = 106
  local slotGap = 10
  local slotY = y + 334
  for i = 1, totalSlots do
    local sx = x + (i - 1) * (slotW + slotGap)
    local unlocked = i <= economy.incubatorSlots(game)
    local slot = game.incubators[i]
    if not unlocked then
      local hover = widgets.hover(app, sx, slotY, slotW, 142)
      if hover then
        app.mouse.hand = true
        app.tooltip = "Mejora: hueco de incubadora."
      end
      if widgets.click(app, sx, slotY, slotW, 142) then
        app:goto("upgrades")
      end
      theme.panel(sx, slotY, slotW, 142, {
        color = theme.colors.panel,
        borderColor = theme.colors.borderSoft,
        shadowSize = 2,
        borderWidth = 1,
      })
      theme.setFont(8)
      theme.setColor(theme.colors.muted, 1)
      love.graphics.printf("BLOQUEADA", sx, slotY + 44, slotW, "center")
      theme.setFont(7)
      love.graphics.printf("Mejora", sx, slotY + 58, slotW, "center")
      theme.drawLock(sx + slotW / 2, slotY + 88, 13, theme.colors.muted)
    elseif not slot then
      theme.panel(sx, slotY, slotW, 142, {
        color = theme.colors.panel2,
        borderColor = theme.colors.borderSoft,
        shadowSize = 2,
        borderWidth = 1,
      })
      theme.setFont(8)
      theme.setColor(theme.colors.muted, 1)
      love.graphics.printf("Incubadora " .. i, sx, slotY + 10, slotW, "center")
      render.egg(sx + slotW / 2, slotY + 62, 0.32, {})
      widgets.button(app, sx + 14, slotY + 112, slotW - 28, 20, "INCUBAR", {
        style = "ghost",
        font = 7,
        disabled = #game.eggs == 0,
        onClick = function()
          if game.eggs[1] then
            stateModule.startIncubation(game, game.eggs[1].id, now)
          end
        end,
      })
    else
      local progress = math.min(1, (now - slot.startedAt) / math.max(1, slot.finishAt - slot.startedAt))
      theme.panel(sx, slotY, slotW, 142, {
        color = theme.colors.panel2,
        borderColor = progress >= 1 and theme.colors.gold or theme.colors.border,
        shadowSize = 2,
        borderWidth = 1,
      })
      theme.setFont(8)
      theme.setColor(theme.colors.text, 1)
      love.graphics.printf("Incubadora " .. i, sx, slotY + 10, slotW, "center")
      render.egg(sx + slotW / 2, slotY + 62, 0.32, {
        wobble = game.settings.calm and 0
          or math.sin(love.timer.getTime() * 6 + i) * 0.06 * (1 - progress),
        cross = slot.egg.kind == "cruce",
      })
      widgets.progressBar(sx + 12, slotY + 108, slotW - 24, 5, progress, theme.colors.amber, {})
      theme.setFont(7)
      theme.setColor(theme.colors.textDim, 1)
      love.graphics.printf(progress >= 1 and "Abriendo…" or theme.fmtTime(math.max(0, slot.finishAt - now)),
        sx, slotY + 118, slotW, "center")
    end
  end

  widgets.button(app, x, y + 486, 454, 30, "INCUBAR TODO", {
    style = canIncubate and "primary" or "secondary",
    disabled = not canIncubate,
    font = 10,
    onClick = function()
      local started = stateModule.incubateAll(game, now)
      if started > 0 then
        app:toast("Incubando " .. started .. " huevo" .. (started > 1 and "s" or "") .. ".", theme.colors.amber)
      end
    end,
  })

  -- Columna derecha
  local rx = x + 468
  theme.panel(rx, y, 260, 300, {
    color = theme.colors.woodDark,
    borderColor = theme.colors.goldDark,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.setFont(12)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("Garantías", rx + 12, y + 10)
  theme.setFont(8)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf("Contadores reales del motor.", rx + 12, y + 27, 236, "left")
  pityRow(app, rx + 12, y + 46, 236, "Raro o superior", snap.pity.rare, config.rates.pity.rareAt,
    theme.colors.blue, snap.pity.rareIn)
  pityRow(app, rx + 12, y + 96, 236, "Legendario", snap.pity.legendary, config.rates.pity.legendaryAt,
    theme.colors.amber, snap.pity.legendaryIn)
  pityRow(app, rx + 12, y + 146, 236, "Mutación", snap.pity.mutation, config.rates.pity.mutationAt,
    theme.colors.essence, snap.pity.mutationIn)
  widgets.button(app, rx + 12, y + 202, 236, 32, "VER PROBABILIDADES", {
    style = "ghost",
    font = 9,
    onClick = function()
      app:openModal("probabilities", {})
    end,
  })
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("Pity suave desde " .. config.rates.pity.legendarySoftStart .. " legendarios.",
    rx + 12, y + 242, 236, "left")

  theme.panel(rx, y + 312, 260, 118, {
    color = theme.colors.panel,
    borderColor = theme.colors.borderSoft,
    shadowSize = 3,
    borderWidth = 1,
  })
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("RESUMEN", rx + 12, y + 322)
  local adults = 0
  for _, dino in ipairs(game.dinos) do
    if now >= (dino.adultAt or 0) then
      adults = adults + 1
    end
  end
  theme.setFont(16)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("+" .. theme.fmtRate(economy.totalProduction(game, now)) .. "/s", rx + 12, y + 337)
  theme.setFont(8)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.print("Adultos " .. adults .. " / " .. #game.dinos, rx + 12, y + 361)
  love.graphics.print("Huevos de hoy " .. (economy.dailyCap(game) > 0
    and (game.daily.eggs .. " / " .. economy.dailyCap(game)) or "sin tope"), rx + 12, y + 376)
  love.graphics.print("Capacidad del nido " .. capacity, rx + 12, y + 391)
  love.graphics.print("Incubadoras " .. economy.incubatorSlots(game) .. " / 4", rx + 12, y + 406)

  theme.panel(rx, y + 442, 260, 80, {
    color = theme.colors.panel,
    borderColor = theme.colors.borderSoft,
    shadowSize = 3,
    borderWidth = 1,
  })
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("ATAJOS", rx + 12, y + 452)
  love.graphics.print("1-7 pestañas · rueda · Esc", rx + 12, y + 466)
  love.graphics.print("Semilla " .. game.seed, rx + 12, y + 490)
  widgets.button(app, rx + 12, y + 502, 116, 20, "REGISTRO", {
    style = "ghost",
    font = 7,
    onClick = function()
      app:goto("log")
    end,
  })
  widgets.button(app, rx + 132, y + 500, 116, 20, "CÓMO SE JUEGA", {
    style = "ghost",
    font = 8,
    onClick = function()
      app:openModal("help", {})
    end,
  })
end

return nest
