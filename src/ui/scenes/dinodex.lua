local config = require("src.game.config")
local genetics = require("src.game.genetics")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local render = require("src.render.dino")

local dinodex = {}

local function variantDino(variant)
  return {
    id = variant.firstDinoId or 1,
    species = variant.species,
    genes = {
      pattern = variant.pattern,
      primaryColor = variant.primaryColor,
      secondaryColor = variant.secondaryColor,
      crest = variant.crest,
    },
    mutation = variant.mutation,
  }
end

local function speciesSample(app, species)
  for _, dino in ipairs(app.game.dinos) do
    if dino.species == species then
      return dino, false
    end
  end
  for _, variant in pairs(app.game.dinodex.variants) do
    if variant.species == species then
      return variantDino(variant), false
    end
  end
  return {
    id = 1,
    species = species,
    genes = {
      pattern = "liso",
      primaryColor = "verde",
      secondaryColor = "crema",
      crest = "ninguna",
    },
    mutation = nil,
  }, true
end

local function speciesStats(game)
  local bySpecies = {}
  for _, key in ipairs(config.speciesOrder) do
    bySpecies[key] = { total = 0, mutations = 0 }
  end
  for _, variant in pairs(game.dinodex.variants) do
    local entry = bySpecies[variant.species]
    if entry then
      entry.total = entry.total + 1
      if variant.mutation then
        entry.mutations = entry.mutations + 1
      end
    end
  end
  return bySpecies
end

function dinodex.draw(app)
  local game = app.game
  local totalPerSpecies = genetics.dexTotalPerSpecies()
  local total = genetics.dexTotal()
  local completion = game.dinodex.total / total
  widgets.sectionTitle("Dinodex", "Cada combinación de patrón, color, cresta y mutación cuenta. No se reinicia con la Gran Migración.", 28, 120, 900)

  theme.panel(28, 170, 1224, 94, { color = theme.colors.panel })
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Completitud global", 48, 184)
  theme.setFont(28)
  theme.setColor(theme.colors.amber, 1)
  love.graphics.print(theme.fmtPct(completion, 1), 48, 200)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print(theme.fmtInt(game.dinodex.total) .. " / " .. theme.fmtInt(total) .. " variantes", 48, 236)
  widgets.progressBar(170, 211, 420, 12, completion, theme.colors.amber)

  local milestoneX = 640
  local bonusPct = config.dinodex.milestoneBonus * 100
  local milestoneLabels = {}
  for i, fraction in ipairs(config.dinodex.milestoneFractions) do
    local claimed = game.dinodex.milestones[i]
    local label = math.floor(fraction * 100) .. " %"
    milestoneLabels[#milestoneLabels + 1] = math.floor(fraction * 100) .. " %"
    local width = widgets.chip(milestoneX, 194, label, claimed and theme.colors.green or theme.colors.muted,
      { font = 11 })
    theme.setFont(9)
    theme.setColor(claimed and theme.colors.green or theme.colors.muted, 1)
    love.graphics.print(claimed and ("+" .. theme.fmt(bonusPct, 0) .. " % producción") or "bloqueado", milestoneX, 217)
    milestoneX = milestoneX + math.max(width, 76) + 10
  end
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("Hitos al " .. table.concat(milestoneLabels, ", ") .. ".\nCada uno da +"
    .. theme.fmt(bonusPct, 0) .. " % de producción permanente.", 1000, 186, 220, "right")
  theme.setColor(theme.colors.green, 1)
  theme.setFont(11)
  love.graphics.printf("Bonus actual: +" .. theme.fmt(game.dinodex.milestoneCount * bonusPct, 0) .. " %",
    1000, 228, 220, "right")

  local stats = speciesStats(game)
  local cardW = 596
  local cardH = 128
  local gapX = 24
  local gapY = 10
  local startY = 278
  for index, species in ipairs(config.speciesOrder) do
    local col = (index - 1) % 2
    local row = math.floor((index - 1) / 2)
    local x = 28 + col * (cardW + gapX)
    local y = startY + row * (cardH + gapY)
    local entry = stats[species]
    local percent = entry.total / totalPerSpecies
    local sample, silhouette = speciesSample(app, species)
    local hover = widgets.hover(app, x, y, cardW, cardH)
    theme.panel(x, y, cardW, cardH, {
      color = hover and theme.colors.panel3 or theme.colors.panel2,
      borderColor = entry.total > 0 and theme.colors.border or theme.colors.borderSoft,
    })
    render.drawDino(sample, x + 76, y + 66, 0.56, { silhouette = silhouette, alpha = silhouette and 0.8 or 1 })
    theme.setFont(16)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(config.species[species].name, x + 148, y + 16)
    theme.setFont(10)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print(entry.total .. " / " .. totalPerSpecies .. " variantes", x + 148, y + 40)
    widgets.progressBar(x + 148, y + 60, 380, 8, percent, theme.colors.amber)
    theme.setFont(10)
    theme.setColor(theme.colors.textDim, 1)
    love.graphics.print(theme.fmtPct(percent, 1), x + 148, y + 73)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print(entry.mutations .. " con mutación descubierta", x + 260, y + 73)

    theme.setFont(9)
    theme.setColor(theme.colors.muted, 1)
    local mutationsFound = {}
    for _, mutation in ipairs(config.mutationOrder) do
      for _, variant in pairs(game.dinodex.variants) do
        if variant.species == species and variant.mutation == mutation then
          mutationsFound[#mutationsFound + 1] = config.mutations[mutation].name
          break
        end
      end
    end
    local mutationText = #mutationsFound > 0 and table.concat(mutationsFound, " · ") or "Aún sin mutaciones"
    love.graphics.printf(mutationText, x + 148, y + 92, 300, "left")
    widgets.button(app, x + cardW - 132, y + 86, 112, 28, "Ver catálogo", {
      style = "ghost",
      font = 10,
      onClick = function()
        app.dexSpecies = species
        app.dexMutation = "todas"
        app:openModal("dex", { species = species })
      end,
    })
  end
end

return dinodex
