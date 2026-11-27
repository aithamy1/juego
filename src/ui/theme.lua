-- Tema visual pixel-art y utilidades de texto. Solo capa de interfaz.
local config = require("src.game.config")

local theme = { colors = {}, fonts = {} }

theme.colorblind = false
theme.textBoost = 0
theme.uiScale = 1.0

local colorblindRarity = {
  common = { 0.86, 0.86, 0.82 },
  uncommon = { 0.25, 0.75, 0.95 },
  rare = { 1.00, 0.70, 0.15 },
  epic = { 0.95, 0.45, 0.95 },
  legendary = { 1.00, 0.92, 0.35 },
}

theme.colors = {
  bg = { 0.075, 0.065, 0.135 },
  bg2 = { 0.095, 0.080, 0.165 },
  bgPattern = { 0.115, 0.095, 0.195 },
  panel = { 0.060, 0.105, 0.205 },
  panel2 = { 0.085, 0.155, 0.300 },
  panel3 = { 0.135, 0.245, 0.445 },
  border = { 0.260, 0.500, 0.760 },
  borderSoft = { 0.135, 0.260, 0.430 },
  text = { 0.985, 0.940, 0.820 },
  textDim = { 0.960, 0.895, 0.755 },
  muted = { 0.790, 0.755, 0.700 },
  section = { 0.115, 0.225, 0.355 },
  sectionLight = { 0.235, 0.405, 0.555 },
  sectionDark = { 0.045, 0.100, 0.175 },
  sectionText = { 0.975, 0.920, 0.790 },
  sectionAccent = { 0.350, 0.720, 0.720 },
  amber = { 0.975, 0.665, 0.180 },
  gold = { 0.965, 0.710, 0.230 },
  goldLight = { 1.000, 0.870, 0.440 },
  goldDark = { 0.520, 0.300, 0.070 },
  amberDark = { 0.480, 0.280, 0.075 },
  essence = { 0.300, 0.840, 0.790 },
  green = { 0.390, 0.790, 0.310 },
  red = { 0.800, 0.235, 0.190 },
  redDark = { 0.470, 0.100, 0.090 },
  blue = { 0.300, 0.620, 0.930 },
  purple = { 0.830, 0.460, 0.780 },
  teal = { 0.310, 0.730, 0.730 },
  tealDark = { 0.100, 0.330, 0.360 },
  wood = { 0.545, 0.350, 0.220 },
  woodLight = { 0.660, 0.445, 0.285 },
  woodDark = { 0.360, 0.215, 0.145 },
  woodGrain = { 0.470, 0.290, 0.180 },
  ink = { 0.130, 0.080, 0.045 },
  white = { 1, 1, 1 },
  black = { 0, 0, 0 },
}

local sizes = { 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 28, 30, 32, 34, 36, 40, 44, 48 }

local function mix(a, b, t)
  return {
    a[1] + (b[1] - a[1]) * t,
    a[2] + (b[2] - a[2]) * t,
    a[3] + (b[3] - a[3]) * t,
  }
end

function theme.load()
  for _, size in ipairs(sizes) do
    local fallback = love.graphics.newFont(size)
    local regular = love.graphics.newFont("assets/fonts/PixelifySans-Regular.ttf", size)
    regular:setFilter("nearest", "nearest")
    regular:setFallbacks(fallback)
    theme.fonts[size] = regular

    local bold = love.graphics.newFont("assets/fonts/PixelifySans-Bold.ttf", size)
    bold:setFilter("nearest", "nearest")
    bold:setFallbacks(fallback)
    theme.boldFonts = theme.boldFonts or {}
    theme.boldFonts[size] = bold
  end
  theme.font = theme.fonts[14]
  theme.buildBackground()
end

function theme.fontFor(size, bold)
  if size < 8 then
    size = 8
    bold = false
  elseif bold == nil then
    bold = size >= 8
  end
  -- Sube solo las etiquetas más pequeñas; el resto conserva su rejilla.
  local effective = size
  if size == 8 then
    effective = 9
  elseif size == 9 then
    effective = 10
  end
  if theme.textBoost > 0 and effective <= 12 then
    effective = effective + 1
  end
  if theme.uiScale and theme.uiScale ~= 1 then
    effective = math.max(8, math.floor(effective * theme.uiScale + 0.5))
  end
  local fonts = bold and theme.boldFonts or theme.fonts
  return fonts[effective] or fonts[size] or fonts[14] or theme.fonts[14]
end

function theme.setLargeText(value)
  theme.textBoost = value and 1 or 0
end

function theme.setUiScale(value)
  theme.uiScale = tonumber(value) or 1.0
end

function theme.setColorblind(value)
  theme.colorblind = not not value
end

function theme.setFont(size, bold)
  love.graphics.setFont(theme.fontFor(size, bold))
end

function theme.setColor(rgb, alpha)
  love.graphics.setColor(rgb[1], rgb[2], rgb[3], alpha or 1)
end

function theme.text(text, x, y, color, size, alpha)
  theme.setFont(size or 14)
  theme.setColor(color or theme.colors.text, alpha or 1)
  love.graphics.print(text, x, y)
end

function theme.printf(text, x, y, width, color, size, align, alpha)
  theme.setFont(size or 14)
  theme.setColor(color or theme.colors.text, alpha or 1)
  love.graphics.printf(text, x, y, width, align or "left")
end

function theme.center(text, x, y, width, color, size, alpha)
  theme.printf(text, x, y, width, color, size, "center", alpha)
end

-- Panel con bisel de píxel: sombra dura, borde, luz arriba/izquierda y sombra abajo/derecha.
function theme.panel(x, y, w, h, opts)
  opts = opts or {}
  local fill = opts.color or theme.colors.panel
  local border = opts.borderColor or theme.colors.border
  local shadow = opts.shadowColor or theme.colors.black
  local shadowSize = opts.shadow == false and 0 or (opts.shadowSize or 4)
  local radius = opts.radius or 0

  if shadowSize > 0 then
    theme.setColor(shadow, (opts.shadowAlpha or 0.72) * (opts.alpha or 1))
    love.graphics.rectangle("fill", x + shadowSize, y + shadowSize, w, h, radius, radius)
  end
  theme.setColor(fill, opts.alpha or 1)
  love.graphics.rectangle("fill", x, y, w, h, radius, radius)

  if opts.border ~= false then
    theme.setColor(border, opts.borderAlpha or 1)
    love.graphics.setLineWidth(opts.borderWidth or 2)
    love.graphics.rectangle("line", x + 1, y + 1, w - 2, h - 2, radius, radius)
    theme.setColor(mix(fill, theme.colors.white, 0.22), 0.72 * (opts.alpha or 1))
    love.graphics.rectangle("fill", x + 3, y + 3, w - 6, 2)
    love.graphics.rectangle("fill", x + 3, y + 3, 2, h - 6)
    theme.setColor(mix(fill, theme.colors.black, 0.36), 0.80 * (opts.alpha or 1))
    love.graphics.rectangle("fill", x + 3, y + h - 5, w - 6, 2)
    love.graphics.rectangle("fill", x + w - 5, y + 3, 2, h - 6)
  end
end

function theme.insetPanel(x, y, w, h, opts)
  opts = opts or {}
  theme.setColor(opts.color or theme.colors.bg, opts.alpha or 0.75)
  love.graphics.rectangle("fill", x, y, w, h)
  theme.setColor(opts.borderColor or theme.colors.borderSoft, opts.borderAlpha or 0.8)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
end

function theme.buildBackground()
  local canvas = love.graphics.newCanvas(1280, 720)
  love.graphics.setCanvas(canvas)
  love.graphics.clear(theme.colors.bg[1], theme.colors.bg[2], theme.colors.bg[3], 1)
  for y = 0, 719, 16 do
    for x = 0, 1279, 16 do
      if ((x / 16) + (y / 16)) % 2 == 0 then
        theme.setColor(theme.colors.bgPattern, 0.52)
        love.graphics.rectangle("fill", x, y, 8, 8)
      end
    end
  end
  theme.setColor({ 0.20, 0.12, 0.32 }, 0.16)
  love.graphics.circle("fill", 80, 120, 260)
  love.graphics.circle("fill", 1200, 640, 280)
  theme.setColor(theme.colors.black, 0.25)
  love.graphics.rectangle("fill", 0, 0, 1280, 24)
  love.graphics.rectangle("fill", 0, 696, 1280, 24)
  love.graphics.setCanvas()
  theme.backgroundCanvas = canvas
end

function theme.background()
  if theme.backgroundCanvas then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(theme.backgroundCanvas, 0, 0)
  else
    love.graphics.clear(theme.colors.bg[1], theme.colors.bg[2], theme.colors.bg[3], 1)
  end
end

function theme.goldBar(x, y, w, h, title, opts)
  opts = opts or {}
  theme.setColor(theme.colors.black, 0.65)
  love.graphics.rectangle("fill", x + 3, y + 3, w, h)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.rectangle("fill", x, y, w, h)
  theme.setColor(theme.colors.goldLight, 0.9)
  love.graphics.rectangle("fill", x + 2, y + 2, w - 4, 3)
  love.graphics.rectangle("fill", x + 2, y + 2, 3, h - 4)
  theme.setColor(theme.colors.goldDark, 0.95)
  love.graphics.rectangle("fill", x + 2, y + h - 5, w - 4, 3)
  love.graphics.rectangle("fill", x + w - 5, y + 2, 3, h - 4)
  theme.setColor(theme.colors.ink, 1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x + 1, y + 1, w - 2, h - 2)

  local icon = opts.icon
  local textX = x + 12
  if icon then
    theme.drawNavIcon(icon, x + 24, y + h / 2, 14, theme.colors.ink)
    textX = x + 44
  end
  theme.setFont(opts.font or 18, true)
  theme.setColor(theme.colors.ink, 1)
  love.graphics.print(title, textX, y + (h - theme.fontFor(opts.font or 18, true):getHeight()) / 2 - 1)
  if opts.right then
    theme.setFont(10)
    theme.setColor(theme.colors.goldDark, 1)
    love.graphics.printf(opts.right, x + 10, y + h - 15, w - 20, "right")
  end
end

-- Barra de sección sobria: el dorado queda para acciones y rarezas.
function theme.sectionBar(x, y, w, h, title, opts)
  opts = opts or {}
  theme.setColor(theme.colors.black, 0.65)
  love.graphics.rectangle("fill", x + 3, y + 3, w, h)
  theme.setColor(theme.colors.section, 1)
  love.graphics.rectangle("fill", x, y, w, h)
  theme.setColor(theme.colors.sectionLight, 0.9)
  love.graphics.rectangle("fill", x + 2, y + 2, w - 4, 3)
  love.graphics.rectangle("fill", x + 2, y + 2, 3, h - 4)
  theme.setColor(theme.colors.sectionDark, 0.95)
  love.graphics.rectangle("fill", x + 2, y + h - 5, w - 4, 3)
  love.graphics.rectangle("fill", x + w - 5, y + 2, 3, h - 4)
  theme.setColor(theme.colors.sectionAccent, 0.9)
  love.graphics.rectangle("fill", x + 3, y + h - 4, w - 6, 1)
  theme.setColor(theme.colors.sectionDark, 1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x + 1, y + 1, w - 2, h - 2)

  local icon = opts.icon
  local textX = x + 12
  if icon then
    theme.drawNavIcon(icon, x + 24, y + h / 2, 14, theme.colors.sectionText)
    textX = x + 44
  end
  theme.setFont(opts.font or 18, true)
  theme.setColor(theme.colors.sectionText, 1)
  love.graphics.print(title, textX, y + (h - theme.fontFor(opts.font or 18, true):getHeight()) / 2 - 1)
  if opts.right then
    theme.setFont(10)
    theme.setColor(theme.colors.sectionText, 0.8)
    love.graphics.printf(opts.right, x + 10, y + h - 15, w - 20, "right")
  end
end

function theme.woodBoard(x, y, w, h)
  -- patas
  theme.setColor(theme.colors.woodDark, 1)
  love.graphics.rectangle("fill", x + 58, y + h - 10, 52, 30)
  love.graphics.rectangle("fill", x + w - 110, y + h - 10, 52, 30)
  theme.setColor(theme.colors.woodLight, 0.5)
  love.graphics.rectangle("fill", x + 62, y + h - 8, 44, 3)
  love.graphics.rectangle("fill", x + w - 106, y + h - 8, 44, 3)

  -- sombra y tabla
  theme.setColor(theme.colors.black, 0.6)
  love.graphics.rectangle("fill", x + 8, y + 8, w, h)
  theme.setColor(theme.colors.woodDark, 1)
  love.graphics.rectangle("fill", x, y, w, h)
  theme.setColor(theme.colors.wood, 1)
  love.graphics.rectangle("fill", x + 6, y + 6, w - 12, h - 12)
  theme.setColor(theme.colors.woodLight, 0.9)
  love.graphics.rectangle("fill", x + 6, y + 6, w - 12, 3)
  love.graphics.rectangle("fill", x + 6, y + 6, 3, h - 12)
  theme.setColor(theme.colors.woodDark, 1)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", x + 1, y + 1, w - 2, h - 2)

  -- vetas
  for i = 1, 13 do
    local gy = y + 28 + i * 42
    if gy < y + h - 12 then
      theme.setColor(theme.colors.woodGrain, 0.40)
      love.graphics.setLineWidth(1)
      love.graphics.line(x + 16, gy, x + w - 18, gy + (i % 3 - 1) * 2)
    end
  end
  theme.setColor(theme.colors.woodGrain, 0.35)
  love.graphics.circle("line", x + w - 110, y + 250, 18)
  love.graphics.circle("line", x + 120, y + 440, 12)
  theme.setColor(theme.colors.woodDark, 0.55)
  love.graphics.rectangle("line", x + 14, y + 14, w - 28, h - 46)
end

function theme.phone(x, y, scale)
  scale = scale or 1
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(scale, scale)
  theme.setColor(theme.colors.black, 0.35)
  love.graphics.rectangle("fill", 6, 20, 90, 40)
  -- base
  theme.setColor(theme.colors.redDark, 1)
  love.graphics.rectangle("fill", 8, 16, 80, 42)
  theme.setColor(theme.colors.red, 1)
  love.graphics.rectangle("fill", 12, 20, 72, 34)
  theme.setColor(theme.colors.goldLight, 0.65)
  love.graphics.rectangle("fill", 13, 21, 70, 3)
  -- auricular
  theme.setColor(theme.colors.redDark, 1)
  love.graphics.rectangle("fill", 0, 0, 22, 20)
  love.graphics.rectangle("fill", 74, 0, 22, 20)
  love.graphics.rectangle("fill", 14, 0, 68, 12)
  theme.setColor(theme.colors.red, 1)
  love.graphics.rectangle("fill", 3, 2, 16, 15)
  love.graphics.rectangle("fill", 77, 2, 16, 15)
  love.graphics.rectangle("fill", 17, 2, 62, 8)
  theme.setColor(theme.colors.goldLight, 0.55)
  love.graphics.rectangle("fill", 5, 4, 12, 2)
  love.graphics.rectangle("fill", 79, 4, 12, 2)
  -- dial
  theme.setColor(theme.colors.goldLight, 1)
  love.graphics.circle("fill", 48, 37, 13)
  theme.setColor(theme.colors.goldDark, 1)
  love.graphics.circle("line", 48, 37, 13)
  for i = 0, 4 do
    local angle = -math.pi / 2 + i * math.pi * 2 / 5
    theme.setColor(theme.colors.redDark, 1)
    love.graphics.circle("fill", 48 + math.cos(angle) * 7, 37 + math.sin(angle) * 7, 2)
  end
  theme.setColor(theme.colors.goldDark, 1)
  love.graphics.circle("fill", 48, 37, 2)
  love.graphics.pop()
end

function theme.drawLock(x, y, size, color)
  color = color or theme.colors.muted
  theme.setColor(color, 1)
  love.graphics.rectangle("fill", x - size * 0.55, y - size * 0.05, size * 1.1, size * 0.9)
  theme.setColor(theme.colors.bg, 0.9)
  love.graphics.rectangle("fill", x - size * 0.18, y + size * 0.30, size * 0.36, size * 0.28)
  theme.setColor(color, 1)
  love.graphics.setLineWidth(2)
  love.graphics.arc("line", "open", x, y - size * 0.15, size * 0.35, math.pi, math.pi * 2)
end


local function starPoints(cx, cy, outer, inner, points)
  local coords = {}
  for i = 0, points * 2 - 1 do
    local radius = (i % 2 == 0) and outer or inner
    local angle = -math.pi / 2 + i * math.pi / points
    coords[#coords + 1] = cx + math.cos(angle) * radius
    coords[#coords + 1] = cy + math.sin(angle) * radius
  end
  return coords
end

function theme.iconAmber(x, y, radius, alpha)
  alpha = alpha or 1
  theme.setColor(theme.colors.goldDark, alpha)
  love.graphics.polygon("fill",
    x - radius, y - radius * 0.45,
    x - radius * 0.55, y - radius,
    x + radius * 0.55, y - radius,
    x + radius, y - radius * 0.45,
    x + radius, y + radius * 0.45,
    x + radius * 0.55, y + radius,
    x - radius * 0.55, y + radius,
    x - radius, y + radius * 0.45)
  theme.setColor(theme.colors.gold, alpha)
  love.graphics.polygon("fill",
    x - radius * 0.78, y - radius * 0.35,
    x - radius * 0.38, y - radius * 0.75,
    x + radius * 0.38, y - radius * 0.75,
    x + radius * 0.78, y - radius * 0.35,
    x + radius * 0.78, y + radius * 0.35,
    x + radius * 0.38, y + radius * 0.75,
    x - radius * 0.38, y + radius * 0.75,
    x - radius * 0.78, y + radius * 0.35)
  theme.setColor(theme.colors.goldLight, alpha)
  love.graphics.rectangle("fill", x - radius * 0.35, y - radius * 0.55, radius * 0.55, radius * 0.35)
  theme.setColor(theme.colors.goldDark, alpha)
  love.graphics.rectangle("fill", x - radius * 0.45, y + radius * 0.45, radius * 0.9, radius * 0.22)
end

function theme.iconEssence(x, y, radius, alpha)
  alpha = alpha or 1
  theme.setColor(theme.colors.tealDark, alpha)
  love.graphics.polygon("fill", x, y - radius, x + radius * 0.9, y, x, y + radius, x - radius * 0.9, y)
  theme.setColor(theme.colors.essence, alpha)
  love.graphics.polygon("fill", x, y - radius * 0.75, x + radius * 0.62, y, x, y + radius * 0.75, x - radius * 0.62, y)
  theme.setColor({ 0.82, 1.0, 0.96 }, alpha)
  love.graphics.polygon("fill", x, y - radius * 0.5, x + radius * 0.25, y - radius * 0.05, x, y + radius * 0.2)
end

function theme.iconLegacy(x, y, radius, alpha)
  alpha = alpha or 1
  theme.setColor(theme.colors.goldDark, alpha)
  love.graphics.polygon("fill", starPoints(x, y + 1, radius, radius * 0.48, 5))
  theme.setColor(theme.colors.purple, alpha)
  love.graphics.polygon("fill", starPoints(x, y - 1, radius * 0.84, radius * 0.40, 5))
end

function theme.drawIcon(currency, x, y, radius, alpha)
  if currency == "amber" then
    theme.iconAmber(x, y, radius, alpha)
  elseif currency == "essence" then
    theme.iconEssence(x, y, radius, alpha)
  else
    theme.iconLegacy(x, y, radius, alpha)
  end
end

function theme.drawGear(x, y, radius, color)
  color = color or theme.colors.text
  theme.setColor(color, 1)
  for i = 0, 7 do
    local angle = i * math.pi / 4
    local cx = x + math.cos(angle) * radius
    local cy = y + math.sin(angle) * radius
    love.graphics.rectangle("fill", cx - 2, cy - 2, 4, 4)
  end
  love.graphics.circle("fill", x, y, radius * 0.72)
  theme.setColor(theme.colors.panel, 1)
  love.graphics.circle("fill", x, y, radius * 0.30)
end

function theme.drawTrophy(x, y, size, color)
  color = color or theme.colors.text
  theme.setColor(color, 1)
  love.graphics.polygon("fill",
    x - size * 0.55, y - size * 0.55,
    x + size * 0.55, y - size * 0.55,
    x + size * 0.35, y + size * 0.22,
    x - size * 0.35, y + size * 0.22)
  love.graphics.rectangle("fill", x - size * 0.10, y + size * 0.22, size * 0.20, size * 0.32)
  love.graphics.rectangle("fill", x - size * 0.42, y + size * 0.54, size * 0.84, size * 0.16)
  love.graphics.rectangle("fill", x - size * 0.72, y - size * 0.48, size * 0.18, size * 0.42)
  love.graphics.rectangle("fill", x + size * 0.54, y - size * 0.48, size * 0.18, size * 0.42)
  theme.setColor(theme.colors.panel, 0.9)
  love.graphics.rectangle("fill", x - size * 0.28, y - size * 0.38, size * 0.56, size * 0.12)
end

function theme.drawNavIcon(kind, x, y, size, color)
  color = color or theme.colors.text
  theme.setColor(color, 1)
  if kind == "nest" then
    love.graphics.ellipse("fill", x, y + 1, size * 0.55, size * 0.75)
    theme.setColor(theme.colors.bg, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.line(x - size * 0.3, y - size * 0.2, x, y, x - size * 0.2, y + size * 0.3)
  elseif kind == "breeding" then
    love.graphics.ellipse("fill", x - 2, y + 2, size * 0.55, size * 0.38)
    love.graphics.circle("fill", x + size * 0.45, y - size * 0.15, size * 0.30)
    love.graphics.rectangle("fill", x - size * 0.7, y + size * 0.18, size * 0.22, size * 0.55)
    love.graphics.rectangle("fill", x + size * 0.1, y + size * 0.25, size * 0.18, size * 0.45)
  elseif kind == "cross" then
    love.graphics.polygon("fill",
      x - size * 0.7, y - size * 0.5, x - size * 0.2, y,
      x - size * 0.7, y + size * 0.5, x - size * 0.3, y + size * 0.5,
      x + size * 0.2, y, x - size * 0.3, y - size * 0.5)
    love.graphics.polygon("fill",
      x + size * 0.2, y - size * 0.5, x + size * 0.7, y,
      x + size * 0.2, y + size * 0.5, x + size * 0.6, y + size * 0.5,
      x + size * 1.0, y, x + size * 0.6, y - size * 0.5)
  elseif kind == "upgrade" then
    love.graphics.polygon("fill", x, y - size * 0.8, x + size * 0.7, y, x + size * 0.25, y, x + size * 0.25, y + size * 0.7,
      x - size * 0.25, y + size * 0.7, x - size * 0.25, y, x - size * 0.7, y)
  elseif kind == "dex" then
    love.graphics.rectangle("fill", x - size * 0.7, y - size * 0.65, size * 1.25, size * 1.3)
    love.graphics.rectangle("fill", x + size * 0.5, y - size * 0.65, size * 0.25, size * 1.3)
    theme.setColor(theme.colors.bg, 0.8)
    love.graphics.rectangle("fill", x - size * 0.45, y - size * 0.35, size * 0.7, 2)
    love.graphics.rectangle("fill", x - size * 0.45, y - size * 0.10, size * 0.55, 2)
  elseif kind == "log" then
    love.graphics.rectangle("fill", x - size * 0.55, y - size * 0.75, size * 1.1, size * 1.5)
    theme.setColor(theme.colors.bg, 0.8)
    love.graphics.rectangle("fill", x - size * 0.3, y - size * 0.45, size * 0.6, 2)
    love.graphics.rectangle("fill", x - size * 0.3, y - size * 0.15, size * 0.4, 2)
    love.graphics.rectangle("fill", x - size * 0.3, y + size * 0.15, size * 0.55, 2)
  else
    theme.drawGear(x, y, size * 0.65, color)
  end
end

local function withThousands(number)
  local text = tostring(math.floor(number))
  local sign = ""
  if text:sub(1, 1) == "-" then
    sign = "-"
    text = text:sub(2)
  end
  local reversed = text:reverse():gsub("(%d%d%d)", "%1."):reverse()
  if reversed:sub(1, 1) == "." then
    reversed = reversed:sub(2)
  end
  return sign .. reversed
end

function theme.fmtInt(number)
  if number ~= number then
    return "0"
  end
  return withThousands(math.floor(number))
end

function theme.fmtCompact(number)
  if number ~= number then
    return "0"
  end
  local abs = math.abs(number)
  if abs < 1000000 then
    return theme.fmtInt(number)
  elseif abs < 1000000000 then
    return string.format("%.1f M", number / 1000000):gsub("%.", ",")
  elseif abs < 1000000000000 then
    return string.format("%.1f B", number / 1000000000):gsub("%.", ",")
  end
  return string.format("%.1e", number):gsub("%.", ",")
end

function theme.fmt(number, decimals)
  decimals = decimals or 0
  if number ~= number then
    return "0"
  end
  if math.abs(number) >= 1000 or decimals == 0 then
    return withThousands(math.floor(number + 0.0001))
  end
  local text = string.format("%." .. decimals .. "f", number)
  return text:gsub("%.", ",")
end

function theme.fmtRate(number)
  if number < 10 then
    return string.format("%.1f", number):gsub("%.", ",")
  end
  return withThousands(math.floor(number))
end

function theme.fmtPct(fraction, decimals)
  decimals = decimals or 1
  local text = string.format("%." .. decimals .. "f", (fraction or 0) * 100)
  return text:gsub("%.", ",") .. " %"
end

function theme.fmtTime(seconds)
  seconds = math.max(0, math.ceil(seconds or 0))
  if seconds < 60 then
    return string.format("%d s", seconds)
  elseif seconds < 3600 then
    local minutes = math.floor(seconds / 60)
    local rest = seconds % 60
    if minutes >= 10 or rest == 0 then
      return string.format("%d min", minutes)
    end
    return string.format("%d min %d s", minutes, rest)
  elseif seconds < 86400 then
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    return string.format("%d h %02d min", hours, minutes)
  end
  local days = math.floor(seconds / 86400)
  local hours = math.floor((seconds % 86400) / 3600)
  return string.format("%d d %d h", days, hours)
end

function theme.fmtClock(timestamp)
  return os.date("%d/%m %H:%M", timestamp or 0)
end

function theme.rarityColor(rarity)
  if theme.colorblind and colorblindRarity[rarity] then
    return colorblindRarity[rarity]
  end
  local def = config.rarity[rarity]
  return def and def.color or theme.colors.muted
end

function theme.rarityName(rarity)
  local def = config.rarity[rarity]
  return def and def.name or "?"
end

function theme.speciesName(key)
  local def = config.species[key]
  return def and def.name or key
end

function theme.mutationName(key)
  if not key then
    return "Sin mutación"
  end
  local def = config.mutations[key]
  return def and def.name or key
end

function theme.drawUpgradeIcon(key, x, y, size, color)
  color = color or theme.colors.gold
  theme.setColor(color, 1)
  if key == "generator" then
    love.graphics.ellipse("fill", x, y, size * 0.55, size * 0.78)
    theme.setColor(theme.colors.bg, 0.85)
    love.graphics.setLineWidth(1)
    love.graphics.line(x - size * 0.35, y - size * 0.15, x - size * 0.05, y + size * 0.05, x - size * 0.28, y + size * 0.35)
  elseif key == "incubators" then
    for i = 0, 2 do
      love.graphics.rectangle("fill", x - size * 0.7 + i * size * 0.55, y - size * 0.55, size * 0.40, size * 0.75)
    end
    love.graphics.rectangle("fill", x - size * 0.7, y + size * 0.35, size * 1.5, size * 0.35)
  elseif key == "incubation" then
    love.graphics.polygon("fill", x, y - size * 0.8, x + size * 0.55, y + size * 0.1, x + size * 0.25, y + size * 0.65,
      x - size * 0.25, y + size * 0.65, x - size * 0.55, y + size * 0.1)
    theme.setColor(theme.colors.bg, 0.8)
    love.graphics.polygon("fill", x, y - size * 0.25, x + size * 0.2, y + size * 0.2, x, y + size * 0.4, x - size * 0.2, y + size * 0.2)
  elseif key == "capacity" then
    love.graphics.rectangle("fill", x - size * 0.7, y - size * 0.5, size * 1.4, size * 1.0)
    theme.setColor(theme.colors.bg, 0.8)
    love.graphics.rectangle("line", x - size * 0.35, y - size * 0.5, size * 0.7, size * 0.4)
  elseif key == "luck" then
    love.graphics.circle("fill", x - size * 0.28, y - size * 0.15, size * 0.30)
    love.graphics.circle("fill", x + size * 0.28, y - size * 0.15, size * 0.30)
    love.graphics.circle("fill", x - size * 0.28, y + size * 0.30, size * 0.30)
    love.graphics.circle("fill", x + size * 0.28, y + size * 0.30, size * 0.30)
  else
    theme.iconAmber(x, y, size * 0.75)
  end
end

function theme.tealBar(x, y, w, h, title, opts)
  opts = opts or {}
  theme.setColor(theme.colors.black, 0.65)
  love.graphics.rectangle("fill", x + 3, y + 3, w, h)
  theme.setColor(theme.colors.tealDark, 1)
  love.graphics.rectangle("fill", x, y, w, h)
  theme.setColor(theme.colors.teal, 0.9)
  love.graphics.rectangle("fill", x + 2, y + 2, w - 4, 3)
  love.graphics.rectangle("fill", x + 2, y + 2, 3, h - 4)
  theme.setColor(theme.colors.black, 0.55)
  love.graphics.rectangle("fill", x + 2, y + h - 5, w - 4, 3)
  love.graphics.rectangle("fill", x + w - 5, y + 2, 3, h - 4)
  theme.setColor(theme.colors.black, 1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x + 1, y + 1, w - 2, h - 2)
  local textX = x + 12
  if opts.icon then
    theme.drawNavIcon(opts.icon, x + 24, y + h / 2, 14, theme.colors.text)
    textX = x + 44
  end
  theme.setFont(opts.font or 18, true)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(title, textX, y + (h - theme.fontFor(opts.font or 18, true):getHeight()) / 2 - 1)
end

function theme.drawTicket(x, y, w, h, angle)
  love.graphics.push()
  love.graphics.translate(x + w / 2, y + h / 2)
  love.graphics.rotate(angle or 0)
  theme.setColor(theme.colors.black, 0.3)
  love.graphics.rectangle("fill", -w / 2 + 2, -h / 2 + 2, w, h)
  theme.setColor(theme.colors.panel2, 1)
  love.graphics.rectangle("fill", -w / 2, -h / 2, w, h)
  theme.setColor(theme.colors.border, 0.9)
  love.graphics.rectangle("line", -w / 2 + 0.5, -h / 2 + 0.5, w - 1, h - 1)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.rectangle("fill", -w / 2 + 3, -h / 2 + 3, 3, 3)
  theme.setColor(theme.colors.bg, 0.8)
  for row = 0, 1 do
    for col = 0, 2 do
      love.graphics.circle("fill", -w / 2 + 11 + col * 6, -h / 2 + 8 + row * 4, 1.4)
    end
  end
  theme.setColor(theme.colors.text, 0.8)
  love.graphics.rectangle("fill", w / 2 - 9, -h / 2 + 4, 4, h - 8)
  love.graphics.pop()
end

return theme
