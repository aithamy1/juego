-- Arte por capas dibujado por código. Solo esta capa usa love.graphics.
local config = require("src.game.config")

local render = {}

local function clamp01(v)
  if v < 0 then
    return 0
  end
  if v > 1 then
    return 1
  end
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
    primary = mix(primary, { 0.96, 0.94, 0.88 }, 0.78)
    secondary = mix(secondary, { 0.99, 0.93, 0.90 }, 0.72)
  elseif mutation == "melanico" then
    primary = mix(primary, { 0.05, 0.06, 0.05 }, 0.72)
    secondary = mix(secondary, { 0.08, 0.08, 0.07 }, 0.65)
  elseif mutation == "fantasma" then
    primary = mix(primary, { 0.85, 0.95, 0.95 }, 0.48)
    secondary = mix(secondary, { 0.95, 1.0, 1.0 }, 0.55)
  end

  return {
    body = primary,
    belly = secondary,
    dark = mix(primary, { 0.04, 0.05, 0.04 }, 0.48),
    light = mix(primary, { 1, 1, 1 }, 0.28),
    outline = mix(primary, { 0.02, 0.03, 0.02 }, 0.72),
  }
end

local function color(rgb, alpha)
  love.graphics.setColor(rgb[1], rgb[2], rgb[3], alpha or 1)
end

local function torso(species, p, detail)
  if species == "triceratops" then
    love.graphics.ellipse("fill", 0, 0, 44, 26)
    love.graphics.ellipse("fill", 48, -2, 21, 18)
    love.graphics.polygon("fill", -42, 0, -74, -8, -78, 3, -43, 12)
  elseif species == "velociraptor" then
    love.graphics.ellipse("fill", 0, 0, 38, 18)
    love.graphics.polygon("fill", 26, -8, 42, -22, 53, -20, 40, -4)
    love.graphics.ellipse("fill", 47, -25, 13, 10)
    love.graphics.polygon("fill", -34, 3, -76, -2, -79, 2, -36, 12)
  elseif species == "parasaurolophus" then
    love.graphics.ellipse("fill", 0, 0, 40, 24)
    love.graphics.polygon("fill", 26, -10, 35, -36, 44, -40, 42, -12)
    love.graphics.ellipse("fill", 40, -43, 14, 12)
    love.graphics.polygon("fill", -38, 0, -74, -6, -77, 4, -38, 10)
  elseif species == "pteranodon" then
    love.graphics.ellipse("fill", 0, 0, 30, 18)
    love.graphics.ellipse("fill", 36, -19, 12, 11)
    love.graphics.polygon("fill", 44, -19, 82, -15, 45, -9)
  elseif species == "stegosaurus" then
    love.graphics.ellipse("fill", 0, 0, 46, 24)
    love.graphics.polygon("fill", 34, -10, 47, -4, 52, 6, 38, 8)
    love.graphics.ellipse("fill", 48, 2, 13, 11)
    love.graphics.polygon("fill", -40, 0, -72, -4, -75, 5, -41, 10)
  elseif species == "ankylosaurus" then
    love.graphics.ellipse("fill", 0, 0, 48, 26)
    love.graphics.polygon("fill", 32, -8, 46, 0, 50, 10, 34, 10)
    love.graphics.ellipse("fill", 48, 4, 14, 11)
    love.graphics.polygon("fill", -42, 2, -60, 2, -62, 10, -42, 12)
    love.graphics.ellipse("fill", -66, 5, 13, 10)
  end
  if detail then
    color(p.dark, 1)
    love.graphics.ellipse("fill", 6, 8, 24, 13)
  end
end

local function legs(species, p)
  color(p.dark, 1)
  local function leg(x, y, w, h)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.ellipse("fill", x + w / 2, y + h, w / 2 + 3, 4)
  end
  if species == "velociraptor" then
    leg(-8, 12, 8, 24)
    leg(16, 12, 8, 24)
    color(p.light, 1)
    love.graphics.polygon("fill", -12, 34, -20, 40, -8, 39)
    love.graphics.polygon("fill", 14, 34, 24, 40, 12, 39)
  elseif species == "pteranodon" then
    leg(-10, 11, 6, 18)
    leg(12, 11, 6, 18)
  else
    leg(-26, 12, 11, 24)
    leg(14, 12, 11, 24)
    leg(-6, 14, 10, 20)
    leg(30, 12, 10, 22)
  end
end

local function backDetails(species, p, crest)
  if species == "triceratops" then
    color(p.belly, 1)
    love.graphics.polygon("fill",
      26, -16, 20, -32, 30, -42, 48, -44,
      66, -36, 78, -20, 72, 0, 56, 12, 32, 6)
    color(mix(p.belly, p.dark, 0.25), 1)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line",
      26, -16, 20, -32, 30, -42, 48, -44,
      66, -36, 78, -20, 72, 0, 56, 12, 32, 6)
  elseif species == "pteranodon" then
    color(p.dark, 0.92)
    love.graphics.polygon("fill",
      2, -8,
      -18, -54,
      -58, -66,
      -50, -34,
      -30, -12)
    love.graphics.polygon("fill",
      8, -10,
      34, -58,
      72, -62,
      62, -34,
      36, -12)
    color(p.light, 0.55)
    love.graphics.polygon("fill",
      -2, -12, -20, -45, -46, -53, -29, -22)
    love.graphics.polygon("fill",
      10, -14, 36, -49, 60, -53, 44, -24)
  elseif species == "stegosaurus" then
    color(p.secondary or p.belly, 1)
    local plates = { { -26, 14 }, { -8, 18 }, { 12, 17 }, { 30, 13 } }
    for i, plate in ipairs(plates) do
      local x, h = plate[1], plate[2]
      love.graphics.polygon("fill", x - 7, -16, x, -16 - h, x + 7, -16)
      color(mix(p.belly, p.dark, 0.25), 1)
      love.graphics.polygon("line", x - 7, -16, x, -16 - h, x + 7, -16)
      color(p.belly, 1)
    end
    color(p.dark, 1)
    love.graphics.polygon("fill", -70, 2, -84, -8, -86, 4, -74, 10)
    love.graphics.polygon("fill", -70, 2, -84, 12, -78, 16, -66, 8)
  elseif species == "ankylosaurus" then
    color(p.dark, 1)
    for i = 1, 6 do
      local x = -28 + (i - 1) * 11
      local y = -14 + (i % 2) * 3
      love.graphics.ellipse("fill", x, y, 6, 4)
    end
    love.graphics.polygon("fill", -80, -2, -86, -10, -88, 2)
    love.graphics.polygon("fill", -80, 10, -88, 16, -84, 4)
  end

  if crest and crest ~= "ninguna" then
    local big = crest == "grande"
    color(p.belly, 1)
    local count = big and 3 or 1
    for i = 1, count do
      local x = -16 + (i - 1) * (big and 16 or 0)
      local h = big and 15 or 9
      love.graphics.polygon("fill", x - 6, -14, x, -14 - h, x + 6, -14)
      color(mix(p.belly, p.dark, 0.3), 1)
      love.graphics.polygon("line", x - 6, -14, x, -14 - h, x + 6, -14)
      color(p.belly, 1)
    end
  end
end

local function headDetails(species, p, crest)
  color(p.outline, 1)
  love.graphics.setLineWidth(2)

  if species == "triceratops" then
    color(p.light, 1)
    love.graphics.polygon("fill", 52, -18, 65, -34, 60, -12)
    love.graphics.polygon("fill", 38, -20, 44, -36, 48, -16)
    color(p.light, 1)
    love.graphics.polygon("fill", 60, -6, 76, -10, 63, 2)
  elseif species == "velociraptor" then
    color(p.light, 1)
    love.graphics.polygon("fill", 40, -31, 48, -42, 54, -29, 46, -24)
    love.graphics.polygon("fill", -40, 0, -66, -8, -72, -2, -42, 10)
    color(p.dark, 1)
    love.graphics.polygon("fill", 54, -19, 64, -17, 54, -14)
  elseif species == "parasaurolophus" then
    color(p.belly, 1)
    love.graphics.polygon("fill",
      34, -48, 20, -64, 8, -62, 22, -52, 38, -42)
    color(mix(p.belly, p.dark, 0.3), 1)
    love.graphics.polygon("line", 34, -48, 20, -64, 8, -62, 22, -52, 38, -42)
    color(p.light, 1)
    love.graphics.polygon("fill", 46, -46, 58, -44, 46, -40)
  elseif species == "pteranodon" then
    color(p.belly, 1)
    love.graphics.polygon("fill", 30, -28, 8, -38, 22, -20)
    color(p.light, 1)
    love.graphics.polygon("fill", 42, -24, 80, -17, 42, -12)
    color(p.dark, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(42, -24, 80, -17)
    love.graphics.line(42, -12, 78, -16)
  elseif species == "stegosaurus" then
    color(p.light, 1)
    love.graphics.polygon("fill", 54, -4, 62, -1, 54, 3)
  elseif species == "ankylosaurus" then
    color(p.light, 1)
    love.graphics.polygon("fill", 58, 1, 66, 4, 58, 8)
    color(p.dark, 1)
    for i = 1, 4 do
      love.graphics.circle("fill", 36 + i * 5, -2 + (i % 2) * 4, 2)
    end
  end

  -- Cresta genética adicional, visible en la cabeza para todas las especies.
  if crest == "grande" then
    color(p.belly, 1)
    love.graphics.polygon("fill", 34, -28, 42, -48, 50, -28)
    color(mix(p.belly, p.dark, 0.3), 1)
    love.graphics.polygon("line", 34, -28, 42, -48, 50, -28)
  elseif crest == "pequena" then
    color(p.belly, 1)
    love.graphics.polygon("fill", 38, -26, 44, -39, 49, -25)
  end
end

local function eye(species, p, mutated)
  local x, y = 52, -8
  if species == "velociraptor" then
    x, y = 51, -27
  elseif species == "parasaurolophus" then
    x, y = 45, -45
  elseif species == "pteranodon" then
    x, y = 40, -21
  elseif species == "stegosaurus" then
    x, y = 50, -1
  elseif species == "ankylosaurus" then
    x, y = 51, 1
  end
  color({ 0.97, 0.95, 0.84 }, 1)
  love.graphics.circle("fill", x, y, 4.4)
  if mutated == "albino" then
    color({ 0.72, 0.16, 0.12 }, 1)
  elseif mutated == "fantasma" then
    color({ 0.55, 0.95, 0.92 }, 1)
  else
    color({ 0.07, 0.08, 0.07 }, 1)
  end
  love.graphics.circle("fill", x + 1.1, y, 2.1)
  color({ 1, 1, 1 }, 0.9)
  love.graphics.circle("fill", x + 0.1, y - 1, 0.8)
end

local function drawPattern(genes, p, dino)
  local pattern = genes.pattern or "liso"
  if pattern == "liso" then
    return
  end
  local seed = (dino.id or 1) * 7.13
  color(p.dark, 0.58)
  love.graphics.setLineWidth(3.2)
  if pattern == "rayado" then
    for i = -8, 8 do
      local x = i * 12
      love.graphics.line(x - 22, 34, x + 26, -32)
    end
  elseif pattern == "moteado" then
    for i = 1, 26 do
      local x = -52 + hash(seed + i) * 112
      local y = -30 + hash(seed + i + 40) * 54
      love.graphics.circle("fill", x, y, 1.8 + hash(seed + i + 80) * 1.8)
    end
  elseif pattern == "manchas" then
    for i = 1, 11 do
      local x = -48 + hash(seed + i) * 102
      local y = -28 + hash(seed + i + 30) * 48
      local radius = 4 + hash(seed + i + 60) * 5
      love.graphics.circle("fill", x, y, radius)
    end
  end
end

local function mutationOverlay(dino, p, alpha)
  if dino.mutation == "bioluminiscente" then
    color(mix(p.body, { 0.95, 1.0, 0.55 }, 0.7), 0.85)
    local seed = (dino.id or 1) * 3.7
    for i = 1, 9 do
      local x = -34 + hash(seed + i) * 74
      local y = -18 + hash(seed + i + 20) * 34
      love.graphics.circle("fill", x, y, 1.3 + hash(seed + i + 40) * 1.4)
    end
    color(mix(p.body, { 0.9, 1.0, 0.6 }, 0.85), 0.9 * alpha)
    love.graphics.circle("fill", 52, -8, 2.2)
  elseif dino.mutation == "fantasma" then
    color({ 0.78, 0.98, 0.95 }, 0.55)
    love.graphics.setLineWidth(1.2)
    love.graphics.ellipse("line", 0, 0, 48, 30)
  end
end

function render.drawDino(dino, x, y, scale, opts)
  opts = opts or {}
  local species = dino.species or "triceratops"
  local genes = dino.genes or {}
  local p = palette(dino)
  local alpha = opts.alpha or 1
  local mutation = dino.mutation
  if mutation == "fantasma" then
    alpha = alpha * 0.56
  end
  if opts.silhouette then
    p = {
      body = { 0.25, 0.28, 0.25 },
      belly = { 0.32, 0.35, 0.31 },
      dark = { 0.18, 0.20, 0.18 },
      light = { 0.35, 0.38, 0.34 },
      outline = { 0.15, 0.17, 0.15 },
    }
    alpha = alpha * 0.7
  end
  local bodyScale = ((config.species[species] or config.species.triceratops).bodyScale or 1)
  local finalScale = scale * bodyScale
  if mutation == "gigante" then
    finalScale = finalScale * 1.24
  end

  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(finalScale, finalScale)

  color({ 0, 0, 0 }, 0.22 * alpha)
  love.graphics.ellipse("fill", 0, 48, 50, 7)

  if mutation == "bioluminiscente" and not opts.silhouette then
    love.graphics.setBlendMode("add")
    for i = 4, 1, -1 do
      color(mix(p.body, { 0.9, 1.0, 0.5 }, 0.75), 0.035 * alpha * i)
      love.graphics.circle("fill", 4, 0, 34 + i * 9)
    end
    love.graphics.setBlendMode("alpha")
  end

  if not opts.silhouette then
    legs(species, p)
    backDetails(species, p, genes.crest)
  else
    legs(species, p)
  end

  color(p.body, alpha)
  torso(species, p, false)
  color(p.belly, alpha * 0.9)
  love.graphics.ellipse("fill", 4, 12, 26, 11)

  if not opts.silhouette then
    love.graphics.stencil(function()
      color(p.body, 1)
      torso(species, p, false)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    drawPattern(genes, p, dino)
    love.graphics.setStencilTest()
  end

  color(p.outline, alpha)
  love.graphics.setLineWidth(1.8)
  if species == "triceratops" then
    love.graphics.ellipse("line", 0, 0, 44, 26)
    love.graphics.ellipse("line", 48, -2, 21, 18)
    love.graphics.polygon("line", -42, 0, -74, -8, -78, 3, -43, 12)
  elseif species == "velociraptor" then
    love.graphics.ellipse("line", 0, 0, 38, 18)
    love.graphics.ellipse("line", 47, -25, 13, 10)
    love.graphics.polygon("line", -34, 3, -76, -2, -79, 2, -36, 12)
  elseif species == "parasaurolophus" then
    love.graphics.ellipse("line", 0, 0, 40, 24)
    love.graphics.ellipse("line", 40, -43, 14, 12)
    love.graphics.polygon("line", -38, 0, -74, -6, -77, 4, -38, 10)
  elseif species == "pteranodon" then
    love.graphics.ellipse("line", 0, 0, 30, 18)
    love.graphics.ellipse("line", 36, -19, 12, 11)
  elseif species == "stegosaurus" then
    love.graphics.ellipse("line", 0, 0, 46, 24)
    love.graphics.ellipse("line", 48, 2, 13, 11)
  elseif species == "ankylosaurus" then
    love.graphics.ellipse("line", 0, 0, 48, 26)
    love.graphics.ellipse("line", 48, 4, 14, 11)
    love.graphics.ellipse("line", -66, 5, 13, 10)
  end

  if not opts.silhouette then
    headDetails(species, p, genes.crest)
    eye(species, p, mutation)
    mutationOverlay(dino, p, alpha)
  end

  love.graphics.setLineWidth(1)
  love.graphics.pop()
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
