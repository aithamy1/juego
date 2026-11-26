local config = require("src.game.config")
local hatch = require("src.game.hatch")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")

local logScene = {}

local function genesLine(entry)
  local genes = entry.genes or {}
  local function name(kind, key)
    local def = config[kind] and config[kind][key]
    return def and def.name or tostring(key)
  end
  return table.concat({
    name("patterns", genes.pattern),
    name("colors", genes.primaryColor),
    name("secondaryColors", genes.secondaryColor),
    name("crests", genes.crest),
  }, " · ")
end

local function sourceName(source)
  if source == "cruce" then
    return "Cruce"
  end
  return "Nido"
end

function logScene.draw(app)
  local game = app.game
  widgets.sectionTitle("Registro de huevos", "Cada apertura queda anotada con su semilla y sus tiradas. Sin borrados y sin datos ocultos.", 28, 120, 900)

  local snap = hatch.snapshot(game)
  theme.panel(28, 170, 1224, 160, { color = theme.colors.panel })
  theme.setFont(13)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Tasas reales frente a las teóricas", 46, 182)
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Solo huevos del nido · " .. theme.fmtInt(game.stats.nestHatched) .. " aperturas", 46, 202)

  local headers = { "Rareza", "Huevos", "Real", "Base", "Efectiva", "Diferencia" }
  local xs = { 46, 190, 276, 366, 456, 560 }
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  for i, header in ipairs(headers) do
    love.graphics.print(header, xs[i], 220)
  end
  local rowY = 238
  for _, rarity in ipairs(config.rarityOrder) do
    local count = game.stats.nestByRarity[rarity] or 0
    local actual = game.stats.nestHatched > 0 and (count / game.stats.nestHatched) or 0
    local base = snap.base[rarity] or 0
    local effective = snap.effective[rarity] or 0
    theme.setColor(theme.rarityColor(rarity), 1)
    love.graphics.setFont(theme.fontFor(10))
    love.graphics.print(theme.rarityName(rarity), xs[1], rowY)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(theme.fmtInt(count), xs[2], rowY)
    if game.stats.nestHatched > 0 then
      love.graphics.print(theme.fmtPct(actual, 1), xs[3], rowY)
    else
      theme.setColor(theme.colors.muted, 1)
      love.graphics.print("—", xs[3], rowY)
    end
    theme.setColor(theme.colors.textDim, 1)
    love.graphics.print(theme.fmtPct(base, 1), xs[4], rowY)
    love.graphics.print(theme.fmtPct(effective, 1), xs[5], rowY)
    if game.stats.nestHatched > 0 then
      local diff = actual - base
      theme.setColor(diff >= 0 and theme.colors.green or theme.colors.red, 1)
      love.graphics.print((diff >= 0 and "+" or "") .. theme.fmtPct(diff, 1), xs[6], rowY)
    else
      theme.setColor(theme.colors.muted, 1)
      love.graphics.print("—", xs[6], rowY)
    end
    rowY = rowY + 19
  end

  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("La columna Real incluye las garantías, por eso suele superar a la Base. La Efectiva es la tasa actual con tus mejoras de suerte y el pity suave; cambia según el contador. Los huevos de cruce se cuentan aparte porque su rareza es heredada.", 710, 186, 510, "left")
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf("Semilla de la partida: " .. game.seed .. "  ·  Tiradas: " .. theme.fmtInt(game.rng.count)
    .. "  ·  Mutaciones: " .. game.stats.mutations, 710, 292, 510, "left")

  theme.panel(28, 344, 1224, 346, { color = theme.colors.panel })
  theme.setFont(13)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("Últimos huevos abiertos", 46, 356)
  theme.setFont(9)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("R = garantía de raro · L = legendario · M = mutación · NUEVO = primera vez en el Dinodex", 280, 360)

  local filters = {
    { value = "todos", label = "Todos" },
    { value = "nido", label = "Nido" },
    { value = "cruce", label = "Cruce" },
  }
  for i, filter in ipairs(filters) do
    widgets.button(app, 900 + (i - 1) * 108, 350, 98, 28, filter.label, {
      style = app.logFilter == filter.value and "primary" or "ghost",
      font = 10,
      onClick = function()
        app.logFilter = filter.value
        app.scroll.log_list = 0
      end,
    })
  end

  local entries = {}
  for i = #game.log, 1, -1 do
    local entry = game.log[i]
    if app.logFilter == "todos" or entry.source == app.logFilter then
      entries[#entries + 1] = entry
    end
  end
  local rowH = 34
  local contentH = #entries * rowH
  widgets.scroll(app, "log_list", 44, 388, 1192, 292, contentH, function(offset)
    if #entries == 0 then
      widgets.emptyState(44, 410, 1192, 140, "Aún no hay huevos abiertos",
        "Incuba un huevo en el Nido. Cada resultado quedará aquí.")
      return
    end
    for index, entry in ipairs(entries) do
      local y = 388 + (index - 1) * rowH - offset
      if y + rowH >= 388 and y <= 680 then
        if index % 2 == 0 then
          theme.setColor(theme.colors.panel2, 0.45)
          love.graphics.rectangle("fill", 44, y, 1192, rowH)
        end
        theme.setFont(9)
        theme.setColor(theme.colors.muted, 1)
        love.graphics.print(theme.fmtClock(entry.at), 54, y + 10)
        love.graphics.print(sourceName(entry.source), 146, y + 10)
        theme.setColor(theme.rarityColor(entry.rarity), 1)
        theme.setFont(10)
        love.graphics.print(theme.rarityName(entry.rarity), 216, y + 9)
        theme.setColor(theme.colors.text, 1)
        theme.setFont(10)
        local species = entry.species and config.species[entry.species].name or "Por elegir"
        if entry.pending then
          theme.setColor(theme.colors.amber, 1)
        end
        love.graphics.print(species, 312, y + 9)
        theme.setColor(theme.colors.textDim, 1)
        love.graphics.print(genesLine(entry), 474, y + 9)
        theme.setColor(entry.mutation and theme.colors.purple or theme.colors.muted, 1)
        love.graphics.print(entry.mutation and config.mutations[entry.mutation].name or "—", 824, y + 9)

        local badgeX = 1000
        if entry.guaranteed then
          if entry.guaranteed.rare then
            widgets.chip(badgeX, y + 7, "R", theme.colors.blue, { font = 9 })
            badgeX = badgeX + 22
          end
          if entry.guaranteed.legendary then
            widgets.chip(badgeX, y + 7, "L", theme.colors.amber, { font = 9 })
            badgeX = badgeX + 22
          end
          if entry.guaranteed.mutation then
            widgets.chip(badgeX, y + 7, "M", theme.colors.essence, { font = 9 })
            badgeX = badgeX + 22
          end
        end
        if entry.newDex then
          theme.setColor(theme.colors.green, 1)
          theme.setFont(9)
          love.graphics.print("NUEVO", 1120, y + 10)
        end
      end
    end
  end)
end

return logScene
