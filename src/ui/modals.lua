-- Modales: transparencia, apertura de huevos, liberación, Dinodex y prestigio.
local config = require("src.game.config")
local stateModule = require("src.game.state")
local economy = require("src.game.economy")
local hatch = require("src.game.hatch")
local prestige = require("src.game.prestige")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local render = require("src.render.dino")
local eggReveal = require("src.ui.egg_reveal")

local modals = {}

local function closeButton(app, x, y, w, h, label)
  widgets.button(app, x, y, w, h, label or "Cerrar", {
    style = "secondary",
    onClick = function()
      app:closeModal()
    end,
  })
end

local function geneSummary(genes)
  if not genes then
    return ""
  end
  return table.concat({
    config.patterns[genes.pattern] and config.patterns[genes.pattern].name or genes.pattern,
    config.colors[genes.primaryColor] and config.colors[genes.primaryColor].name or genes.primaryColor,
    config.secondaryColors[genes.secondaryColor] and config.secondaryColors[genes.secondaryColor].name or genes.secondaryColor,
    config.crests[genes.crest] and config.crests[genes.crest].name or genes.crest,
  }, " · ")
end

local function guaranteesText(guaranteed)
  if not guaranteed then
    return nil
  end
  local parts = {}
  if guaranteed.rare then
    parts[#parts + 1] = "Garantía de raro"
  end
  if guaranteed.legendary then
    parts[#parts + 1] = "Garantía de legendario"
  end
  if guaranteed.mutation then
    parts[#parts + 1] = "Garantía de mutación"
  end
  if #parts == 0 then
    return nil
  end
  return table.concat(parts, " · ")
end

-- Ayuda
local function drawHelp(app, modal)
  local x, y = widgets.modalFrame(app, "Cómo se juega", "Un incremental de cría sin prisas, sin anuncios y sin dinero real.", 840, 600)
  theme.setFont(13)
  theme.setColor(theme.colors.amber, 1)
  love.graphics.print("El bucle", x + 28, y + 94)
  theme.setFont(11)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf("Empiezas con un huevo. Cada adulto pone a su propio ritmo y una colonia grande alarga la puesta. Los incubas y, cuando termina la incubación, pulsas ABRIR HUEVOS para abrirlos. Nacen dinosaurios y los adultos generan ámbar de forma pasiva. Con ámbar compras mejoras; con esencia (al liberar ejemplares) amplías el nido y mejoras la suerte. Los cruces heredan genes con proporciones mendelianas y el Dinodex registra cada combinación nueva. En el Criadero asignas rol y hábitat; en la pradera, las pestañas TODOS, BOSQUE, VOLCÁN y COSTA cambian la vista y muestran solo a sus residentes. En Hábitats puedes decorar. Los puntos de la migración se gastan en el Árbol de legado de Ajustes. La primera Gran Migración pide 120 huevos abiertos.",
    x + 28, y + 118, 784, "left")

  theme.setFont(13)
  theme.setColor(theme.colors.amber, 1)
  love.graphics.print("Transparencia", x + 28, y + 210)
  theme.setFont(11)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf("Todas las probabilidades salen de config.lua y el panel del Nido muestra las tasas efectivas del motor. Las barras de garantía son contadores reales: te dicen cuántos huevos faltan para el próximo resultado asegurado. El Registro guarda fecha, rareza, genes, mutación, semilla y tiradas de cada apertura. No hay falsos “casi”, ni urgencia artificial, ni compras.",
    x + 28, y + 234, 784, "left")

  theme.setFont(13)
  theme.setColor(theme.colors.amber, 1)
  love.graphics.print("Atajos", x + 28, y + 330)
  theme.setFont(11)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf("1–7 cambian de pestaña · Esc cierra paneles · Espacio salta la animación de apertura · Rueda del ratón para desplazar listas. En el Criadero, el botón F protege un ejemplar y VS abre la comparación. El trofeo de la cabecera abre objetivos y logros.",
    x + 28, y + 354, 784, "left")

  theme.setFont(13)
  theme.setColor(theme.colors.amber, 1)
  love.graphics.print("Tu ritmo", x + 28, y + 432)
  theme.setFont(11)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf("En Ajustes puedes activar el modo tranquilo, un recordatorio opcional cada 60 o 90 minutos y un tope diario de huevos. En Opciones ajustas volumen, accesibilidad, mando, copias de seguridad y liberación de duplicados. El juego sigue funcionando sin conexión y guarda el progreso hasta 8 horas de ausencia.",
    x + 28, y + 456, 784, "left")

  closeButton(app, x + 660, y + 540, 152, 36, "Entendido")
end

-- Probabilidades
local function drawProbabilities(app, modal)
  local game = app.game
  local snap = hatch.snapshot(game)
  local x, y = widgets.modalFrame(app, "Probabilidades exactas", "Estas son las tasas que usa el motor en este momento. Nada está duplicado en la interfaz.", 920, 620)
  local colX = { x + 28, x + 200, x + 320, x + 450 }
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Rareza", colX[1], y + 94)
  love.graphics.print("Tasa base", colX[2], y + 94)
  love.graphics.print("Tasa efectiva", colX[3], y + 94)
  love.graphics.print("Garantía", colX[4], y + 94)
  local rowY = y + 116
  for _, rarity in ipairs(config.rarityOrder) do
    theme.setFont(11)
    theme.setColor(theme.rarityColor(rarity), 1)
    love.graphics.print(theme.rarityName(rarity), colX[1], rowY)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(theme.fmtPct(snap.base[rarity], 2), colX[2], rowY)
    love.graphics.print(theme.fmtPct(snap.effective[rarity], 2), colX[3], rowY)
    theme.setFont(9)
    theme.setColor(theme.colors.muted, 1)
    if rarity == "rare" then
      love.graphics.print("Raro+ en " .. snap.pity.rareIn .. " huevos", colX[4], rowY + 2)
    elseif rarity == "legendary" then
      love.graphics.print("En " .. snap.pity.legendaryIn .. " · suave desde " .. config.rates.pity.legendarySoftStart, colX[4], rowY + 2)
    end
    rowY = rowY + 24
  end

  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("La tasa efectiva incluye la mejora de suerte. La garantía sustituye la tirada cuando el contador llega al umbral; el resultado forzado puede ser aún mejor.", x + 28, y + 244, 850, "left")

  theme.setFont(11)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Contadores de garantía", x + 28, y + 278)
  local bars = {
    { "Raro o superior", snap.pity.rare, config.rates.pity.rareAt, theme.colors.blue, snap.pity.rareIn },
    { "Legendario", snap.pity.legendary, config.rates.pity.legendaryAt, theme.colors.amber, snap.pity.legendaryIn },
    { "Mutación", snap.pity.mutation, config.rates.pity.mutationAt, theme.colors.essence, snap.pity.mutationIn },
  }
  local barY = y + 300
  for _, bar in ipairs(bars) do
    theme.setFont(10)
    theme.setColor(theme.colors.textDim, 1)
    love.graphics.print(bar[1], x + 28, barY)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print("Próximo garantizado en " .. bar[5] .. " huevo" .. (bar[5] == 1 and "" or "s"), x + 180, barY)
    widgets.progressBar(x + 390, barY + 1, 400, 8, bar[2] / math.max(1, bar[3] - 1), bar[4])
    theme.setFont(9)
    love.graphics.print(bar[2] .. " / " .. (bar[3] - 1), x + 800, barY)
    barY = barY + 24
  end

  theme.setFont(11)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Mutaciones", x + 28, y + 390)
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Probabilidad total: " .. theme.fmtPct(snap.mutationChance, 2)
    .. (snap.pity.mutationGuaranteed and " · garantizada en el próximo huevo" or ""), x + 150, y + 392)
  local mutY = y + 414
  for _, entry in ipairs(snap.mutations) do
    theme.setFont(10)
    theme.setColor(theme.colors.purple, 1)
    love.graphics.print(entry.name, x + 28, mutY)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(theme.fmtPct(entry.chance, 2), x + 200, mutY)
    theme.setFont(9)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print(entry.desc .. "  ·  x" .. theme.fmt(entry.production, 2) .. " de ámbar", x + 290, mutY + 1)
    mutY = mutY + 22
  end

  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("Semilla " .. game.seed .. " · " .. game.rng.count .. " tiradas · Las garantías no se reinician con el prestigio.", x + 28, y + 548, 700, "left")
  widgets.button(app, x + 540, y + 548, 160, 34, "Abrir registro", {
    style = "ghost",
    onClick = function()
      app:closeModal()
      app:goto("log")
    end,
  })
  closeButton(app, x + 720, y + 548, 160, 34)
end

-- Liberar
local function drawRelease(app, modal)
  local dino = stateModule.findDino(app.game, modal.dinoId)
  if not dino then
    app:closeModal()
    return
  end
  local x, y = widgets.modalFrame(app, "Liberar ejemplar", "Esta acción no se puede deshacer.", 620, 390, {
    borderColor = theme.colors.red,
  })
  render.drawDino(dino, x + 120, y + 190, 1.0, {})
  theme.setFont(19)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(config.species[dino.species].name, x + 244, y + 104)
  widgets.rarityChip(x + 244, y + 134, dino.rarity)
  if dino.mutation then
    widgets.chip(x + 244 + 100, y + 134, config.mutations[dino.mutation].name, theme.colors.purple)
  end
  theme.setFont(11)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf(geneSummary(dino.genes), x + 244, y + 170, 330, "left")
  theme.setFont(12)
  theme.setColor(theme.colors.essence, 1)
  local essence = config.rarity[dino.rarity].essence
  love.graphics.print("Recibirás " .. essence .. " de esencia.", x + 244, y + 206)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("El ejemplar desaparece del criadero. No afecta al Dinodex ya descubierto.", x + 244, y + 230, 330, "left")

  widgets.button(app, x + 330, y + 320, 120, 38, "Cancelar", {
    style = "secondary",
    onClick = function()
      app:closeModal()
    end,
  })
  widgets.button(app, x + 462, y + 320, 130, 38, "Liberar", {
    style = "danger",
    onClick = function()
      local ok, value = stateModule.releaseDino(app.game, dino.id)
      if ok then
        app.selectedDino = nil
        app:toast("Liberado. +" .. value .. " esencia.", theme.colors.essence)
        app:closeModal()
      else
        app:toast(value or "No se pudo liberar.", theme.colors.red)
      end
    end,
  })
end

-- Apertura de huevo
local function revealIsPending(app, reveal)
  if not reveal then
    return false
  end
  for _, candidate in ipairs(app.game.pendingReveals) do
    if candidate.id == reveal.id then
      return true
    end
  end
  return false
end

local function drawRevealResult(app, modal, reveal, x, y)
  local elapsed = love.timer.getTime() - (modal.revealStart or 0)
  local resultAt = config.time.revealResult
  local calm = app.game.settings.calm
  local skipped = modal.skipped or calm
  local show = skipped or elapsed >= resultAt
  local anim = modal.anim
  if not anim then
    anim = eggReveal.new(reveal.id)
    modal.anim = anim
  end

  local dino = nil
  if not reveal.pendingSpecies then
    dino = reveal.dinoId and stateModule.findDino(app.game, reveal.dinoId) or nil
    if not dino then
      dino = {
        id = reveal.dinoId or 1,
        species = reveal.species,
        genes = reveal.genes,
        mutation = reveal.mutation,
      }
    end
  end

  if skipped then
    if dino then
      render.drawDino(dino, x + 380, y + 255, 1.65, {})
    end
  else
    eggReveal.draw(anim, dino, reveal, x, y, elapsed)
  end

  if not show then
    local fade = 1
    if elapsed > resultAt - 0.30 then
      fade = math.max(0, math.min(1, (resultAt - elapsed) / 0.30))
    end
    local bursting = elapsed >= config.time.revealBurst
    theme.setFont(18)
    theme.setColor(theme.colors.text, fade)
    love.graphics.printf(bursting and "Saliendo del huevo" or "Abriendo huevo",
      x + 60, y + 84, 640, "center")
    theme.setFont(11)
    theme.setColor(theme.colors.muted, fade)
    love.graphics.printf(bursting
      and "El resultado se mostrará tal cual. Nada de destellos que sugieran rareza falsa."
      or "La cáscara se rompe poco a poco. Nada de destellos que sugieran rareza falsa.",
      x + 60, y + 440, 640, "center")
    local skipW, skipH = 260, 36
    local skipX = x + (760 - skipW) / 2
    widgets.button(app, skipX, y + 472, skipW, skipH, "CLIC PARA SALTAR", {
      style = "primary",
      font = 11,
      onClick = function()
        modal.skipped = true
        modal.revealStart = love.timer.getTime() - config.time.revealResult - 1
      end,
    })
    theme.setFont(8)
    theme.setColor(theme.colors.muted, fade)
    love.graphics.printf("También puedes pulsar Espacio", x + 60, y + 516, 640, "center")
    return
  end

  local fade = 1
  if not skipped then
    fade = math.max(0, math.min(1, (elapsed - resultAt) / 0.28))
  end
  local slide = (1 - fade) * 8

  if reveal.pendingSpecies then
    theme.setFont(13)
    theme.setColor(theme.colors.amber, fade)
    love.graphics.printf("Legendario: elige una de las dos especies", x + 40, y + 96 + slide, 640, "center")
    local cardW = 280
    local cardH = 270
    local startX = x + 70
    for i, species in ipairs(reveal.pendingSpecies) do
      local cx = startX + (i - 1) * (cardW + 30)
      local cy = y + 140 + slide
      theme.panel(cx, cy, cardW, cardH, {
        color = theme.colors.panel2,
        borderColor = theme.colors.amber,
        alpha = fade,
      })
      local sample = {
        id = 1,
        species = species,
        genes = reveal.genes,
        mutation = reveal.mutation,
      }
      render.drawDino(sample, cx + cardW / 2, cy + 105, 1.05, { alpha = fade })
      theme.setFont(16)
      theme.setColor(theme.colors.text, fade)
      love.graphics.printf(config.species[species].name, cx, cy + 170, cardW, "center")
      theme.setFont(9)
      theme.setColor(theme.colors.muted, fade)
      love.graphics.printf(config.species[species].desc, cx + 20, cy + 192, cardW - 40, "center")
      if fade > 0.30 then
        widgets.button(app, cx + 60, cy + 226, cardW - 120, 30, "Elegir", {
          style = "primary",
          onClick = function()
            local ok, dinoOrErr = stateModule.chooseSpecies(app.game, reveal.id, species)
            if ok then
              app:toast("Has elegido " .. config.species[species].name .. ".", theme.colors.amber)
            else
              app:toast(dinoOrErr or "No se pudo elegir.", theme.colors.red)
            end
          end,
        })
      end
    end
    return
  end

  theme.setFont(10)
  theme.setColor(theme.colors.muted, fade)
  love.graphics.printf("Huevo abierto", x + 40, y + 78 + slide, 640, "center")
  theme.setFont(24)
  theme.setColor(theme.colors.text, fade)
  love.graphics.printf(config.species[reveal.species].name, x + 40, y + 96 + slide, 640, "center")

  local rarityColor = theme.rarityColor(reveal.rarity)
  local rarityWidth = widgets.chipWidth(theme.rarityName(reveal.rarity), 11)
  local mutationWidth = reveal.mutation and widgets.chipWidth(config.mutations[reveal.mutation].name, 11) or 0
  local totalWidth = rarityWidth + (reveal.mutation and (mutationWidth + 8) or 0)
  local chipX = x + 380 - totalWidth / 2
  widgets.chip(chipX, y + 388, theme.rarityName(reveal.rarity), rarityColor, { font = 11, alpha = fade })
  if reveal.mutation then
    widgets.chip(chipX + rarityWidth + 8, y + 388, config.mutations[reveal.mutation].name, theme.colors.purple, {
      font = 11,
      alpha = fade,
    })
  end

  theme.setFont(11)
  theme.setColor(theme.colors.textDim, fade)
  love.graphics.printf(geneSummary(reveal.genes), x + 40, y + 424, 640, "center")
  local guarantee = guaranteesText(reveal.guaranteed)
  if guarantee then
    theme.setFont(10)
    theme.setColor(theme.colors.amber, fade)
    love.graphics.printf(guarantee, x + 40, y + 444, 640, "center")
  end
  if reveal.newDex then
    theme.setFont(10)
    theme.setColor(theme.colors.green, fade)
    love.graphics.printf("Nuevo en el Dinodex", x + 40, y + 462, 640, "center")
  end
  if reveal.milestone then
    theme.setFont(10)
    theme.setColor(theme.colors.purple, fade)
    local milestonePct = config.dinodex.milestoneFractions[reveal.milestone] * 100
    love.graphics.printf("Hito del Dinodex " .. theme.fmt(milestonePct, 0) .. " % alcanzado: +"
      .. theme.fmt(config.dinodex.milestoneBonus * 100, 0) .. " % de producción.",
      x + 40, y + 478, 640, "center")
  end
  theme.setFont(9)
  theme.setColor(theme.colors.muted, fade)
  love.graphics.printf("Semilla " .. app.game.seed .. " · tiradas " .. tostring(reveal.rollStart) .. "–" .. tostring(reveal.rollEnd),
    x + 40, y + 500, 640, "center")
  if fade > 0.30 then
    widgets.button(app, x + 210, y + 522, 340, 40, "Continuar", {
      style = "primary",
      onClick = function()
        stateModule.dismissReveal(app.game, reveal.id)
        app:closeModal()
      end,
    })
  end
end

local function drawReveal(app, modal)
  local reveal = modal.reveal
  if not revealIsPending(app, reveal) then
    app:closeModal()
    return
  end
  love.graphics.setColor(0, 0, 0, 0.78)
  love.graphics.rectangle("fill", 0, 0, 1280, 720)
  local x = (1280 - 760) / 2
  local y = (720 - 590) / 2
  theme.panel(x, y, 760, 590, {
    color = theme.colors.panel,
    radius = 0,
    borderColor = theme.colors.gold,
    borderWidth = 3,
    shadowSize = 7,
  })

  local elapsed = love.timer.getTime() - (modal.revealStart or 0)
  if not modal.skipped and not app.game.settings.calm and elapsed < config.time.revealResult then
    if app.click then
      modal.skipped = true
      app.click = nil
    end
  end

  drawRevealResult(app, modal, reveal, x, y)
end

function modals.update(app, dt)
  local modal = app.modal
  if not modal or modal.kind ~= "reveal" then
    return
  end
  local reveal = modal.reveal
  if not revealIsPending(app, reveal) then
    return
  end
  if not modal.anim then
    modal.anim = eggReveal.new(reveal.id)
  end
  if modal.skipped or app.game.settings.calm then
    return
  end
  local elapsed = love.timer.getTime() - (modal.revealStart or 0)
  if elapsed <= config.time.revealDuration then
    eggReveal.sync(modal.anim, elapsed, reveal, app.game)
  end
end

-- Offline
local function drawOffline(app, modal)
  local summary = modal.summary or {}
  local x, y = widgets.modalFrame(app, "Mientras estabas fuera",
    "El progreso offline se calcula con os.time() y tiene un tope de 8 horas.", 680, 440)
  theme.setFont(11)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Tiempo real ausente", x + 40, y + 102)
  love.graphics.print("Tiempo acreditado", x + 40, y + 126)
  theme.setFont(15)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(theme.fmtTime(summary.elapsed or 0), x + 240, y + 99)
  love.graphics.print(theme.fmtTime(summary.credited or 0), x + 240, y + 123)

  theme.setFont(11)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Ámbar generado", x + 40, y + 178)
  theme.setFont(26)
  theme.setColor(theme.colors.amber, 1)
  love.graphics.print("+" .. theme.fmtInt(summary.amber or 0), x + 240, y + 168)

  theme.setFont(11)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Huevos nuevos", x + 40, y + 232)
  love.graphics.print("Huevos abiertos", x + 40, y + 256)
  love.graphics.print("Cruces terminados", x + 40, y + 280)
  theme.setColor(theme.colors.text, 1)
  theme.setFont(13)
  love.graphics.print(summary.eggs or 0, x + 240, y + 230)
  love.graphics.print(summary.hatches or 0, x + 240, y + 254)
  love.graphics.print(summary.crosses or 0, x + 240, y + 278)

  if summary.capped then
    theme.setFont(10)
    theme.setColor(theme.colors.amber, 1)
    love.graphics.printf("La ausencia superaba 8 horas. El ámbar y los huevos offline se limitaron a ese tope; las incubadoras ya iniciadas terminaron igualmente.",
      x + 40, y + 318, 600, "left")
  else
    theme.setFont(10)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf("Al cerrar este resumen, pulsa ABRIR HUEVOS en el Nido para abrir los huevos pendientes.",
      x + 40, y + 318, 600, "left")
  end
  widgets.button(app, x + 480, y + 368, 160, 38, "Continuar", {
    style = "primary",
    onClick = function()
      app:closeModal()
    end,
  })
end

-- Dinodex por especie
local function dexFilterOptions()
  local options = { { value = "todas", label = "Todas" }, { value = "ninguna", label = "Sin mutación" } }
  for _, key in ipairs(config.mutationOrder) do
    options[#options + 1] = { value = key, label = config.mutations[key].name }
  end
  return options
end

local function drawDex(app, modal)
  local species = modal.species
  local x, y = widgets.modalFrame(app, config.species[species].name,
    "Combinaciones de patrón, color, cresta y mutación descubiertas.", 1000, 620)
  widgets.cycle(app, x + 28, y + 82, 250, 50, "Filtrar por mutación", app.dexMutation or "todas", dexFilterOptions(), function(value)
    app.dexMutation = value
  end)

  local mutationRank = { ninguna = 0 }
  for index, key in ipairs(config.mutationOrder) do
    mutationRank[key] = index
  end
  local patternRank = {}
  for index, key in ipairs(config.patternOrder) do
    patternRank[key] = index
  end
  local colorRank = {}
  for index, key in ipairs(config.colorOrder) do
    colorRank[key] = index
  end
  local crestRank = {}
  for index, key in ipairs(config.crestOrder) do
    crestRank[key] = index
  end

  local list = {}
  for _, variant in pairs(app.game.dinodex.variants) do
    if variant.species == species then
      local mutation = variant.mutation or "ninguna"
      if app.dexMutation == "todas" or app.dexMutation == mutation then
        list[#list + 1] = variant
      end
    end
  end
  table.sort(list, function(a, b)
    local ma = mutationRank[a.mutation or "ninguna"] or 0
    local mb = mutationRank[b.mutation or "ninguna"] or 0
    if ma ~= mb then
      return ma < mb
    end
    local pa = patternRank[a.pattern] or 0
    local pb = patternRank[b.pattern] or 0
    if pa ~= pb then
      return pa < pb
    end
    local ca = colorRank[a.primaryColor] or 0
    local cb = colorRank[b.primaryColor] or 0
    if ca ~= cb then
      return ca < cb
    end
    return (crestRank[a.crest] or 0) < (crestRank[b.crest] or 0)
  end)

  theme.setFont(10)
  theme.setColor(theme.colors.textDim, 1)
  local totalPerSpecies = #config.patternOrder * #config.colorOrder * #config.crestOrder
    * (#config.mutationOrder + 1)
  love.graphics.printf(#list .. " variantes mostradas · " .. (app.game.dinodex.bySpecies[species] or 0)
    .. " descubiertas de " .. totalPerSpecies,
    x + 300, y + 96, 500, "left")

  local rowH = 64
  local contentH = #list * rowH
  widgets.scroll(app, "dex_list", x + 28, y + 144, 944, 400, contentH, function(offset)
    if #list == 0 then
      widgets.emptyState(x + 28, y + 170, 944, 140, "Sin variantes con ese filtro",
        "Sigue incubando y cruzando ejemplares para descubrir combinaciones.")
      return
    end
    for index, variant in ipairs(list) do
      local ry = y + 144 + (index - 1) * rowH - offset
      if ry + rowH >= y + 144 and ry <= y + 544 then
        if index % 2 == 0 then
          theme.setColor(theme.colors.panel2, 0.5)
          love.graphics.rectangle("fill", x + 28, ry, 944, rowH)
        end
        local sample = {
          id = variant.firstDinoId or index,
          species = variant.species,
          genes = {
            pattern = variant.pattern,
            primaryColor = variant.primaryColor,
            secondaryColor = variant.secondaryColor,
            crest = variant.crest,
          },
          mutation = variant.mutation,
        }
        render.drawDino(sample, x + 70, ry + 32, 0.34, {})
        theme.setFont(12)
        theme.setColor(theme.colors.text, 1)
        love.graphics.print(config.patterns[variant.pattern].name .. " · "
          .. config.colors[variant.primaryColor].name .. " · "
          .. config.crests[variant.crest].name, x + 116, ry + 12)
        theme.setFont(10)
        theme.setColor(variant.mutation and theme.colors.purple or theme.colors.muted, 1)
        love.graphics.print(variant.mutation and config.mutations[variant.mutation].name or "Sin mutación", x + 116, ry + 34)
        theme.setFont(9)
        theme.setColor(theme.colors.muted, 1)
        love.graphics.printf("Descubierto " .. theme.fmtClock(variant.firstAt or 0) .. " · secundario "
          .. (config.secondaryColors[variant.secondaryColor] and config.secondaryColors[variant.secondaryColor].name or "?"),
          x + 420, ry + 22, 500, "left")
      end
    end
  end)
  closeButton(app, x + 792, y + 560, 180, 36)
end

-- Combinaciones de un cruce
local function drawCombos(app, modal)
  local x, y = widgets.modalFrame(app, "Todas las combinaciones", "Distribución exacta de los genes visibles del cruce. La mutación se sortea aparte.", 900, 600)
  local combos = modal.combos or {}
  local rowH = 26
  local contentH = #combos * rowH
  widgets.scroll(app, "combos_list", x + 28, y + 100, 844, 420, contentH, function(offset)
    for index, combo in ipairs(combos) do
      local ry = y + 100 + (index - 1) * rowH - offset
      if ry + rowH >= y + 100 and ry <= y + 520 then
        if index % 2 == 0 then
          theme.setColor(theme.colors.panel2, 0.5)
          love.graphics.rectangle("fill", x + 28, ry, 844, rowH)
        end
        theme.setFont(10)
        theme.setColor(theme.colors.amber, 1)
        love.graphics.print(theme.fmtPct(combo.probability, 2), x + 40, ry + 7)
        theme.setColor(theme.colors.text, 1)
        love.graphics.print(config.patterns[combo.phenotype.pattern].name .. " · "
          .. config.colors[combo.phenotype.primaryColor].name .. " · "
          .. config.secondaryColors[combo.phenotype.secondaryColor].name .. " · "
          .. config.crests[combo.phenotype.crest].name, x + 120, ry + 7)
      end
    end
  end)
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf(#combos .. " combinaciones visibles · suma 100 %", x + 28, y + 532, 700, "left")
  closeButton(app, x + 692, y + 540, 180, 36)
end

-- Prestigio
local function drawPrestige(app, modal)
  local game = app.game
  local can, reason = prestige.canPrestige(game)
  if not can then
    app:closeModal()
    app:toast(reason or "No puedes migrar todavía.", theme.colors.red)
    return
  end
  local gain, fromDinos, fromDex = prestige.gain(game)
  local x, y = widgets.modalFrame(app, "Gran Migración",
    "Elige hasta " .. config.prestige.maxFounders .. " fundadores. El resto de la colonia se reinicia; el Dinodex, el pity y el registro se conservan.", 1000, 640, {
      borderColor = theme.colors.amber,
    })
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Ganancia de legado", x + 28, y + 84)
  theme.setFont(22)
  theme.setColor(theme.colors.purple, 1)
  love.graphics.print("+" .. theme.fmtInt(gain), x + 28, y + 102)
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Por ejemplares: " .. fromDinos .. " · por Dinodex: " .. fromDex, x + 28, y + 130)
  theme.setFont(10)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf("Se conservan también: semilla, ajustes, árbol de legado, decoraciones y multiplicador. Se reinician ámbar, esencia, mejoras, huevos e incubadoras.",
    x + 28, y + 154, 300, "left")
  theme.setFont(9)
  theme.setColor(theme.colors.red, 1)
  love.graphics.printf("Esta acción no se puede deshacer.", x + 28, y + 222, 300, "left")

  theme.setFont(13)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Fundadores elegidos: " .. (function()
    local count = 0
    for _ in pairs(app.prestigeFounders) do
      count = count + 1
    end
    return count
  end)(), x + 28, y + 260)

  local list = {}
  for _, dino in ipairs(game.dinos) do
    list[#list + 1] = dino
  end
  table.sort(list, function(a, b)
    local ia, ib = 1, 1
    for i, key in ipairs(config.rarityOrder) do
      if key == a.rarity then
        ia = i
      end
      if key == b.rarity then
        ib = i
      end
    end
    if ia ~= ib then
      return ia > ib
    end
    return a.id > b.id
  end)

  theme.setFont(12)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.print("Criadero actual", x + 356, y + 84)
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Haz clic para marcar o desmarcar un fundador.", x + 356, y + 104)
  local rowH = 44
  local contentH = #list * rowH
  widgets.scroll(app, "prestige_list", x + 356, y + 128, 616, 396, contentH, function(offset)
    if #list == 0 then
      widgets.emptyState(x + 356, y + 150, 616, 160, "No hay ejemplares", "La migración conservará el Dinodex.")
      return
    end
    for index, dino in ipairs(list) do
      local ry = y + 128 + (index - 1) * rowH - offset
      if ry + rowH >= y + 128 and ry <= y + 524 then
        local selected = app.prestigeFounders[dino.id]
        local hover = widgets.hover(app, x + 356, ry + 2, 616, rowH - 4)
        if hover then
          app.mouse.hand = true
        end
        if widgets.click(app, x + 356, ry + 2, 616, rowH - 4) then
          if selected then
            app.prestigeFounders[dino.id] = nil
          else
            local count = 0
            for _ in pairs(app.prestigeFounders) do
              count = count + 1
            end
            if count >= config.prestige.maxFounders then
              app:toast("Solo puedes conservar " .. config.prestige.maxFounders .. " fundadores.", theme.colors.amber)
            else
              app.prestigeFounders[dino.id] = true
            end
          end
        end
        theme.panel(x + 356, ry + 2, 616, rowH - 4, {
          color = selected and theme.colors.panel3 or (hover and theme.colors.panel2 or theme.colors.panel),
          borderColor = selected and theme.colors.amber or theme.colors.borderSoft,
        })
        theme.setColor(selected and theme.colors.amber or theme.colors.border, 1)
        love.graphics.rectangle("line", x + 370, ry + 13, 16, 16, 3, 3)
        if selected then
          theme.setColor(theme.colors.amber, 1)
          love.graphics.rectangle("fill", x + 374, ry + 17, 8, 8, 2, 2)
        end
        render.drawDino(dino, x + 418, ry + 22, 0.24, {})
        theme.setFont(11)
        theme.setColor(theme.colors.text, 1)
        love.graphics.print(config.species[dino.species].name, x + 446, ry + 9)
        widgets.rarityChip(x + 590, ry + 8, dino.rarity, true)
        theme.setFont(9)
        theme.setColor(theme.colors.muted, 1)
        love.graphics.print("+" .. theme.fmtRate(economy.dinoRate(dino, game)) .. "/s", x + 446, ry + 25)
      end
    end
  end)

  widgets.button(app, x + 356, y + 560, 290, 44, "Cancelar", {
    style = "secondary",
    onClick = function()
      app:closeModal()
    end,
  })
  widgets.button(app, x + 662, y + 560, 310, 44, "Migrar y reiniciar", {
    style = "danger",
    onClick = function()
      local founders = {}
      for id in pairs(app.prestigeFounders) do
        founders[#founders + 1] = id
      end
      table.sort(founders)
      local ok, value = stateModule.prestigeNow(game, founders, app.now)
      if ok then
        app.prestigeFounders = {}
        app.selectedDino = nil
        app.crossSelect.a = nil
        app.crossSelect.b = nil
        app.scroll.breeding_grid = 0
        app:toast("Gran Migración completada. +" .. value .. " de legado permanente.", theme.colors.purple)
        app:closeModal()
      else
        app:toast(value or "No se pudo migrar.", theme.colors.red)
      end
    end,
  })
end

local function drawHabitatScene(key, x, y, w, h, decorated)
  local previous = { love.graphics.getScissor() }
  love.graphics.setScissor(x, y, w, h)
  love.graphics.setColor(0.05, 0.09, 0.08, 1)
  love.graphics.rectangle("fill", x, y, w, h)

  if key == "bosque" then
    theme.setColor({ 0.35, 0.58, 0.70 }, 1)
    love.graphics.rectangle("fill", x, y, w, h * 0.58)
    theme.setColor({ 0.25, 0.48, 0.30 }, 1)
    love.graphics.ellipse("fill", x + w * 0.25, y + h * 0.55, w * 0.32, h * 0.25)
    love.graphics.ellipse("fill", x + w * 0.78, y + h * 0.58, w * 0.30, h * 0.22)
    theme.setColor({ 0.23, 0.48, 0.24 }, 1)
    love.graphics.rectangle("fill", x, y + h * 0.50, w, h * 0.50)
    for i = 0, 3 do
      local tx = x + 22 + i * (w - 44) / 3
      theme.setColor({ 0.42, 0.29, 0.17 }, 1)
      love.graphics.rectangle("fill", tx, y + h * 0.38, 4, h * 0.30)
      theme.setColor(i % 2 == 0 and { 0.20, 0.46, 0.24 } or { 0.28, 0.55, 0.29 }, 1)
      love.graphics.circle("fill", tx + 2, y + h * 0.34, 12)
      love.graphics.circle("fill", tx - 6, y + h * 0.37, 8)
    end
    if decorated then
      theme.setColor({ 0.61, 0.58, 0.48 }, 1)
      for i = 0, 4 do
        love.graphics.rectangle("fill", x + 18 + i * 28, y + h - 13 - (i % 2) * 2, 18, 5)
      end
    end
  elseif key == "volcan" then
    theme.setColor({ 0.18, 0.12, 0.18 }, 1)
    love.graphics.rectangle("fill", x, y, w, h)
    theme.setColor({ 0.34, 0.15, 0.14 }, 1)
    love.graphics.polygon("fill", x + w * 0.18, y + h, x + w * 0.50, y + h * 0.20, x + w * 0.82, y + h)
    theme.setColor({ 0.09, 0.07, 0.09 }, 1)
    love.graphics.polygon("fill", x + w * 0.42, y + h, x + w * 0.50, y + h * 0.20, x + w * 0.58, y + h)
    theme.setColor({ 0.97, 0.45, 0.13 }, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x + w * 0.50, y + h * 0.22, x + w * 0.47, y + h * 0.42, x + w * 0.54, y + h * 0.55,
      x + w * 0.49, y + h * 0.75)
    love.graphics.setLineWidth(1)
    theme.setColor({ 0.72, 0.70, 0.72 }, 0.45)
    love.graphics.circle("fill", x + w * 0.50, y + h * 0.16, 5)
    love.graphics.circle("fill", x + w * 0.56, y + h * 0.10, 4)
    if decorated then
      theme.setColor({ 0.12, 0.10, 0.14 }, 1)
      love.graphics.rectangle("fill", x + w - 45, y + h - 48, 16, 40)
      love.graphics.rectangle("fill", x + w - 53, y + h - 54, 32, 8)
      theme.setColor(theme.colors.gold, 1)
      love.graphics.rectangle("fill", x + w - 48, y + h - 60, 22, 6)
    end
  else
    theme.setColor({ 0.45, 0.70, 0.82 }, 1)
    love.graphics.rectangle("fill", x, y, w, h * 0.45)
    theme.setColor(theme.colors.goldLight, 1)
    love.graphics.circle("fill", x + w - 36, y + 18, 9)
    theme.setColor({ 0.20, 0.48, 0.64 }, 1)
    love.graphics.rectangle("fill", x, y + h * 0.42, w, h * 0.35)
    theme.setColor({ 0.85, 0.75, 0.52 }, 1)
    love.graphics.rectangle("fill", x, y + h * 0.74, w, h * 0.26)
    theme.setColor({ 0.93, 0.92, 0.82 }, 0.45)
    love.graphics.setLineWidth(2)
    love.graphics.line(x + 12, y + h * 0.56, x + 40, y + h * 0.56)
    love.graphics.line(x + 58, y + h * 0.62, x + 82, y + h * 0.62)
    love.graphics.setLineWidth(1)
    if decorated then
      theme.setColor({ 0.26, 0.30, 0.30 }, 1)
      love.graphics.ellipse("fill", x + w - 56, y + h - 18, 28, 10)
      theme.setColor({ 0.42, 0.75, 0.76 }, 0.75)
      love.graphics.ellipse("fill", x + w - 56, y + h - 19, 20, 6)
      theme.setColor({ 0.85, 0.95, 0.95 }, 0.45)
      love.graphics.circle("fill", x + w - 62, y + h - 40, 5)
      love.graphics.circle("fill", x + w - 48, y + h - 48, 4)
    end
  end

  theme.setColor(theme.colors.black, 0.25)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
  love.graphics.setScissor(previous[1], previous[2], previous[3], previous[4])
end

local function adultHabitatResidents(game, key, now)
  local count = 0
  for _, dino in ipairs(stateModule.habitatResidents(game, key)) do
    if economy.isAdult(dino, now) then
      count = count + 1
    end
  end
  return count
end

local function habitatBonusText(key, game, now)
  local def = config.habitats[key]
  local decorated = game.habitats[key] and game.habitats[key].decor
  local count = adultHabitatResidents(game, key, now)
  if key == "bosque" then
    local bonus = def.productionBonus + (decorated and def.decor.productionBonus or 0)
    return "Producción de residentes: +" .. theme.fmtPct(bonus, 0)
  elseif key == "volcan" then
    local bonus = math.min(def.luckCap, count * def.luckPerResident)
      + (decorated and def.decor.luckBonus or 0)
    return "Peso raro+: +" .. theme.fmtPct(bonus, 0) .. " · " .. count .. " adulto" .. (count == 1 and "" or "s")
  end
  local reduction = math.min(def.incubationCap, count * def.incubationPerResident)
    + (decorated and def.decor.incubationBonus or 0)
  return "Incubación: -" .. theme.fmtPct(reduction, 0) .. " · " .. count .. " adulto" .. (count == 1 and "" or "s")
end

local function drawHabitatCard(app, key, x, y)
  local game = app.game
  local def = config.habitats[key]
  local residents = stateModule.habitatResidents(game, key)
  local cardW, cardH = 320, 440
  theme.panel(x, y, cardW, cardH, {
    color = theme.colors.panel2,
    borderColor = def.color,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.setFont(14)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print(def.name, x + 12, y + 10)
  theme.setFont(8)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf(#residents .. " / " .. def.capacity, x + cardW - 96, y + 14, 84, "right")
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf(def.desc, x + 12, y + 32, cardW - 24, "left")

  drawHabitatScene(key, x + 12, y + 60, cardW - 24, 64, game.habitats[key].decor)

  theme.setFont(8)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("RESIDENTES", x + 12, y + 136)
  local rowY = y + 152
  for index = 1, def.capacity do
    local dino = residents[index]
    if dino then
      theme.panel(x + 12, rowY, cardW - 24, 28, {
        color = theme.colors.panel,
        borderColor = theme.colors.borderSoft,
        shadow = false,
        borderWidth = 1,
      })
      theme.setFont(9)
      theme.setColor(theme.colors.text, 1)
      love.graphics.print(config.species[dino.species].name, x + 20, rowY + 3)
      local role = dino.role and config.roles[dino.role].short or "—"
      local status
      if economy.isAdult(dino, app.now) then
        status = role .. " · +" .. theme.fmtRate(economy.dinoRate(dino, game)) .. "/s"
      else
        status = role .. " · creciendo"
      end
      theme.setFont(7)
      theme.setColor(theme.colors.muted, 1)
      love.graphics.print(status, x + 20, rowY + 16)
      widgets.button(app, x + cardW - 42, rowY + 4, 22, 20, "X", {
        style = "ghost",
        font = 7,
        tooltip = "Quitar este ejemplar del hábitat.",
        onClick = function()
          stateModule.setDinoHabitat(game, dino.id, "ninguno")
          app:toast("Ejemplar retirado del hábitat.", theme.colors.gold)
        end,
      })
    else
      theme.setFont(8)
      theme.setColor(theme.colors.muted, 1)
      love.graphics.print("Hueco libre", x + 20, rowY + 8)
      theme.setFont(7)
      theme.setColor(theme.colors.textDim, 0.8)
      love.graphics.print("Asigna desde la ficha del Criadero.", x + 100, rowY + 9)
    end
    rowY = rowY + 32
  end

  theme.setFont(8)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("BONO ACTUAL", x + 12, y + 258)
  theme.setFont(8)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf(habitatBonusText(key, game, app.now), x + 12, y + 272, cardW - 24, "left")

  local dy = y + 300
  theme.panel(x + 12, dy, cardW - 24, 120, {
    color = theme.colors.panel,
    borderColor = theme.colors.borderSoft,
    shadow = false,
    borderWidth = 1,
  })
  theme.setFont(8)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("DECORACIÓN", x + 22, dy + 8)
  theme.setFont(10)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(def.decor.name, x + 22, dy + 25)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf(def.decor.desc, x + 22, dy + 43, cardW - 44, "left")
  if game.habitats[key].decor then
    theme.setFont(9)
    theme.setColor(theme.colors.green, 1)
    love.graphics.print("ACTIVA", x + 22, dy + 88)
  else
    local currency = def.decor.currency == "amber" and "ámbar" or "esencia"
    local affordable = (game[def.decor.currency] or 0) >= def.decor.cost
    widgets.button(app, x + 22, dy + 82, cardW - 44, 28,
      "DECORAR · " .. def.decor.cost .. " " .. currency, {
        style = affordable and "primary" or "secondary",
        font = 8,
        disabled = not affordable,
        tooltip = affordable and "Comprar y activar esta decoración permanentemente."
          or ("Faltan " .. currency .. "."),
        onClick = function()
          local ok, value = stateModule.buyDecoration(game, key)
          if ok then
            app:toast(def.decor.name .. " activada.", theme.colors.gold)
          else
            app:toast(value or "No se pudo comprar.", theme.colors.red)
          end
        end,
      })
  end
end

local function drawHabitats(app, modal)
  local game = app.game
  local x, y = widgets.modalFrame(app, "Hábitats y decoración",
    "Asigna residentes desde la ficha del Criadero. Una decoración permanente por hábitat.", 1080, 620)
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("Ámbar " .. theme.fmtInt(game.amber) .. " · Esencia " .. theme.fmtInt(game.essence),
    x + 760, y + 64, 290, "right")
  for index, key in ipairs(config.habitatOrder) do
    drawHabitatCard(app, key, x + 30 + (index - 1) * 350, y + 92)
  end
  closeButton(app, x + 900, y + 560, 150, 36, "Cerrar")
end

local function drawPrestigeTree(app, modal)
  local game = app.game
  local x, y = widgets.modalFrame(app, "Árbol de legado",
    "Gasta puntos de legado en mejoras permanentes. Los nodos inferiores piden nivel 1 del nodo superior.", 940, 620)
  theme.setFont(11)
  theme.setColor(theme.colors.ink, 0.95)
  love.graphics.printf("PUNTOS: " .. theme.fmtInt(game.prestige.points or 0), x + 600, y + 19, 312, "right")

  local cardW, cardH = 280, 180
  local colX = { x + 30, x + 330, x + 630 }
  local rowY = { y + 120, y + 350 }
  for _, key in ipairs(config.prestigeTreeOrder) do
    local def = config.prestigeTree[key]
    if def.requires then
      local from = config.prestigeTree[def.requires.key]
      local fromX = colX[from.col] + cardW / 2
      local toX = colX[def.col] + cardW / 2
      local unlocked = (game.prestige.tree[def.requires.key] or 0) >= def.requires.level
      theme.setColor(unlocked and theme.colors.green or theme.colors.borderSoft, 0.8)
      love.graphics.setLineWidth(2)
      love.graphics.line(fromX, rowY[1] + cardH, fromX, rowY[1] + cardH + 20,
        toX, rowY[2] - 20, toX, rowY[2])
    end
  end

  for _, key in ipairs(config.prestigeTreeOrder) do
    local def = config.prestigeTree[key]
    local level = game.prestige.tree[key] or 0
    local maxed = level >= def.max
    local canBuy, reason = prestige.canBuyNode(game, key)
    local cx = colX[def.col]
    local cy = rowY[def.row]
    theme.panel(cx, cy, cardW, cardH, {
      color = level > 0 and theme.colors.panel2 or theme.colors.panel,
      borderColor = maxed and theme.colors.green or (level > 0 and theme.colors.gold or theme.colors.border),
      shadowSize = 3,
      borderWidth = 2,
    })
    theme.setFont(13)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(def.name, cx + 12, cy + 10)
    theme.setFont(8)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf("Nv " .. level .. "/" .. def.max, cx + cardW - 78, cy + 14, 66, "right")
    theme.setFont(8)
    theme.setColor(theme.colors.textDim, 1)
    love.graphics.printf(def.desc, cx + 12, cy + 34, cardW - 24, "left")
    if def.requires then
      local required = config.prestigeTree[def.requires.key]
      local unlocked = (game.prestige.tree[def.requires.key] or 0) >= def.requires.level
      theme.setFont(7)
      theme.setColor(unlocked and theme.colors.green or theme.colors.red, 1)
      love.graphics.print("Requiere " .. required.name .. " Nv " .. def.requires.level, cx + 12, cy + 78)
    end
    theme.setFont(8)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print("Coste", cx + 12, cy + 105)
    theme.setFont(11)
    theme.setColor(theme.colors.gold, 1)
    love.graphics.print(maxed and "MÁXIMO" or (prestige.nodeCost(key, level) .. " pts"), cx + 70, cy + 101)
    widgets.button(app, cx + 12, cy + 136, cardW - 24, 32, maxed and "MÁXIMO" or "COMPRAR", {
      style = canBuy and "primary" or "secondary",
      font = 9,
      disabled = not canBuy,
      tooltip = canBuy and ("Gastar " .. prestige.nodeCost(key, level) .. " puntos de legado.") or reason,
      onClick = function()
        local ok, value = stateModule.buyPrestigeNode(game, key)
        if ok then
          app:toast(def.name .. " · nivel " .. game.prestige.tree[key] .. " por " .. value .. " puntos.", theme.colors.purple)
        else
          app:toast(value or "No se pudo comprar.", theme.colors.red)
        end
      end,
    })
  end

  closeButton(app, x + 760, y + 560, 150, 36, "Cerrar")
end

local function drawOptions(app, modal)
  local game = app.game
  local x, y = widgets.modalFrame(app, "Opciones",
    "Audio, accesibilidad, mando y copias de seguridad.", 1000, 620)
  local columns = { x + 30, x + 350, x + 670 }
  local colW = 300
  local top = y + 100

  theme.panel(columns[1], top, colW, 420, {
    color = theme.colors.panel,
    borderColor = theme.colors.border,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.setFont(12)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("Audio", columns[1] + 12, top + 10)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Volumen independiente.", columns[1] + 12, top + 28)
  widgets.toggle(app, columns[1] + 12, top + 48, colW - 24, 30, "Música",
    game.settings.music, function(value)
      stateModule.setSetting(game, "music", value)
      app:toast(value and "Música activada." or "Música silenciada.", theme.colors.textDim)
    end, { tooltip = "Silenciar o activar la música." })
  widgets.slider(app, columns[1] + 12, top + 82, colW - 24, 32, "Volumen de música",
    game.settings.musicVolume, function(value)
      stateModule.setSetting(game, "musicVolume", value)
    end, { tooltip = "Arrastra o pulsa para ajustar." })
  widgets.toggle(app, columns[1] + 12, top + 126, colW - 24, 30, "Efectos",
    game.settings.sfx, function(value)
      stateModule.setSetting(game, "sfx", value)
      app:toast(value and "Efectos activados." or "Efectos silenciados.", theme.colors.textDim)
    end, { tooltip = "Crujidos y eclosión." })
  widgets.slider(app, columns[1] + 12, top + 160, colW - 24, 32, "Volumen de efectos",
    game.settings.sfxVolume, function(value)
      stateModule.setSetting(game, "sfxVolume", value)
    end, { tooltip = "Arrastra o pulsa para ajustar." })
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("La música baja de volumen durante la eclosión.",
    columns[1] + 12, top + 206, colW - 24, "left")

  theme.panel(columns[2], top, colW, 420, {
    color = theme.colors.panel,
    borderColor = theme.colors.border,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.setFont(12)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("Pantalla y accesibilidad", columns[2] + 12, top + 10)
  widgets.toggle(app, columns[2] + 12, top + 46, colW - 24, 30, "Modo daltónico",
    game.settings.colorblind, function(value)
      stateModule.setSetting(game, "colorblind", value)
      theme.setColorblind(value)
      app:toast(value and "Modo daltónico activado." or "Colores estándar.", theme.colors.textDim)
    end, { tooltip = "Usa una paleta de alto contraste para las rarezas." })
  widgets.toggle(app, columns[2] + 12, top + 80, colW - 24, 30, "Texto grande",
    game.settings.largeText, function(value)
      stateModule.setSetting(game, "largeText", value)
      theme.setLargeText(value)
      app:toast(value and "Texto grande activado." or "Texto normal.", theme.colors.textDim)
    end, { tooltip = "Aumenta un punto las etiquetas pequeñas." })
  local scaleOptions = {}
  for _, value in ipairs(config.settings.uiScaleOptions) do
    scaleOptions[#scaleOptions + 1] = {
      value = value,
      label = math.floor(value * 100) .. " %",
    }
  end
  widgets.cycle(app, columns[2] + 12, top + 120, colW - 24, 40, "Escala de ventana",
    game.settings.uiScale, scaleOptions, function(value)
      stateModule.setSetting(game, "uiScale", value)
      app.displayDirty = true
      app:toast("Escala de ventana: " .. math.floor(value * 100) .. " %.", theme.colors.textDim)
    end, { tooltip = "El lienzo se adapta a la ventana." })
  widgets.toggle(app, columns[2] + 12, top + 172, colW - 24, 30, "Pantalla completa",
    game.settings.fullscreen, function(value)
      stateModule.setSetting(game, "fullscreen", value)
      app.displayDirty = true
      app:toast(value and "Pantalla completa." or "Modo ventana.", theme.colors.textDim)
    end, { tooltip = "Usa el escritorio completo." })
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("La escala se limita al tamaño del escritorio. Mando: stick izquierdo mueve el cursor; A pulsa; B vuelve; LB/RB cambian de pestaña; Start guarda.",
    columns[2] + 12, top + 210, colW - 24, "left")

  theme.panel(columns[3], top, colW, 420, {
    color = theme.colors.panel,
    borderColor = theme.colors.border,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.setFont(12)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("Datos y criadero", columns[3] + 12, top + 10)
  widgets.button(app, columns[3] + 12, top + 44, colW - 24, 34, "GUARDAR COPIA", {
    style = "secondary",
    font = 9,
    tooltip = "Crea save-backup.json junto a la partida.",
    onClick = function()
      app:backupSave()
    end,
  })
  local hasBackup = love.filesystem.getInfo("save-backup.json") ~= nil
  widgets.button(app, columns[3] + 12, top + 86, colW - 24, 34, "RESTAURAR COPIA", {
    style = "secondary",
    font = 9,
    disabled = not hasBackup,
    tooltip = hasBackup and "Sustituye la partida actual por la copia." or "Todavía no hay copia.",
    onClick = function()
      app:openModal("restore_backup", {})
    end,
  })
  theme.setFont(7)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf(hasBackup and "Copia disponible: save-backup.json." or "Sin copia guardada todavía.",
    columns[3] + 12, top + 126, colW - 24, "left")
  local plan = stateModule.duplicatePlan(game)
  widgets.button(app, columns[3] + 12, top + 158, colW - 24, 34, "LIBERAR DUPLICADOS", {
    style = "ghost",
    font = 8,
    disabled = #plan == 0,
    tooltip = #plan > 0 and ("Revisa antes de liberar " .. #plan .. " ejemplares.") or "No hay duplicados que liberar.",
    onClick = function()
      app:openModal("bulk_release", {})
    end,
  })
  theme.setFont(7)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("Nunca libera favoritos, residentes de hábitats, ejemplares en cruce ni huevos pendientes.",
    columns[3] + 12, top + 198, colW - 24, "left")
  widgets.button(app, columns[3] + 12, top + 230, colW - 24, 34, "OBJETIVOS Y LOGROS", {
    style = "teal",
    font = 8,
    onClick = function()
      app:openModal("goals", {})
    end,
  })
  theme.setFont(7)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("Los objetivos se renuevan al completarse. Los logros son permanentes.",
    columns[3] + 12, top + 270, colW - 24, "left")

  closeButton(app, x + 810, y + 550, 150, 36, "Cerrar")
end

local function drawRestoreBackup(app, modal)
  local x, y = widgets.modalFrame(app, "Restaurar copia",
    "Se sustituirá la partida actual por save-backup.json. Esta acción no se puede deshacer.", 720, 360, {
      borderColor = theme.colors.red,
    })
  theme.setFont(11)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf("La partida actual se sobrescribirá y el juego se reiniciará. La copia debe ser válida; si no lo es, no se tocará nada.",
    x + 30, y + 100, 660, "left")
  widgets.button(app, x + 30, y + 210, 300, 44, "Cancelar", {
    style = "secondary",
    font = 11,
    onClick = function()
      app:closeModal()
    end,
  })
  widgets.button(app, x + 390, y + 210, 300, 44, "Restaurar y reiniciar", {
    style = "danger",
    font = 10,
    onClick = function()
      app:restoreBackup()
    end,
  })
end

local function drawBulkRelease(app, modal)
  local game = app.game
  local plan, essence = stateModule.duplicatePlan(game)
  local x, y = widgets.modalFrame(app, "Liberar duplicados",
    "Se liberarán copias repetidas de la misma especie, rareza, genes y mutación. Se conserva la de mayor producción.", 760, 420, {
      borderColor = theme.colors.red,
    })
  theme.setFont(13)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Ejemplares a liberar: " .. #plan, x + 30, y + 100)
  theme.setFont(13)
  theme.setColor(theme.colors.essence, 1)
  love.graphics.print("Esencia recuperada: +" .. essence, x + 30, y + 126)
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("No se liberan favoritos, residentes de hábitats, ejemplares en cruce ni dinosaurios pendientes de abrir. Si no hay duplicados, la acción no hace nada.",
    x + 30, y + 160, 700, "left")
  widgets.button(app, x + 30, y + 260, 330, 44, "Cancelar", {
    style = "secondary",
    font = 11,
    onClick = function()
      app:closeModal()
    end,
  })
  widgets.button(app, x + 390, y + 260, 340, 44, "Liberar " .. #plan .. " duplicados", {
    style = "danger",
    font = 10,
    disabled = #plan == 0,
    onClick = function()
      local count, total = stateModule.releaseDuplicates(game)
      app.selectedDino = nil
      app:toast("Liberados " .. count .. " duplicados. +" .. total .. " esencia.", theme.colors.essence)
      app:closeModal()
    end,
  })
end

local function drawGoals(app, modal)
  local game = app.game
  local x, y = widgets.modalFrame(app, "Objetivos y logros",
    "Los objetivos rotan al completarse. Los logros son permanentes y se guardan con la partida.", 1000, 620)
  theme.setFont(12)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("OBJETIVOS", x + 30, y + 92)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  local completed = 0
  for _ in pairs(game.goals.completed) do
    completed = completed + 1
  end
  love.graphics.printf(completed .. " / " .. #config.objectiveOrder .. " completados", x + 30, y + 108, 430, "right")

  local cardY = y + 126
  local objectiveRows = math.max(1, #game.goals.active)
  for index = 1, objectiveRows do
    local entry = game.goals.active[index]
    local def = entry and config.objectives[entry.id] or nil
    theme.panel(x + 30, cardY, 430, 100, {
      color = theme.colors.panel2,
      borderColor = def and theme.colors.border or theme.colors.borderSoft,
      shadowSize = 2,
      borderWidth = 1,
    })
    if def then
      local current = stateModule.metric(game, def.metric) - (entry.start or 0)
      local progress = math.max(0, math.min(1, current / def.target))
      theme.setFont(11)
      theme.setColor(theme.colors.text, 1)
      love.graphics.print(def.name, x + 42, cardY + 10)
      theme.setFont(8)
      theme.setColor(theme.colors.muted, 1)
      love.graphics.print(def.desc, x + 42, cardY + 28)
      widgets.progressBar(x + 42, cardY + 48, 406, 7, progress, theme.colors.gold, {})
      theme.setFont(8)
      theme.setColor(theme.colors.textDim, 1)
      love.graphics.print(math.min(def.target, math.max(0, current)) .. " / " .. def.target,
        x + 42, cardY + 61)
      local reward = {}
      if def.reward.amber then reward[#reward + 1] = "+" .. def.reward.amber .. " ámbar" end
      if def.reward.essence then reward[#reward + 1] = "+" .. def.reward.essence .. " esencia" end
      if def.reward.points then reward[#reward + 1] = "+" .. def.reward.points .. " pts" end
      theme.setColor(theme.colors.green, 1)
      love.graphics.print(table.concat(reward, " · "), x + 42, cardY + 78)
    else
      theme.setFont(11)
      theme.setColor(theme.colors.green, 1)
      love.graphics.printf("Todos los objetivos completados.", x + 42, cardY + 36, 406, "left")
    end
    cardY = cardY + 112
  end

  theme.setFont(12)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("LOGROS", x + 490, y + 92)
  local unlocked = 0
  for _ in pairs(game.achievements.unlocked) do
    unlocked = unlocked + 1
  end
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf(unlocked .. " / " .. #config.achievementOrder, x + 490, y + 108, 460, "right")
  local rowH = 50
  local contentH = #config.achievementOrder * rowH
  widgets.scroll(app, "goals_achievements", x + 490, y + 126, 480, 430, contentH, function(offset)
    for index, id in ipairs(config.achievementOrder) do
      local def = config.achievements[id]
      local ry = y + 126 + (index - 1) * rowH - offset
      if ry + rowH >= y + 126 and ry <= y + 550 then
        local done = game.achievements.unlocked[id]
        local value = stateModule.metric(game, def.metric)
        local progress = math.max(0, math.min(1, value / def.target))
        theme.panel(x + 490, ry + 2, 480, rowH - 4, {
          color = done and theme.colors.panel2 or theme.colors.panel,
          borderColor = done and theme.colors.green or theme.colors.borderSoft,
          shadow = false,
          borderWidth = 1,
        })
        theme.setFont(9)
        theme.setColor(done and theme.colors.green or theme.colors.text, 1)
        love.graphics.print((done and "OK " or "· ") .. def.name, x + 500, ry + 7)
        theme.setFont(7)
        theme.setColor(theme.colors.muted, 1)
        love.graphics.print(def.desc, x + 500, ry + 22)
        widgets.progressBar(x + 500, ry + 35, 240, 5, progress, done and theme.colors.green or theme.colors.gold, {})
        theme.setFont(7)
        theme.setColor(theme.colors.textDim, 1)
        love.graphics.printf(math.min(def.target, value) .. " / " .. def.target, x + 746, ry + 33, 50, "right")
        local reward = {}
        if def.reward.amber then reward[#reward + 1] = "+" .. def.reward.amber .. " ámbar" end
        if def.reward.essence then reward[#reward + 1] = "+" .. def.reward.essence .. " esencia" end
        if def.reward.points then reward[#reward + 1] = "+" .. def.reward.points .. " pts" end
        theme.setColor(theme.colors.green, 1)
        love.graphics.printf(table.concat(reward, " · "), x + 800, ry + 22, 160, "right")
      end
    end
  end)

  closeButton(app, x + 810, y + 560, 150, 36, "Cerrar")
end

local function drawCompare(app, modal)
  local game = app.game
  local x, y = widgets.modalFrame(app, "Comparar ejemplares",
    "Elige dos ejemplares para comparar producción, genes, rol y hábitat.", 900, 620)
  local options = {}
  for _, dino in ipairs(game.dinos) do
    if not stateModule.isDinoPending(game, dino.id) then
      options[#options + 1] = {
        value = dino.id,
        label = config.species[dino.species].name .. " #" .. dino.id,
      }
    end
  end
  table.sort(options, function(a, b)
    return a.label < b.label
  end)
  local function has(value)
    for _, option in ipairs(options) do
      if option.value == value then
        return true
      end
    end
    return false
  end
  if not has(app.compareA) then
    app.compareA = options[1] and options[1].value or nil
  end
  if not has(app.compareB) or app.compareB == app.compareA then
    app.compareB = options[2] and options[2].value or options[1] and options[1].value or nil
  end

  if #options == 0 then
    widgets.emptyState(x + 30, y + 120, 840, 180, "No hay ejemplares visibles",
      "Abre algún huevo para poder comparar.")
    closeButton(app, x + 720, y + 560, 150, 36, "Cerrar")
    return
  end

  local function drawColumn(dinoId, columnX, columnY, label, onChange)
    theme.panel(columnX, columnY, 400, 430, {
      color = theme.colors.panel2,
      borderColor = theme.colors.border,
      shadowSize = 3,
      borderWidth = 2,
    })
    widgets.cycle(app, columnX + 12, columnY + 10, 376, 40, label, dinoId, options, onChange)
    local dino = stateModule.findDino(game, dinoId)
    if not dino then
      return
    end
    render.drawDino(dino, columnX + 200, columnY + 150, 0.62, {})
    if dino.favorite then
      theme.setFont(8)
      theme.setColor(theme.colors.gold, 1)
      love.graphics.print("FAV", columnX + 352, columnY + 58)
    end
    theme.setFont(14)
    theme.setColor(theme.colors.text, 1)
    love.graphics.printf(config.species[dino.species].name, columnX, columnY + 166, 400, "center")
    local chipW = widgets.rarityChip(columnX + 12, columnY + 190, dino.rarity, true)
    theme.setFont(8)
    theme.setColor(theme.colors.muted, 1)
    local role = dino.role and config.roles[dino.role].name or "Sin rol"
    local habitat = dino.habitat and config.habitats[dino.habitat].short or "Sin hábitat"
    love.graphics.print(role .. " · " .. habitat, columnX + 18 + chipW, columnY + 194)
    theme.setFont(9)
    theme.setColor(theme.colors.amber, 1)
    love.graphics.printf("+" .. theme.fmtRate(economy.dinoRate(dino, game)) .. "/s", columnX + 200, columnY + 210, 188, "right")
    theme.setFont(8)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print("Patrón", columnX + 12, columnY + 236)
    love.graphics.print("Color", columnX + 12, columnY + 252)
    love.graphics.print("Secundario", columnX + 12, columnY + 268)
    love.graphics.print("Cresta", columnX + 12, columnY + 284)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(config.patterns[dino.genes.pattern].name, columnX + 118, columnY + 236)
    love.graphics.print(config.colors[dino.genes.primaryColor].name, columnX + 118, columnY + 252)
    love.graphics.print(config.secondaryColors[dino.genes.secondaryColor].name, columnX + 118, columnY + 268)
    love.graphics.print(config.crests[dino.genes.crest].name, columnX + 118, columnY + 284)
    if dino.mutation then
      theme.setColor(theme.colors.purple, 1)
      love.graphics.print(config.mutations[dino.mutation].name, columnX + 260, columnY + 236)
    end
    theme.setFont(8)
    theme.setColor(theme.colors.gold, 1)
    love.graphics.print("GENES FUNCIONALES", columnX + 12, columnY + 306)
    for index, gene in ipairs(config.functionalOrder) do
      local value = (dino.functional and dino.functional[gene]) or 1
      local geneY = columnY + 320 + (index - 1) * 14
      theme.setFont(8)
      theme.setColor(theme.colors.textDim, 1)
      love.graphics.print(config.functional[gene].short, columnX + 12, geneY)
      widgets.progressBar(columnX + 46, geneY + 3, 280, 5, value / 5, theme.colors.green, {})
      theme.setColor(theme.colors.text, 1)
      love.graphics.print(tostring(value), columnX + 334, geneY)
    end
  end

  drawColumn(app.compareA, x + 30, y + 100, "Ejemplar A", function(value)
    app.compareA = value
  end)
  drawColumn(app.compareB, x + 470, y + 100, "Ejemplar B", function(value)
    app.compareB = value
  end)
  closeButton(app, x + 720, y + 560, 150, 36, "Cerrar")
end

function modals.draw(app, modal)
  local handlers = {
    help = drawHelp,
    probabilities = drawProbabilities,
    release = drawRelease,
    reveal = drawReveal,
    offline = drawOffline,
    dex = drawDex,
    combos = drawCombos,
    prestige = drawPrestige,
    habitats = drawHabitats,
    prestige_tree = drawPrestigeTree,
    options = drawOptions,
    restore_backup = drawRestoreBackup,
    bulk_release = drawBulkRelease,
    goals = drawGoals,
    compare = drawCompare,
  }
  local handler = handlers[modal.kind]
  if handler then
    handler(app, modal)
  else
    app:closeModal()
  end
end

function modals.escape(app)
  if not app.modal then
    return
  end
  if app.modal.kind == "reveal" then
    local reveal = app.modal.reveal
    if reveal and reveal.pendingSpecies then
      app:toast("Elige una especie para continuar.", theme.colors.amber)
      return
    end
    app.modal.skipped = true
    app.modal.revealStart = love.timer.getTime() - config.time.revealResult - 1
    return
  end
  app:closeModal()
end

return modals
