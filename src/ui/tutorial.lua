-- Tutorial lineal de la primera partida. Capa de interfaz; no toca la lógica.
local config = require("src.game.config")
local stateModule = require("src.game.state")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")

local tutorial = {}

local tabs = {
  nest = { 12, 114, 228, 64 },
  breeding = { 12, 182, 228, 64 },
  cross = { 12, 250, 228, 64 },
  upgrades = { 12, 318, 228, 64 },
}

local sceneLabels = {
  nest = "NIDO",
  breeding = "CRIADERO",
  cross = "CRUCES",
  upgrades = "MEJORAS",
}

local targets = {
  incubate = { 600, 164, 122, 44 },
  incubator1 = { 748, 488, 126, 92 },
  openEggs = { 508, 455, 216, 32 },
  roleSelector = { 756, 562, 120, 46 },
  habitatSelector = { 876, 562, 120, 46 },
  quickUpgrade = { 1044, 110, 228, 82 },
  crossTab = { 12, 250, 228, 64 },
  guideButton = { 1108, 6, 52, 52 },
}

local steps = {
  {
    id = "welcome",
    title = "Bienvenido al Criadero de Ámbar",
    text = "Tu objetivo es criar dinosaurios, conseguir ámbar y completar la Gran Migración. Te guío en 9 pasos; puedes saltarlo cuando quieras.",
    button = "EMPEZAR",
  },
  {
    id = "incubate",
    title = "Incuba tu primer huevo",
    text = "Pulsa INCUBAR para poner el huevo en la incubadora. Tarda unos segundos; el ámbar se genera mientras esperas.",
    scene = "nest",
    target = "incubate",
    advance = "incubating",
  },
  {
    id = "waiting",
    title = "La incubadora está trabajando",
    text = "La cuenta atrás aparece en la incubadora. Cuando termine, el huevo estará listo para abrir. Mientras, puedes mirar las mejoras o el Dinodex.",
    scene = "nest",
    target = "incubator1",
    advance = "ready",
  },
  {
    id = "open",
    title = "Abre el huevo",
    text = "Pulsa ABRIR HUEVOS para ver qué dinosaurio ha nacido. La rareza, los genes y la mutación se deciden al abrirlo.",
    scene = "nest",
    target = "openEggs",
    advance = "opened",
  },
  {
    id = "role",
    title = "Asigna un rol",
    text = "En el Criadero, selecciona tu ejemplar y usa el selector Rol. La ficha te sugiere el rol según su estadística más alta.",
    scene = "breeding",
    target = "roleSelector",
    advance = "role",
  },
  {
    id = "habitat",
    title = "Asigna un hábitat",
    text = "Ahora el Hábitat. Bosque da producción, Volcán sube la suerte y Costa acelera la incubación. Cada uno admite 3 residentes.",
    scene = "breeding",
    target = "habitatSelector",
    advance = "habitat",
  },
  {
    id = "upgrade",
    title = "Compra una mejora",
    text = "Usa el ámbar en el panel derecho. Ritmo de puesta (35) es la más barata; también puedes abrir Mejoras para ver todas.",
    scene = "breeding",
    target = "quickUpgrade",
    advance = "upgrade",
  },
  {
    id = "cross",
    title = "Los cruces",
    text = "En Cruces puedes juntar dos adultos de la misma especie para heredar genes. Es opcional por ahora; puedes continuar.",
    scene = "cross",
    target = "crossTab",
    button = "SIGUIENTE",
  },
  {
    id = "done",
    title = "Tutorial completado",
    text = "La guía de Primeros pasos queda en el botón ?. Ahí puedes repasar roles, hábitats, cruces, legado y migración cuando quieras.",
    target = "guideButton",
    button = "TERMINAR",
    final = true,
  },
}

local function anyIncubating(game)
  for i = 1, #game.incubators do
    if game.incubators[i] then
      return true
    end
  end
  return false
end

local function anyUpgrade(game)
  for key in pairs(config.upgrades) do
    if (game.upgrades[key] or 0) > 0 then
      return true
    end
  end
  return false
end

local function selectedDino(app)
  if not app.selectedDino then
    return nil
  end
  return stateModule.findDino(app.game, app.selectedDino)
end

local function conditionMet(app, condition)
  local game = app.game
  local dino = selectedDino(app)
  if condition == "incubating" then
    return anyIncubating(game)
  elseif condition == "ready" then
    return #(game.pendingReveals or {}) > 0
  elseif condition == "opened" then
    return (game.stats and game.stats.opened or 0) >= 1
  elseif condition == "role" then
    return dino ~= nil and dino.role ~= nil
  elseif condition == "habitat" then
    return dino ~= nil and dino.habitat ~= nil
  elseif condition == "upgrade" then
    return anyUpgrade(game)
  end
  return false
end

local function selectDinoForStep(app, stepId)
  if app.scene ~= "breeding" then
    return
  end
  local current = selectedDino(app)
  if current and not stateModule.isDinoPending(app.game, current.id) then
    local needs = (stepId == "role" and not current.role)
      or (stepId == "habitat" and not current.habitat)
    if needs then
      return
    end
  end
  local fallback = nil
  for _, dino in ipairs(app.game.dinos or {}) do
    if not stateModule.isDinoPending(app.game, dino.id) then
      fallback = fallback or dino.id
      local needs = (stepId == "role" and not dino.role)
        or (stepId == "habitat" and not dino.habitat)
      if needs then
        app.selectedDino = dino.id
        return
      end
    end
  end
  if fallback then
    app.selectedDino = fallback
  end
end

local function targetRect(app, step)
  if not step.target then
    return nil
  end
  if step.scene and app.scene ~= step.scene then
    return tabs[step.scene]
  end
  return targets[step.target]
end

local function panelLayout(app)
  local state = app.game.tutorial
  local step = state and steps[state.step]
  if not step then
    return nil
  end
  local target = targetRect(app, step)
  local w, h = 600, 160
  local x = 340
  local y
  if target and target[2] + target[4] > 500 then
    y = 76
  elseif target then
    y = 540
  else
    y = 250
  end
  local layout = { x = x, y = y, w = w, h = h, step = step, target = target }
  local buttonY = y + h - 42
  if not step.final then
    layout.skip = { x = x + 14, y = buttonY, w = 150, h = 32 }
  end
  if step.scene and app.scene ~= step.scene then
    layout.ir = { x = x + 174, y = buttonY, w = 160, h = 32, scene = step.scene }
  end
  if step.button then
    layout.next = { x = x + w - 172, y = buttonY, w = 158, h = 32, label = step.button }
  end
  return layout
end

local function advance(app)
  local state = app.game.tutorial
  state.step = state.step + 1
  if state.step > #steps then
    tutorial.finish(app)
  end
end

function tutorial.finish(app)
  local state = app.game.tutorial
  state.active = false
  state.done = true
  state.skipped = false
  state.step = #steps + 1
  app.game.meta.firstRun = false
  app:toast("Tutorial completado. La guía queda en ?.", theme.colors.teal)
end

function tutorial.skip(app)
  local state = app.game.tutorial
  state.active = false
  state.skipped = true
  state.done = false
  state.step = #steps + 1
  app.game.meta.firstRun = false
  app:toast("Tutorial saltado. Puedes abrir la guía con ?.", theme.colors.teal)
end

function tutorial.update(app)
  local state = app.game.tutorial
  if not state or not state.active or app.modal then
    return
  end
  local step = steps[state.step]
  if not step then
    tutorial.finish(app)
    return
  end
  if step.id == "role" or step.id == "habitat" then
    selectDinoForStep(app, step.id)
  end
  if step.advance and conditionMet(app, step.advance) then
    advance(app)
  end
end

function tutorial.handleInput(app)
  local state = app.game.tutorial
  if not state or not state.active or app.modal or not app.click then
    return
  end
  local layout = panelLayout(app)
  if not layout then
    return
  end
  local click = app.click
  local function inside(rect)
    return rect and click.x >= rect.x and click.x <= rect.x + rect.w
      and click.y >= rect.y and click.y <= rect.y + rect.h
  end
  if inside(layout.skip) then
    app.click = nil
    tutorial.skip(app)
  elseif inside(layout.ir) then
    app.click = nil
    app:goto(layout.ir.scene)
  elseif inside(layout.next) then
    app.click = nil
    if layout.step.final then
      tutorial.finish(app)
    else
      advance(app)
    end
  elseif inside(layout) then
    -- El panel no debe activar botones de la escena que quedan debajo.
    app.click = nil
  end
end

function tutorial.draw(app)
  local state = app.game.tutorial
  if not state or not state.active or app.modal then
    return
  end
  local layout = panelLayout(app)
  if not layout then
    return
  end
  local step = layout.step
  local target = layout.target
  local time = love.timer.getTime()
  local reduced = app.game.settings and app.game.settings.reduceMotion

  love.graphics.setColor(0, 0, 0, 0.58)
  if target then
    local x, y, w, h = target[1], target[2], target[3], target[4]
    love.graphics.rectangle("fill", 0, 0, 1280, y)
    love.graphics.rectangle("fill", 0, y + h, 1280, 720 - y - h)
    love.graphics.rectangle("fill", 0, y, x, h)
    love.graphics.rectangle("fill", x + w, y, 1280 - x - w, h)
    local pulse = reduced and 1 or (0.7 + 0.3 * math.sin(time * 4))
    theme.setColor(theme.colors.teal, 0.95)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x - 3, y - 3, w + 6, h + 6)
    theme.setColor(theme.colors.goldLight, 0.45 * pulse)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x - 6, y - 6, w + 12, h + 12)
    love.graphics.setLineWidth(1)
  else
    love.graphics.rectangle("fill", 0, 0, 1280, 720)
  end

  local x, y, w, h = layout.x, layout.y, layout.w, layout.h
  theme.panel(x, y, w, h, {
    color = theme.colors.panel2,
    borderColor = theme.colors.teal,
    shadowSize = 5,
    borderWidth = 2,
  })
  theme.setColor(theme.colors.teal, 0.95)
  love.graphics.rectangle("fill", x + 2, y + 2, w - 4, 3)

  theme.setFont(8)
  theme.setColor(theme.colors.teal, 1)
  love.graphics.print("PASO " .. state.step .. " DE " .. #steps, x + 14, y + 9)
  widgets.progressBar(x + 160, y + 12, 260, 4, (state.step - 1) / math.max(1, #steps - 1),
    theme.colors.teal, {})

  theme.setFont(16)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(step.title, x + 14, y + 24)
  theme.setFont(9)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf(step.text, x + 14, y + 50, w - 28, "left")

  if layout.skip then
    widgets.button(app, layout.skip.x, layout.skip.y, layout.skip.w, layout.skip.h,
      "SALTAR TUTORIAL", { style = "ghost", font = 8 })
  end
  if layout.ir then
    widgets.button(app, layout.ir.x, layout.ir.y, layout.ir.w, layout.ir.h,
      "IR A " .. (sceneLabels[layout.ir.scene] or "LA SECCIÓN"),
      { style = "secondary", font = 8 })
  end
  if layout.next then
    widgets.button(app, layout.next.x, layout.next.y, layout.next.w, layout.next.h,
      layout.next.label, { style = "primary", font = 9 })
  end
end

return tutorial
