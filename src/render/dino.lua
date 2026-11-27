-- Dinosaurios pixel-art de 64x40. Solo esta capa usa love.graphics.
local config = require("src.game.config")
local templates = require("src.render.dino_sprites")

local render = {}

local W, H = 96, 56
local PIXEL = 2.0
local ORIGIN_X, ORIGIN_Y = 48, 40

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
  trex = { 80, 5 },
  triceratops = { 86, 32 },
  velociraptor = { 87, 27 },
  parasaurolophus = { 86, 26 },
  pteranodon = { 62, 31 },
  stegosaurus = { 84, 42 },
  ankylosaurus = { 84, 40 },
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

-- Cada especie tiene su propio ciclo de marcha: patas, cola, cabeza o alas.
-- Las coordenadas son las de la plantilla de 96x56 (1-based).
local walkStyles = {
  trex = {
    frames = 8, fps = 6.0, bob = 1,
    tail = { x1 = 2, x2 = 28, cy1 = 32, cy2 = 35, h1 = 4, h2 = 7, amp = 2, waves = 1.0 },
    head = { x1 = 63, y1 = 3, x2 = 96, y2 = 25, amp = 1 },
    legs = {
      { x1 = 29, x2 = 45, top = 43, phase = 0 },
      { x1 = 50, x2 = 66, top = 43, phase = math.pi },
    },
    swing = 3,
    arm = { x1 = 66, y1 = 32, x2 = 80, y2 = 41, amp = 1 },
  },
  triceratops = {
    frames = 8, fps = 5.0, bob = 1,
    tail = { x1 = 1, x2 = 20, cy1 = 32, cy2 = 31, h1 = 3, h2 = 5, amp = 1, waves = 1.0 },
    legs = {
      { x1 = 26, x2 = 31, top = 44, phase = 0 },
      { x1 = 36, x2 = 42, top = 44, phase = math.pi },
      { x1 = 51, x2 = 56, top = 44, phase = math.pi },
      { x1 = 61, x2 = 66, top = 44, phase = 0 },
    },
    swing = 2,
  },
  stegosaurus = {
    frames = 8, fps = 4.5, bob = 1,
    tail = { x1 = 1, x2 = 20, cy1 = 27, cy2 = 31, h1 = 12, h2 = 6, amp = 2, waves = 1.2 },
    legs = {
      { x1 = 22, x2 = 31, top = 45, phase = 0 },
      { x1 = 36, x2 = 39, top = 45, phase = math.pi },
      { x1 = 44, x2 = 48, top = 45, phase = 0 },
      { x1 = 55, x2 = 58, top = 45, phase = math.pi },
      { x1 = 63, x2 = 66, top = 45, phase = 0 },
    },
    swing = 2,
  },
  ankylosaurus = {
    frames = 8, fps = 6.0, bob = 1,
    tail = { x1 = 1, x2 = 24, cy1 = 19, cy2 = 24, h1 = 9, h2 = 5, amp = 1, waves = 1.0 },
    legs = {
      { x1 = 32, x2 = 46, top = 46, phase = 0 },
      { x1 = 51, x2 = 59, top = 46, phase = math.pi },
      { x1 = 61, x2 = 76, top = 46, phase = math.pi },
    },
    swing = 1,
    shear = { top = 46, amp = 1 },
  },
  parasaurolophus = {
    frames = 8, fps = 7.0, bob = 2,
    tail = { x1 = 4, x2 = 30, cy1 = 13, cy2 = 24, h1 = 4, h2 = 5, amp = 2, waves = 1.1 },
    head = { x1 = 68, y1 = 10, x2 = 96, y2 = 40, amp = 1 },
    legs = {
      { x1 = 44, x2 = 47, top = 41, phase = 0 },
      { x1 = 55, x2 = 58, top = 41, phase = math.pi },
      { x1 = 64, x2 = 67, top = 41, phase = math.pi },
      { x1 = 70, x2 = 74, top = 41, phase = 0 },
    },
    swing = 2,
  },
  velociraptor = {
    frames = 8, fps = 10.0, bob = 1,
    tail = { x1 = 3, x2 = 52, cy1 = 19, cy2 = 25, h1 = 4, h2 = 6, amp = 2, waves = 1.3 },
    head = { x1 = 76, y1 = 8, x2 = 96, y2 = 34, amp = 1 },
    legs = {
      { x1 = 53, x2 = 58, top = 51, phase = 0 },
      { x1 = 59, x2 = 67, top = 51, phase = math.pi },
    },
    swing = 3,
  },
  pteranodon = {
    frames = 8, fps = 8.0, bob = 2,
    wings = {
      { x1 = 2, x2 = 42, y1 = 10, y2 = 30, amp = 3, pivot = 42, tip = 2 },
      { x1 = 58, x2 = 96, y1 = 10, y2 = 29, amp = 3, pivot = 60, tip = 96 },
    },
  },
}

local function roundInt(value)
  if value >= 0 then
    return math.floor(value + 0.5)
  end
  return math.ceil(value - 0.5)
end

local function copyGrid(g)
  local out = {}
  for y = 1, H do
    local src = g[y]
    local row = {}
    for x = 1, W do
      row[x] = src[x]
    end
    out[y] = row
  end
  return out
end

local function shiftBand(g, x, y1, y2, dy)
  y1 = math.max(1, y1)
  y2 = math.min(H, y2)
  if dy == 0 or y2 < y1 then
    return
  end
  local column = {}
  for y = y1, y2 do
    column[y - y1 + 1] = g[y][x]
    g[y][x] = "."
  end
  for index = 1, #column do
    local ch = column[index]
    local y = y1 + index - 1 + dy
    if ch ~= "." and y >= 1 and y <= H then
      g[y][x] = ch
    end
  end
end

local function moveRect(g, x1, y1, x2, y2, dx, dy)
  local cells = {}
  for y = y1, y2 do
    for x = x1, x2 do
      cells[#cells + 1] = { x, y, g[y][x] }
      g[y][x] = "."
    end
  end
  for index = 1, #cells do
    local cell = cells[index]
    local ch = cell[3]
    local nx, ny = cell[1] + dx, cell[2] + dy
    if ch ~= "." and nx >= 1 and nx <= W and ny >= 1 and ny <= H then
      g[ny][nx] = ch
    end
  end
end

local function applyTail(g, config, phase)
  local span = math.max(1, config.x2 - config.x1)
  for x = config.x1, config.x2 do
    local u = (x - config.x1) / span
    local fall = 1 - u
    local dy = roundInt(config.amp * fall * math.sin(phase + u * config.waves * math.pi * 2))
    if dy ~= 0 then
      local cy = config.cy1 + (config.cy2 - config.cy1) * u
      local half = config.h1 + (config.h2 - config.h1) * u
      shiftBand(g, x, roundInt(cy - half), roundInt(cy + half), dy)
    end
  end
end

local function applyHead(g, config, phase)
  local offset = roundInt(config.amp * math.cos(phase))
  if offset ~= 0 then
    moveRect(g, config.x1, config.y1, config.x2, config.y2, 0, offset)
  end
end

local function applyLeg(g, leg, amount)
  local span = math.max(1, H - leg.top)
  for y = leg.top, H do
    local t = (y - leg.top) / span
    local dx = roundInt(amount * t ^ 1.3)
    if dx ~= 0 then
      local row = g[y]
      local segment = {}
      for x = leg.x1, leg.x2 do
        segment[#segment + 1] = row[x]
        row[x] = "."
      end
      for index = 1, #segment do
        local ch = segment[index]
        local nx = leg.x1 + index - 1 + dx
        if ch ~= "." and nx >= 1 and nx <= W then
          row[nx] = ch
        end
      end
    end
  end
end

local function applyShear(g, config, phase)
  for y = 1, config.top - 1 do
    local t = (config.top - y) / math.max(1, config.top - 1)
    local dx = roundInt(config.amp * t * math.sin(phase))
    if dx ~= 0 then
      local row = g[y]
      local copy = {}
      for x = 1, W do
        copy[x] = row[x]
      end
      for x = 1, W do
        local nx = x + dx
        row[x] = (nx >= 1 and nx <= W) and copy[nx] or "."
      end
    end
  end
end

local function applyWings(g, wings, phase)
  local lift = math.sin(phase)
  for wingIndex = 1, #wings do
    local wing = wings[wingIndex]
    local span = math.max(1, math.abs(wing.tip - wing.pivot))
    for x = wing.x1, wing.x2 do
      local u = (x - wing.pivot) / span
      if wing.tip < wing.pivot then
        u = -u
      end
      u = math.max(0, math.min(1, u))
      local dy = roundInt(-wing.amp * u * lift)
      if dy ~= 0 then
        shiftBand(g, x, wing.y1, wing.y2, dy)
      end
    end
  end
end

local function applyWalkPose(g, style, frame)
  local phase = (frame - 1) / style.frames * math.pi * 2
  if style.tail then
    applyTail(g, style.tail, phase)
  end
  if style.head then
    applyHead(g, style.head, phase)
  end
  if style.legs then
    local swing = style.swing or 1
    for index = 1, #style.legs do
      local leg = style.legs[index]
      applyLeg(g, leg, swing * math.sin(phase + leg.phase))
    end
  end
  if style.shear then
    applyShear(g, style.shear, phase)
  end
  if style.arm then
    local arm = style.arm
    local offset = roundInt(arm.amp * math.sin(phase + 1.2))
    if offset ~= 0 then
      moveRect(g, arm.x1, arm.y1, arm.x2, arm.y2, 0, -offset)
    end
  end
  if style.wings then
    applyWings(g, style.wings, phase)
  end
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

local baseGridCache = {}
local baseGridOrder = {}

local function baseGridFor(dino, opts)
  local key = spriteKey(dino, opts)
  local cached = baseGridCache[key]
  if cached then
    return cached
  end
  if #baseGridOrder >= 160 then
    baseGridCache = {}
    baseGridOrder = {}
  end
  local grid = buildGrid(dino, opts)
  baseGridCache[key] = grid
  baseGridOrder[#baseGridOrder + 1] = key
  return grid
end

local function spriteFor(dino, opts, frame)
  local key = spriteKey(dino, opts)
  if opts.walk then
    key = key .. "|p" .. tostring(frame or 1)
  end
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
  local g
  if opts.walk then
    g = copyGrid(baseGridFor(dino, opts))
    local style = walkStyles[dino.species or "triceratops"] or walkStyles.triceratops
    applyWalkPose(g, style, frame or 1)
  else
    g = baseGridFor(dino, opts)
  end

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

  -- Dibuja cada fila por tramos del mismo color: menos llamadas que pixel a pixel.
  for y = 1, H do
    local row = g[y]
    local x = 1
    while x <= W do
      local ch = row[x]
      if ch == "." then
        x = x + 1
      else
        local start = x
        while x <= W and row[x] == ch do
          x = x + 1
        end
        local rgb = colorFor[ch] or p.outline
        love.graphics.setColor(rgb[1], rgb[2], rgb[3], 1)
        love.graphics.rectangle("fill", start - 1, y - 1, x - start, 1)
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

function render.walkStyle(species)
  return walkStyles[species] or walkStyles.triceratops
end

function render.walkFrame(species, time, seed, tempo)
  local style = walkStyles[species] or walkStyles.triceratops
  local cycle = (time or 0) * style.fps * (tempo or 1) + (seed or 0)
  local loop = cycle % style.frames
  if loop < 0 then
    loop = loop + style.frames
  end
  return math.floor(loop) + 1, loop / style.frames
end

function render.walkGrid(dino, frame, opts)
  opts = opts or {}
  local grid = copyGrid(baseGridFor(dino, opts))
  local style = walkStyles[dino.species or "triceratops"] or walkStyles.triceratops
  applyWalkPose(grid, style, frame or 1)
  return grid
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
  -- El sprite se dibuja a un numero entero de pixeles de pantalla por pixel de arte.
  -- En miniaturas muy pequenas se mantiene la escala fraccionaria para no romper la lista.
  if scale >= 0.33 then
    ps = math.max(1, math.floor(ps + 0.5))
  end

  -- sombra pixelada, alineada con los pies del sprite
  local shadowY = y + 15.5 * ps
  love.graphics.setColor(0, 0, 0, 0.24 * alpha)
  for i = -3, 3 do
    local width = 28 * ps * (1 - math.abs(i) * 0.10)
    love.graphics.rectangle("fill", x - width, shadowY + i * 1.6 * ps, width * 2, 1.6 * ps + 1)
  end

  if mutation == "bioluminiscente" and not opts.silhouette then
    local p = palette(dino)
    love.graphics.setBlendMode("add")
    for i = 4, 1, -1 do
      love.graphics.setColor(p.body[1], p.body[2], p.body[3], 0.035 * alpha * i)
      love.graphics.circle("fill", x, y - 4 * ps, (26 + i * 7) * ps)
    end
    love.graphics.setBlendMode("alpha")
  end

  local canvas
  local bob = 0
  local frame = 1
  if opts.walk and not opts.silhouette then
    local style = walkStyles[species] or walkStyles.triceratops
    local seed = opts.phase or ((dino.id or 0) % 29) * 0.31
    local tempo = opts.tempo or (0.93 + ((dino.id or 0) % 17) * 0.008)
    local time = opts.time
    if time == nil then
      time = love.timer.getTime()
    end
    frame = render.walkFrame(species, time, seed, tempo)
    local loop = (time * style.fps * tempo + seed) % style.frames
    if loop < 0 then
      loop = loop + style.frames
    end
    bob = roundInt((style.bob or 0) * math.abs(math.sin(loop / style.frames * math.pi * 2)))
    canvas = spriteFor(dino, opts, frame)
  else
    canvas = spriteFor(dino, opts)
  end
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.draw(canvas, x, y - bob * ps, 0, ps * flip, ps, ORIGIN_X, ORIGIN_Y)
  love.graphics.setColor(1, 1, 1, 1)
end

local eggCracks = {
  { at = 0.04, points = { { -1, -27 }, { 2, -23 }, { 0, -20 }, { 4, -16 }, { 2, -13 } } },
  { at = 0.18, points = { { 5, -14 }, { 8, -10 }, { 5, -6 }, { 9, -2 } } },
  { at = 0.33, points = { { -2, -18 }, { -5, -14 }, { -2, -10 }, { -6, -5 }, { -3, -1 } } },
  { at = 0.49, points = { { -7, 1 }, { -11, 5 }, { -8, 9 }, { -12, 13 }, { -9, 17 } } },
  { at = 0.63, points = { { 3, -7 }, { 6, -3 }, { 3, 1 }, { 7, 5 }, { 4, 9 } } },
  { at = 0.77, points = { { 0, 8 }, { -3, 12 }, { -1, 16 }, { 2, 20 }, { 6, 23 } } },
  { at = 0.87, points = { { 2, -26 }, { -1, -20 }, { 3, -14 }, { 0, -8 }, { 4, -2 }, { 2, 4 }, { 5, 11 }, { 3, 18 }, { 6, 24 } } },
  { at = 0.94, points = { { -16, 6 }, { -9, 3 }, { -4, 6 }, { 1, 3 }, { 7, 7 }, { 13, 4 } } },
}

local function drawCrackPath(points, fraction)
  local segments = #points - 1
  local exact = math.max(0, math.min(1, fraction)) * segments
  local full = math.floor(exact)
  local remainder = exact - full
  for i = 1, full do
    local a, b = points[i], points[i + 1]
    love.graphics.line(a[1], a[2], b[1], b[2])
  end
  if full < segments and remainder > 0 then
    local a, b = points[full + 1], points[full + 2]
    love.graphics.line(a[1], a[2], a[1] + (b[1] - a[1]) * remainder, a[2] + (b[2] - a[2]) * remainder)
  end
end

function render.egg(x, y, scale, opts)
  opts = opts or {}
  local alpha = opts.alpha or 1
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(scale, scale)
  local wobble = opts.wobble or 0
  love.graphics.rotate(wobble)
  if not opts.noShadow then
    love.graphics.setColor(0, 0, 0, 0.18 * alpha)
    love.graphics.ellipse("fill", 0, 34, 26, 5)
  end
  love.graphics.setColor(0.86, 0.80, 0.63, alpha)
  love.graphics.ellipse("fill", 0, 0, 22, 30)
  love.graphics.setColor(0.94, 0.90, 0.76, alpha)
  love.graphics.ellipse("fill", -6, -8, 10, 16)
  love.graphics.setColor(0.66, 0.56, 0.37, alpha)
  love.graphics.ellipse("line", 0, 0, 22, 30)
  if not opts.clean then
    love.graphics.setColor(0.55, 0.46, 0.30, 0.7 * alpha)
    love.graphics.setLineWidth(1.4)
    love.graphics.line(-12, -10, -4, -4, 2, -10, 9, -3)
    love.graphics.line(-10, 10, -2, 15, 5, 9, 12, 14)
  end

  local crack = opts.crack or 0
  if crack > 0 then
    love.graphics.setLineWidth(1.45)
    for _, path in ipairs(eggCracks) do
      local fraction = (crack - path.at) / 0.20
      if fraction > 0 then
        love.graphics.setColor(0.32, 0.24, 0.14, 0.92 * alpha)
        drawCrackPath(path.points, fraction)
        love.graphics.setColor(0.97, 0.93, 0.82, 0.55 * alpha)
        love.graphics.setLineWidth(0.7)
        local points = path.points
        for i = 1, #points - 1 do
          local a, b = points[i], points[i + 1]
          love.graphics.line(a[1] + 0.8, a[2] + 0.3, b[1] + 0.8, b[2] + 0.3)
        end
        love.graphics.setLineWidth(1.45)
        if fraction >= 1 then
          local tip = points[#points]
          love.graphics.setColor(0.74, 0.66, 0.48, 0.95 * alpha)
          love.graphics.polygon("fill", tip[1], tip[2], tip[1] + 2.2, tip[2] + 0.8, tip[1] + 0.8, tip[2] + 2.4)
        end
      end
    end
  end

  if opts.cross then
    love.graphics.setColor(0.56, 0.78, 0.82, 0.9 * alpha)
    love.graphics.circle("line", 0, 0, 27)
  end
  love.graphics.setLineWidth(1)
  love.graphics.pop()
end

return render
