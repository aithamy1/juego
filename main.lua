local config = require("src.game.config")
local stateModule = require("src.game.state")
local save = require("src.game.save")
local theme = require("src.ui.theme")
local appModule = require("src.ui.app")
local modals = require("src.ui.modals")

local canvas
local uiApp
local game
local autosaveTimer = 0
local handCursor
local arrowCursor

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

  uiApp = appModule.new(game)
  uiApp.saveCallback = writeSave

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
  love.graphics.setCanvas()

  love.graphics.clear(0, 0, 0, 1)
  local scale, offsetX, offsetY = scaling()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, offsetX, offsetY, 0, scale, scale)
end

function love.mousepressed(x, y, button)
  local cx, cy = toCanvas(x, y)
  if cx < 0 or cy < 0 or cx > config.window.width or cy > config.window.height then
    return
  end
  uiApp.mouse.x = cx
  uiApp.mouse.y = cy
  if button == 1 then
    uiApp.click = { x = cx, y = cy, button = button }
  end
end

function love.mousemoved(x, y)
  local cx, cy = toCanvas(x, y)
  uiApp.mouse.x = cx
  uiApp.mouse.y = cy
end

function love.wheelmoved(_, y)
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
    uiApp.modal.revealStart = love.timer.getTime() - 2
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
  if not focused then
    writeSave()
  end
end

function love.quit()
  writeSave()
  return false
end
