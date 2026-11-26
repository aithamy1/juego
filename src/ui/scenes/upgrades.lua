local config = require("src.game.config")
local stateModule = require("src.game.state")
local economy = require("src.game.economy")
local prestige = require("src.game.prestige")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")

local upgrades = {}

function upgrades.draw(app)
  local game = app.game
  local now = app.now
  widgets.sectionTitle("Mejoras", "Todo se compra con ámbar o esencia. Los costes crecen y el efecto se aplica al instante.", 28, 120, 790)

  local production = economy.totalProduction(game, now)
  local legacyMult = prestige.multiplier(game)
  local dexBonus = 1 + config.dinodex.milestoneBonus * (game.dinodex.milestoneCount or 0)
  theme.panel(28, 170, 1224, 64, { color = theme.colors.panel2 })
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Producción actual", 48, 182)
  theme.setFont(18)
  theme.setColor(theme.colors.amber, 1)
  love.graphics.print("+" .. theme.fmtRate(production) .. " ámbar/s", 48, 198)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Multiplicador de legado", 290, 182)
  theme.setFont(14)
  theme.setColor(theme.colors.purple, 1)
  love.graphics.print("x" .. theme.fmt(legacyMult, 2), 290, 200)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Bonus del Dinodex", 480, 182)
  theme.setFont(14)
  theme.setColor(theme.colors.green, 1)
  love.graphics.print("x" .. theme.fmt(dexBonus, 2), 480, 200)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("Mejora de producción", 660, 182)
  theme.setFont(14)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("x" .. theme.fmt(1 + config.upgrades.production.perLevel * game.upgrades.production, 2), 660, 200)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("Los bonus de Dinodex y legado se conservan al migrar.", 880, 186, 340, "right")

  local cardW = 596
  local cardH = 136
  local gapX = 24
  local gapY = 12
  local startY = 250
  for index, key in ipairs(config.upgradesOrder) do
    local def = config.upgrades[key]
    local col = (index - 1) % 2
    local row = math.floor((index - 1) / 2)
    local x = 28 + col * (cardW + gapX)
    local y = startY + row * (cardH + gapY)
    local level = game.upgrades[key] or 0
    local maxed = level >= def.max
    local cost = economy.upgradeCost(key, level)
    local canBuy, reason = stateModule.canBuyUpgrade(game, key)
    local hover = widgets.hover(app, x, y, cardW, cardH)
    theme.panel(x, y, cardW, cardH, {
      color = hover and theme.colors.panel3 or theme.colors.panel,
      borderColor = maxed and theme.colors.green or theme.colors.borderSoft,
    })

    theme.setFont(16)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(def.name, x + 20, y + 12)
    theme.setFont(10)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf(def.desc, x + 20, y + 34, cardW - 180, "left")

    theme.setFont(10)
    theme.setColor(theme.colors.textDim, 1)
    love.graphics.print("Nivel " .. level .. " / " .. def.max, x + 20, y + 62)
    widgets.progressBar(x + 20, y + 80, cardW - 190, 7, level / def.max,
      maxed and theme.colors.green or theme.colors.amber)

    theme.setFont(10)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print("Ahora: " .. economy.upgradeEffect(key, game), x + 20, y + 96)

    theme.setColor(theme.colors.muted, 1)
    theme.setFont(10)
    love.graphics.print(maxed and "Máximo alcanzado" or "Siguiente", x + cardW - 160, y + 38)
    if not maxed then
      theme.drawIcon(def.currency, x + cardW - 154, y + 64, 5)
      theme.setFont(14)
      theme.setColor(theme.colors.text, 1)
      love.graphics.print(theme.fmtInt(cost), x + cardW - 142, y + 55)
      theme.setFont(9)
      theme.setColor(theme.colors.muted, 1)
      love.graphics.print(def.currency == "amber" and "ámbar" or "esencia", x + cardW - 142, y + 73)
    end

    widgets.button(app, x + cardW - 138, y + 92, 118, 30, maxed and "Máximo" or "Comprar", {
      style = canBuy and "primary" or "secondary",
      disabled = not canBuy,
      font = 11,
      tooltip = canBuy and ("Pagar " .. theme.fmtInt(cost) .. " " .. (def.currency == "amber" and "ámbar" or "esencia"))
        or reason,
      onClick = function()
        local ok, value = stateModule.buyUpgrade(game, key)
        if ok then
          app:toast("Mejora comprada: " .. def.name .. " · nivel " .. (game.upgrades[key] or 0)
            .. " · " .. theme.fmtInt(value) .. " "
            .. (def.currency == "amber" and "ámbar." or "esencia."), theme.colors.amber)
        else
          app:toast(value or "No se pudo comprar.", theme.colors.red)
        end
      end,
    })
  end
end

return upgrades
