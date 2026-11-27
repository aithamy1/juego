-- Animación de eclosión: grietas progresivas, rotura de cáscara y salida del dinosaurio.
local config = require("src.game.config")
local theme = require("src.ui.theme")
local render = require("src.render.dino")
local audio = require("src.audio.audio")

local eggReveal = {}
local TAU = math.pi * 2

local function clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

local function smoothstep(t)
  t = clamp(t, 0, 1)
  return t * t * (3 - 2 * t)
end

function eggReveal.new(seed)
  return {
    seed = seed or 1,
    crackStage = 0,
    hatchPlayed = false,
  }
end

function eggReveal.sync(anim, elapsed, reveal, game)
  if not anim or game.settings.calm then
    return
  end
  if elapsed >= config.time.revealBurst then
    if not anim.hatchPlayed then
      anim.hatchPlayed = true
      audio.playHatch(reveal.rarity)
    end
    return
  end
  local latest = 0
  for index, at in ipairs(config.time.revealCracks) do
    if elapsed >= at then
      latest = index
    end
  end
  if latest > anim.crackStage then
    anim.crackStage = latest
    audio.playCrack(latest)
  end
end

local function drawGlow(cx, cy, elapsed, rarity)
  local burst = config.time.revealBurst
  local build = clamp((elapsed - 0.55) / (burst - 0.55), 0, 1)
  if build > 0 and elapsed < burst then
    love.graphics.setBlendMode("add")
    for layer = 3, 1, -1 do
      local pulse = 0.5 + 0.5 * math.sin(elapsed * 7 + layer)
      love.graphics.setColor(1.0, 0.82, 0.38, 0.05 * build * pulse * layer)
      love.graphics.circle("fill", cx, cy - 6, (34 + layer * 10) * (0.75 + build * 0.35))
    end
    love.graphics.setBlendMode("alpha")
  end

  local since = elapsed - burst
  if since < 0 then
    return
  end
  local fade = clamp(1 - since / 0.85, 0, 1)
  if fade <= 0 then
    return
  end
  local color = theme.rarityColor(rarity)
  love.graphics.setBlendMode("add")
  love.graphics.setLineWidth(3)
  for ray = 0, 11 do
    local angle = ray * TAU / 12 + since * 0.45
    local inner = 26 + since * 80
    local outer = 70 + since * 190
    love.graphics.setColor(1.0, 0.86, 0.44, 0.20 * fade)
    love.graphics.line(cx + math.cos(angle) * inner, cy - 4 + math.sin(angle) * inner,
      cx + math.cos(angle) * outer, cy - 4 + math.sin(angle) * outer)
  end
  love.graphics.setLineWidth(1)
  love.graphics.setColor(color[1], color[2], color[3], 0.12 * fade)
  love.graphics.circle("fill", cx, cy - 4, 42 + since * 90)
  love.graphics.setBlendMode("alpha")
end

local function drawShellHalf(cx, cy, scale, left, dx, dy, angle, alpha)
  local previous = { love.graphics.getScissor() }
  local splitX = cx + dx
  if left then
    love.graphics.setScissor(0, 0, splitX, config.window.height)
  else
    love.graphics.setScissor(splitX, 0, config.window.width - splitX, config.window.height)
  end
  love.graphics.push()
  love.graphics.translate(cx + dx, cy + dy)
  love.graphics.rotate(angle)
  render.egg(0, 0, scale, {
    noShadow = true,
    clean = true,
    crack = 1,
    alpha = alpha,
  })
  love.graphics.pop()
  love.graphics.setScissor(previous[1], previous[2], previous[3], previous[4])
end

local function drawParticles(anim, elapsed, cx, cy, rarity)
  local burst = config.time.revealBurst
  local since = elapsed - burst
  if since < 0 then
    return
  end
  local rarityColor = theme.rarityColor(rarity)
  love.graphics.setBlendMode("add")
  for i = 1, 30 do
    local angle = (i * 2.39996 + anim.seed * 0.017) % TAU
    local speed = 65 + (i * 37) % 150
    local life = 0.55 + ((i * 29) % 45) / 100
    local alpha = clamp(1 - since / life, 0, 1)
    if alpha > 0 then
      local x = cx + math.cos(angle) * speed * since
      local y = cy - 8 + math.sin(angle) * speed * since * 0.72 + 230 * since * since
      local size = 2 + (i % 3)
      if i % 4 == 0 then
        love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], alpha)
      elseif i % 3 == 0 then
        love.graphics.setColor(1.0, 0.97, 0.84, alpha)
      else
        love.graphics.setColor(1.0, 0.78, 0.30, alpha)
      end
      love.graphics.rectangle("fill", x - size / 2, y - size / 2, size, size)
    end
  end
  love.graphics.setBlendMode("alpha")

  -- Trozos de cáscara que caen.
  love.graphics.setColor(0.78, 0.70, 0.52, clamp(1 - since / 0.8, 0, 1))
  for i = 1, 7 do
    local direction = (i % 2 == 0) and 1 or -1
    local speed = 24 + i * 9
    local x = cx + direction * speed * since
    local y = cy + 24 + 110 * since * since + i * 3
    love.graphics.rectangle("fill", x, y, 3 + (i % 2), 2 + (i % 3))
  end
end

function eggReveal.draw(anim, dino, reveal, x, y, elapsed)
  anim = anim or eggReveal.new(reveal.id)
  local cx = x + 380
  local cy = y + 248
  local burst = config.time.revealBurst
  local baseY = y + 255
  local crack = clamp((elapsed - 0.18) / (burst - 0.18), 0, 1)
  local intensity = clamp(elapsed / burst, 0, 1)
  local shakeX, shakeY = 0, 0
  if elapsed >= burst then
    local since = elapsed - burst
    local amount = 6 * math.max(0, 1 - since / 0.28)
    shakeX = math.sin(elapsed * 95) * amount
    shakeY = math.cos(elapsed * 81) * amount * 0.65
  end
  local ecx = cx + shakeX
  local ecy = cy + shakeY

  -- Sombra del huevo o del dinosaurio.
  local shadowAlpha = 0.20
  if elapsed >= burst then
    local since = elapsed - burst
    shadowAlpha = 0.20 * clamp(1 - (since - 0.25) / 0.35, 0, 1)
  end
  if shadowAlpha > 0 then
    love.graphics.setColor(0, 0, 0, shadowAlpha)
    love.graphics.ellipse("fill", ecx, ecy + 58, 50, 9)
  end

  drawGlow(ecx, ecy, elapsed, reveal.rarity)

  if elapsed >= burst then
    local since = elapsed - burst
    local t = clamp((since - 0.08) / 0.62, 0, 1)
    local pop = smoothstep(t)
    if t > 0.78 then
      pop = pop + math.sin((t - 0.78) / 0.22 * math.pi) * 0.035
    end
    if dino and since >= 0.08 then
      local alpha = clamp((since - 0.08) / 0.10, 0, 1)
      local scale = 1.65 * math.max(0.04, pop)
      render.drawDino(dino, ecx, baseY + shakeY + (1 - pop) * 24, scale, { alpha = alpha })
    elseif not dino and reveal.pendingSpecies and elapsed < config.time.revealResult then
      local alpha = clamp((since - 0.08) / 0.18, 0, 1)
      local pulse = 1 + math.sin(since * 7) * 0.05
      love.graphics.push()
      love.graphics.translate(ecx, ecy - 4)
      love.graphics.scale(pulse, pulse)
      theme.setFont(48)
      theme.setColor(theme.colors.goldLight, alpha)
      love.graphics.printf("?", -58, -54, 116, "center")
      love.graphics.pop()
    end
  end

  if elapsed < burst then
    local jitter = 0
    local wobble = math.sin(elapsed * 34) * (0.018 + 0.075 * intensity)
    if elapsed > 0.25 then
      jitter = math.sin(elapsed * 67) * (0.7 + 3.4 * intensity)
    end
    local pulse = 1 + math.sin(elapsed * 22) * 0.018 * intensity
    render.egg(ecx + jitter, ecy, 2.0 * pulse, {
      wobble = wobble,
      crack = crack,
      clean = true,
    })
  else
    local since = elapsed - burst
    local split = clamp(since / 0.50, 0, 1)
    local alpha = clamp(1 - (split - 0.55) / 0.45, 0, 1)
    if alpha > 0 then
      local fall = split * 24 + split * split * 20
      drawShellHalf(ecx, ecy, 2.0 * (1 - split * 0.06), true,
        -split * 46, fall, -split * 0.55, alpha)
      drawShellHalf(ecx, ecy, 2.0 * (1 - split * 0.06), false,
        split * 46, fall, split * 0.55, alpha)
    end
  end

  if elapsed >= burst then
    local since = elapsed - burst
    local flash = clamp(1 - since / 0.34, 0, 1)
    if flash > 0 then
      love.graphics.setBlendMode("add")
      love.graphics.setColor(1.0, 0.94, 0.74, 0.55 * flash)
      love.graphics.circle("fill", ecx, ecy - 4, 28 + since * 520)
      love.graphics.setBlendMode("alpha")
    end
    drawParticles(anim, elapsed, ecx, ecy, reveal.rarity)
  else
    -- Polvo y esquirlas que salen de las grietas.
    if crack > 0.15 then
      love.graphics.setColor(0.82, 0.74, 0.56, 0.55 * crack)
      for i = 1, 7 do
        local angle = i * 0.9 + elapsed * 1.4
        local distance = 20 + crack * 26 + i * 2
        love.graphics.rectangle("fill",
          ecx + math.cos(angle) * distance,
          ecy + 20 - math.sin(angle) * 8 + crack * 10,
          2, 2)
      end
    end
    for i = 1, anim.crackStage do
      local age = elapsed - config.time.revealCracks[i]
      if age >= 0 and age < 0.65 then
        local side = (i % 2 == 0) and 1 or -1
        love.graphics.setColor(0.78, 0.70, 0.52, 1 - age / 0.65)
        love.graphics.rectangle("fill",
          ecx + side * (12 + i * 2) + side * age * 44,
          ecy - 8 + i * 4 + 70 * age * age,
          2 + (i % 2), 2 + (i % 2))
      end
    end
  end
end

return eggReveal
