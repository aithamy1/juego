-- Dinosaurios pixel-art de 64x40. Solo esta capa usa love.graphics.
local config = require("src.game.config")
local templates = require("src.render.dino_sprites")

local render = {}

local W, H = 64, 40
local PIXEL = 3.0
local ORIGIN_X, ORIGIN_Y = 32, 27

local function mix(a, b, t)
  return {
    a[1] + (b[1] - a[1]) * t,
    a[2] + (b[2] - a[2]) * t,
    a[3] + (b[3] - a[3]) * t,
  }
end

local function hash(n)
  local x = math.sin(n * 12.9898 + 78.233) * 43758.5453
  return x - math.floor(x)
end

local function palette(dino)
  local genes = dino.genes or {}
  local primary = (config.colors[genes.primaryColor] or config.colors.verde).rgb
  local secondary = (config.secondaryColors[genes.secondaryColor] or config.secondaryColors.crema).rgb
  local mutation = dino.mutation

  if mutation == "albino" then
    primary = mix(primary, { 0.96, 0.94, 0.88 }, 0.82)
    secondary = mix(secondary, { 0.99, 0.94, 0.90 }, 0.76)
  elseif mutation == "melanico" then
    primary = mix(primary, { 0.04, 0.05, 0.05 }, 0.78)
    secondary = mix(secondary, { 0.07, 0.07, 0.07 }, 0.70)
  elseif mutation == "fantasma" then
    primary = mix(primary, { 0.84, 0.96, 0.96 }, 0.55)
    secondary = mix(secondary, { 0.92, 1.0, 1.0 }, 0.60)
  end

  local eye = { 0.08, 0.08, 0.10 }
  if mutation == "albino" then
    eye = { 0.62, 0.18, 0.14 }
  elseif mutation == "fantasma" then
    eye = { 0.45, 0.88, 0.86 }
  elseif mutation == "melanico" then
    eye = { 0.92, 0.90, 0.70 }
  end

  return {
    body = primary,
    light = mix(primary, { 1, 1, 1 }, 0.30),
    shade = mix(primary, { 0.02, 0.02, 0.02 }, 0.30),
    belly = secondary,
    feature = secondary,
    featureLight = mix(secondary, { 1, 1, 1 }, 0.28),
    featureShade = mix(secondary, { 0.02, 0.02, 0.02 }, 0.32),
    horn = { 0.93, 0.88, 0.72 },
    hornShade = { 0.76, 0.70, 0.54 },
    outline = mix(primary, { 0.01, 0.01, 0.01 }, 0.86),
    eye = eye,
    crest = { 1.0, 0.78, 0.22 },
    pattern = mix(secondary, primary, 0.18),
  }
end

local crestSpots = {
  triceratops = { 52, 15 },
  velociraptor = { 44, 16 },
  parasaurolophus = { 50, 16 },
  pteranodon = { 44, 18 },
  stegosaurus = { 47, 24 },
  ankylosaurus = { 47, 27 },
}

local function emptyGrid()
  local g = {}
  for y = 1, H do
    local row = {}
    for x = 1, W do
      row[x] = "."
    end
    g[y] = row
  end
  return g
end

local function parseTemplate(species)
  local raw = templates[species] or templates.triceratops
  raw = raw:gsub("^%s*\n", ""):gsub("\n%s*$", "")
  local g = emptyGrid()
  local y = 0
  for line in raw:gmatch("[^\n]+") do
    y = y + 1
    if y <= H then
      for x = 1, math.min(#line, W) do
        g[y][x] = line:sub(x, x)
      end
    end
  end
  return g
end

local function applyPattern(g, pattern)
  if not pattern or pattern == "liso" then
    return
  end
  for y = 1, H do
    for x = 1, W do
      local ch = g[y][x]
      if ch == "b" or ch == "l" then
        local paint = false
        if pattern == "rayado" then
          paint = (x + y * 2) % 9 <= 1
        elseif pattern == "moteado" then
          paint = hash(x * 13 + y * 7) > 0.86
        elseif pattern == "manchas" then
          paint = hash(math.floor(x / 3) * 17 + math.floor(y / 2) * 11) > 0.72
        end
        if paint then
          g[y][x] = "p"
        end
      end
    end
  end
end

local function applyCrest(g, dino)
  local genes = dino.genes or {}
  local crest = genes.crest
  if not crest or crest == "ninguna" then
    return
  end
  local spot = crestSpots[dino.species or "triceratops"]
  if not spot then
    return
  end
  local isBig = crest == "grande"
  local blockW = 2
  local blockH = isBig and 3 or 1
  local function isSkin(ch)
    return ch == "b" or ch == "l" or ch == "s" or ch == "n"
  end
  local ax, ay = spot[1], spot[2]
  for radius = 0, 5 do
    for dy = -radius, radius do
      for dx = -radius, radius do
        local x, y = ax + dx, ay + dy
        if x >= 1 and x <= W and y >= 1 and y <= H and isSkin(g[y][x]) then
          local painted = 0
          for yy = y, math.min(H, y + blockH - 1) do
            for xx = x, math.min(W, x + blockW - 1) do
              if isSkin(g[yy][xx]) then
                g[yy][xx] = "c"
                painted = painted + 1
              end
            end
          end
          if painted > 0 then
            return
          end
        end
      end
    end
  end
end

local function buildGrid(dino, opts)
  local g = parseTemplate(dino.species or "triceratops")
  applyPattern(g, (dino.genes or {}).pattern or "liso")
  applyCrest(g, dino)

  if opts.silhouette then
    for y = 1, H do
      for x = 1, W do
        if g[y][x] ~= "." then
          g[y][x] = "o"
        end
      end
    end
  end
  return g
end

local spriteCache = {}
local spriteOrder = {}

local function spriteKey(dino, opts)
  local genes = dino.genes or {}
  return table.concat({
    dino.species or "triceratops",
    genes.pattern or "liso",
    genes.primaryColor or "verde",
    genes.secondaryColor or "crema",
    genes.crest or "ninguna",
    dino.mutation or "ninguna",
    opts.silhouette and "silueta" or "color",
  }, "|")
end

local function spriteFor(dino, opts)
  local key = spriteKey(dino, opts)
  local cached = spriteCache[key]
  if cached then
    return cached
  end
  if #spriteOrder >= 240 then
    spriteCache = {}
    spriteOrder = {}
  end

  local previousCanvas = love.graphics.getCanvas()
  local sx, sy, sw, sh = love.graphics.getScissor()
  love.graphics.setScissor()

  local canvas = love.graphics.newCanvas(W, H)
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  local p = palette(dino)
  local g = buildGrid(dino, opts)

  local colorFor = {
    b = p.body,
    l = p.light,
    s = p.shade,
    n = p.belly,
    f = p.feature,
    g = p.featureLight,
    q = p.featureShade,
    h = p.horn,
    y = p.hornShade,
    o = p.outline,
    e = p.eye,
    w = { 0.99, 0.98, 0.94 },
    c = p.crest,
    p = p.pattern,
  }

  for y = 1, H do
    for x = 1, W do
      local ch = g[y][x]
      if ch ~= "." then
        local rgb = colorFor[ch] or p.outline
        love.graphics.setColor(rgb[1], rgb[2], rgb[3], 1)
        love.graphics.rectangle("fill", x - 1, y - 1, 1, 1)
      end
    end
  end

  if previousCanvas then
    love.graphics.setCanvas({ previousCanvas, stencil = true })
  else
    love.graphics.setCanvas()
  end
  if sx then
    love.graphics.setScissor(sx, sy, sw, sh)
  end
  canvas:setFilter("nearest", "nearest")
  spriteCache[key] = canvas
  spriteOrder[#spriteOrder + 1] = key
  return canvas
end

function render.drawDino(dino, x, y, scale, opts)
  opts = opts or {}
  local species = dino.species or "triceratops"
  local mutation = dino.mutation
  local alpha = opts.alpha or 1
  if mutation == "fantasma" then
    alpha = alpha * 0.56
  end
  if opts.silhouette then
    alpha = alpha * 0.7
  end
  local bodyScale = ((config.species[species] or config.species.triceratops).bodyScale or 1)
  local finalScale = scale * bodyScale
  if mutation == "gigante" then
    finalScale = finalScale * 1.24
  end
  local flip = opts.flip and -1 or 1
  local ps = PIXEL * finalScale

  -- sombra pixelada
  love.graphics.setColor(0, 0, 0, 0.24 * alpha)
  for i = -3, 3 do
    local width = 50 * finalScale * (1 - math.abs(i) * 0.11)
    love.graphics.rectangle("fill", x - width, y + 37 * finalScale + i * 2 * finalScale, width * 2, 2 * finalScale + 1)
  end

  if mutation == "bioluminiscente" and not opts.silhouette then
    local p = palette(dino)
    love.graphics.setBlendMode("add")
    for i = 4, 1, -1 do
      love.graphics.setColor(p.body[1], p.body[2], p.body[3], 0.035 * alpha * i)
      love.graphics.circle("fill", x, y - 4 * finalScale, (52 + i * 10) * finalScale)
    end
    love.graphics.setBlendMode("alpha")
  end

  local canvas = spriteFor(dino, opts)
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.draw(canvas, x, y, 0, ps * flip, ps, ORIGIN_X, ORIGIN_Y)
  love.graphics.setColor(1, 1, 1, 1)
end

function render.egg(x, y, scale, opts)
  opts = opts or {}
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(scale, scale)
  local wobble = opts.wobble or 0
  love.graphics.rotate(wobble)
  love.graphics.setColor(0, 0, 0, 0.18)
  love.graphics.ellipse("fill", 0, 34, 26, 5)
  love.graphics.setColor(0.86, 0.80, 0.63, 1)
  love.graphics.ellipse("fill", 0, 0, 22, 30)
  love.graphics.setColor(0.94, 0.90, 0.76, 1)
  love.graphics.ellipse("fill", -6, -8, 10, 16)
  love.graphics.setColor(0.66, 0.56, 0.37, 1)
  love.graphics.ellipse("line", 0, 0, 22, 30)
  love.graphics.setColor(0.55, 0.46, 0.30, 0.7)
  love.graphics.setLineWidth(1.4)
  love.graphics.line(-12, -10, -4, -4, 2, -10, 9, -3)
  love.graphics.line(-10, 10, -2, 15, 5, 9, 12, 14)
  if opts.cross then
    love.graphics.setColor(0.56, 0.78, 0.82, 0.9)
    love.graphics.circle("line", 0, 0, 27)
  end
  love.graphics.pop()
end

return render
