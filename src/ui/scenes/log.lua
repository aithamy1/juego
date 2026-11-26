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
  return source == "cruce" and "Cruce" or "Nido"
end

function logScene.draw(app)
  local game = app.game
  local x = app.layout.contentX
  local y = app.layout.contentY
  local snap = hatch.snapshot(game)

  theme.panel(x, y, 360, 190, {
    color = theme.colors.panel2,
    borderColor = theme.colors.border,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.setFont(11)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("Tasas reales", x + 10, y + 8)
  theme.setFont(7)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Solo nido · " .. theme.fmtInt(game.stats.nestHatched) .. " aperturas", x + 10, y + 23)

  local headers = { "Rareza", "N", "Real", "Base", "Efect.", "Dif." }
  local xs = { x + 10, x + 92, x + 130, x + 184, x + 238, x + 294 }
  theme.setFont(7)
  theme.setColor(theme.colors.muted, 1)
  for i, header in ipairs(headers) do
    love.graphics.print(header, xs[i], y + 39)
  end
  local rowY = y + 54
  for _, rarity in ipairs(config.rarityOrder) do
    local count = game.stats.nestByRarity[rarity] or 0
    local actual = game.stats.nestHatched > 0 and count / game.stats.nestHatched or 0
    local base = snap.base[rarity] or 0
    local effective = snap.effective[rarity] or 0
    theme.setFont(8)
    theme.setColor(theme.rarityColor(rarity), 1)
    love.graphics.print(theme.rarityName(rarity), xs[1], rowY)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(theme.fmtInt(count), xs[2], rowY)
    if game.stats.nestHatched > 0 then
      love.graphics.print(theme.fmtPct(actual, 0), xs[3], rowY)
    else
      theme.setColor(theme.colors.muted, 1)
      love.graphics.print("—", xs[3], rowY)
    end
    theme.setColor(theme.colors.textDim, 1)
    love.graphics.print(theme.fmtPct(base, 0), xs[4], rowY)
    love.graphics.print(theme.fmtPct(effective, 0), xs[5], rowY)
    if game.stats.nestHatched > 0 then
      local diff = actual - base
      theme.setColor(diff >= 0 and theme.colors.green or theme.colors.red, 1)
      love.graphics.print((diff >= 0 and "+" or "") .. theme.fmtPct(diff, 0), xs[6], rowY)
    else
      theme.setColor(theme.colors.muted, 1)
      love.graphics.print("—", xs[6], rowY)
    end
    rowY = rowY + 21
  end

  theme.panel(x + 372, y, 356, 190, {
    color = theme.colors.panel,
    borderColor = theme.colors.borderSoft,
    shadowSize = 3,
    borderWidth = 1,
  })
  theme.setFont(10)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("Auditoría", x + 384, y + 8)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("La columna Real incluye las garantías; por eso suele superar a la Base. La Efectiva es la tasa actual con tu suerte y el pity suave. Los huevos de cruce se cuentan aparte.",
    x + 384, y + 28, 332, "left")
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf("Semilla " .. game.seed .. "  ·  " .. theme.fmtInt(game.rng.count) .. " tiradas  ·  "
    .. game.stats.mutations .. " mutaciones", x + 384, y + 162, 332, "left")

  theme.panel(x, y + 204, 728, 318, {
    color = theme.colors.panel,
    borderColor = theme.colors.border,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.setFont(11)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("Últimos huevos abiertos", x + 10, y + 214)
  theme.setFont(7)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("R = raro · L = legendario · M = mutación · ● = nuevo en el Dinodex", x + 10, y + 230)

  local filters = {
    { value = "todos", label = "Todos" },
    { value = "nido", label = "Nido" },
    { value = "cruce", label = "Cruce" },
  }
  for i, filter in ipairs(filters) do
    widgets.button(app, x + 512 + (i - 1) * 70, y + 210, 64, 24, filter.label, {
      style = app.logFilter == filter.value and "primary" or "ghost",
      font = 8,
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
  local rowH = 28
  widgets.scroll(app, "log_list", x + 10, y + 246, 708, 258, #entries * rowH, function(offset)
    if #entries == 0 then
      widgets.emptyState(x + 10, y + 266, 708, 130, "Aún no hay huevos abiertos",
        "Incuba un huevo en el Nido. Cada resultado quedará aquí.")
      return
    end
    for index, entry in ipairs(entries) do
      local ry = y + 246 + (index - 1) * rowH - offset
      if ry + rowH >= y + 246 and ry <= y + 504 then
        if index % 2 == 0 then
          theme.setColor(theme.colors.panel2, 0.45)
          love.graphics.rectangle("fill", x + 10, ry, 708, rowH)
        end
        theme.setFont(7)
        theme.setColor(theme.colors.muted, 1)
        love.graphics.print(theme.fmtClock(entry.at or 0), x + 16, ry + 9)
        theme.setFont(7)
        love.graphics.print(sourceName(entry.source), x + 78, ry + 9)
        theme.setColor(theme.rarityColor(entry.rarity), 1)
        theme.setFont(8)
        love.graphics.print(theme.rarityName(entry.rarity), x + 116, ry + 8)
        theme.setFont(8)
        theme.setColor(entry.pending and theme.colors.amber or theme.colors.text, 1)
        love.graphics.print(entry.species and config.species[entry.species].name or "Por elegir", x + 190, ry + 8)
        theme.setFont(7)
        theme.setColor(theme.colors.textDim, 1)
        love.graphics.print(genesLine(entry), x + 300, ry + 8)
        theme.setColor(entry.mutation and theme.colors.purple or theme.colors.muted, 1)
        love.graphics.print(entry.mutation and config.mutations[entry.mutation].name or "—", x + 548, ry + 8)

        local badgeX = x + 636
        if entry.guaranteed then
          if entry.guaranteed.rare then
            widgets.chip(badgeX, ry + 6, "R", theme.colors.blue, { font = 7 })
            badgeX = badgeX + 18
          end
          if entry.guaranteed.legendary then
            widgets.chip(badgeX, ry + 6, "L", theme.colors.amber, { font = 7 })
            badgeX = badgeX + 18
          end
          if entry.guaranteed.mutation then
            widgets.chip(badgeX, ry + 6, "M", theme.colors.essence, { font = 7 })
            badgeX = badgeX + 18
          end
        end
        if entry.newDex then
          theme.setColor(theme.colors.green, 1)
          love.graphics.rectangle("fill", x + 700, ry + 11, 5, 5)
        end
      end
    end
  end)
end

return logScene
