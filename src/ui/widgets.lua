-- Componentes de interfaz inmediatos: botones, paneles, barras, scroll y tooltips.
local theme = require("src.ui.theme")

local widgets = {}

local function clamp(value, low, high)
  if value < low then
    return low
  end
  if value > high then
    return high
  end
  return value
end

local function pointAllowed(app, px, py)
  if app.blocked then
    return false
  end
  if app.clip then
    local c = app.clip
    if px < c.x or py < c.y or px > c.x + c.w or py > c.y + c.h then
      return false
    end
  end
  return true
end

function widgets.hover(app, x, y, w, h)
  if not pointAllowed(app, app.mouse.x, app.mouse.y) then
    return false
  end
  return app.mouse.x >= x and app.mouse.x <= x + w
    and app.mouse.y >= y and app.mouse.y <= y + h
end

function widgets.click(app, x, y, w, h)
  if not app.click or not pointAllowed(app, app.click.x, app.click.y) then
    return false
  end
  if app.click.x >= x and app.click.x <= x + w
    and app.click.y >= y and app.click.y <= y + h then
    app.click = nil
    return true
  end
  return false
end

function widgets.button(app, x, y, w, h, label, opts)
  opts = opts or {}
  local hover = widgets.hover(app, x, y, w, h) and not opts.disabled
  local clicked = widgets.click(app, x, y, w, h)
  if hover and opts.tooltip then
    app.tooltip = opts.tooltip
  end
  if clicked and not opts.disabled and opts.onClick then
    opts.onClick()
  end

  local style = opts.style or "secondary"
  local radius = opts.radius or 8
  local bg, border, fg, bgAlpha
  if opts.disabled then
    bg = theme.colors.panel
    border = theme.colors.borderSoft
    fg = theme.colors.muted
  elseif style == "primary" then
    bg = hover and { 0.98, 0.76, 0.36 } or theme.colors.amber
    border = theme.colors.amber
    fg = { 0.12, 0.10, 0.05 }
  elseif style == "danger" then
    bg = hover and { 0.93, 0.50, 0.43 } or theme.colors.red
    border = theme.colors.red
    fg = { 0.12, 0.05, 0.04 }
  elseif style == "ghost" then
    bg = hover and theme.colors.panel2 or theme.colors.panel
    bgAlpha = hover and 0.9 or 0.45
    border = hover and theme.colors.border or theme.colors.borderSoft
    fg = opts.selected and theme.colors.amber or theme.colors.textDim
  elseif style == "tab" then
    bg = opts.selected and theme.colors.panel2 or theme.colors.panel
    border = opts.selected and theme.colors.amber or theme.colors.borderSoft
    fg = opts.selected and theme.colors.text or theme.colors.textDim
  else
    bg = hover and theme.colors.panel3 or theme.colors.panel2
    border = hover and theme.colors.border or theme.colors.borderSoft
    fg = opts.selected and theme.colors.amber or theme.colors.text
  end

  if hover and not opts.disabled then
    app.mouse.hand = true
  end
  love.graphics.setColor(bg[1], bg[2], bg[3], bgAlpha or 1)
  love.graphics.rectangle("fill", x, y, w, h, radius, radius)
  theme.setColor(border, opts.disabled and 0.55 or 0.9)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, w, h, radius, radius)

  theme.setFont(opts.font or 14)
  local font = theme.fontFor(opts.font or 14)
  local textY = y + (h - font:getHeight()) / 2
  local padding = 8
  if opts.icon then
    local iconX = x + 18
    theme.drawIcon(opts.icon, iconX, y + h / 2, 5, 1)
    padding = 28
    theme.setColor(fg, 1)
    love.graphics.printf(label, x + padding, textY, w - padding - 8, opts.align or "center")
  else
    theme.setColor(fg, 1)
    love.graphics.printf(label, x + padding, textY, w - padding * 2, opts.align or "center")
  end
  return hover, clicked
end

function widgets.progressBar(x, y, w, h, value, color, opts)
  opts = opts or {}
  value = clamp(value or 0, 0, 1)
  theme.setColor(opts.trackColor or theme.colors.bg, 0.9)
  love.graphics.rectangle("fill", x, y, w, h, h / 2, h / 2)
  if value > 0 then
    theme.setColor(color or theme.colors.amber, 1)
    love.graphics.rectangle("fill", x, y, math.max(h, w * value), h, h / 2, h / 2)
  end
  if opts.label then
    theme.setFont(opts.font or 11)
    theme.setColor(theme.colors.text, 0.95)
    local font = theme.fontFor(opts.font or 11)
    love.graphics.printf(opts.label, x, y + (h - font:getHeight()) / 2, w, "center")
  end
end

function widgets.chipWidth(text, fontSize)
  theme.setFont(fontSize or 11)
  return theme.fontFor(fontSize or 11):getWidth(text) + 16
end

function widgets.chip(x, y, text, color, opts)
  opts = opts or {}
  theme.setFont(opts.font or 11)
  local font = theme.fontFor(opts.font or 11)
  local width = font:getWidth(text) + 16
  theme.setColor(color, 0.15)
  love.graphics.rectangle("fill", x, y, width, 20, 10, 10)
  theme.setColor(color, 0.85)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, width, 20, 10, 10)
  theme.setColor(color, 1)
  love.graphics.print(text, x + 8, y + (20 - font:getHeight()) / 2)
  return width
end

function widgets.rarityChip(x, y, rarity, small)
  return widgets.chip(x, y, theme.rarityName(rarity), theme.rarityColor(rarity),
    { font = small and 10 or 11 })
end

function widgets.sectionTitle(title, subtitle, x, y, width)
  theme.setFont(26)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(title, x, y)
  if subtitle then
    theme.setFont(12)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf(subtitle, x, y + 34, width, "left")
  end
end

function widgets.cycle(app, x, y, w, h, label, value, options, onSelect, opts)
  opts = opts or {}
  local hover = widgets.hover(app, x, y, w, h)
  local clicked = widgets.click(app, x, y, w, h)
  if hover then
    app.mouse.hand = true
    if opts.tooltip then
      app.tooltip = opts.tooltip
    end
  end
  if clicked and onSelect then
    local index = 1
    for i, option in ipairs(options) do
      if option.value == value then
        index = i
        break
      end
    end
    local nextOption = options[index % #options + 1]
    onSelect(nextOption.value)
  end

  theme.setColor(hover and theme.colors.panel3 or theme.colors.panel2, 1)
  love.graphics.rectangle("fill", x, y, w, h, 8, 8)
  theme.setColor(hover and theme.colors.border or theme.colors.borderSoft, 1)
  love.graphics.rectangle("line", x, y, w, h, 8, 8)
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.print(label:upper(), x + 10, y + 6)
  local shown = value
  for _, option in ipairs(options) do
    if option.value == value then
      shown = option.label
    end
  end
  theme.setFont(13)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(shown, x + 10, y + 21)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.polygon("fill", x + w - 18, y + h / 2 - 2, x + w - 10, y + h / 2 - 2, x + w - 14, y + h / 2 + 3)
end

function widgets.toggle(app, x, y, w, h, label, value, onToggle, opts)
  opts = opts or {}
  local hover = widgets.hover(app, x, y, w, h)
  local clicked = widgets.click(app, x, y, w, h)
  if hover then
    app.mouse.hand = true
    if opts.tooltip then
      app.tooltip = opts.tooltip
    end
  end
  if clicked and onToggle then
    onToggle(not value)
  end
  theme.setFont(13)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(label, x, y + (h - theme.fontFor(13):getHeight()) / 2)
  local px = x + w - 48
  local py = y + (h - 22) / 2
  theme.setColor(value and theme.colors.green or theme.colors.border, 1)
  love.graphics.rectangle("fill", px, py, 42, 22, 11, 11)
  theme.setColor(theme.colors.text, 1)
  love.graphics.circle("fill", value and (px + 28) or (px + 14), py + 11, 8)
end

function widgets.scroll(app, id, x, y, w, h, contentHeight, drawFn)
  local offset = app.scroll[id] or 0
  local maxOffset = math.max(0, contentHeight - h)
  if widgets.hover(app, x, y, w, h) and app.wheel then
    offset = offset - app.wheel.dy * 52
    app.wheel = nil
  end
  offset = clamp(offset, 0, maxOffset)
  app.scroll[id] = offset

  local previousClip = app.clip
  app.clip = { x = x, y = y, w = w, h = h }
  love.graphics.setScissor(x, y, w, h)
  drawFn(offset)
  love.graphics.setScissor()
  app.clip = previousClip

  if maxOffset > 0 then
    local barH = math.max(28, h * (h / contentHeight))
    local barY = y + (h - barH) * (offset / maxOffset)
    theme.setColor(theme.colors.border, 0.6)
    love.graphics.rectangle("fill", x + w - 5, barY, 3, barH, 2, 2)
  end
end

function widgets.modalFrame(app, title, subtitle, width, height, opts)
  opts = opts or {}
  love.graphics.setColor(0, 0, 0, 0.68)
  love.graphics.rectangle("fill", 0, 0, 1280, 720)
  local x = (1280 - width) / 2
  local y = (720 - height) / 2
  theme.panel(x, y, width, height, {
    color = opts.color or theme.colors.panel,
    radius = 16,
    borderColor = opts.borderColor or theme.colors.border,
  })
  theme.setFont(24)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(title, x + 28, y + 22)
  if subtitle then
    theme.setFont(12)
    theme.setColor(theme.colors.muted, 1)
    love.graphics.printf(subtitle, x + 28, y + 54, width - 56, "left")
  end
  return x, y
end

function widgets.drawTooltip(app)
  if not app.tooltip then
    return
  end
  theme.setFont(12)
  local font = theme.fontFor(12)
  local maxWidth = 300
  local _, lines = font:getWrap(app.tooltip, maxWidth)
  local textHeight = #lines * font:getHeight()
  local width = math.min(maxWidth, font:getWidth(app.tooltip) + 4) + 20
  local height = textHeight + 16
  local x = math.min(app.mouse.x + 16, 1280 - width - 8)
  local y = math.min(app.mouse.y + 18, 720 - height - 8)
  theme.setColor(theme.colors.bg, 0.97)
  love.graphics.rectangle("fill", x, y, width, height, 8, 8)
  theme.setColor(theme.colors.border, 1)
  love.graphics.rectangle("line", x, y, width, height, 8, 8)
  theme.setColor(theme.colors.text, 1)
  love.graphics.printf(app.tooltip, x + 10, y + 8, width - 20, "left")
end

function widgets.dimButton(app, x, y, w, h, label, onClick)
  return widgets.button(app, x, y, w, h, label, { style = "ghost", onClick = onClick })
end

function widgets.emptyState(x, y, w, h, title, body)
  theme.setColor(theme.colors.panel2, 0.55)
  love.graphics.rectangle("fill", x, y, w, h, 12, 12)
  theme.setFont(16)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf(title, x + 20, y + h / 2 - 26, w - 40, "center")
  theme.setFont(12)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf(body or "", x + 20, y + h / 2 + 2, w - 40, "center")
end

return widgets
