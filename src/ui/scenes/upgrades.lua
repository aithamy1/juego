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
  local x = app.layout.contentX
  local y = app.layout.contentY
  local production = economy.totalProduction(game, now)
  local legacyMult = prestige.multiplier(game)
  local dexBonus = 1 + config.dinodex.milestoneBonus * (game.dinodex.milestoneCount or 0)

  theme.panel(x, y, 728, 52, {
    color = theme.colors.panel2,
    borderColor = theme.colors.border,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("PRODUCCIÓN", x + 12, y + 8)
  theme.setFont(16)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print("+" .. theme.fmtRate(production) .. "/s", x + 12, y + 22)
  theme.setFont(8)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print("LEGADO", x + 180, y + 8)
  love.graphics.print("DINODEX", x + 320, y + 8)
  love.graphics.print("PRODUCCIÓN +", x + 470, y + 8)
  theme.setFont(11)
  theme.setColor(theme.colors.purple, 1)
  love.graphics.print("x" .. theme.fmt(legacyMult, 2), x + 180, y + 25)
  theme.setColor(theme.colors.green, 1)
  love.graphics.print("x" .. theme.fmt(dexBonus, 2), x + 320, y + 25)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print("x" .. theme.fmt(1 + config.upgrades.production.perLevel * game.upgrades.production, 2), x + 470, y + 25)
  theme.setFont(7)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf("El legado y el Dinodex se conservan al migrar.", x + 560, y + 20, 156, "right")

  local cardW = 354
  local cardH = 138
  local gapX = 20
  local gapY = 12
  local startY = 220
  for index, key in ipairs(config.upgradesOrder) do
    local def = config.upgrades[key]
    local col = (index - 1) % 2
    local row = math.floor((index - 1) / 2)
    local cx = x + col * (cardW + gapX)
    local cy = startY + row * (cardH + gapY)
    local level = game.upgrades[key] or 0
    local maxed = level >= def.max
    local cost = economy.upgradeCost(key, level)
    local canBuy, reason = stateModule.canBuyUpgrade(game, key)
    local hover = widgets.hover(app, cx, cy, cardW, cardH)
    if hover then
      app.mouse.hand = true
      app.tooltip = def.desc
    end
    theme.panel(cx, cy, cardW, cardH, {
      color = hover and theme.colors.panel3 or theme.colors.panel2,
      borderColor = maxed and theme.colors.green or theme.colors.border,
      shadowSize = 3,
      borderWidth = 2,
    })
    if canBuy and not maxed then
      theme.setColor(theme.colors.green, 0.95)
      love.graphics.rectangle("fill", cx, cy, 3, cardH)
    end
    theme.insetPanel(cx + 9, cy + 9, 28, 28, {
      color = theme.colors.bg,
      borderColor = theme.colors.borderSoft,
    })
    theme.drawUpgradeIcon(key, cx + 23, cy + 23, 10, theme.colors.gold)
    theme.setFont(12)
    theme.setColor(theme.colors.text, 1)
    love.graphics.print(def.name, cx + 46, cy + 9)
    theme.setFont(8)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf(def.desc, cx + 46, cy + 25, 158, "left")

    if not maxed then
      theme.drawIcon(def.currency, cx + cardW - 126, cy + 16, 4)
      theme.setFont(10)
      theme.setColor(theme.colors.text, 1)
      love.graphics.print(theme.fmtInt(cost), cx + cardW - 116, cy + 8)
      theme.setFont(8)
      if canBuy then
        theme.setColor(theme.colors.green, 1)
        love.graphics.print("LISTO", cx + cardW - 116, cy + 22)
      else
        local missing = math.max(0, cost - (game[def.currency] or 0))
        theme.setColor(theme.colors.muted, 1)
        love.graphics.print("faltan " .. theme.fmtInt(missing), cx + cardW - 116, cy + 22)
      end
    end

    theme.setFont(9)
    theme.setColor(theme.colors.textDim, 1)
    love.graphics.print("Nivel " .. level .. " / " .. def.max, cx + 12, cy + 58)
    widgets.progressBar(cx + 12, cy + 71, 330, 6, level / def.max,
      maxed and theme.colors.green or theme.colors.gold, {})
    theme.setFont(9)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.print(economy.upgradeEffect(key, game), cx + 12, cy + 84)

    widgets.button(app, cx + cardW - 124, cy + 104, 112, 28, maxed and "MÁXIMO" or "COMPRAR", {
      style = canBuy and "primary" or "secondary",
      disabled = not canBuy,
      font = 9,
      tooltip = canBuy and ("Pagar " .. theme.fmtInt(cost) .. (def.currency == "amber" and " ámbar." or " esencia.")) or reason,
      onClick = function()
        local ok, value = stateModule.buyUpgrade(game, key)
        if ok then
          app:toast(def.name .. " · nivel " .. game.upgrades[key] .. " por " .. theme.fmtInt(value), theme.colors.gold)
        else
          app:toast(value or "No se pudo comprar.", theme.colors.red)
        end
      end,
    })
  end
end

return upgrades
