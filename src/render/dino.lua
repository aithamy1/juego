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
    dark = mix(primary, { 0.04, 0.05, 0.04 }, 0.52),
    light = mix(primary, { 1, 1, 1 }, 0.30),
    horn = { 0.93, 0.86, 0.68 },
    outline = mix(primary, { 0.02, 0.03, 0.02 }, 0.84),
  }
end

local function color(rgb, alpha)
  love.graphics.setColor(rgb[1], rgb[2], rgb[3], alpha or 1)
end

local function torso(species, p, detail)
  if species == "triceratops" then
    love.graphics.polygon("fill",
      -40, -2, -34, -16, -20, -23, 0, -25, 22, -21, 34, -11, 34, 2,
      24, 14, 4, 19, -18, 17, -34, 9)
    love.graphics.ellipse("fill", 48, -2, 21, 18)
    love.graphics.polygon("fill", -40, -2, -72, -12, -88, -7, -86, 1, -66, 8, -40, 12)
  elseif species == "velociraptor" then
    love.graphics.ellipse("fill", 0, 0, 38, 18)
    love.graphics.polygon("fill", 26, -8, 42, -22, 53, -20, 40, -4)
    love.graphics.ellipse("fill", 47, -25, 13, 10)
    love.graphics.polygon("fill", -34, 3, -76, -2, -79, 2, -36, 12)
  elseif species == "parasaurolophus" then
    love.graphics.polygon("fill",
      -40, 4, -36, -10, -20, -18, 2, -20, 22, -16, 34, -6, 32, 4,
      20, 12, 0, 16, -22, 15, -36, 10)
    love.graphics.polygon("fill", 24, -10, 34, -36, 44, -40, 42, -12)
    love.graphics.ellipse("fill", 40, -43, 14, 12)
    love.graphics.polygon("fill", -38, -2, -72, -10, -86, -5, -80, 2, -62, 8, -38, 12)
  elseif species == "pteranodon" then
    love.graphics.ellipse("fill", 0, 0, 30, 18)
    love.graphics.ellipse("fill", 36, -19, 12, 11)
    love.graphics.polygon("fill", 44, -19, 82, -15, 45, -9)
  elseif species == "stegosaurus" then
    love.graphics.polygon("fill",
      -42, 2, -38, -10, -26, -18, -8, -21, 12, -19, 30, -11, 36, -2,
      34, 7, 22, 14, 0, 17, -22, 14, -38, 10)
    love.graphics.polygon("fill", 34, -10, 47, -4, 52, 6, 38, 8)
    love.graphics.ellipse("fill", 48, 2, 13, 11)
    love.graphics.polygon("fill", -40, 0, -72, -4, -75, 5, -41, 10)
  elseif species == "ankylosaurus" then
    love.graphics.polygon("fill",
      -44, 0, -40, -12, -26, -19, -6, -21, 16, -19, 34, -11, 40, 0,
      38, 8, 26, 14, 0, 18, -26, 15, -42, 8)
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
  local function leg(x, y, w, h, back)
    color(p.body, 1)
    love.graphics.ellipse("fill", x + w / 2, y + 3, w * 0.78, h * 0.28)
    color(p.dark, 1)
    love.graphics.rectangle("fill", x + w * 0.18, y + h * 0.28, w * 0.64, h * 0.68)
    love.graphics.ellipse("fill", x + w / 2, y + h, w / 2 + 3, 4)
    color(p.light, 0.35)
    love.graphics.rectangle("fill", x + w * 0.25, y + h * 0.30, 2, h * 0.35)
    color(p.horn or { 0.9, 0.82, 0.63 }, 1)
    love.graphics.rectangle("fill", x + w - 2, y + h + 2, 4, 2)
    love.graphics.rectangle("fill", x + w - 7, y + h + 3, 3, 2)
  end

  if species == "velociraptor" then
    leg(-7, 10, 9, 27)
    leg(15, 10, 9, 27)
    color(p.body, 1)
    love.graphics.ellipse("fill", 28, 2, 7, 5)
    love.graphics.rectangle("fill", 24, 5, 10, 5, 2, 2)
    color(p.horn, 1)
    love.graphics.rectangle("fill", 20, 33, 5, 2)
    love.graphics.rectangle("fill", 27, 34, 4, 2)
  elseif species == "parasaurolophus" then
    leg(-12, 10, 11, 27)
    leg(11, 10, 11, 27)
    color(p.body, 1)
    love.graphics.ellipse("fill", 28, 5, 6, 4)
    love.graphics.rectangle("fill", 25, 8, 8, 4, 2, 2)
    color(p.horn, 1)
    love.graphics.rectangle("fill", 26, 13, 4, 2)
  elseif species == "pteranodon" then
    leg(-10, 12, 6, 19)
    leg(10, 12, 6, 19)
  else
    leg(-31, 10, 13, 25)
    leg(-15, 13, 10, 22)
    leg(12, 10, 13, 25)
    leg(28, 12, 10, 23)
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
    color(mix(p.belly, p.dark, 0.45), 0.85)
    love.graphics.setLineWidth(2)
    love.graphics.line(40, -8, 28, -28)
    love.graphics.line(45, -10, 42, -34)
    love.graphics.line(52, -8, 58, -32)
    love.graphics.line(58, -4, 68, -22)
    color(p.belly, 1)
    love.graphics.polygon("fill", 22, -30, 17, -39, 30, -36)
    love.graphics.polygon("fill", 34, -40, 34, -49, 44, -43)
    love.graphics.polygon("fill", 50, -44, 54, -52, 62, -41)
    love.graphics.polygon("fill", 66, -36, 76, -37, 71, -26)
    color(p.outline, 0.9)
    love.graphics.line(17, -39, 30, -36)
    love.graphics.line(34, -49, 44, -43)
    love.graphics.line(54, -52, 62, -41)
    love.graphics.line(76, -37, 71, -26)
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
    color(p.outline, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, -8, -28, -32, -58, -66)
    love.graphics.line(2, -8, -42, -30, -58, -44)
    love.graphics.line(8, -8, 34, -32, 72, -62)
    love.graphics.line(8, -8, 46, -26, 66, -40)
  elseif species == "stegosaurus" then
    color(p.secondary or p.belly, 1)
    local plates = { { -38, 17 }, { -22, 26 }, { -4, 31 }, { 14, 27 }, { 30, 18 } }
    for i, plate in ipairs(plates) do
      local x, h = plate[1], plate[2]
      local half = 9
      love.graphics.polygon("fill", x - half, -17, x, -17 - h, x + half, -17)
      color(mix(p.belly, p.dark, 0.28), 1)
      love.graphics.polygon("line", x - half, -17, x, -17 - h, x + half, -17)
      color(mix(p.belly, { 1, 1, 1 }, 0.22), 0.75)
      love.graphics.polygon("fill", x - half + 2, -17, x, -17 - h + 3, x - 1, -17)
      color(p.belly, 1)
    end
    color(p.dark, 1)
    love.graphics.polygon("fill", -70, 2, -84, -8, -86, 4, -74, 10)
    love.graphics.polygon("fill", -70, 2, -84, 12, -78, 16, -66, 8)
  elseif species == "ankylosaurus" then
    color(p.horn, 1)
    love.graphics.polygon("fill", -78, 0, -86, -9, -88, 3)
    love.graphics.polygon("fill", -78, 10, -88, 16, -84, 3)
  end

  if crest and crest ~= "ninguna" and species ~= "stegosaurus" and species ~= "ankylosaurus" then
    local big = crest == "grande"
    color(p.belly, 1)
    local x = -22
    local h = big and 17 or 10
    love.graphics.polygon("fill", x - 5, -14, x, -14 - h, x + 5, -14)
    color(mix(p.belly, p.dark, 0.3), 1)
    love.graphics.polygon("line", x - 5, -14, x, -14 - h, x + 5, -14)
  end
end

local function headDetails(species, p, crest)
  color(p.outline, 1)
  love.graphics.setLineWidth(2)

  if species == "triceratops" then
    color(p.horn, 1)
    love.graphics.polygon("fill", 37, -16, 32, -38, 45, -18)
    love.graphics.polygon("fill", 51, -16, 60, -42, 58, -17)
    love.graphics.polygon("fill", 62, -8, 77, -13, 64, 1)
    color(p.outline, 1)
    love.graphics.setLineWidth(3)
    love.graphics.polygon("line", 37, -16, 32, -38, 45, -18)
    love.graphics.polygon("line", 51, -16, 60, -42, 58, -17)
    love.graphics.polygon("line", 62, -8, 77, -13, 64, 1)
    color(p.horn, 1)
    love.graphics.polygon("fill", 63, 0, 78, -2, 64, 8)
    color(p.outline, 1)
    love.graphics.line(65, 3, 76, 0)
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
    color(p.horn, 1)
    love.graphics.polygon("fill", 48, -44, 63, -41, 47, -36)
    color(p.outline, 1)
    love.graphics.line(47, -39, 61, -39)
    color(mix(p.belly, p.dark, 0.4), 1)
    love.graphics.line(18, -58, 30, -50)
    love.graphics.line(22, -62, 34, -54)
  elseif species == "pteranodon" then
    color(p.belly, 1)
    love.graphics.polygon("fill", 30, -28, 8, -38, 22, -20)
    color(p.horn, 1)
    love.graphics.polygon("fill", 42, -24, 82, -17, 42, -12)
    color(p.dark, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(42, -24, 80, -17)
    love.graphics.line(42, -12, 78, -16)
  elseif species == "stegosaurus" then
    color(p.light, 1)
    love.graphics.polygon("fill", 54, -4, 62, -1, 54, 3)
  elseif species == "ankylosaurus" then
    color(p.horn, 1)
    love.graphics.polygon("fill", 58, 1, 68, 4, 58, 8)
    color(p.outline, 1)
    love.graphics.line(57, 5, 67, 4)

    -- coraza en filas, visible por delante del cuerpo
    for row = 0, 1 do
      for i = 1, 5 do
        local ax = -32 + (i - 1) * 12 + row * 3
        local ay = -10 + row * 7
        color(p.belly, 1)
        love.graphics.ellipse("fill", ax, ay, 7, 4)
        color(p.outline, 0.85)
        love.graphics.setLineWidth(1.5)
        love.graphics.ellipse("line", ax, ay, 7, 4)
        color(mix(p.belly, { 1, 1, 1 }, 0.25), 0.7)
        love.graphics.rectangle("fill", ax - 3, ay - 2, 5, 1)
      end
    end
    -- púas laterales y de la maza
    color(p.horn, 1)
    love.graphics.polygon("fill", -52, -6, -62, -12, -58, 0)
    love.graphics.polygon("fill", -34, -8, -42, -16, -30, -4)
    love.graphics.polygon("fill", -74, -4, -82, -12, -80, 2)
    love.graphics.polygon("fill", -74, 12, -82, 18, -80, 6)
  end

  if species == "velociraptor" then
    color(p.body, 1)
    love.graphics.rectangle("fill", 27, 4, 6, 10, 2, 2)
    color(p.horn, 1)
    love.graphics.rectangle("fill", 31, 14, 4, 2)
    color(p.outline, 1)
    love.graphics.rectangle("line", 27, 4, 6, 10, 2, 2)
  elseif species == "parasaurolophus" then
    color(p.body, 1)
    love.graphics.rectangle("fill", 26, 8, 6, 9, 2, 2)
    color(p.horn, 1)
    love.graphics.rectangle("fill", 30, 17, 4, 2)
    color(p.outline, 1)
    love.graphics.rectangle("line", 26, 8, 6, 9, 2, 2)
  end

  -- boca y nariz
  color(p.outline, 1)
  love.graphics.setLineWidth(2)
  if species == "triceratops" then
    love.graphics.line(63, 2, 77, -3)
    love.graphics.rectangle("fill", 66, -9, 2, 2)
  elseif species == "velociraptor" then
    love.graphics.line(54, -19, 64, -17)
    love.graphics.rectangle("fill", 54, -23, 2, 2)
  elseif species == "parasaurolophus" then
    love.graphics.line(47, -39, 60, -42)
    love.graphics.rectangle("fill", 48, -46, 2, 2)
  elseif species == "pteranodon" then
    love.graphics.line(48, -19, 76, -17)
    love.graphics.rectangle("fill", 47, -25, 2, 2)
  elseif species == "stegosaurus" then
    love.graphics.line(54, 4, 62, 1)
    love.graphics.rectangle("fill", 52, -1, 2, 2)
  elseif species == "ankylosaurus" then
    love.graphics.line(55, 7, 65, 4)
    love.graphics.rectangle("fill", 53, 2, 2, 2)
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
  color(p.dark, 0.9)
  love.graphics.rectangle("fill", x - 3, y - 3, 8, 2)
  color({ 0.97, 0.95, 0.84 }, 1)
  love.graphics.circle("fill", x, y, 2.1)
  if mutated == "albino" then
    color({ 0.72, 0.16, 0.12 }, 1)
  elseif mutated == "fantasma" then
    color({ 0.55, 0.95, 0.92 }, 1)
  else
    color({ 0.05, 0.06, 0.05 }, 1)
  end
  love.graphics.rectangle("fill", x + 0.2, y - 1.6, 1.3, 3.2)
  color({ 1, 1, 1 }, 0.9)
  love.graphics.rectangle("fill", x - 1.1, y - 1.5, 0.8, 0.8)
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

local function drawRaw(dino, opts)
  opts = opts or {}
  local species = dino.species or "triceratops"
  local genes = dino.genes or {}
  local p = palette(dino)
  local mutation = dino.mutation
  if opts.silhouette then
    p = {
      body = { 0.25, 0.28, 0.25 },
      belly = { 0.32, 0.35, 0.31 },
      dark = { 0.18, 0.20, 0.18 },
      light = { 0.35, 0.38, 0.34 },
      horn = { 0.36, 0.38, 0.34 },
      outline = { 0.15, 0.17, 0.15 },
    }
  end

  if not opts.silhouette then
    legs(species, p)
    backDetails(species, p, genes.crest)
  else
    legs(species, p)
  end

  color(p.body, 1)
  torso(species, p, false)
  color(p.belly, 0.9)
  love.graphics.ellipse("fill", 4, 12, 26, 11)

  if not opts.silhouette then
    love.graphics.stencil(function()
      color(p.body, 1)
      torso(species, p, false)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    drawPattern(genes, p, dino)
    -- volumen y textura de piel, siempre dentro de la silueta
    color(p.light, 0.18)
    love.graphics.ellipse("fill", 2, -7, 35, 14)
    color(p.dark, 0.16)
    love.graphics.ellipse("fill", 2, 14, 39, 11)
    local seed = (dino.id or 1) * 5.3
    for i = 1, 22 do
      local tx = -42 + hash(seed + i) * 86
      local ty = -24 + hash(seed + i + 30) * 42
      color(p.dark, 0.18)
      love.graphics.circle("fill", tx, ty, 0.7 + hash(seed + i + 60) * 1.1)
    end
    love.graphics.setStencilTest()
  end

  color(p.outline, 1)
  love.graphics.setLineWidth(3.2)
  if species == "triceratops" then
    love.graphics.polygon("line",
      -40, -2, -34, -16, -20, -23, 0, -25, 22, -21, 34, -11, 34, 2,
      24, 14, 4, 19, -18, 17, -34, 9)
    love.graphics.ellipse("line", 48, -2, 21, 18)
    love.graphics.polygon("line", -40, -2, -72, -12, -88, -7, -86, 1, -66, 8, -40, 12)
  elseif species == "velociraptor" then
    love.graphics.ellipse("line", 0, 0, 38, 18)
    love.graphics.ellipse("line", 47, -25, 13, 10)
    love.graphics.polygon("line", -34, 3, -76, -2, -79, 2, -36, 12)
  elseif species == "parasaurolophus" then
    love.graphics.polygon("line",
      -40, 4, -36, -10, -20, -18, 2, -20, 22, -16, 34, -6, 32, 4,
      20, 12, 0, 16, -22, 15, -36, 10)
    love.graphics.ellipse("line", 40, -43, 14, 12)
    love.graphics.polygon("line", -38, -2, -72, -10, -86, -5, -80, 2, -62, 8, -38, 12)
  elseif species == "pteranodon" then
    love.graphics.ellipse("line", 0, 0, 30, 18)
    love.graphics.ellipse("line", 36, -19, 12, 11)
  elseif species == "stegosaurus" then
    love.graphics.polygon("line",
      -42, 2, -38, -10, -26, -18, -8, -21, 12, -19, 30, -11, 36, -2,
      34, 7, 22, 14, 0, 17, -22, 14, -38, 10)
    love.graphics.ellipse("line", 48, 2, 13, 11)
  elseif species == "ankylosaurus" then
    love.graphics.polygon("line",
      -44, 0, -40, -12, -26, -19, -6, -21, 16, -19, 34, -11, 40, 0,
      38, 8, 26, 14, 0, 18, -26, 15, -42, 8)
    love.graphics.ellipse("line", 48, 4, 14, 11)
    love.graphics.ellipse("line", -66, 5, 13, 10)
  end

  if not opts.silhouette then
    headDetails(species, p, genes.crest)
    eye(species, p, mutation)
    mutationOverlay(dino, p, 1)
  end

  love.graphics.setLineWidth(1)
end

local spriteCache = {}
local spriteOrder = {}

local function spriteKey(dino, opts, high)
  local genes = dino.genes or {}
  return table.concat({
    dino.species or "triceratops",
    genes.pattern or "liso",
    genes.primaryColor or "verde",
    genes.secondaryColor or "crema",
    genes.crest or "ninguna",
    dino.mutation or "ninguna",
    opts.silhouette and "silueta" or "color",
    tostring(dino.id or 1),
    high and "hi" or "lo",
  }, "|")
end

local function spriteFor(dino, opts, high)
  local key = spriteKey(dino, opts, high)
  local cached = spriteCache[key]
  if cached then
    return cached
  end

  if #spriteOrder >= 240 then
    spriteCache = {}
    spriteOrder = {}
  end

  local width, height, designScale
  if high then
    width, height, designScale = 96, 72, 0.5
  else
    width, height, designScale = 64, 48, 0.32
  end

  local previousCanvas = love.graphics.getCanvas()
  local sx, sy, sw, sh = love.graphics.getScissor()
  love.graphics.setScissor()

  local canvas = love.graphics.newCanvas(width, height)
  love.graphics.setCanvas({ canvas, stencil = true })
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.push()
  love.graphics.translate(width / 2, height / 2)
  love.graphics.scale(designScale, designScale)
  drawRaw(dino, opts)
  love.graphics.pop()

  if previousCanvas then
    love.graphics.setCanvas({ previousCanvas, stencil = true })
  else
    love.graphics.setCanvas()
  end
  if sx then
    love.graphics.setScissor(sx, sy, sw, sh)
  end

  canvas:setFilter("nearest", "nearest")
  spriteCache[key] = { canvas = canvas, width = width, height = height, designScale = designScale }
  spriteOrder[#spriteOrder + 1] = key
  return spriteCache[key]
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

  -- sombra de píxel
  color({ 0, 0, 0 }, 0.24 * alpha)
  local shadowW = 50 * finalScale
  local shadowH = 7 * finalScale
  for i = -3, 3 do
    local width = shadowW * (1 - math.abs(i) * 0.11)
    love.graphics.rectangle("fill", x - width, y + 46 * finalScale + i * shadowH / 3, width * 2, shadowH / 3 + 1)
  end

  if mutation == "bioluminiscente" and not opts.silhouette then
    love.graphics.setBlendMode("add")
    local p = palette(dino)
    for i = 4, 1, -1 do
      color(mix(p.body, { 0.9, 1.0, 0.5 }, 0.75), 0.035 * alpha * i)
      love.graphics.circle("fill", x + 4 * finalScale, y, (34 + i * 9) * finalScale)
    end
    love.graphics.setBlendMode("alpha")
  end

  local high = finalScale >= 0.60
  local sprite = spriteFor(dino, opts, high)
  local pixelScale = finalScale / sprite.designScale
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.draw(sprite.canvas, x, y, 0, pixelScale * flip, pixelScale,
    sprite.width / 2, sprite.height / 2)
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
