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
    genes = { pattern = "liso", primaryColor = "verde", secondaryColor = "crema", crest = "ninguna" },
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
  local x = app.layout.contentX
  local y = app.layout.contentY
  local totalPerSpecies = genetics.dexTotalPerSpecies()
  local total = genetics.dexTotal()
  local completion = game.dinodex.total / total
  local bonusPct = config.dinodex.milestoneBonus * 100

  theme.panel(x, y, 728, 68, {
    color = theme.colors.panel2,
    borderColor = theme.colors.border,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("COMPLETITUD GLOBAL", x + 12, y + 9)
  theme.setFont(24)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print(theme.fmtPct(completion, 1), x + 12, y + 22)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print(theme.fmtInt(game.dinodex.total) .. " / " .. theme.fmtInt(total), x + 12, y + 51)
  widgets.progressBar(x + 130, y + 36, 270, 10, completion, theme.colors.purple, {})

  local chipX = x + 420
  for i, fraction in ipairs(config.dinodex.milestoneFractions) do
    local claimed = game.dinodex.milestones[i]
    local label = math.floor(fraction * 100) .. "%"
    local width = widgets.chip(chipX, y + 10, label, claimed and theme.colors.green or theme.colors.muted, { font = 9 })
    theme.setFont(7)
    theme.setColor(claimed and theme.colors.green or theme.colors.muted, 1)
    love.graphics.print(claimed and ("+" .. theme.fmt(bonusPct, 0) .. "%") or "—", chipX, y + 31)
    chipX = chipX + width + 7
  end
  theme.setFont(8)
  theme.setColor(theme.colors.green, 1)
  love.graphics.printf("Bonus +" .. theme.fmt(game.dinodex.milestoneCount * bonusPct, 0) .. "%",
    x + 600, y + 12, 112, "right")
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("Hitos permanentes", x + 600, y + 25, 112, "right")

  local stats = speciesStats(game)
  local cardW = 354
  local cardH = 136
  local gapX = 20
  local gapY = 12
  local startY = 238
  for index, species in ipairs(config.speciesOrder) do
    local col = (index - 1) % 2
    local row = math.floor((index - 1) / 2)
    local cx = x + col * (cardW + gapX)
    local cy = startY + row * (cardH + gapY)
    local entry = stats[species]
    local percent = entry.total / totalPerSpecies
    local sample, silhouette = speciesSample(app, species)
    local hover = widgets.hover(app, cx, cy, cardW, cardH)
    if hover then
      app.mouse.hand = true
      app.tooltip = config.species[species].desc
    end
    theme.panel(cx, cy, cardW, cardH, {
      color = hover and theme.colors.panel3 or theme.colors.panel2,
      borderColor = entry.total > 0 and theme.colors.border or theme.colors.borderSoft,
      shadowSize = 3,
      borderWidth = 2,
    })
    render.drawDino(sample, cx + 58, cy + 82, 0.42, { silhouette = silhouette, alpha = silhouette and 0.7 or 1 })
    theme.setFont(11)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(config.species[species].name, cx + 112, cy + 10)
    theme.setFont(8)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print(entry.total .. " / " .. totalPerSpecies .. " variantes", cx + 112, cy + 29)
    widgets.progressBar(cx + 112, cy + 45, 220, 7, percent, theme.colors.purple, {})
    theme.setFont(8)
    theme.setColor(theme.colors.textDim, 1)
    love.graphics.print(theme.fmtPct(percent, 1), cx + 112, cy + 57)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print(entry.mutations .. " con mutación", cx + 180, cy + 57)

    local mutationNames = {}
    for _, mutation in ipairs(config.mutationOrder) do
      for _, variant in pairs(game.dinodex.variants) do
        if variant.species == species and variant.mutation == mutation then
          mutationNames[#mutationNames + 1] = config.mutations[mutation].name
          break
        end
      end
    end
    theme.setFont(8)
    theme.setColor(theme.colors.purple, #mutationNames > 0 and 1 or 0.4)
    love.graphics.printf(#mutationNames > 0 and table.concat(mutationNames, " · ") or "Aún sin mutaciones",
      cx + 112, cy + 74, 228, "left")

    widgets.button(app, cx + cardW - 92, cy + 98, 80, 26, "VER", {
      style = "ghost",
      font = 8,
      onClick = function()
        app.dexSpecies = species
        app.dexMutation = "todas"
        app:openModal("dex", { species = species })
      end,
    })
  end
end

return dinodex
