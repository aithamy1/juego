local config = require("src.game.config")
local stateModule = require("src.game.state")
local save = require("src.game.save")
local theme = require("src.ui.theme")
local appModule = require("src.ui.app")
local modals = require("src.ui.modals")
local audio = require("src.audio.audio")

local canvas
local uiApp
local game
local autosaveTimer = 0
local handCursor
local arrowCursor
local suppressSaveOnQuit = false

local function scaling()
  local width, height = love.graphics.getDimensions()
  local scale = math.min(width / config.window.width, height / config.window.height)
  local offsetX = (width - config.window.width * scale) / 2
  local offsetY = (height - config.window.height * scale) / 2
  return scale, offsetX, offsetY
end

local function toCanvas(x, y)
  local scale, offsetX, offsetY = scaling()
  return (x - offsetX) / scale, (y - offsetY) / scale
end

local function writeSave()
  if not game then
    return false, "El juego aún no está inicializado."
  end
  game.lastSeen = os.time()
  local text = save.encode(game)
  local ok, err = love.filesystem.write("save.json", text)
  return ok, err
end

local function newSeed()
  local value = os.time() % 100000000
  value = value * 100003 + math.floor(love.math.random() * 100000)
  return value % 4294967296
end

local function clampValue(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

local function applyDisplaySettings(settings)
  local scale = settings.uiScale or 1
  local targetW = math.floor(config.window.width * scale)
  local targetH = math.floor(config.window.height * scale)
  local changed = false
  local ok = true
  if settings.fullscreen then
    if not love.window.getFullscreen() then
      changed = true
      ok = pcall(love.window.setFullscreen, true, "desktop")
    end
    return changed, ok
  end
  if love.window.getFullscreen() then
    pcall(love.window.setFullscreen, false)
    changed = true
  end
  local desktopW, desktopH = love.window.getDesktopDimensions()
  if desktopW and desktopH and desktopW > 0 and desktopH > 0 then
    scale = math.min(scale, desktopW / config.window.width, desktopH / config.window.height)
    targetW = math.max(960, math.floor(config.window.width * scale))
    targetH = math.max(540, math.floor(config.window.height * scale))
  end
  local width, height = love.graphics.getDimensions()
  if math.abs(width - targetW) > 2 or math.abs(height - targetH) > 2 then
    changed = true
    ok = pcall(love.window.setMode, targetW, targetH, {
      resizable = true,
      minwidth = 960,
      minheight = 540,
      vsync = 1,
      msaa = 0,
      highdpi = true,
    })
  end
  return changed, ok
end

local function firstGamepad()
  if not love.joystick then
    return nil
  end
  local list = love.joystick.getJoysticks()
  return list and list[1] or nil
end

local padState = {
  a = false,
  b = false,
  lb = false,
  rb = false,
  start = false,
}

function love.load()
  love.graphics.setDefaultFilter("linear", "linear", 8)
  love.graphics.setLineStyle("smooth")
  love.graphics.setBackgroundColor(0, 0, 0, 1)
  love.keyboard.setKeyRepeat(false)

  theme.load()
  canvas = love.graphics.newCanvas(config.window.width, config.window.height)
  canvas:setFilter("linear", "linear")
  handCursor = love.mouse.getSystemCursor("hand")
  arrowCursor = love.mouse.getSystemCursor("arrow")

  local text = love.filesystem.read("save.json")
  local loadError = nil
  local offlineSummary = nil
  if text and #text > 0 then
    local decoded, err = save.decode(text)
    if decoded then
      local ok, summaryOrError = pcall(stateModule.applyOffline, decoded, os.time())
      if ok then
        game = decoded
        offlineSummary = summaryOrError
      else
        loadError = "No se pudo aplicar el progreso offline: " .. tostring(summaryOrError)
        love.filesystem.write("save.corrupt.json", text)
      end
    else
      loadError = err
      love.filesystem.write("save.corrupt.json", text)
    end
  end

  if not game then
    game = stateModule.new(newSeed(), os.time())
  end

  theme.setColorblind(game.settings.colorblind)
  theme.setLargeText(game.settings.largeText)
  local displayChanged, displayOk = applyDisplaySettings(game.settings)
  if not displayOk then
    print("No se pudo aplicar el tamaño de ventana guardado.")
  end
  if displayChanged then
    theme.load()
    canvas = love.graphics.newCanvas(config.window.width, config.window.height)
    canvas:setFilter("linear", "linear")
    handCursor = love.mouse.getSystemCursor("hand")
    arrowCursor = love.mouse.getSystemCursor("arrow")
  end

  uiApp = appModule.new(game)
  uiApp.saveCallback = writeSave
  uiApp.backupCallback = function()
    local saved, saveErr = writeSave()
    if not saved then
      return false, saveErr
    end
    local data = love.filesystem.read("save.json")
    if not data or #data == 0 then
      return false, "No hay una partida guardada."
    end
    return love.filesystem.write("save-backup.json", data)
  end
  uiApp.restoreCallback = function()
    local data = love.filesystem.read("save-backup.json")
    if not data or #data == 0 then
      return false, "No existe save-backup.json."
    end
    local decoded, err = save.decode(data)
    if not decoded then
      return false, "La copia no es válida: " .. tostring(err)
    end
    local ok, writeErr = love.filesystem.write("save.json", data)
    if not ok then
      return false, writeErr
    end
    suppressSaveOnQuit = true
    love.event.quit("restart")
    return true
  end

  local audioOk, audioError = audio.load()
  if not audioOk then
    print("Audio no disponible: " .. tostring(audioError))
  end
  audio.update(0, game.settings)

  if loadError then
    uiApp:toast("No se pudo cargar la partida anterior. Se guardó una copia y se empezó de cero.", theme.colors.red)
  end
  if offlineSummary and (offlineSummary.credited >= 30 or offlineSummary.hatches > 0) then
    uiApp:openModal("offline", { summary = offlineSummary })
  elseif game.meta.firstRun then
    uiApp:openModal("help", {})
  end

  local mx, my = toCanvas(love.mouse.getPosition())
  uiApp.mouse.x = mx
  uiApp.mouse.y = my
  love.window.setTitle(config.title)
end

function love.update(dt)
  local now = os.time()
  uiApp:update(dt, now)
  audio.update(dt, game.settings)

  if uiApp.displayDirty then
    uiApp.displayDirty = false
    local changed, ok = applyDisplaySettings(game.settings)
    if changed then
      theme.load()
      canvas = love.graphics.newCanvas(config.window.width, config.window.height)
      canvas:setFilter("linear", "linear")
      handCursor = love.mouse.getSystemCursor("hand")
      arrowCursor = love.mouse.getSystemCursor("arrow")
    end
    if not ok then
      uiApp:toast("No se pudo cambiar el tamaño de la ventana.", theme.colors.red)
    end
  end
  theme.setColorblind(game.settings.colorblind)
  theme.setLargeText(game.settings.largeText)

  local pad = firstGamepad()
  if pad and pad.isGamepad and pad:isGamepad() then
    local ax = pad:getGamepadAxis("leftx") or 0
    local ay = pad:getGamepadAxis("lefty") or 0
    if math.abs(ax) > 0.22 or math.abs(ay) > 0.22 then
      if uiApp.mouse.x < 0 then
        uiApp.mouse.x = 640
        uiApp.mouse.y = 360
      end
      uiApp.mouse.x = clampValue(uiApp.mouse.x + ax * 620 * dt, 0, config.window.width)
      uiApp.mouse.y = clampValue(uiApp.mouse.y + ay * 620 * dt, 0, config.window.height)
      uiApp.gamepadCursor = true
    end

    local a = pad:isGamepadDown("a")
    if a and not padState.a then
      if uiApp.mouse.x < 0 then
        uiApp.mouse.x = 640
        uiApp.mouse.y = 360
      end
      uiApp.gamepadCursor = true
      uiApp.click = { x = uiApp.mouse.x, y = uiApp.mouse.y, button = 1 }
    end
    padState.a = a

    local b = pad:isGamepadDown("b")
    if b and not padState.b then
      if uiApp.modal then
        modals.escape(uiApp)
      else
        uiApp:goto("nest")
      end
    end
    padState.b = b

    local lb = pad:isGamepadDown("leftshoulder")
    if lb and not padState.lb then
      uiApp:cycleTab(-1)
    end
    padState.lb = lb

    local rb = pad:isGamepadDown("rightshoulder")
    if rb and not padState.rb then
      uiApp:cycleTab(1)
    end
    padState.rb = rb

    local start = pad:isGamepadDown("start")
    if start and not padState.start then
      writeSave()
      uiApp:toast("Partida guardada.", theme.colors.green)
    end
    padState.start = start
  else
    uiApp.gamepadCursor = false
    padState.a = false
    padState.b = false
    padState.lb = false
    padState.rb = false
    padState.start = false
  end
  love.mouse.setVisible(not uiApp.gamepadCursor)

  autosaveTimer = autosaveTimer + dt
  if autosaveTimer >= config.time.autosave then
    autosaveTimer = 0
    writeSave()
  end

  local cursor = uiApp.mouse.hand and handCursor or arrowCursor
  if love.mouse.getCursor() ~= cursor then
    love.mouse.setCursor(cursor)
  end
end

function love.draw()
  love.graphics.setCanvas({ canvas, stencil = true })
  love.graphics.clear(theme.colors.bg[1], theme.colors.bg[2], theme.colors.bg[3], 1)
  uiApp:draw()
  if uiApp.gamepadCursor then
    love.graphics.setColor(1.0, 0.86, 0.34, 1)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", uiApp.mouse.x, uiApp.mouse.y, 8)
    love.graphics.circle("fill", uiApp.mouse.x, uiApp.mouse.y, 2)
    love.graphics.setLineWidth(1)
  end
  love.graphics.setCanvas()

  love.graphics.clear(0, 0, 0, 1)
  local scale, offsetX, offsetY = scaling()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, offsetX, offsetY, 0, scale, scale)
end

function love.mousepressed(x, y, button)
  uiApp.gamepadCursor = false
  love.mouse.setVisible(true)
  local cx, cy = toCanvas(x, y)
  if cx < 0 or cy < 0 or cx > config.window.width or cy > config.window.height then
    return
  end
  uiApp.mouse.x = cx
  uiApp.mouse.y = cy
  if button == 1 then
    uiApp.mouse.down = true
    uiApp.click = { x = cx, y = cy, button = button }
  end
end

function love.mousereleased(x, y, button)
  if button == 1 then
    uiApp.mouse.down = false
  end
end

function love.mousemoved(x, y)
  uiApp.gamepadCursor = false
  love.mouse.setVisible(true)
  local cx, cy = toCanvas(x, y)
  uiApp.mouse.x = cx
  uiApp.mouse.y = cy
end

function love.wheelmoved(_, y)
  uiApp.gamepadCursor = false
  love.mouse.setVisible(true)
  local cx, cy = toCanvas(love.mouse.getPosition())
  uiApp.wheel = { x = cx, y = cy, dy = y }
end

function love.keypressed(key)
  if key == "escape" then
    modals.escape(uiApp)
    return
  end
  if key == "space" and uiApp.modal and uiApp.modal.kind == "reveal" then
    uiApp.modal.skipped = true
    uiApp.modal.revealStart = love.timer.getTime() - config.time.revealResult - 1
    return
  end
  if key == "f5" then
    writeSave()
    uiApp:toast("Partida guardada.", theme.colors.green)
    return
  end
  if not uiApp.modal then
    uiApp:hotkey(key)
  end
end

function love.focus(focused)
  if not focused and not suppressSaveOnQuit then
    writeSave()
  end
end

function love.quit()
  if not suppressSaveOnQuit then
    writeSave()
  end
  return false
end
