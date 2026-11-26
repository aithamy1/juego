-- Dinosaurios pixel-art de rejilla. Solo esta capa usa love.graphics.
local config = require("src.game.config")

local render = {}

local W, H = 32, 24

local function clamp01(v)
  if v < 0 then return 0 end
  if v > 1 then return 1 end
  return v
end

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

  local eye = { 0.04, 0.04, 0.04 }
  if mutation == "albino" then
    eye = { 0.72, 0.16, 0.12 }
  elseif mutation == "fantasma" then
    eye = { 0.55, 0.95, 0.92 }
  elseif mutation == "melanico" then
    eye = { 0.92, 0.90, 0.70 }
  end

  return {
    body = primary,
    shade = mix(primary, { 0.02, 0.02, 0.02 }, 0.42),
    light = mix(primary, { 1, 1, 1 }, 0.28),
    belly = secondary,
    feature = secondary,
    featureShade = mix(secondary, { 0.02, 0.02, 0.02 }, 0.38),
    horn = { 0.94, 0.88, 0.70 },
    outline = mix(primary, { 0.01, 0.01, 0.01 }, 0.84),
    eye = eye,
  }
end

local function newGrid()
  local g = { cells = {}, w = W, h = H }
  for y = 1, H do
    local row = {}
    for x = 1, W do
      row[x] = "."
    end
    g.cells[y] = row
  end
  return g
end

local function set(g, x, y, ch)
  x, y = math.floor(x + 0.5), math.floor(y + 0.5)
  if x >= 1 and x <= W and y >= 1 and y <= H then
    g.cells[y][x] = ch
  end
end

local function get(g, x, y)
  if x < 1 or x > W or y < 1 or y > H then
    return "."
  end
  return g.cells[y][x]
end

local function rect(g, x, y, w, h, ch)
  for yy = y, y + h - 1 do
    for xx = x, x + w - 1 do
      set(g, xx, yy, ch)
    end
  end
end

local function ellipse(g, cx, cy, rx, ry, ch)
  for y = math.floor(cy - ry), math.ceil(cy + ry) do
    for x = math.floor(cx - rx), math.ceil(cx + rx) do
      local nx = (x - cx) / rx
      local ny = (y - cy) / ry
      if nx * nx + ny * ny <= 1.02 then
        set(g, x, y, ch)
      end
    end
  end
end

local function polygon(g, points, ch)
  local minY, maxY = 999, -999
  for i = 1, #points, 2 do
    local y = points[i + 1]
    if y < minY then minY = y end
    if y > maxY then maxY = y end
  end
  for y = math.floor(minY), math.ceil(maxY) do
    local xs = {}
    local count = #points / 2
    for i = 1, count do
      local x1 = points[i * 2 - 1]
      local y1 = points[i * 2]
      local j = i % count + 1
      local x2 = points[j * 2 - 1]
      local y2 = points[j * 2]
      if (y1 <= y and y2 > y) or (y2 <= y and y1 > y) then
        xs[#xs + 1] = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
      end
    end
    table.sort(xs)
    for i = 1, #xs - 1, 2 do
      local from = math.ceil(xs[i] - 0.5)
      local to = math.floor(xs[i + 1] - 0.5)
      for x = from, to do
        set(g, x, y, ch)
      end
    end
  end
end

local function pixelLine(g, x1, y1, x2, y2, ch)
  local dx = math.abs(x2 - x1)
  local dy = math.abs(y2 - y1)
  local sx = x1 < x2 and 1 or -1
  local sy = y1 < y2 and 1 or -1
  local err = dx - dy
  while true do
    set(g, x1, y1, ch)
    if x1 == x2 and y1 == y2 then break end
    local e2 = err * 2
    if e2 > -dy then err = err - dy; x1 = x1 + sx end
    if e2 < dx then err = err + dx; y1 = y1 + sy end
  end
end

local crestSpots = {
  triceratops = { 19, 5 },
  velociraptor = { 23, 6 },
  parasaurolophus = { 24, 3 },
  pteranodon = { 19, 7 },
  stegosaurus = { 24, 11 },
  ankylosaurus = { 24, 11 },
}

local function buildGrid(dino, silhouette)
  local species = dino.species or "triceratops"
  local genes = dino.genes or {}
  local g = newGrid()

  if species == "triceratops" then
    ellipse(g, 23, 11, 8, 7, "v")          -- gola
    ellipse(g, 13, 15, 9, 6, "b")          -- cuerpo
    polygon(g, { 2, 13, 4, 11, 8, 14, 8, 18, 3, 18 }, "b")
    ellipse(g, 25, 12, 5, 5, "b")          -- cabeza
    polygon(g, { 18, 12, 23, 8, 27, 9, 27, 15, 20, 16 }, "b")
    rect(g, 5, 18, 3, 6, "b")
    rect(g, 9, 19, 3, 5, "b")
    rect(g, 16, 18, 3, 6, "b")
    rect(g, 21, 19, 3, 5, "b")
    ellipse(g, 14, 19, 7, 2, "n")
    polygon(g, { 20, 8, 18, 3, 22, 7 }, "h")
    polygon(g, { 26, 8, 29, 3, 24, 7 }, "h")
    polygon(g, { 29, 11, 32, 7, 28, 10 }, "h")
    polygon(g, { 28, 14, 32, 15, 28, 17 }, "h")
  elseif species == "parasaurolophus" then
    polygon(g, { 1, 11, 3, 9, 7, 13, 7, 18, 2, 18 }, "b")
    ellipse(g, 14, 15, 8, 5, "b")
    polygon(g, { 20, 13, 22, 7, 28, 7, 28, 14, 20, 14 }, "b")
    ellipse(g, 27, 7, 4, 3, "b")
    rect(g, 12, 18, 3, 6, "b")
    rect(g, 18, 18, 3, 6, "b")
    rect(g, 24, 13, 2, 4, "b")
    ellipse(g, 14, 18, 6, 2, "n")
    polygon(g, { 26, 5, 18, 1, 15, 2, 23, 6 }, "v")
    polygon(g, { 29, 8, 32, 9, 29, 11 }, "h")
  elseif species == "stegosaurus" then
    polygon(g, { 1, 14, 4, 12, 8, 15, 7, 18, 1, 18 }, "b")
    ellipse(g, 14, 15, 10, 5, "b")
    polygon(g, { 22, 14, 26, 14, 27, 17, 22, 18 }, "b")
    ellipse(g, 27, 16, 4, 3, "b")
    rect(g, 4, 18, 3, 6, "b")
    rect(g, 8, 19, 3, 5, "b")
    rect(g, 16, 18, 3, 6, "b")
    rect(g, 20, 19, 3, 5, "b")
    ellipse(g, 14, 19, 8, 2, "n")
    local plates = {
      { 5, 6 }, { 12, 8 }, { 19, 8 }, { 26, 6 },
    }
    for _, plate in ipairs(plates) do
      local px, ph = plate[1], plate[2]
      for row = 0, ph - 1 do
        local w = math.max(1, math.floor(7 * (1 - row / ph) + 0.5))
        local half = math.floor((w - 1) / 2)
        for xx = px - half, px + half do
          set(g, xx, 12 - row, "v")
        end
        set(g, px - half - 1, 12 - row, "o")
        set(g, px + half + 1, 12 - row, "o")
      end
      set(g, px, 12 - ph, "o")
    end
    polygon(g, { 1, 12, 0, 8, 3, 13 }, "h")
    polygon(g, { 1, 18, 0, 21, 3, 18 }, "h")
  elseif species == "ankylosaurus" then
    polygon(g, { 1, 15, 5, 13, 8, 16, 6, 19, 1, 19 }, "b")
    ellipse(g, 2, 17, 3, 3, "b")
    ellipse(g, 14, 16, 10, 5, "b")
    ellipse(g, 26, 16, 4, 4, "b")
    rect(g, 4, 19, 3, 5, "b")
    rect(g, 9, 20, 3, 4, "b")
    rect(g, 17, 19, 3, 5, "b")
    rect(g, 21, 20, 3, 4, "b")
    ellipse(g, 14, 20, 8, 2, "n")
    for i = 0, 4 do
      local ax = 5 + i * 4
      rect(g, ax, 11, 3, 2, "v")
      rect(g, ax + 1, 14, 3, 2, "v")
    end
    polygon(g, { 1, 12, 0, 8, 3, 12 }, "h")
    polygon(g, { 1, 21, 0, 23, 3, 21 }, "h")
    polygon(g, { 5, 9, 7, 6, 8, 10 }, "h")
  elseif species == "pteranodon" then
    polygon(g, { 11, 12, 3, 2, 8, 0, 17, 10 }, "v")
    polygon(g, { 17, 12, 24, 1, 30, 4, 20, 14 }, "v")
    ellipse(g, 15, 15, 5, 4, "b")
    ellipse(g, 22, 12, 4, 3, "b")
    rect(g, 13, 19, 2, 4, "b")
    rect(g, 17, 19, 2, 4, "b")
    ellipse(g, 15, 17, 4, 2, "n")
    polygon(g, { 20, 10, 16, 7, 22, 8 }, "v")
    polygon(g, { 25, 11, 32, 10, 25, 13 }, "h")
  else -- velociraptor
    polygon(g, { 1, 10, 4, 9, 8, 14, 5, 17, 1, 17 }, "b")
    ellipse(g, 14, 14, 7, 4, "b")
    polygon(g, { 20, 12, 23, 8, 27, 9, 28, 13, 21, 14 }, "b")
    ellipse(g, 24, 10, 4, 3, "b")
    rect(g, 12, 17, 3, 7, "b")
    rect(g, 18, 17, 3, 7, "b")
    rect(g, 23, 13, 2, 3, "b")
    ellipse(g, 14, 17, 5, 2, "n")
    polygon(g, { 1, 10, 4, 9, 6, 12, 2, 13 }, "v")
    polygon(g, { 10, 15, 12, 14, 11, 17 }, "v")
    polygon(g, { 12, 23, 10, 23, 12, 21 }, "h")
    polygon(g, { 18, 23, 20, 23, 18, 21 }, "h")
  end

  -- sombreado por bandas
  for y = 1, H do
    for x = 1, W do
      if g.cells[y][x] == "b" then
        if y <= 11 then
          g.cells[y][x] = "l"
        elseif y >= 17 then
          g.cells[y][x] = "s"
        end
      end
    end
  end

  -- patrón genético
  local pattern = genes.pattern or "liso"
  if pattern ~= "liso" then
    for y = 1, H do
      for x = 1, W do
        local ch = g.cells[y][x]
        if ch == "b" or ch == "l" or ch == "s" then
          local paint = false
          if pattern == "rayado" then
            paint = (x + y) % 7 <= 1
          elseif pattern == "moteado" then
            paint = hash(x * 7 + y * 13) > 0.80
          elseif pattern == "manchas" then
            paint = hash(math.floor(x / 3) * 17 + math.floor(y / 2) * 11) > 0.63
          end
          if paint then
            g.cells[y][x] = "s"
          end
        end
      end
    end
  end

  -- cresta genética discreta en la cabeza
  if genes.crest and genes.crest ~= "ninguna" then
    local spot = crestSpots[species]
    if spot then
      set(g, spot[1], spot[2], "v")
      if genes.crest == "grande" then
        set(g, spot[1] + 1, spot[2] - 1, "v")
      end
    end
  end

  -- separar rasgos del cuerpo antes del contorno exterior
  local bodyChars = { b = true, l = true, s = true, n = true }
  local featureChars = { v = true, h = true }
  local toOutline = {}
  for y = 1, H do
    for x = 1, W do
      if featureChars[g.cells[y][x]] then
        local neighbors = { { x - 1, y }, { x + 1, y }, { x, y - 1 }, { x, y + 1 } }
        for _, n in ipairs(neighbors) do
          if bodyChars[get(g, n[1], n[2])] then
            toOutline[#toOutline + 1] = n
          end
        end
      end
    end
  end
  for _, n in ipairs(toOutline) do
    set(g, n[1], n[2], "o")
  end

  -- contorno exterior
  local exterior = {}
  for y = 1, H do
    for x = 1, W do
      local ch = g.cells[y][x]
      if ch ~= "." and ch ~= "o" then
        local neighbors = { { x - 1, y }, { x + 1, y }, { x, y - 1 }, { x, y + 1 } }
        for _, n in ipairs(neighbors) do
          if get(g, n[1], n[2]) == "." then
            exterior[#exterior + 1] = n
          end
        end
      end
    end
  end
  for _, n in ipairs(exterior) do
    set(g, n[1], n[2], "o")
  end

  if silhouette then
    for y = 1, H do
      for x = 1, W do
        if g.cells[y][x] ~= "." then
          g.cells[y][x] = "o"
        end
      end
    end
    return g
  end

  -- ojos y boca después del contorno
  local eyes = {
    triceratops = { 27, 12 },
    parasaurolophus = { 28, 7 },
    stegosaurus = { 28, 16 },
    ankylosaurus = { 28, 16 },
    pteranodon = { 23, 12 },
    velociraptor = { 25, 10 },
  }
  local eye = eyes[species] or eyes.triceratops
  set(g, eye[1], eye[2], "e")
  set(g, eye[1], eye[2] - 1, "e")
  if species == "triceratops" then
    pixelLine(g, 29, 16, 31, 15, "o")
  elseif species == "parasaurolophus" then
    pixelLine(g, 29, 10, 31, 10, "o")
  elseif species == "stegosaurus" or species == "ankylosaurus" then
    pixelLine(g, 27, 18, 29, 18, "o")
  elseif species == "pteranodon" then
    pixelLine(g, 24, 13, 30, 12, "o")
  else
    pixelLine(g, 25, 12, 27, 11, "o")
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
  local g = buildGrid(dino, opts.silhouette)

  local colorFor = {
    b = p.body,
    s = p.shade,
    l = p.light,
    n = p.belly,
    v = p.feature,
    h = p.horn,
    o = p.outline,
    e = p.eye,
  }

  for y = 1, H do
    for x = 1, W do
      local ch = g.cells[y][x]
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
  local ps = 5 * finalScale

  -- sombra pixelada
  love.graphics.setColor(0, 0, 0, 0.24 * alpha)
  for i = -3, 3 do
    local width = 50 * finalScale * (1 - math.abs(i) * 0.11)
    love.graphics.rectangle("fill", x - width, y + 44 * finalScale + i * 2 * finalScale, width * 2, 2 * finalScale + 1)
  end

  if mutation == "bioluminiscente" and not opts.silhouette then
    local p = palette(dino)
    love.graphics.setBlendMode("add")
    for i = 4, 1, -1 do
      love.graphics.setColor(p.body[1], p.body[2], p.body[3], 0.035 * alpha * i)
      love.graphics.circle("fill", x, y - 4 * finalScale, (34 + i * 9) * finalScale)
    end
    love.graphics.setBlendMode("alpha")
  end

  local canvas = spriteFor(dino, opts)
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.draw(canvas, x, y, 0, ps * flip, ps, 16, 14)
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
