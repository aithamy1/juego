local config = require("src.game.config")
local stateModule = require("src.game.state")
local economy = require("src.game.economy")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local render = require("src.render.dino")

local breeding = {}

local function optionList(keys, names, allLabel)
  local options = { { value = "todas", label = allLabel } }
  for _, key in ipairs(keys) do
    options[#options + 1] = { value = key, label = names[key] or key }
  end
  return options
end

local function speciesOptions()
  local names = {}
  for _, key in ipairs(config.speciesOrder) do
    names[key] = config.species[key].name
  end
  return optionList(config.speciesOrder, names, "Todas")
end

local function rarityOptions()
  local names = {}
  for _, key in ipairs(config.rarityOrder) do
    names[key] = config.rarity[key].name
  end
  return optionList(config.rarityOrder, names, "Todas")
end

local function mutationOptions()
  local names = { ninguna = "Sin mutación" }
  for _, key in ipairs(config.mutationOrder) do
    names[key] = config.mutations[key].name
  end
  local keys = { "ninguna" }
  for _, key in ipairs(config.mutationOrder) do
    keys[#keys + 1] = key
  end
  return optionList(keys, names, "Todas")
end

local sortOptions = {
  { value = "reciente", label = "Más recientes" },
  { value = "rareza", label = "Rareza" },
  { value = "produccion", label = "Producción" },
  { value = "nombre", label = "Especie" },
}

local function filteredDinos(app)
  local game = app.game
  local filters = app.filters
  local list = {}
  for _, dino in ipairs(game.dinos) do
    local ok = true
    if filters.species ~= "todas" and dino.species ~= filters.species then
      ok = false
    end
    if filters.rarity ~= "todas" and dino.rarity ~= filters.rarity then
      ok = false
    end
    if filters.mutation ~= "todas" then
      local mutation = dino.mutation or "ninguna"
      if mutation ~= filters.mutation then
        ok = false
      end
    end
    if ok then
      list[#list + 1] = dino
    end
  end
  table.sort(list, function(a, b)
    if filters.sort == "rareza" then
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
      if indexA ~= indexB then
        return indexA > indexB
      end
      return a.id > b.id
    elseif filters.sort == "produccion" then
      local rateA = economy.dinoRate(a, app.game)
      local rateB = economy.dinoRate(b, app.game)
      if rateA ~= rateB then
        return rateA > rateB
      end
      return a.id > b.id
    elseif filters.sort == "nombre" then
      local nameA = config.species[a.species].name
      local nameB = config.species[b.species].name
      if nameA ~= nameB then
        return nameA < nameB
      end
      return a.id < b.id
    end
    return a.id > b.id
  end)
  return list
end

local function drawDinoCard(app, dino, x, y, w, h, now)
  local hover = widgets.hover(app, x, y, w, h)
  if hover then
    app.mouse.hand = true
    app.tooltip = "Haz clic para ver la ficha completa."
  end
  local clicked = widgets.click(app, x, y, w, h)
  if clicked then
    if app.selectedDino == dino.id then
      app.selectedDino = nil
    else
      app.selectedDino = dino.id
    end
  end
  local selected = app.selectedDino == dino.id
  theme.panel(x, y, w, h, {
    color = hover and theme.colors.panel3 or theme.colors.panel2,
    borderColor = selected and theme.colors.amber or theme.colors.borderSoft,
  })
  if selected then
    theme.setColor(theme.colors.amber, 1)
    love.graphics.rectangle("fill", x + 8, y + 8, 3, h - 16, 1.5, 1.5)
  end
  render.drawDino(dino, x + w / 2, y + 64, 0.48, {})
  theme.setFont(12)
  theme.setColor(theme.colors.text, 1)
  love.graphics.printf(config.species[dino.species].name, x + 8, y + 106, w - 16, "center")
  local chipWidth = widgets.rarityChip(x + 10, y + 126, dino.rarity, true)
  if dino.mutation then
    widgets.chip(x + 14 + chipWidth, y + 126, config.mutations[dino.mutation].name,
      dino.mutation == "bioluminiscente" and theme.colors.green or theme.colors.purple, { font = 9 })
  end
  theme.setFont(9)
  if now >= (dino.adultAt or 0) then
    theme.setColor(theme.colors.textDim, 1)
    love.graphics.print("Adulto · +" .. theme.fmtRate(economy.dinoRate(dino, app.game)) .. "/s", x + 10, y + 154)
  else
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print("Creciendo · " .. theme.fmtTime((dino.adultAt or now) - now), x + 10, y + 154)
  end
  if stateModule.isCrossing(app.game, dino.id) then
    theme.setColor(theme.colors.essence, 1)
    theme.setFont(9)
    love.graphics.print("EN CRUCE", x + w - 58, y + 10)
  end
end

local function drawDetail(app, dino, x, y, w, h, now)
  theme.panel(x, y, w, h, { color = theme.colors.panel })
  if not dino then
    theme.setFont(15)
    theme.setColor(theme.colors.textDim, 1)
    love.graphics.printf("Ficha del ejemplar", x + 20, y + 24, w - 40, "left")
    theme.setFont(12)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf("Selecciona un dinosaurio de la rejilla para ver sus genes, su producción y las acciones disponibles.", x + 20, y + 58, w - 40, "left")
    theme.setFont(11)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print("En el criadero hay " .. #app.game.dinos .. " ejemplares.", x + 20, y + 126)
    theme.setFont(10)
    love.graphics.print("Los adultos producen ámbar. Los jóvenes maduran solos.", x + 20, y + 148)
    return
  end

  local adult = now >= (dino.adultAt or 0)
  render.drawDino(dino, x + w / 2, y + 95, 1.0, {})
  theme.setFont(21)
  theme.setColor(theme.colors.text, 1)
  love.graphics.printf(config.species[dino.species].name, x + 16, y + 151, w - 32, "center")
  local chipW = widgets.rarityChip(x + 20, y + 181, dino.rarity)
  if dino.mutation then
    widgets.chip(x + 28 + chipW, y + 181, config.mutations[dino.mutation].name, theme.colors.purple, { font = 10 })
  end
  theme.setFont(10)
  theme.setColor(adult and theme.colors.green or theme.colors.muted, 1)
  love.graphics.printf(adult and "Adulto" or ("Creciendo: " .. theme.fmtTime((dino.adultAt or now) - now)),
    x + 16, y + 209, w - 32, "center")

  local labelX = x + 20
  local valueX = x + 138
  local rowY = y + 232
  theme.setFont(10)
  local genes = {
    { "Patrón", config.patterns[dino.genes.pattern].name },
    { "Color", config.colors[dino.genes.primaryColor].name },
    { "Secundario", config.secondaryColors[dino.genes.secondaryColor].name },
    { "Cresta", config.crests[dino.genes.crest].name },
  }
  for _, row in ipairs(genes) do
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print(row[1], labelX, rowY)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(row[2], valueX, rowY)
    rowY = rowY + 18
  end

  rowY = rowY + 6
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Genes funcionales", labelX, rowY)
  rowY = rowY + 18
  for _, gene in ipairs(config.functionalOrder) do
    local value = dino.functional[gene] or 1
    theme.setFont(10)
    theme.setColor(theme.colors.textDim, 1)
    love.graphics.print(config.functional[gene].name, labelX, rowY)
    theme.setColor(theme.colors.border, 0.8)
    love.graphics.rectangle("fill", x + 120, rowY + 4, 120, 6, 3, 3)
    theme.setColor(theme.colors.green, 1)
    love.graphics.rectangle("fill", x + 120, rowY + 4, 120 * value / 5, 6, 3, 3)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(tostring(value), x + 248, rowY)
    rowY = rowY + 17
  end

  local rate = economy.dinoRate(dino, app.game)
  theme.setFont(11)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Producción", labelX, rowY + 7)
  theme.setFont(14)
  theme.setColor(theme.colors.amber, 1)
  love.graphics.print("+" .. theme.fmtRate(rate) .. " ámbar/s", x + 120, rowY + 4)

  local busy = stateModule.isCrossing(app.game, dino.id)
  local canCross = adult and not busy
  widgets.button(app, x + 20, y + h - 100, w - 40, 38, "Enviar a cruces", {
    style = "primary",
    disabled = not canCross,
    tooltip = busy and "Este ejemplar está en un cruce." or (not adult and "Debe ser adulto para cruzar.")
      or "Elige este ejemplar como progenitor.",
    onClick = function()
      local selection = app.crossSelect
      if not selection.a then
        selection.a = dino.id
        app:goto("cross")
      elseif selection.a == dino.id then
        selection.a = nil
      elseif not selection.b then
        local first = stateModule.findDino(app.game, selection.a)
        if first and first.species ~= dino.species then
          app:toast("Los cruces del MVP son entre la misma especie.", theme.colors.red)
          return
        end
        selection.b = dino.id
        app:goto("cross")
      else
        selection.a = dino.id
        selection.b = nil
        app:goto("cross")
      end
    end,
  })
  widgets.button(app, x + 20, y + h - 52, w - 40, 36, "Liberar ejemplar", {
    style = "danger",
    disabled = busy,
    tooltip = busy and "No puedes liberar un ejemplar que está en un cruce." or "Obtienes esencia según su rareza.",
    onClick = function()
      if dino.rarity == "epic" or dino.rarity == "legendary" then
        app:openModal("release", { dinoId = dino.id })
      else
        local ok, essence = stateModule.releaseDino(app.game, dino.id)
        if ok then
          app.selectedDino = nil
          app:toast("Liberado. +" .. essence .. " esencia.", theme.colors.essence)
        end
      end
    end,
  })
end

function breeding.draw(app)
  local game = app.game
  local now = app.now

  widgets.sectionTitle("Criadero", "Todos tus ejemplares. Filtra, ordena y elige cuáles producen, cruzan o vuelven al bosque.", 28, 120, 820)

  local filters = app.filters
  local y = 170
  widgets.cycle(app, 28, y, 190, 52, "Especie", filters.species, speciesOptions(), function(value)
    filters.species = value
    app.scroll.breeding_grid = 0
  end)
  widgets.cycle(app, 226, y, 160, 52, "Rareza", filters.rarity, rarityOptions(), function(value)
    filters.rarity = value
    app.scroll.breeding_grid = 0
  end)
  widgets.cycle(app, 394, y, 190, 52, "Mutación", filters.mutation, mutationOptions(), function(value)
    filters.mutation = value
    app.scroll.breeding_grid = 0
  end)
  widgets.cycle(app, 592, y, 170, 52, "Orden", filters.sort, sortOptions, function(value)
    filters.sort = value
  end)

  local list = filteredDinos(app)
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf(#list .. " / " .. #game.dinos, 766, 168, 100, "right")
  widgets.button(app, 772, 188, 94, 32, "Limpiar", {
    style = "ghost",
    font = 10,
    tooltip = "Quitar todos los filtros.",
    onClick = function()
      filters.species = "todas"
      filters.rarity = "todas"
      filters.mutation = "todas"
      filters.sort = "reciente"
      app.scroll.breeding_grid = 0
    end,
  })

  local selected = app.selectedDino and stateModule.findDino(game, app.selectedDino) or nil
  if app.selectedDino and not selected then
    app.selectedDino = nil
  end

  local columns = 5
  local cardW = 156
  local cardH = 180
  local gapX = 12
  local gapY = 12
  local rows = math.max(1, math.ceil(math.max(1, #list) / columns))
  local contentH = rows * (cardH + gapY)
  widgets.scroll(app, "breeding_grid", 28, 238, 828, 444, contentH, function(offset)
    if #list == 0 then
      widgets.emptyState(28, 258, 828, 160, "No hay ejemplares con esos filtros",
        "Prueba con otros filtros o incuba huevos en el Nido.")
      return
    end
    for index, dino in ipairs(list) do
      local row = math.floor((index - 1) / columns)
      local col = (index - 1) % columns
      local x = 28 + col * (cardW + gapX)
      local cardY = 238 + row * (cardH + gapY) - offset
      if cardY + cardH >= 238 and cardY <= 238 + 444 then
        drawDinoCard(app, dino, x, cardY, cardW, cardH, now)
      end
    end
  end)

  -- La ficha siempre usa el ejemplar seleccionado, aunque el scroll lo oculte.
  drawDetail(app, selected, 876, 170, 376, 520, now)
end

return breeding
