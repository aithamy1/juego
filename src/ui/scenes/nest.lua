local config = require("src.game.config")
local stateModule = require("src.game.state")
local economy = require("src.game.economy")
local hatch = require("src.game.hatch")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local render = require("src.render.dino")

local nest = {}

local function pityBar(app, x, y, label, counter, threshold, color, detail)
  local fraction = counter / math.max(1, threshold - 1)
  theme.setFont(12)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(label, x, y)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print(detail, x, y + 18)
  widgets.progressBar(x, y + 37, 342, 9, fraction, color)
  theme.setFont(10)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.print(string.format("%d / %d", counter, threshold - 1), x + 302, y + 17)
end

function nest.draw(app)
  local game = app.game
  local now = app.now
  local snap = hatch.snapshot(game)
  local interval = economy.eggInterval(game)
  local capacity = economy.nestCapacity(game)

  widgets.sectionTitle("Nido", "Los huevos aparecen solos. Incuba, abre y decide qué hacer con cada ejemplar.", 28, 120, 780)

  -- Generador
  theme.panel(28, 176, 790, 84)
  render.egg(64, 216, 0.45, {})
  theme.setFont(14)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Próximo huevo del nido", 102, 189)
  local remaining = math.max(0, interval - game.nestTimer)
  theme.setFont(11)
  theme.setColor(theme.colors.muted, 1)
  if economy.dailyCapReached(game, now) then
    love.graphics.print("Tope diario alcanzado. Se reanuda mañana.", 102, 209)
  elseif #game.eggs >= capacity then
    love.graphics.print("Nido lleno. Incuba o libera espacio.", 102, 209)
  else
    love.graphics.print("Cada " .. theme.fmtTime(interval) .. " · " .. theme.fmtTime(remaining) .. " para el siguiente", 102, 209)
  end
  widgets.progressBar(102, 230, 306, 8, game.nestTimer / interval, theme.colors.amber)

  theme.setFont(11)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.print("Nido", 430, 187)
  theme.setFont(18)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(string.format("%d / %d", #game.eggs, capacity), 430, 203)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("huevos sin incubar", 430, 226)

  local canIncubate = #game.eggs > 0 and stateModule.freeIncubator(game) ~= nil
  widgets.button(app, 596, 196, 202, 44, "Incubar todo", {
    style = canIncubate and "primary" or "secondary",
    disabled = not canIncubate,
    tooltip = "Coloca huevos en todas las incubadoras libres.",
    onClick = function()
      local started = stateModule.incubateAll(game, now)
      if started > 0 then
        app:toast("Incubando " .. started .. " huevo" .. (started > 1 and "s" or "") .. ".", theme.colors.amber)
      end
    end,
  })

  -- Huevos
  theme.setFont(15)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Huevos sin incubar", 28, 278)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Haz clic en un huevo para ponerlo a incubar.", 190, 282)

  local columns = 5
  local cardW = 146
  local cardH = 82
  local gap = 10
  local rows = math.max(1, math.ceil(math.max(1, #game.eggs) / columns))
  local contentH = rows * (cardH + gap)
  widgets.scroll(app, "nest_eggs", 28, 302, 790, 184, contentH, function(offset)
    if #game.eggs == 0 then
      widgets.emptyState(28, 302 + 18, 790, 140, "No hay huevos en el nido",
        "El siguiente aparece en " .. theme.fmtTime(remaining) .. ". También puedes crear uno con un cruce.")
      return
    end
    for index, egg in ipairs(game.eggs) do
      local row = math.floor((index - 1) / columns)
      local col = (index - 1) % columns
      local x = 28 + col * (cardW + gap)
      local y = 302 + row * (cardH + gap) - offset
      if y + cardH >= 302 and y <= 302 + 184 then
        local hover = widgets.hover(app, x, y, cardW, cardH)
        local free = stateModule.freeIncubator(game)
        if hover then
          app.mouse.hand = true
          app.tooltip = free and "Poner este huevo a incubar." or "No hay incubadoras libres."
        end
        if widgets.click(app, x, y, cardW, cardH) and free then
          local ok, message = stateModule.startIncubation(game, egg.id, now)
          if ok then
            app:toast("Huevo en la incubadora.", theme.colors.amber)
          else
            app:toast(message or "No se pudo incubar.", theme.colors.red)
          end
        end
        theme.panel(x, y, cardW, cardH, {
          color = hover and theme.colors.panel3 or theme.colors.panel2,
          borderColor = egg.kind == "cruce" and theme.colors.essence or theme.colors.borderSoft,
        })
        render.egg(x + 34, y + 42, 0.38, { cross = egg.kind == "cruce" })
        theme.setFont(egg.kind == "cruce" and 9 or 12)
        theme.setColor(theme.colors.text, 1)
        love.graphics.print(egg.kind == "cruce" and "Huevo de cruce" or "Huevo", x + 62, y + 20)
        theme.setFont(10)
        theme.setColor(free and theme.colors.amber or theme.colors.muted, 1)
        love.graphics.print(free and "Incubar" or "Sin hueco", x + 62, y + 38)
        theme.setColor(theme.colors.muted, 0.8)
        love.graphics.print("#" .. egg.id, x + 62, y + 58)
      end
    end
  end)

  -- Incubadoras
  theme.setFont(15)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Incubadoras", 28, 496)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Al terminar, el huevo se abre y verás el resultado. No hay sorpresas ocultas.", 128, 500)

  local totalSlots = 4
  local slotGap = 12
  local slotW = (790 - slotGap * (totalSlots - 1)) / totalSlots
  for i = 1, totalSlots do
    local x = 28 + (i - 1) * (slotW + slotGap)
    local y = 522
    local unlocked = i <= economy.incubatorSlots(game)
    local slot = game.incubators[i]
    if not unlocked then
      theme.panel(x, y, slotW, 166, { color = theme.colors.panel, borderColor = theme.colors.borderSoft })
      theme.setFont(11)
      theme.setColor(theme.colors.muted, 1)
      love.graphics.printf("Bloqueada", x, y + 48, slotW, "center")
      theme.setFont(10)
      love.graphics.printf("Mejora: hueco de incubadora", x + 10, y + 68, slotW - 20, "center")
      widgets.button(app, x + 24, y + 116, slotW - 48, 30, "Ver mejoras", {
        style = "ghost",
        onClick = function()
          app:goto("upgrades")
        end,
      })
    elseif not slot then
      theme.panel(x, y, slotW, 166, { borderColor = theme.colors.borderSoft })
      theme.setFont(12)
      theme.setColor(theme.colors.muted, 1)
      love.graphics.printf("Incubadora " .. i, x, y + 16, slotW, "center")
      theme.setFont(10)
      love.graphics.printf("Libre", x, y + 80, slotW, "center")
      widgets.button(app, x + 24, y + 116, slotW - 48, 30, "Incubar siguiente", {
        style = "ghost",
        disabled = #game.eggs == 0,
        onClick = function()
          if game.eggs[1] then
            stateModule.startIncubation(game, game.eggs[1].id, now)
          end
        end,
      })
    else
      local progress = math.min(1, (now - slot.startedAt) / math.max(1, slot.finishAt - slot.startedAt))
      local left = math.max(0, slot.finishAt - now)
      theme.panel(x, y, slotW, 166, {
        borderColor = progress >= 1 and theme.colors.amber or theme.colors.border,
      })
      theme.setFont(12)
      theme.setColor(theme.colors.text, 1)
      love.graphics.printf("Incubadora " .. i, x, y + 12, slotW, "center")
      render.egg(x + slotW / 2, y + 72, 0.44, {
        wobble = game.settings.calm and 0
          or math.sin(love.timer.getTime() * 6 + i) * 0.06 * (1 - progress),
        cross = slot.egg.kind == "cruce",
      })
      widgets.progressBar(x + 16, y + 122, slotW - 32, 8, progress, theme.colors.amber)
      theme.setFont(10)
      theme.setColor(theme.colors.textDim, 1)
      love.graphics.printf(progress >= 1 and "Abriendo…" or ("Quedan " .. theme.fmtTime(left)), x, y + 138, slotW, "center")
    end
  end

  -- Panel derecho: garantías
  theme.panel(838, 176, 414, 292, { color = theme.colors.panel })
  theme.setFont(17)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Garantías a la vista", 858, 192)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("Los contadores son los del motor. Las garantías no se reinician con el prestigio.", 858, 216, 374, "left")

  pityBar(app, 858, 244, "Raro o superior", snap.pity.rare, config.rates.pity.rareAt,
    theme.colors.blue, "Garantizado en " .. snap.pity.rareIn .. " huevo" .. (snap.pity.rareIn == 1 and "" or "s"))
  pityBar(app, 858, 312, "Legendario", snap.pity.legendary, config.rates.pity.legendaryAt,
    theme.colors.amber, "Pity suave desde " .. config.rates.pity.legendarySoftStart .. " · en " .. snap.pity.legendaryIn)
  pityBar(app, 858, 380, "Mutación", snap.pity.mutation, config.rates.pity.mutationAt,
    theme.colors.essence, "Garantizada en " .. snap.pity.mutationIn .. " huevo" .. (snap.pity.mutationIn == 1 and "" or "s"))

  widgets.button(app, 858, 432, 374, 24, "Ver probabilidades exactas", {
    style = "ghost",
    onClick = function()
      app:openModal("probabilities", {})
    end,
  })

  -- Panel derecho: resumen
  theme.panel(838, 484, 414, 206, { color = theme.colors.panel })
  theme.setFont(13)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.print("Resumen de la colonia", 858, 500)
  local adults = 0
  for _, dino in ipairs(game.dinos) do
    if now >= (dino.adultAt or 0) then
      adults = adults + 1
    end
  end
  local production = economy.totalProduction(game, now)
  theme.setFont(11)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Adultos", 858, 530)
  love.graphics.print("Producción", 1010, 530)
  theme.setFont(20)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(adults .. " / " .. #game.dinos, 858, 546)
  theme.setFont(14)
  theme.setColor(theme.colors.amber, 1)
  love.graphics.print("+" .. theme.fmtRate(production) .. " ámbar/s", 1010, 550)

  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  local cap = economy.dailyCap(game)
  if cap > 0 then
    love.graphics.print("Huevos de hoy: " .. game.daily.eggs .. " / " .. cap, 858, 584)
  else
    love.graphics.print("Tope diario: sin límite (puedes cambiarlo en Ajustes)", 858, 584)
  end
  love.graphics.print("Semilla " .. game.seed .. " · " .. theme.fmtInt(game.rng.count) .. " tiradas", 858, 602)

  widgets.button(app, 858, 630, 178, 38, "Abrir registro", {
    style = "ghost",
    onClick = function()
      app:goto("log")
    end,
  })
  widgets.button(app, 1054, 630, 178, 38, "Cómo se juega", {
    style = "ghost",
    onClick = function()
      app:openModal("help", {})
    end,
  })
end

return nest
