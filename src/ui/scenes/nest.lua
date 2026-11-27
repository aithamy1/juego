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
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf("en " .. remaining, x + w - 46, y + 1, 46, "right")
  widgets.progressBar(x, y + 15, w, 6, counter / math.max(1, threshold - 1), color, {})
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print(counter .. " / " .. threshold - 1, x, y + 24)
end

local function grassTuft(x, y, height, color, alpha)
  theme.setColor(color, alpha or 1)
  love.graphics.setLineWidth(1)
  love.graphics.line(x, y, x - 2, y - height)
  love.graphics.line(x, y, x, y - height - 2)
  love.graphics.line(x, y, x + 2, y - height + 1)
end

local function drawSkyBands(ix, iy, iw, topColor, bottomColor)
  for band = 0, 3 do
    local t = band / 3
    theme.setColor({
      topColor[1] + (bottomColor[1] - topColor[1]) * t,
      topColor[2] + (bottomColor[2] - topColor[2]) * t,
      topColor[3] + (bottomColor[3] - topColor[3]) * t,
    }, 1)
    love.graphics.rectangle("fill", ix, iy + band * 18, iw, 18)
  end
end

local function drawClouds(ix, iy, iw, time, color, alpha)
  local cloudShift = math.sin(time * 0.18) * 26
  for i = 0, 2 do
    local cx = ix + 30 + ((i * 118 + time * 3 + cloudShift) % (iw + 80)) - 40
    local cy = iy + 16 + (i % 2) * 13
    theme.setColor(color, alpha)
    love.graphics.rectangle("fill", cx, cy, 34, 8)
    love.graphics.rectangle("fill", cx + 8, cy - 6, 20, 8)
  end
end

local function drawHabitatTabs(app, x, y)
  local tabs = {
    { key = "todos", label = "TODOS", tooltip = "Ver todos los ejemplares de la colonia." },
    { key = "bosque", label = "BOSQUE", tooltip = "Ver los residentes del Bosque." },
    { key = "volcan", label = "VOLCÁN", tooltip = "Ver los residentes del Volcán." },
    { key = "costa", label = "COSTA", tooltip = "Ver los residentes de la Costa." },
  }
  local barW = 238
  theme.panel(x + 9, y + 9, barW, 18, {
    color = { 0.07, 0.10, 0.13 },
    borderColor = theme.colors.goldDark,
    shadow = false,
    borderWidth = 1,
  })
  local segmentW = (barW - 4) / #tabs
  local hovered = false
  for index, tab in ipairs(tabs) do
    local tx = x + 11 + (index - 1) * segmentW
    local selected = (app.pastureHabitat or "todos") == tab.key
    local hover = widgets.hover(app, tx, y + 10, segmentW, 16)
    if hover then
      hovered = true
      app.mouse.hand = true
      app.tooltip = tab.tooltip
    end
    if widgets.click(app, tx, y + 10, segmentW, 16) then
      app.pastureHabitat = tab.key
    end
    if selected then
      theme.setColor(theme.colors.gold, 1)
      love.graphics.rectangle("fill", tx, y + 10, segmentW, 16)
      theme.setColor(theme.colors.ink, 1)
    else
      theme.setColor(hover and theme.colors.panel3 or theme.colors.bg, 0.9)
      love.graphics.rectangle("fill", tx, y + 10, segmentW, 16)
      theme.setColor(hover and theme.colors.goldLight or theme.colors.textDim, 1)
    end
    theme.setFont(8)
    love.graphics.printf(tab.label, tx, y + 13, segmentW, "center")
  end
  return hovered
end

local function drawPasture(app, x, y, w, h, now)
  local game = app.game
  local time = game.settings.calm and 0 or love.timer.getTime()
  theme.panel(x, y, w, h, {
    color = { 0.17, 0.12, 0.08 },
    borderColor = theme.colors.goldDark,
    shadowSize = 3,
    borderWidth = 2,
  })

  local ix, iy, iw, ih = x + 5, y + 5, w - 10, h - 10
  love.graphics.setScissor(ix, iy, iw, ih)

  local habitat = app.pastureHabitat or "todos"
  if habitat == "volcan" then
    drawSkyBands(ix, iy, iw, { 0.17, 0.10, 0.16 }, { 0.42, 0.18, 0.14 })
    theme.setColor({ 1.0, 0.58, 0.25 }, 1)
    love.graphics.circle("fill", ix + iw - 38, iy + 28, 12)
    theme.setColor({ 1.0, 0.48, 0.18 }, 0.28)
    love.graphics.circle("fill", ix + iw - 38, iy + 28, 19)
    drawClouds(ix, iy, iw, time, { 0.42, 0.34, 0.36 }, 0.35)
    theme.setColor({ 0.24, 0.12, 0.14 }, 1)
    love.graphics.polygon("fill", ix + 38, iy + 78, ix + iw / 2, iy + 18, ix + iw - 38, iy + 78)
    theme.setColor({ 0.08, 0.06, 0.08 }, 1)
    love.graphics.polygon("fill", ix + iw * 0.41, iy + 78, ix + iw / 2, iy + 18, ix + iw * 0.59, iy + 78)
    theme.setColor({ 1.0, 0.43, 0.10 }, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.line(ix + iw / 2, iy + 20, ix + iw * 0.46, iy + 40, ix + iw * 0.54, iy + 54, ix + iw * 0.48, iy + 70)
    love.graphics.setLineWidth(1)
    theme.setColor({ 0.13, 0.10, 0.10 }, 1)
    love.graphics.rectangle("fill", ix, iy + 62, iw, ih - 62)
    theme.setColor({ 0.21, 0.14, 0.12 }, 1)
    love.graphics.rectangle("fill", ix, iy + 80, iw, ih - 80)
    theme.setColor({ 0.95, 0.32, 0.08 }, 0.55)
    for i = 0, 6 do
      love.graphics.rectangle("fill", ix + 18 + i * 62, iy + 96 + (i % 3) * 12, 16, 3)
    end
    theme.setColor({ 1.0, 0.58, 0.20 }, 0.6)
    for i = 0, 8 do
      local ex = ix + 20 + ((i * 53 + time * 16) % (iw - 40))
      local ey = iy + 90 + (i % 5) * 14
      love.graphics.rectangle("fill", ex, ey, 2, 2)
    end
  elseif habitat == "costa" then
    drawSkyBands(ix, iy, iw, { 0.35, 0.65, 0.85 }, { 0.66, 0.86, 0.91 })
    theme.setColor({ 1.0, 0.86, 0.42 }, 1)
    love.graphics.circle("fill", ix + iw - 38, iy + 28, 12)
    theme.setColor({ 1.0, 0.90, 0.52 }, 0.28)
    love.graphics.circle("fill", ix + iw - 38, iy + 28, 18)
    drawClouds(ix, iy, iw, time, { 0.95, 0.97, 0.98 }, 0.55)
    theme.setColor({ 0.18, 0.46, 0.65 }, 1)
    love.graphics.rectangle("fill", ix, iy + 54, iw, 38)
    theme.setColor({ 0.24, 0.58, 0.72 }, 0.8)
    love.graphics.rectangle("fill", ix, iy + 62, iw, 20)
    theme.setColor({ 0.72, 0.92, 0.95 }, 0.55)
    love.graphics.setLineWidth(2)
    for i = 0, 6 do
      local wx = ix + 10 + i * 68 + math.sin(time * 0.7 + i) * 6
      love.graphics.line(wx, iy + 70 + (i % 2) * 10, wx + 26, iy + 70 + (i % 2) * 10)
    end
    love.graphics.setLineWidth(1)
    theme.setColor({ 0.86, 0.76, 0.52 }, 1)
    love.graphics.rectangle("fill", ix, iy + 90, iw, ih - 90)
    theme.setColor({ 0.95, 0.88, 0.66 }, 1)
    love.graphics.rectangle("fill", ix, iy + 90, iw, 4)
    theme.setColor({ 0.72, 0.62, 0.42 }, 0.8)
    for i = 0, 5 do
      local sx = ix + 18 + i * 78
      love.graphics.rectangle("fill", sx, iy + 112 + (i % 3) * 18, 5, 3)
    end
  else
    drawSkyBands(ix, iy, iw, { 0.31, 0.58, 0.79 }, { 0.56, 0.79, 0.87 })
    theme.setColor(theme.colors.goldLight, 1)
    love.graphics.circle("fill", ix + iw - 38, iy + 28, 12)
    theme.setColor({ 1.0, 0.95, 0.62 }, 0.45)
    love.graphics.circle("fill", ix + iw - 38, iy + 28, 17)
    drawClouds(ix, iy, iw, time, theme.colors.white, 0.55)
    theme.setColor({ 0.25, 0.48, 0.31 }, 1)
    love.graphics.ellipse("fill", ix + 80, iy + 82, 120, 42)
    love.graphics.ellipse("fill", ix + iw - 40, iy + 84, 105, 38)
    theme.setColor({ 0.19, 0.40, 0.25 }, 1)
    love.graphics.ellipse("fill", ix + 260, iy + 88, 150, 42)
    if habitat == "bosque" then
      for i = 0, 2 do
        local tx = ix + 52 + i * 138
        theme.setColor({ 0.42, 0.29, 0.17 }, 1)
        love.graphics.rectangle("fill", tx, iy + 40, 5, 30)
        theme.setColor({ 0.18, 0.45, 0.22 }, 1)
        love.graphics.circle("fill", tx + 2, iy + 34, 16)
        love.graphics.circle("fill", tx - 10, iy + 40, 10)
        love.graphics.circle("fill", tx + 13, iy + 40, 9)
      end
    end
    theme.setColor({ 0.30, 0.58, 0.24 }, 1)
    love.graphics.rectangle("fill", ix, iy + 60, iw, ih - 60)
    theme.setColor({ 0.25, 0.50, 0.20 }, 1)
    love.graphics.rectangle("fill", ix, iy + 72, iw, ih - 72)
    theme.setColor({ 0.36, 0.66, 0.27 }, 0.8)
    love.graphics.rectangle("fill", ix, iy + 60, iw, 4)
    theme.setColor({ 0.77, 0.58, 0.33 }, 1)
    love.graphics.rectangle("fill", ix, iy + 68, iw, 3)
    love.graphics.rectangle("fill", ix, iy + 78, iw, 3)
    for px = ix + 8, ix + iw - 4, 30 do
      love.graphics.rectangle("fill", px, iy + 58, 4, 28)
      theme.setColor({ 0.52, 0.36, 0.19 }, 1)
      love.graphics.rectangle("fill", px + 3, iy + 58, 1, 28)
      theme.setColor({ 0.77, 0.58, 0.33 }, 1)
    end
    local shiftBack = math.sin(time * 0.55) * 12
    local shiftFront = math.sin(time * 0.85 + 1.2) * 22
    for i = 0, math.ceil(iw / 28) + 2 do
      local gx = ix + i * 28 - 20 + shiftBack
      local gy = iy + 96 + (i % 4) * 8
      grassTuft(gx, gy, 7, { 0.20, 0.42, 0.18 }, 0.75)
    end
    for i = 0, math.ceil(iw / 34) + 2 do
      local gx = ix + i * 34 - 24 + shiftFront
      local gy = iy + ih - 4 - (i % 3) * 5
      grassTuft(gx, gy, 12, { 0.45, 0.75, 0.32 }, 0.85)
      if i % 5 == 0 then
        theme.setColor({ 0.97, 0.82, 0.34 }, 1)
        love.graphics.rectangle("fill", gx - 1, gy - 14, 3, 3)
      end
    end
  end

  -- dinosaurios ordenados por rareza; la pradera filtra por hábitat
  local list = {}
  for _, dino in ipairs(game.dinos) do
    if not stateModule.isDinoPending(game, dino.id)
      and (habitat == "todos" or dino.habitat == habitat) then
      list[#list + 1] = dino
    end
  end
  local rank = {}
  for i, key in ipairs(config.rarityOrder) do
    rank[key] = i
  end
  table.sort(list, function(a, b)
    local ra, rb = rank[a.rarity] or 0, rank[b.rarity] or 0
    if ra ~= rb then return ra > rb end
    return a.id > b.id
  end)

  local slots = habitat == "todos" and 2 or 1
  local shown = math.min(slots * 3, #list)
  local hoveredDino = false
  local lanes = {
    { ground = iy + ih - 78, scale = 0.34 },
    { ground = iy + ih - 50, scale = 0.41 },
    { ground = iy + ih - 22, scale = 0.48 },
  }
  local segW = (iw - 36) / slots
  for lane = 1, 3 do
    local laneCfg = lanes[lane]
    local index = habitat == "todos" and lane or (4 - lane)
    for slot = 1, slots do
      if habitat == "todos" then
        index = (slot - 1) * 3 + lane
      end
      local dino = list[index]
      if dino then
        local phase = slot * 2.1 + lane * 1.3 + (dino.id % 7) * 0.17
        local speed = 0.34 + lane * 0.06
        local walk = math.sin(time * speed + phase)
        local baseX = ix + 18 + (slot - 1) * segW
        local dx = baseX + 34 + (0.5 + 0.5 * walk) * (segW - 68)
        local flip = math.cos(time * speed + phase) < 0
        local cy = laneCfg.ground - 48 * laneCfg.scale
        render.drawDino(dino, dx, cy, laneCfg.scale, { flip = flip })
        local hw, hh = 72 * laneCfg.scale, 52 * laneCfg.scale
        if widgets.hover(app, dx - hw, cy - hh, hw * 2, hh * 2) then
          hoveredDino = true
          app.mouse.hand = true
          app.tooltip = "Ver la ficha de " .. config.species[dino.species].name .. "."
          if widgets.click(app, dx - hw, cy - hh, hw * 2, hh * 2) then
            app.selectedDino = dino.id
            app:goto("breeding")
          end
        end
      end
    end
  end

  if #list == 0 then
    theme.setFont(10)
    theme.setColor(theme.colors.text, 1)
    if habitat ~= "todos" then
      love.graphics.printf("Este hábitat está vacío", ix, iy + 128, iw, "center")
      theme.setFont(8)
      theme.setColor(theme.colors.textDim, 1)
      love.graphics.printf("Asigna ejemplares desde su ficha en el Criadero.", ix, iy + 146, iw, "center")
    elseif #game.pendingReveals > 0 then
      love.graphics.printf("Huevo listo para abrir", ix, iy + 128, iw, "center")
      theme.setFont(8)
      theme.setColor(theme.colors.textDim, 1)
      love.graphics.printf("Pulsa ABRIR HUEVOS en el panel de huevos.", ix, iy + 146, iw, "center")
    else
      love.graphics.printf("Aún no hay dinosaurios en la pradera", ix, iy + 128, iw, "center")
      theme.setFont(8)
      theme.setColor(theme.colors.textDim, 1)
      love.graphics.printf("Incuba un huevo y aparecerá aquí.", ix, iy + 146, iw, "center")
    end
  end

  -- selector de hábitat y acciones
  local tabsHover = drawHabitatTabs(app, x, y)
  theme.setFont(8)
  theme.setColor(theme.colors.text, 1)
  if habitat == "todos" then
    love.graphics.printf(#list > shown and (shown .. " / " .. #list) or tostring(#list),
      x + w - 100, y + 14, 88, "right")
  else
    love.graphics.printf(#list .. " / " .. config.habitats[habitat].capacity,
      x + w - 100, y + 14, 88, "right")
  end

  widgets.button(app, x + w - 198, y + 9, 88, 18, "HÁBITATS", {
    style = "secondary",
    font = 7,
    tooltip = "Gestionar residentes, bonus y decoración.",
    onClick = function()
      app:openModal("habitats", {})
    end,
  })
  local habitatsHover = widgets.hover(app, x + w - 198, y + 9, 88, 18)

  love.graphics.setScissor()

  if not hoveredDino and not habitatsHover and not tabsHover then
    if widgets.hover(app, x, y, w, h) then
      app.mouse.hand = true
      app.tooltip = "Ver todos los ejemplares en el Criadero."
    end
    if widgets.click(app, x, y, w, h) then
      app:goto("breeding")
    end
  end
end

local function drawGenerator(app, x, y, w, game, now)
  theme.panel(x, y, w, 64, {
    color = theme.colors.panel2,
    borderColor = theme.colors.border,
    shadowSize = 3,
    borderWidth = 2,
  })
  if widgets.hover(app, x, y, w, 64) then
    app.tooltip = "Cada adulto pone a su ritmo. Una colonia grande alarga la puesta."
  end
  render.egg(x + 26, y + 34, 0.40, {})
  local remaining, eggDino, interval = economy.nextEggInfo(game, now)
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("PRÓXIMO HUEVO" .. (eggDino and (" · " .. config.species[eggDino.species].short) or ""),
    x + 48, y + 7)
  theme.setFont(16)
  theme.setColor(theme.colors.gold, 1)
  if eggDino then
    love.graphics.print(theme.fmtTime(math.max(0, remaining)), x + 48, y + 20)
    widgets.progressBar(x + 48, y + 42, 224, 6,
      1 - math.max(0, remaining) / math.max(1, interval), theme.colors.amber, {})
  else
    theme.setFont(11)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print("Sin adultos", x + 48, y + 24)
    widgets.progressBar(x + 48, y + 42, 224, 6, 0, theme.colors.amber, {})
  end

  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("NIDO", x + 292, y + 8)
  theme.setFont(12)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(#game.eggs .. " / " .. economy.nestCapacity(game), x + 292, y + 20)

  local canIncubate = #game.eggs > 0 and stateModule.freeIncubator(game) ~= nil
  widgets.button(app, x + 330, y + 16, 110, 32, "INCUBAR", {
    style = canIncubate and "primary" or "secondary",
    disabled = not canIncubate,
    font = 9,
    tooltip = "Mueve todos los huevos posibles a incubadoras libres.",
    onClick = function()
      local started = stateModule.incubateAll(game, now)
      if started > 0 then
        app:toast("Incubando " .. started .. " huevo" .. (started > 1 and "s" or "") .. ".", theme.colors.amber)
      end
    end,
  })
end

local function drawEggCard(app, game, egg, x, y, now)
  local cardW, cardH = 104, 82
  local free = stateModule.freeIncubator(game)
  local hover = widgets.hover(app, x, y, cardW, cardH)
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
    shadowSize = 2,
    borderWidth = 1,
  })
  render.egg(x + 24, y + 38, 0.30, { cross = egg.kind == "cruce" })
  theme.setFont(9)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(egg.kind == "cruce" and "Cruce" or "Huevo", x + 45, y + 12)
  theme.setFont(8)
  theme.setColor(free and theme.colors.gold or theme.colors.muted, 1)
  love.graphics.print(free and "Incubar" or "Sin hueco", x + 45, y + 29)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("#" .. egg.id, x + 45, y + 44)
end

local function drawIncubatorCard(app, game, index, x, y, w, h, now)
  local unlocked = index <= economy.incubatorSlots(game)
  local slot = game.incubators[index]
  if not unlocked then
    local hover = widgets.hover(app, x, y, w, h)
    if hover then
      app.mouse.hand = true
      app.tooltip = "Mejora: hueco de incubadora."
    end
    if widgets.click(app, x, y, w, h) then
      app:goto("upgrades")
    end
    theme.panel(x, y, w, h, {
      color = theme.colors.panel,
      borderColor = theme.colors.borderSoft,
      shadowSize = 2,
      borderWidth = 1,
    })
    theme.setFont(8)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf("INCUBADORA " .. index, x, y + 8, w, "center")
    theme.drawLock(x + w / 2, y + 40, 12, theme.colors.muted)
    theme.setFont(7)
    love.graphics.printf("BLOQUEADA", x, y + 62, w, "center")
  elseif not slot then
    local hover = widgets.hover(app, x, y, w, h)
    if hover then
      app.mouse.hand = true
      app.tooltip = #game.eggs > 0 and "Incubar el primer huevo." or "No hay huevos en el nido."
    end
    if widgets.click(app, x, y, w, h) then
      if game.eggs[1] then
        stateModule.startIncubation(game, game.eggs[1].id, now)
      else
        app:toast("No hay huevos en el nido.", theme.colors.amber)
      end
    end
    theme.panel(x, y, w, h, {
      color = hover and theme.colors.panel3 or theme.colors.panel2,
      borderColor = theme.colors.borderSoft,
      shadowSize = 2,
      borderWidth = 1,
    })
    theme.setFont(8)
    theme.setColor(theme.colors.text, 1)
    love.graphics.printf("INCUBADORA " .. index, x, y + 8, w, "center")
    render.egg(x + 25, y + 45, 0.24, {})
    theme.setFont(8)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print("Libre", x + 44, y + 32)
    theme.setColor(theme.colors.gold, 1)
    love.graphics.print("Incubar", x + 44, y + 48)
  else
    local progress = math.min(1, (now - slot.startedAt) / math.max(1, slot.finishAt - slot.startedAt))
    theme.panel(x, y, w, h, {
      color = theme.colors.panel2,
      borderColor = progress >= 1 and theme.colors.gold or theme.colors.border,
      shadowSize = 2,
      borderWidth = 1,
    })
    theme.setFont(8)
    theme.setColor(theme.colors.text, 1)
    love.graphics.printf("INCUBADORA " .. index, x, y + 8, w, "center")
    render.egg(x + 25, y + 42, 0.24, {
      wobble = game.settings.calm and 0
        or math.sin(love.timer.getTime() * 6 + index) * 0.06 * (1 - progress),
      cross = slot.egg.kind == "cruce",
    })
    theme.setFont(8)
    if progress >= 1 then
      theme.setColor(theme.colors.green, 1)
      love.graphics.printf("LISTO", x + 44, y + 32, w - 50, "left")
      widgets.button(app, x + 38, y + 48, w - 44, 22, "ABRIR", {
        style = "primary",
        font = 8,
        tooltip = "Abrir este huevo.",
        onClick = function()
          app:openNextReveal(slot.egg.id)
        end,
      })
    else
      theme.setColor(theme.colors.textDim, 1)
      love.graphics.printf(theme.fmtTime(math.max(0, slot.finishAt - now)),
        x + 44, y + 32, w - 50, "left")
      widgets.progressBar(x + 8, y + 58, w - 16, 5, progress, theme.colors.amber, {})
    end
  end
end

function nest.draw(app)
  local game = app.game
  local now = app.now
  local snap = hatch.snapshot(game)
  local pending = #game.pendingReveals
  local x = app.layout.contentX
  local y = app.layout.contentY

  drawGenerator(app, x, y, 454, game, now)

  -- pradera animada
  drawPasture(app, x, y + 74, 454, 216, now)

  -- huevos
  local eggsY = y + 300
  theme.panel(x, eggsY, 454, 222, {
    color = theme.colors.panel,
    borderColor = theme.colors.border,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.setFont(11)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Huevos en el nido", x + 10, eggsY + 8)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  if pending > 0 then
    love.graphics.printf(#game.eggs .. " / " .. economy.nestCapacity(game), x + 150, eggsY + 10, 76, "right")
    local primaryWidth = pending > 1 and 140 or 208
    widgets.button(app, x + 236, eggsY + 5, primaryWidth, 24, "ABRIR HUEVOS (" .. pending .. ")", {
      style = "primary",
      font = 8,
      tooltip = "Abrir el siguiente huevo listo.",
      onClick = function()
        app:openNextReveal()
      end,
    })
    if pending > 1 then
      widgets.button(app, x + 384, eggsY + 5, 60, 24, "TODOS", {
        style = "secondary",
        font = 7,
        tooltip = "Abrir todos los huevos pendientes en cadena.",
        onClick = function()
          app:openAllReveals()
        end,
      })
    end
  else
    love.graphics.printf(#game.eggs .. " / " .. economy.nestCapacity(game), x + 350, eggsY + 10, 92, "right")
    if #game.eggs > 8 then
      theme.setColor(theme.colors.gold, 1)
      love.graphics.printf("rueda ↓", x + 350, eggsY + 24, 92, "right")
    end
  end

  local columns = 4
  local cardW, cardH, gap = 104, 82, 8
  local rows = math.max(1, math.ceil(math.max(1, #game.eggs) / columns))
  widgets.scroll(app, "nest_eggs", x + 6, eggsY + 30, 442, 182, rows * (cardH + gap), function(offset)
    if #game.eggs == 0 then
      local eggRemaining = economy.nextEggInfo(game, now)
      local emptyBody
      if #game.pendingReveals > 0 then
        emptyBody = "Huevo listo para abrir. Pulsa ABRIR HUEVOS."
      elseif eggRemaining then
        emptyBody = "El siguiente aparece en " .. theme.fmtTime(math.max(0, eggRemaining)) .. "."
      else
        emptyBody = "Madura un adulto para que empiece la puesta."
      end
      widgets.emptyState(x + 6, eggsY + 46, 442, 120, "No hay huevos en el nido", emptyBody)
      return
    end
    for index, egg in ipairs(game.eggs) do
      local row = math.floor((index - 1) / columns)
      local col = (index - 1) % columns
      local ex = x + 6 + col * (cardW + gap)
      local ey = eggsY + 30 + row * (cardH + gap) - offset
      if ey + cardH >= eggsY + 30 and ey <= eggsY + 212 then
        drawEggCard(app, game, egg, ex, ey, now)
      end
    end
  end)

  -- columna derecha: garantías
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
  pityRow(app, rx + 12, y + 48, 236, "Raro o superior", snap.pity.rare, config.rates.pity.rareAt,
    theme.colors.blue, snap.pity.rareIn)
  pityRow(app, rx + 12, y + 98, 236, "Legendario", snap.pity.legendary, config.rates.pity.legendaryAt,
    theme.colors.amber, snap.pity.legendaryIn)
  pityRow(app, rx + 12, y + 148, 236, "Mutación", snap.pity.mutation, config.rates.pity.mutationAt,
    theme.colors.essence, snap.pity.mutationIn)
  widgets.button(app, rx + 12, y + 202, 236, 30, "VER PROBABILIDADES", {
    style = "ghost",
    font = 8,
    onClick = function()
      app:openModal("probabilities", {})
    end,
  })
  theme.setFont(8)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf("Pity suave desde " .. config.rates.pity.legendarySoftStart .. " legendarios.",
    rx + 12, y + 242, 236, "left")

  -- columna derecha: incubadoras
  local incY = y + 310
  theme.panel(rx, incY, 260, 212, {
    color = theme.colors.panel,
    borderColor = theme.colors.border,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.setFont(10)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Incubadoras", rx + 10, incY + 8)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf(economy.incubatorSlots(game) .. " / 4", rx + 170, incY + 9, 80, "right")
  for index = 1, 4 do
    local col = (index - 1) % 2
    local row = math.floor((index - 1) / 2)
    local cx = rx + 8 + col * 126
    local cy = incY + 28 + row * 90
    drawIncubatorCard(app, game, index, cx, cy, 118, 84, now)
  end
end

return nest
