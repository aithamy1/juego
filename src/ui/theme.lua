-- Tema visual y utilidades de texto. Solo capa de interfaz.
local config = require("src.game.config")

local theme = { colors = {}, fonts = {} }

theme.colors = {
  bg = { 0.047, 0.066, 0.055 },
  bg2 = { 0.062, 0.085, 0.069 },
  panel = { 0.086, 0.114, 0.093 },
  panel2 = { 0.115, 0.148, 0.120 },
  panel3 = { 0.145, 0.180, 0.147 },
  border = { 0.235, 0.280, 0.228 },
  borderSoft = { 0.170, 0.205, 0.170 },
  text = { 0.930, 0.905, 0.820 },
  textDim = { 0.730, 0.750, 0.680 },
  muted = { 0.560, 0.600, 0.540 },
  amber = { 0.925, 0.690, 0.300 },
  amberDark = { 0.560, 0.380, 0.120 },
  essence = { 0.470, 0.800, 0.780 },
  green = { 0.560, 0.790, 0.460 },
  red = { 0.850, 0.420, 0.360 },
  blue = { 0.450, 0.680, 0.900 },
  purple = { 0.700, 0.500, 0.880 },
  white = { 1, 1, 1 },
  black = { 0, 0, 0 },
}

local sizes = { 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24, 26, 30, 34, 40, 48 }

function theme.load()
  for _, size in ipairs(sizes) do
    local font = love.graphics.newFont(size)
    font:setFilter("linear", "linear")
    theme.fonts[size] = font
  end
  theme.font = theme.fonts[14]
end

function theme.fontFor(size)
  return theme.fonts[size] or theme.fonts[14]
end

function theme.setFont(size)
  love.graphics.setFont(theme.fontFor(size))
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

function theme.panel(x, y, w, h, opts)
  opts = opts or {}
  theme.setColor(opts.color or theme.colors.panel, opts.alpha or 1)
  love.graphics.rectangle("fill", x, y, w, h, opts.radius or 12, opts.radius or 12)
  if opts.border ~= false then
    theme.setColor(opts.borderColor or theme.colors.border, opts.borderAlpha or 0.85)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, opts.radius or 12, opts.radius or 12)
  end
end

function theme.background()
  love.graphics.clear(theme.colors.bg[1], theme.colors.bg[2], theme.colors.bg[3], 1)
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
  theme.setColor(theme.colors.amber, alpha or 1)
  love.graphics.circle("fill", x, y, radius)
  theme.setColor({ 1, 0.88, 0.55 }, (alpha or 1) * 0.9)
  love.graphics.circle("fill", x - radius * 0.28, y - radius * 0.3, radius * 0.38)
  theme.setColor(theme.colors.amberDark, (alpha or 1) * 0.8)
  love.graphics.setLineWidth(1)
  love.graphics.circle("line", x, y, radius)
end

function theme.iconEssence(x, y, radius, alpha)
  theme.setColor(theme.colors.essence, alpha or 1)
  love.graphics.polygon("fill", x, y - radius, x + radius * 0.8, y, x, y + radius, x - radius * 0.8, y)
  theme.setColor({ 0.78, 0.98, 0.95 }, (alpha or 1) * 0.85)
  love.graphics.polygon("fill", x, y - radius * 0.7, x + radius * 0.35, y - radius * 0.05, x, y + radius * 0.2)
end

function theme.iconLegacy(x, y, radius, alpha)
  theme.setColor(theme.colors.purple, alpha or 1)
  love.graphics.polygon("fill", starPoints(x, y, radius, radius * 0.45, 5))
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

return theme
