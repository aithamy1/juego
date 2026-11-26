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
  return stateModule.findDino(app.game, app.crossSelect.a), stateModule.findDino(app.game, app.crossSelect.b)
end

local function slotCard(app, x, y, w, h, title, dino, onClear)
  theme.panel(x, y, w, h, {
    color = theme.colors.panel2,
    borderColor = dino and theme.colors.gold or theme.colors.borderSoft,
    shadowSize = 2,
    borderWidth = 2,
  })
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print(title, x + 8, y + 8)
  if dino then
    render.drawDino(dino, x + 50, y + 62, 0.40, {})
    theme.setFont(10)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(config.species[dino.species].name, x + 92, y + 24)
    widgets.rarityChip(x + 92, y + 44, dino.rarity, true)
    theme.setFont(7)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print("+" .. theme.fmtRate(economy.dinoRate(dino, app.game)) .. "/s", x + 92, y + 72)
    widgets.button(app, x + w - 44, y + 6, 36, 18, "X", {
      style = "ghost",
      font = 8,
      onClick = onClear,
    })
  else
    theme.setFont(8)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf("Elige un adulto abajo", x + 8, y + 56, w - 16, "center")
  end
end

local function drawDistribution(x, y, w, gene, entries)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print(genetics.geneLabels[gene], x, y)
  local parts = {}
  for _, entry in ipairs(entries) do
    local def
    if gene == "pattern" then def = config.patterns[entry.value]
    elseif gene == "primaryColor" then def = config.colors[entry.value]
    elseif gene == "secondaryColor" then def = config.secondaryColors[entry.value]
    else def = config.crests[entry.value] end
    parts[#parts + 1] = (def and def.name or entry.value) .. " " .. theme.fmtPct(entry.probability, 0)
  end
  local text = table.concat(parts, "  ·  ")
  theme.setFont(8)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf(text, x, y + 12, w, "left")
  local font = theme.fontFor(8)
  local _, lines = font:getWrap(text, w)
  return 14 + #lines * font:getHeight() + 4
end

local function drawSimulator(app, a, b, x, y, w, h, now)
  theme.panel(x, y, w, h, {
    color = theme.colors.panel,
    borderColor = theme.colors.border,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.setFont(12)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("Simulador", x + 10, y + 8)
  theme.setFont(7)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Genes visibles del cruce.", x + 10, y + 24)

  local sim = genetics.simulate(a, b)
  local chance = hatch.mutationProbability(app.game)
  local duration = economy.crossDuration(a, b)
  local rarityChance = genetics.rarityUpgradeChance(a, b)
  local ia, ib = 1, 1
  for i, key in ipairs(config.rarityOrder) do
    if key == a.rarity then ia = i end
    if key == b.rarity then ib = i end
  end
  local baseIndex = math.max(ia, ib)
  local baseRarity = config.rarityOrder[baseIndex]
  local upgraded = config.rarityOrder[math.min(#config.rarityOrder, baseIndex + 1)] or baseRarity
  if baseIndex >= #config.rarityOrder then rarityChance = 0 end

  local lineY = y + 46
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Rareza", x + 10, lineY)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(config.rarity[baseRarity].name .. " " .. theme.fmtPct(1 - rarityChance, 0)
    .. " · " .. config.rarity[upgraded].name .. " " .. theme.fmtPct(rarityChance, 0), x + 64, lineY)
  lineY = lineY + 16
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Mutación", x + 10, lineY)
  theme.setColor(chance >= 1 and theme.colors.green or theme.colors.text, 1)
  love.graphics.print(chance >= 1 and "Garantizada" or theme.fmtPct(chance, 2), x + 64, lineY)
  lineY = lineY + 16
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Duración", x + 10, lineY)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(theme.fmtTime(duration), x + 64, lineY)

  lineY = lineY + 26
  theme.setFont(9)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.print("Genes visibles", x + 10, lineY)
  lineY = lineY + 16
  for _, gene in ipairs({ "pattern", "primaryColor", "secondaryColor", "crest" }) do
    lineY = lineY + drawDistribution(x + 10, lineY, w - 20, gene, sim.distributions[gene])
  end

  theme.setFont(7)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf(#sim.combos .. " combinaciones visibles · mutación aparte", x + 10, y + h - 94, w - 20, "left")
  widgets.button(app, x + 10, y + h - 80, w - 20, 24, "VER COMBINACIONES", {
    style = "ghost",
    font = 8,
    onClick = function()
      app:openModal("combos", { combos = sim.combos, a = a, b = b })
    end,
  })
  widgets.button(app, x + 10, y + h - 48, w - 20, 36, "INICIAR CRUCE", {
    style = "primary",
    font = 10,
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
  theme.panel(x, y, w, h, {
    color = theme.colors.panel2,
    borderColor = theme.colors.teal,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.setFont(12)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("Cruce en curso", x + 12, y + 10)
  local a = stateModule.findDino(app.game, job.aId)
  local b = stateModule.findDino(app.game, job.bId)
  if a then
    render.drawDino(a, x + 58, y + 82, 0.42, {})
    theme.setFont(8)
    theme.setColor(theme.colors.text, 1)
    love.graphics.printf(config.species[a.species].name, x + 8, y + 110, 100, "center")
  end
  if b then
    render.drawDino(b, x + w - 58, y + 82, 0.42, {})
    theme.setFont(8)
    theme.setColor(theme.colors.text, 1)
    love.graphics.printf(config.species[b.species].name, x + w - 108, y + 110, 100, "center")
  end
  theme.setFont(20)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.printf(theme.fmtTime(math.max(0, job.finishAt - now)), x + 110, y + 44, w - 220, "center")
  local progress = math.min(1, (now - job.startedAt) / math.max(1, job.finishAt - job.startedAt))
  widgets.progressBar(x + 110, y + 76, w - 220, 7, progress, theme.colors.essence, {})
  theme.setFont(7)
  theme.setColor(job.finished and theme.colors.amber or theme.colors.muted, 1)
  love.graphics.printf(job.finished and "Huevo listo, pero el nido está lleno."
    or "El huevo aparecerá en el nido al terminar.", x + 100, y + 92, w - 200, "center")
end

function cross.draw(app)
  local game = app.game
  local now = app.now
  local x = app.layout.contentX
  local y = app.layout.contentY
  local a, b = selectedDinos(app)
  if app.crossSelect.a and not a then app.crossSelect.a = nil end
  if app.crossSelect.b and not b then app.crossSelect.b = nil end

  if game.cross then
    drawActiveCross(app, x, y, 460, 150, now)
  else
    slotCard(app, x, y, 225, 120, "PROGENITOR A", a, function()
      app.crossSelect.a = nil
    end)
    slotCard(app, x + 235, y, 225, 120, "PROGENITOR B", b, function()
      app.crossSelect.b = nil
    end)
  end

  local listY = game.cross and y + 174 or y + 138
  local listH = game.cross and y + app.layout.contentH - listY - 4 or y + app.layout.contentH - listY - 4
  theme.setFont(11)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Adultos disponibles", x, listY)
  theme.setFont(7)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Misma especie y libres", x + 112, listY + 2)

  local adults = {}
  for _, dino in ipairs(game.dinos) do
    if now >= (dino.adultAt or 0) then
      adults[#adults + 1] = dino
    end
  end
  table.sort(adults, function(left, right)
    if left.species ~= right.species then return left.species < right.species end
    if left.rarity ~= right.rarity then
      local ia, ib = 1, 1
      for i, key in ipairs(config.rarityOrder) do
        if key == left.rarity then ia = i end
        if key == right.rarity then ib = i end
      end
      return ia > ib
    end
    return left.id < right.id
  end)

  local rowH = 56
  widgets.scroll(app, "cross_list", x, listY + 20, 460, listH - 20, #adults * rowH, function(offset)
    if #adults == 0 then
      widgets.emptyState(x, listY + 30, 460, 130, "Todavía no hay adultos",
        "Los dinosaurios maduran tras unos segundos.")
      return
    end
    for index, dino in ipairs(adults) do
      local ry = listY + 20 + (index - 1) * rowH - offset
      if ry + rowH >= listY + 20 and ry <= listY + listH then
        local isA = app.crossSelect.a == dino.id
        local isB = app.crossSelect.b == dino.id
        local busy = stateModule.isCrossing(game, dino.id)
        local active = game.cross ~= nil
        local wrongSpecies = a and not isA and dino.species ~= a.species
        local hover = widgets.hover(app, x, ry + 3, 460, rowH - 6)
        theme.panel(x, ry + 3, 460, rowH - 6, {
          color = (isA or isB) and theme.colors.panel3 or (hover and theme.colors.panel2 or theme.colors.panel),
          borderColor = (isA or isB) and theme.colors.gold or theme.colors.borderSoft,
          shadowSize = 1,
          borderWidth = 1,
        })
        render.drawDino(dino, x + 30, ry + 28, 0.27, {})
        theme.setFont(9)
        theme.setColor(theme.colors.text, 1)
        love.graphics.print(config.species[dino.species].name, x + 58, ry + 10)
        widgets.rarityChip(x + 58, ry + 26, dino.rarity, true)
        theme.setFont(7)
        theme.setColor(theme.colors.muted, 1)
        love.graphics.print("+" .. theme.fmtRate(economy.dinoRate(dino, game)) .. "/s", x + 152, ry + 30)
        if busy then
          widgets.chip(x + 214, ry + 12, "EN CRUCE", theme.colors.essence, { font = 7 })
        end
        widgets.button(app, x + 290, ry + 12, 52, 24, isA and "QUITAR" or "A", {
          style = isA and "primary" or "ghost",
          font = 8,
          disabled = busy or active or (b and b.species ~= dino.species and not isA),
          onClick = function()
            if isA then
              app.crossSelect.a = nil
            else
              app.crossSelect.a = dino.id
              if app.crossSelect.b == dino.id then app.crossSelect.b = nil end
              local chosenB = app.crossSelect.b and stateModule.findDino(game, app.crossSelect.b) or nil
              if chosenB and chosenB.species ~= dino.species then
                app.crossSelect.b = nil
                app:toast("El progenitor B era de otra especie y se ha quitado.", theme.colors.amber)
              end
            end
          end,
        })
        widgets.button(app, x + 346, ry + 12, 52, 24, isB and "QUITAR" or "B", {
          style = isB and "primary" or "ghost",
          font = 8,
          disabled = busy or active or not a or wrongSpecies,
          onClick = function()
            if isB then
              app.crossSelect.b = nil
            else
              app.crossSelect.b = dino.id
            end
          end,
        })
        widgets.button(app, x + 402, ry + 12, 46, 24, "VER", {
          style = "ghost",
          font = 8,
          onClick = function()
            app.selectedDino = dino.id
            app:goto("breeding")
          end,
        })
      end
    end
  end)

  local sx = x + 472
  if game.cross then
    theme.panel(sx, y, 256, 522, {
      color = theme.colors.panel,
      borderColor = theme.colors.borderSoft,
      shadowSize = 3,
      borderWidth = 2,
    })
    theme.setFont(12)
    theme.setColor(theme.colors.gold, 1)
    love.graphics.print("Mientras esperas", sx + 10, y + 10)
    theme.setFont(8)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf("Los padres están ocupados. Cuando el huevo llegue al nido podrás incubarlo.", sx + 10, y + 30, 236, "left")
    local pa = stateModule.findDino(game, game.cross.aId)
    local pb = stateModule.findDino(game, game.cross.bId)
    if pa then
      render.drawDino(pa, sx + 70, y + 150, 0.56, {})
      theme.setFont(8)
      theme.setColor(theme.colors.text, 1)
      love.graphics.printf(config.species[pa.species].name, sx + 8, y + 182, 124, "center")
    end
    if pb then
      render.drawDino(pb, sx + 186, y + 150, 0.56, {})
      theme.setFont(8)
      theme.setColor(theme.colors.text, 1)
      love.graphics.printf(config.species[pb.species].name, sx + 124, y + 182, 124, "center")
    end
    theme.setFont(8)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf("El resultado genético ya está calculado y guardado.", sx + 10, y + 486, 236, "center")
  elseif a and b then
    drawSimulator(app, a, b, sx, y, 256, 522, now)
  else
    theme.panel(sx, y, 256, 522, {
      color = theme.colors.panel,
      borderColor = theme.colors.borderSoft,
      shadowSize = 3,
      borderWidth = 2,
    })
    theme.setFont(12)
    theme.setColor(theme.colors.gold, 1)
    love.graphics.print("Cómo funciona", sx + 10, y + 10)
    theme.setFont(8)
    theme.setColor(theme.colors.muted, 1)
    local instructions = "1. Elige dos adultos de la misma especie.\n"
      .. "2. El simulador muestra la distribución exacta de los genes visibles.\n"
      .. "3. La rareza del hijo parte de la mayor de los padres.\n"
      .. "4. El cruce tarda un tiempo y produce un huevo.\n"
      .. "5. Ese huevo se incuba en el Nido."
    love.graphics.printf(instructions, sx + 10, y + 34, 236, "left")
    local font = theme.fontFor(8)
    local _, lines = font:getWrap(instructions, 236)
    local infoY = y + 34 + #lines * font:getHeight() + 12
    theme.setColor(theme.colors.textDim, 1)
    love.graphics.printf("La mutación espontánea comparte la garantía del nido. No hay cruces entre especies.",
      sx + 10, infoY, 236, "left")
    theme.setFont(8)
    theme.setColor(theme.colors.essence, 1)
    love.graphics.printf((a and "A elegido" or "Falta A") .. " · " .. (b and "B elegido" or "Falta B"),
      sx + 10, y + 486, 236, "center")
  end
end

return cross
