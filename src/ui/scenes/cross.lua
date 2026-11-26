local config = require("src.game.config")
local stateModule = require("src.game.state")
local economy = require("src.game.economy")
local genetics = require("src.game.genetics")
local hatch = require("src.game.hatch")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local render = require("src.render.dino")

local cross = {}

local function selectedDinos(app)
  local selection = app.crossSelect
  return stateModule.findDino(app.game, selection.a), stateModule.findDino(app.game, selection.b)
end

local function slotCard(app, x, y, w, h, title, dino, onClear)
  theme.panel(x, y, w, h, {
    color = theme.colors.panel2,
    borderColor = dino and theme.colors.amber or theme.colors.borderSoft,
  })
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print(title, x + 14, y + 10)
  if dino then
    render.drawDino(dino, x + 66, y + 66, 0.52, {})
    theme.setFont(14)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(config.species[dino.species].name, x + 122, y + 24)
    widgets.rarityChip(x + 122, y + 46, dino.rarity, true)
    theme.setFont(10)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print("+" .. theme.fmtRate(economy.dinoRate(dino, app.game)) .. " ámbar/s", x + 122, y + 70)
    widgets.button(app, x + w - 70, y + 8, 58, 24, "Quitar", {
      style = "ghost",
      font = 10,
      onClick = onClear,
    })
  else
    theme.setFont(12)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf("Elige un adulto en la lista de abajo.", x + 20, y + h / 2 - 10, w - 40, "center")
  end
end

local function drawGeneDistribution(x, y, w, gene, entries)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print(genetics.geneLabels[gene], x, y)
  local parts = {}
  for _, entry in ipairs(entries) do
    local def
    if gene == "pattern" then
      def = config.patterns[entry.value]
    elseif gene == "primaryColor" then
      def = config.colors[entry.value]
    elseif gene == "secondaryColor" then
      def = config.secondaryColors[entry.value]
    else
      def = config.crests[entry.value]
    end
    parts[#parts + 1] = (def and def.name or entry.value) .. " " .. theme.fmtPct(entry.probability, 0)
  end
  local text = table.concat(parts, "  ·  ")
  theme.setFont(10)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf(text, x, y + 16, w, "left")
  local font = theme.fontFor(10)
  local _, lines = font:getWrap(text, w)
  return 18 + #lines * font:getHeight() + 5
end

local function drawSimulator(app, a, b, x, y, w, h, now)
  theme.panel(x, y, w, h, { color = theme.colors.panel })
  theme.setFont(16)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Simulador de cruce", x + 20, y + 18)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("Probabilidades exactas calculadas con los alelos de estos dos ejemplares.", x + 20, y + 42, w - 40, "left")

  local sim = genetics.simulate(a, b)
  local chance = hatch.mutationProbability(app.game)
  local duration = economy.crossDuration(a, b)
  local rarityChance = genetics.rarityUpgradeChance(a, b)
  local indexA = 1
  local indexB = 1
  for i, key in ipairs(config.rarityOrder) do
    if key == a.rarity then
      indexA = i
    end
    if key == b.rarity then
      indexB = i
    end
  end
  local baseIndex = math.max(indexA, indexB)
  local baseRarity = config.rarityOrder[baseIndex]
  local upgraded = config.rarityOrder[math.min(#config.rarityOrder, baseIndex + 1)] or baseRarity
  if baseIndex >= #config.rarityOrder then
    rarityChance = 0
  end

  local lineY = y + 72
  theme.setFont(11)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Rareza del hijo", x + 20, lineY)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(config.rarity[baseRarity].name .. " · " .. theme.fmtPct(1 - rarityChance, 0)
    .. " / " .. config.rarity[upgraded].name .. " · " .. theme.fmtPct(rarityChance, 0), x + 150, lineY)
  lineY = lineY + 20
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Mutación espontánea", x + 20, lineY)
  theme.setColor(chance >= 1 and theme.colors.green or theme.colors.text, 1)
  love.graphics.print(chance >= 1 and "Garantizada en este cruce" or theme.fmtPct(chance, 2), x + 150, lineY)
  lineY = lineY + 20
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Duración", x + 20, lineY)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(theme.fmtTime(duration), x + 150, lineY)

  lineY = lineY + 30
  theme.setFont(12)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.print("Genes visibles", x + 20, lineY)
  lineY = lineY + 20
  for _, gene in ipairs({ "pattern", "primaryColor", "secondaryColor", "crest" }) do
    lineY = lineY + drawGeneDistribution(x + 20, lineY, w - 40, gene, sim.distributions[gene])
  end

  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf(string.format("%d combinaciones visibles posibles. La mutación se sortea aparte.", #sim.combos),
    x + 20, y + h - 112, w - 40, "left")
  widgets.button(app, x + 20, y + h - 90, w - 40, 30, "Ver todas las combinaciones", {
    style = "ghost",
    font = 11,
    onClick = function()
      app:openModal("combos", { combos = sim.combos, a = a, b = b })
    end,
  })
  widgets.button(app, x + 20, y + h - 50, w - 40, 36, "Iniciar cruce", {
    style = "primary",
    tooltip = "Consume el tiempo de cruce y genera un huevo con la herencia calculada.",
    onClick = function()
      local ok, err = stateModule.startCross(app.game, a.id, b.id, now)
      if ok then
        app.crossSelect.a = nil
        app.crossSelect.b = nil
        app.crossWasActive = true
        app:toast("Cruce iniciado. Tardará " .. theme.fmtTime(duration) .. ".", theme.colors.essence)
      else
        app:toast(err or "No se pudo iniciar el cruce.", theme.colors.red)
      end
    end,
  })
end

local function drawActiveCross(app, x, y, w, h, now)
  local job = app.game.cross
  theme.panel(x, y, w, h, { color = theme.colors.panel, borderColor = theme.colors.essence })
  theme.setFont(16)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Cruce en curso", x + 20, y + 18)
  local a = stateModule.findDino(app.game, job.aId)
  local b = stateModule.findDino(app.game, job.bId)
  if a then
    render.drawDino(a, x + 86, y + 92, 0.55, {})
    theme.setFont(12)
    theme.setColor(theme.colors.text, 1)
    love.graphics.printf(config.species[a.species].name, x + 20, y + 124, 130, "center")
  end
  if b then
    render.drawDino(b, x + w - 86, y + 92, 0.55, {})
    theme.setFont(12)
    theme.setColor(theme.colors.text, 1)
    love.graphics.printf(config.species[b.species].name, x + w - 150, y + 124, 130, "center")
  end
  theme.setFont(26)
  theme.setColor(theme.colors.amber, 1)
  local remaining = math.max(0, job.finishAt - now)
  love.graphics.printf(theme.fmtTime(remaining), x + 150, y + 58, w - 300, "center")
  local progress = math.min(1, (now - job.startedAt) / math.max(1, job.finishAt - job.startedAt))
  widgets.progressBar(x + 150, y + 96, w - 300, 10, progress, theme.colors.essence)
  theme.setFont(10)
  if job.finished then
    theme.setColor(theme.colors.amber, 1)
    love.graphics.printf("El huevo de cruce está listo, pero el nido no tiene espacio. Incuba o libera huevos.",
      x + 140, y + 112, w - 280, "center")
  else
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf("Mismo cruce para los dos progenitores. El huevo aparecerá en el nido al terminar.",
      x + 140, y + 112, w - 280, "center")
  end
end

function cross.draw(app)
  local game = app.game
  local now = app.now
  widgets.sectionTitle("Cruces", "Dos adultos de la misma especie. La herencia es mendeliana y el simulador muestra las probabilidades reales.", 28, 120, 790)

  local a, b = selectedDinos(app)
  if app.crossSelect.a and not a then
    app.crossSelect.a = nil
  end
  if app.crossSelect.b and not b then
    app.crossSelect.b = nil
  end

  if game.cross then
    drawActiveCross(app, 28, 176, 790, 150, now)
  else
    slotCard(app, 28, 176, 380, 142, "Progenitor A", a, function()
      app.crossSelect.a = nil
    end)
    slotCard(app, 438, 176, 380, 142, "Progenitor B", b, function()
      app.crossSelect.b = nil
    end)
  end

  theme.setFont(15)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Adultos disponibles", 28, 344)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("Elige A y B. Solo se pueden cruzar adultos de la misma especie y libres.", 190, 348, 620, "left")

  local adults = {}
  for _, dino in ipairs(game.dinos) do
    if now >= (dino.adultAt or 0) then
      adults[#adults + 1] = dino
    end
  end
  table.sort(adults, function(left, right)
    if left.species ~= right.species then
      return left.species < right.species
    end
    if left.rarity ~= right.rarity then
      local ia, ib = 1, 1
      for i, key in ipairs(config.rarityOrder) do
        if key == left.rarity then
          ia = i
        end
        if key == right.rarity then
          ib = i
        end
      end
      return ia > ib
    end
    return left.id < right.id
  end)

  local rowH = 66
  local contentH = #adults * rowH
  widgets.scroll(app, "cross_list", 28, 370, 790, 320, contentH, function(offset)
    if #adults == 0 then
      widgets.emptyState(28, 390, 790, 160, "Todavía no hay adultos",
        "Los dinosaurios maduran tras unos segundos. Espera o incuba más huevos.")
      return
    end
    for index, dino in ipairs(adults) do
      local y = 370 + (index - 1) * rowH - offset
      if y + rowH >= 370 and y <= 690 then
        local isA = app.crossSelect.a == dino.id
        local isB = app.crossSelect.b == dino.id
        local busy = stateModule.isCrossing(game, dino.id)
        local activeCross = game.cross ~= nil
        local wrongSpecies = a and not isA and dino.species ~= a.species
        local hover = widgets.hover(app, 28, y + 4, 790, rowH - 6)
        theme.panel(28, y + 4, 790, rowH - 6, {
          color = (isA or isB) and theme.colors.panel3 or (hover and theme.colors.panel2 or theme.colors.panel),
          borderColor = (isA or isB) and theme.colors.amber or theme.colors.borderSoft,
        })
        render.drawDino(dino, 66, y + 35, 0.36, {})
        theme.setFont(13)
        theme.setColor(theme.colors.text, 1)
        love.graphics.print(config.species[dino.species].name, 104, y + 14)
        widgets.rarityChip(104, y + 36, dino.rarity, true)
        theme.setFont(9)
        theme.setColor(theme.colors.muted, 1)
        love.graphics.print("+" .. theme.fmtRate(economy.dinoRate(dino, game)) .. "/s", 260, y + 38)
        if busy then
          widgets.chip(330, y + 18, "En cruce", theme.colors.essence, { font = 10 })
        end
        widgets.button(app, 560, y + 17, 72, 28, isA and "Quitar A" or "Elegir A", {
          style = isA and "primary" or "ghost",
          font = 10,
          disabled = busy or activeCross or (b and b.species ~= dino.species and not isA),
          tooltip = "Asignar como progenitor A.",
          onClick = function()
            if isA then
              app.crossSelect.a = nil
            else
              app.crossSelect.a = dino.id
              if app.crossSelect.b == dino.id then
                app.crossSelect.b = nil
              end
              local chosenB = app.crossSelect.b and stateModule.findDino(game, app.crossSelect.b) or nil
              if chosenB and chosenB.species ~= dino.species then
                app.crossSelect.b = nil
                app:toast("El progenitor B era de otra especie y se ha quitado.", theme.colors.amber)
              end
            end
          end,
        })
        widgets.button(app, 642, y + 17, 72, 28, isB and "Quitar B" or "Elegir B", {
          style = isB and "primary" or "ghost",
          font = 10,
          disabled = busy or activeCross or not a or wrongSpecies,
          tooltip = not a and "Elige primero el progenitor A."
            or (wrongSpecies and "Debe ser de la misma especie que A." or "Asignar como progenitor B."),
          onClick = function()
            if isB then
              app.crossSelect.b = nil
            else
              app.crossSelect.b = dino.id
            end
          end,
        })
        widgets.button(app, 724, y + 17, 76, 28, "Ficha", {
          style = "ghost",
          font = 10,
          onClick = function()
            app.selectedDino = dino.id
            app:goto("breeding")
          end,
        })
      end
    end
  end)

  if game.cross then
    theme.panel(838, 176, 414, 514, { color = theme.colors.panel })
    theme.setFont(16)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print("Mientras esperas", 858, 194)
    theme.setFont(11)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf("Los padres están ocupados hasta que termine el cruce. Cuando el huevo llegue al nido, podrás incubarlo como cualquier otro.", 858, 224, 374, "left")
    theme.setFont(12)
    theme.setColor(theme.colors.textDim, 1)
    love.graphics.print("Progenitores", 858, 300)
    local pa = stateModule.findDino(game, game.cross.aId)
    local pb = stateModule.findDino(game, game.cross.bId)
    if pa then
      render.drawDino(pa, 942, 380, 0.62, {})
      love.graphics.printf(config.species[pa.species].name, 880, 414, 124, "center")
    end
    if pb then
      render.drawDino(pb, 1148, 380, 0.62, {})
      love.graphics.printf(config.species[pb.species].name, 1086, 414, 124, "center")
    end
    theme.setFont(10)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf("El resultado genético ya está calculado y guardado; el huevo solo espera su turno.", 858, 620, 374, "center")
  elseif a and b then
    drawSimulator(app, a, b, 838, 176, 414, 514, now)
  else
    theme.panel(838, 176, 414, 514, { color = theme.colors.panel })
    theme.setFont(16)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print("Cómo funciona", 858, 194)
    local instructions = "1. Elige dos adultos de la misma especie.\n"
      .. "2. El simulador calcula la distribución exacta de los genes visibles.\n"
      .. "3. La rareza del hijo parte de la rareza mayor de los padres.\n"
      .. "4. El cruce tarda un tiempo y produce un huevo.\n"
      .. "5. Ese huevo se incuba en el Nido como cualquier otro."
    theme.setFont(11)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf(instructions, 858, 232, 374, "left")
    local font = theme.fontFor(11)
    local _, lines = font:getWrap(instructions, 374)
    local infoY = 232 + #lines * font:getHeight() + 16
    theme.setColor(theme.colors.textDim, 1)
    love.graphics.printf("La mutación espontánea se sortea con la probabilidad visible y comparte la garantía del nido.\n\nNo hay cruces entre especies en este MVP.",
      858, infoY, 374, "left")
    theme.setFont(10)
    theme.setColor(theme.colors.essence, 1)
    love.graphics.printf("La selección actual: " .. (a and "A elegido" or "falta A") .. " · " .. (b and "B elegido" or "falta B"),
      858, 624, 374, "center")
  end
end

return cross
