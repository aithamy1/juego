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
  { value = "reciente", label = "Recientes" },
  { value = "rareza", label = "Rareza" },
  { value = "produccion", label = "Producción" },
  { value = "nombre", label = "Especie" },
}

local roleOptions = {
  { value = "ninguno", label = "Sin rol" },
  { value = "recolector", label = "Recolector" },
  { value = "incubador", label = "Incubador" },
  { value = "explorador", label = "Explorador" },
}

local habitatOptions = {
  { value = "ninguno", label = "Sin hábitat" },
  { value = "bosque", label = "Bosque" },
  { value = "volcan", label = "Volcán" },
  { value = "costa", label = "Costa" },
}

local function filteredDinos(app)
  local game = app.game
  local filters = app.filters
  local list = {}
  for _, dino in ipairs(game.dinos) do
    local ok = not stateModule.isDinoPending(game, dino.id)
    if filters.species ~= "todas" and dino.species ~= filters.species then
      ok = false
    end
    if filters.rarity ~= "todas" and dino.rarity ~= filters.rarity then
      ok = false
    end
    if filters.mutation ~= "todas" then
      if (dino.mutation or "ninguna") ~= filters.mutation then
        ok = false
      end
    end
    if ok then
      list[#list + 1] = dino
    end
  end
  table.sort(list, function(a, b)
    if filters.sort == "rareza" then
      local ia, ib = 1, 1
      for i, key in ipairs(config.rarityOrder) do
        if key == a.rarity then ia = i end
        if key == b.rarity then ib = i end
      end
      if ia ~= ib then return ia > ib end
      return a.id > b.id
    elseif filters.sort == "produccion" then
      local ra, rb = economy.dinoRate(a, app.game), economy.dinoRate(b, app.game)
      if ra ~= rb then return ra > rb end
      return a.id > b.id
    elseif filters.sort == "nombre" then
      local na, nb = config.species[a.species].name, config.species[b.species].name
      if na ~= nb then return na < nb end
      return a.id < b.id
    end
    return a.id > b.id
  end)
  return list
end

local function drawCard(app, dino, x, y, w, h, now)
  local hover = widgets.hover(app, x, y, w, h)
  if hover then
    app.mouse.hand = true
    app.tooltip = "Ver la ficha de " .. config.species[dino.species].name .. "."
  end
  if widgets.click(app, x, y, w, h) then
    app.selectedDino = app.selectedDino == dino.id and nil or dino.id
  end
  local selected = app.selectedDino == dino.id
  theme.panel(x, y, w, h, {
    color = hover and theme.colors.panel3 or theme.colors.panel2,
    borderColor = selected and theme.colors.gold or theme.colors.borderSoft,
    shadowSize = 2,
    borderWidth = selected and 2 or 1,
  })
  render.drawDino(dino, x + w / 2, y + 42, 0.38, {})
  if dino.favorite then
    theme.setFont(9)
    theme.setColor(theme.colors.gold, 1)
    love.graphics.print("F", x + w - 12, y + 5)
  end
  theme.setFont(10)
  theme.setColor(theme.colors.text, 1)
  love.graphics.printf(config.species[dino.species].name, x + 4, y + 74, w - 8, "center")
  widgets.rarityChip(x + 8, y + 90, dino.rarity, true)
  local adult = now >= (dino.adultAt or 0)
  theme.setFont(9)
  theme.setColor(adult and theme.colors.textDim or theme.colors.muted, 1)
  love.graphics.printf(adult and ("+" .. theme.fmtRate(economy.dinoRate(dino, app.game)) .. "/s")
    or ("Creciendo " .. theme.fmtTime((dino.adultAt or now) - now)), x + 4, y + 112, w - 8, "center")
  if stateModule.isCrossing(app.game, dino.id) then
    theme.setFont(8)
    theme.setColor(theme.colors.essence, 1)
    love.graphics.printf("EN CRUCE", x + 4, y + 128, w - 8, "center")
  elseif dino.mutation then
    theme.setFont(8)
    theme.setColor(theme.colors.purple, 1)
    love.graphics.printf(config.mutations[dino.mutation].name, x + 4, y + 128, w - 8, "center")
  end
end

local function drawDetail(app, dino, x, y, w, h, now)
  theme.panel(x, y, w, h, {
    color = theme.colors.panel,
    borderColor = theme.colors.border,
    shadowSize = 3,
    borderWidth = 2,
  })
  if not dino then
    local game = app.game
    local adults = 0
    local visible = 0
    for _, candidate in ipairs(game.dinos) do
      if not stateModule.isDinoPending(game, candidate.id) then
        visible = visible + 1
        if now >= (candidate.adultAt or 0) then
          adults = adults + 1
        end
      end
    end
    theme.setFont(11)
    theme.setColor(theme.colors.gold, 1)
    love.graphics.printf("Ficha del ejemplar", x + 10, y + 12, w - 20, "left")
    theme.setFont(9)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf("Selecciona una tarjeta para ver sus genes y acciones.", x + 10, y + 34, w - 20, "left")

    theme.panel(x + 10, y + 76, w - 20, 148, {
      color = theme.colors.panel2,
      borderColor = theme.colors.borderSoft,
      shadowSize = 0,
      borderWidth = 1,
    })
    theme.setFont(9)
    theme.setColor(theme.colors.gold, 1)
    love.graphics.print("RESUMEN DEL CRIADERO", x + 20, y + 85)
    theme.setFont(9)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print("Ejemplares", x + 20, y + 105)
    love.graphics.print("Adultos", x + 130, y + 105)
    theme.setFont(13)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(tostring(visible), x + 20, y + 118)
    love.graphics.print(adults .. " / " .. visible, x + 130, y + 118)
    theme.setFont(9)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print("Producción", x + 20, y + 143)
    theme.setFont(12)
    theme.setColor(theme.colors.amber, 1)
    love.graphics.print("+" .. theme.fmtRate(economy.totalProduction(game, now)) .. "/s", x + 20, y + 156)
    theme.setFont(9)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print("Mutaciones", x + 130, y + 143)
    theme.setFont(12)
    theme.setColor(theme.colors.purple, 1)
    love.graphics.print(tostring(game.stats.mutations or 0), x + 130, y + 156)
    theme.setFont(9)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print("Pity raro", x + 20, y + 183)
    theme.setColor(theme.colors.blue, 1)
    love.graphics.print((game.pity.rare or 0) .. " / " .. (config.rates.pity.rareAt - 1), x + 100, y + 184)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print("Legendario", x + 130, y + 184)
    theme.setColor(theme.colors.amber, 1)
    love.graphics.print((game.pity.legendary or 0) .. " / " .. (config.rates.pity.legendaryAt - 1), x + 130, y + 196)
    theme.setFont(9)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print("Capacidad del nido " .. economy.nestCapacity(game), x + 20, y + 209)
    return
  end

  local adult = now >= (dino.adultAt or 0)
  widgets.button(app, x + 8, y + 8, 28, 24, "VS", {
    style = "ghost",
    font = 8,
    tooltip = "Comparar este ejemplar con otro.",
    onClick = function()
      app.compareA = dino.id
      app.compareB = nil
      for _, other in ipairs(app.game.dinos) do
        if other.id ~= dino.id and not stateModule.isDinoPending(app.game, other.id) then
          app.compareB = other.id
          break
        end
      end
      app:openModal("compare", {})
    end,
  })
  widgets.button(app, x + w - 36, y + 8, 28, 24, "F", {
    style = dino.favorite and "primary" or "ghost",
    font = 10,
    tooltip = dino.favorite and "Quitar de favoritos (protegido)." or "Marcar como favorito para no liberarlo por error.",
    onClick = function()
      stateModule.setDinoFavorite(app.game, dino.id, not dino.favorite)
      app:toast(dino.favorite and "Ejemplar protegido." or "Protección quitada.", theme.colors.gold)
    end,
  })
  render.drawDino(dino, x + w / 2, y + 80, 0.92, {})
  theme.setFont(15)
  theme.setColor(theme.colors.text, 1)
  love.graphics.printf(config.species[dino.species].name, x + 10, y + 134, w - 20, "center")
  local chipW = widgets.rarityChip(x + 10, y + 158, dino.rarity)
  if dino.mutation then
    widgets.chip(x + 18 + chipW, y + 158, config.mutations[dino.mutation].name, theme.colors.purple, { font = 9 })
  end
  theme.setFont(9)
  theme.setColor(adult and theme.colors.green or theme.colors.muted, 1)
  local adultStatus = adult
    and ("Adulto · huevo cada " .. theme.fmtTime(economy.layInterval(dino, app.game)))
    or ("Creciendo: " .. theme.fmtTime((dino.adultAt or now) - now))
  love.graphics.printf(adultStatus, x + 10, y + 180, w - 20, "center")

  local rowY = y + 200
  local rows = {
    { "Patrón", config.patterns[dino.genes.pattern].name },
    { "Color", config.colors[dino.genes.primaryColor].name },
    { "Secundario", config.secondaryColors[dino.genes.secondaryColor].name },
    { "Cresta", config.crests[dino.genes.crest].name },
  }
  for _, row in ipairs(rows) do
    theme.setFont(10)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print(row[1], x + 12, rowY)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(row[2], x + 90, rowY)
    rowY = rowY + 16
  end

  rowY = rowY + 4
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Genes funcionales", x + 12, rowY)
  rowY = rowY + 16
  for _, gene in ipairs(config.functionalOrder) do
    local value = dino.functional[gene] or 1
    theme.setFont(9)
    theme.setColor(theme.colors.textDim, 1)
    love.graphics.print(config.functional[gene].short, x + 12, rowY)
    widgets.progressBar(x + 46, rowY + 3, 140, 5, value / 5, theme.colors.green, {})
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(tostring(value), x + 196, rowY)
    rowY = rowY + 14
  end

  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Producción", x + 12, rowY + 6)
  theme.setFont(12)
  theme.setColor(theme.colors.amber, 1)
  love.graphics.print("+" .. theme.fmtRate(economy.dinoRate(dino, app.game)) .. "/s", x + 90, rowY + 4)

  widgets.cycle(app, x + 12, y + 366, 112, 38, "Rol", dino.role or "ninguno", roleOptions, function(value)
    local ok, err = stateModule.setDinoRole(app.game, dino.id, value)
    if ok then
      local name = value == "ninguno" and "Sin rol" or config.roles[value].name
      app:toast("Rol: " .. name .. ".", theme.colors.gold)
    else
      app:toast(err or "No se pudo asignar el rol.", theme.colors.red)
    end
  end, { tooltip = "El rol se activa cuando el ejemplar es adulto." })

  widgets.cycle(app, x + 132, y + 366, 112, 38, "Hábitat", dino.habitat or "ninguno", habitatOptions, function(value)
    local ok, err = stateModule.setDinoHabitat(app.game, dino.id, value)
    if ok then
      local name = value == "ninguno" and "Sin hábitat" or config.habitats[value].short
      app:toast("Hábitat: " .. name .. ".", theme.colors.gold)
    else
      app:toast(err or "No se pudo asignar el hábitat.", theme.colors.red)
    end
  end, { tooltip = "Cada hábitat admite 3 residentes." })

  local busy = stateModule.isCrossing(app.game, dino.id)
  widgets.button(app, x + 12, y + 414, 112, 34, "A CRUCES", {
    style = "primary",
    font = 9,
    disabled = busy or not adult,
    tooltip = busy and "Este ejemplar está en un cruce." or (not adult and "Debe ser adulto.") or "Elegir como progenitor.",
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
          app:toast("Los cruces son entre la misma especie.", theme.colors.red)
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
  widgets.button(app, x + 132, y + 414, 112, 34, "LIBERAR", {
    style = "danger",
    font = 8,
    disabled = busy or dino.favorite,
    tooltip = busy and "No puedes liberar un ejemplar en cruce."
      or (dino.favorite and "Quita la estrella de favorito para liberarlo.")
      or "Obtienes esencia según su rareza.",
    onClick = function()
      if dino.rarity == "epic" or dino.rarity == "legendary" then
        app:openModal("release", { dinoId = dino.id })
      else
        local ok, essence = stateModule.releaseDino(app.game, dino.id)
        if ok then
          app.selectedDino = nil
          app:toast("Liberado. +" .. essence .. " esencia.", theme.colors.essence)
        else
          app:toast(essence or "No se pudo liberar.", theme.colors.red)
        end
      end
    end,
  })
end

function breeding.draw(app)
  local game = app.game
  local now = app.now
  local x = app.layout.contentX
  local y = app.layout.contentY
  local filters = app.filters

  widgets.cycle(app, x, y, 150, 44, "Especie", filters.species, speciesOptions(), function(value)
    filters.species = value
    app.scroll.breeding_grid = 0
  end)
  widgets.cycle(app, x + 160, y, 120, 44, "Rareza", filters.rarity, rarityOptions(), function(value)
    filters.rarity = value
    app.scroll.breeding_grid = 0
  end)
  widgets.cycle(app, x + 290, y, 140, 44, "Mutación", filters.mutation, mutationOptions(), function(value)
    filters.mutation = value
    app.scroll.breeding_grid = 0
  end)
  widgets.cycle(app, x + 440, y, 120, 44, "Orden", filters.sort, sortOptions, function(value)
    filters.sort = value
  end)

  local list = filteredDinos(app)
  local visibleTotal = 0
  for _, candidate in ipairs(game.dinos) do
    if not stateModule.isDinoPending(game, candidate.id) then
      visibleTotal = visibleTotal + 1
    end
  end
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf(#list .. " / " .. visibleTotal, x + 574, y + 4, 70, "right")
  widgets.button(app, x + 650, y + 7, 78, 30, "LIMPIAR", {
    style = "ghost",
    font = 8,
    tooltip = "Quitar filtros.",
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

  local columns = 4
  local cardW = 108
  local cardH = 144
  local gapX = 10
  local gapY = 10
  local rows = math.max(1, math.ceil(math.max(1, #list) / columns))
  widgets.scroll(app, "breeding_grid", x, y + 54, 462, 462, rows * (cardH + gapY), function(offset)
    if #list == 0 then
      if #game.pendingReveals > 0 then
        widgets.emptyState(x, y + 78, 462, 140, "Huevo listo para abrir",
          "Pulsa ABRIR HUEVOS en el Nido para ver el resultado.")
      else
        widgets.emptyState(x, y + 78, 462, 140, "Sin ejemplares con esos filtros",
          "Prueba otros filtros o incuba huevos en el Nido.")
      end
      return
    end
    for index, dino in ipairs(list) do
      local row = math.floor((index - 1) / columns)
      local col = (index - 1) % columns
      local dx = x + col * (cardW + gapX)
      local dy = y + 54 + row * (cardH + gapY) - offset
      if dy + cardH >= y + 54 and dy <= y + 516 then
        drawCard(app, dino, dx, dy, cardW, cardH, now)
      end
    end
  end)

  drawDetail(app, selected, x + 472, y + 54, 256, 462, now)
end

return breeding
