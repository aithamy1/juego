-- Componentes de interfaz inmediatos con estética pixel-art.
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
  local fill, border, fg
  if opts.disabled then
    fill = theme.colors.panel
    border = theme.colors.borderSoft
    fg = theme.colors.muted
  elseif style == "primary" then
    fill = hover and theme.colors.goldLight or theme.colors.gold
    border = theme.colors.goldDark
    fg = theme.colors.ink
  elseif style == "danger" then
    fill = hover and { 0.92, 0.32, 0.26 } or theme.colors.red
    border = theme.colors.redDark
    fg = theme.colors.cream or theme.colors.text
  elseif style == "ghost" then
    fill = hover and theme.colors.panel2 or theme.colors.panel
    border = hover and theme.colors.border or theme.colors.borderSoft
    fg = opts.selected and theme.colors.gold or theme.colors.textDim
  elseif style == "teal" then
    fill = hover and { 0.25, 0.55, 0.58 } or theme.colors.tealDark
    border = theme.colors.teal
    fg = theme.colors.text
  else
    fill = hover and theme.colors.panel3 or theme.colors.panel2
    border = hover and theme.colors.border or theme.colors.borderSoft
    fg = opts.selected and theme.colors.gold or theme.colors.text
  end

  if hover and not opts.disabled then
    app.mouse.hand = true
  end
  local pressed = hover and app.mouse.down and not opts.disabled
  local offset = pressed and 1 or 0
  theme.panel(x, y + offset, w, h, {
    color = fill,
    borderColor = border,
    shadow = not opts.disabled,
    shadowSize = pressed and 2 or 3,
    borderWidth = 2,
  })

  theme.setFont(opts.font or 13)
  local font = theme.fontFor(opts.font or 13)
  local textY = y + offset + (h - font:getHeight()) / 2 - 1
  theme.setColor(fg, 1)
  love.graphics.printf(label, x + 6, textY, w - 12, opts.align or "center")
  return hover, clicked
end

function widgets.progressBar(x, y, w, h, value, color, opts)
  opts = opts or {}
  value = clamp(value or 0, 0, 1)
  theme.setColor(theme.colors.black, 0.55)
  love.graphics.rectangle("fill", x + 1, y + 1, w, h)
  theme.setColor(theme.colors.bg, 1)
  love.graphics.rectangle("fill", x, y, w, h)
  theme.setColor(theme.colors.borderSoft, 0.8)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
  if value > 0 then
    theme.setColor(color or theme.colors.green, 1)
    love.graphics.rectangle("fill", x + 1, y + 1, math.max(0, (w - 2) * value), h - 2)
    theme.setColor({ 1, 1, 1 }, 0.25)
    love.graphics.rectangle("fill", x + 2, y + 2, math.max(0, (w - 4) * value), 1)
  end
  if opts.label then
    theme.setFont(opts.font or 9)
    theme.setColor(theme.colors.text, 0.95)
    local font = theme.fontFor(opts.font or 9)
    love.graphics.printf(opts.label, x, y + (h - font:getHeight()) / 2 - 1, w, "center")
  end
end

function widgets.chipWidth(text, fontSize)
  theme.setFont(fontSize or 10)
  return theme.fontFor(fontSize or 10):getWidth(text) + 14
end

function widgets.chip(x, y, text, color, opts)
  opts = opts or {}
  local alpha = opts.alpha or 1
  local size = opts.font or 10
  theme.setFont(size)
  local font = theme.fontFor(size)
  local width = font:getWidth(text) + 12
  theme.setColor(color, 0.20 * alpha)
  love.graphics.rectangle("fill", x, y, width, 18)
  theme.setColor(color, 0.95 * alpha)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, 17)
  theme.setColor(color, alpha)
  love.graphics.print(text, x + 6, y + (18 - font:getHeight()) / 2 - 1)
  return width
end

function widgets.rarityChip(x, y, rarity, small)
  return widgets.chip(x, y, theme.rarityName(rarity), theme.rarityColor(rarity),
    { font = small and 9 or 10 })
end

function widgets.sectionTitle(title, subtitle, x, y, width)
  theme.setFont(26)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.print(title, x, y)
  if subtitle then
    theme.setFont(11)
    theme.setColor(theme.colors.textDim, 1)
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

  theme.panel(x, y, w, h, {
    color = hover and theme.colors.panel3 or theme.colors.panel2,
    borderColor = hover and theme.colors.border or theme.colors.borderSoft,
    shadowSize = 2,
    borderWidth = 1,
  })
  theme.setFont(8)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.print(label, x + 7, y + 4)
  local shown = value
  for _, option in ipairs(options) do
    if option.value == value then
      shown = option.label
    end
  end
  theme.setFont(11)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(shown, x + 7, y + 19)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.polygon("fill", x + w - 14, y + h / 2 - 2, x + w - 6, y + h / 2 - 2, x + w - 10, y + h / 2 + 3)
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
  theme.setFont(11)
  theme.setColor(theme.colors.text, 1)
  love.graphics.print(label, x, y + (h - theme.fontFor(11):getHeight()) / 2 - 1)
  local px = x + w - 46
  local py = y + (h - 20) / 2
  theme.setColor(theme.colors.black, 0.7)
  love.graphics.rectangle("fill", px + 2, py + 2, 40, 20)
  theme.setColor(value and theme.colors.green or theme.colors.borderSoft, 1)
  love.graphics.rectangle("fill", px, py, 40, 20)
  theme.setColor(value and theme.colors.green or theme.colors.muted, 1)
  love.graphics.rectangle("line", px + 0.5, py + 0.5, 39, 19)
  theme.setColor(theme.colors.text, 1)
  love.graphics.rectangle("fill", value and (px + 22) or (px + 4), py + 3, 14, 14)
end

function widgets.slider(app, x, y, w, h, label, value, onChange, opts)
  opts = opts or {}
  value = clamp(tonumber(value) or 0, 0, 100)
  local hover = widgets.hover(app, x, y, w, h)
  local clicked = widgets.click(app, x, y, w, h)
  if hover then
    app.mouse.hand = true
    if opts.tooltip then
      app.tooltip = opts.tooltip
    end
  end
  local trackX = x + 4
  local trackY = y + h - 9
  local trackW = w - 8
  if (hover and app.mouse.down) or clicked then
    local nextValue = clamp((app.mouse.x - trackX) / trackW * 100, 0, 100)
    nextValue = math.floor(nextValue + 0.5)
    if onChange and nextValue ~= value then
      onChange(nextValue)
      value = nextValue
    end
  end
  theme.setFont(9)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.print(label, x + 2, y)
  theme.setFont(9)
  theme.setColor(theme.colors.text, 1)
  love.graphics.printf(math.floor(value + 0.5) .. " %", x + w - 58, y, 56, "right")
  theme.setColor(theme.colors.bg, 1)
  love.graphics.rectangle("fill", trackX, trackY, trackW, 5)
  theme.setColor(theme.colors.gold, 1)
  love.graphics.rectangle("fill", trackX, trackY, trackW * value / 100, 5)
  theme.setColor(theme.colors.text, 1)
  love.graphics.rectangle("fill", trackX + trackW * value / 100 - 3, trackY - 3, 6, 11)
end

function widgets.scroll(app, id, x, y, w, h, contentHeight, drawFn)
  local offset = app.scroll[id] or 0
  local maxOffset = math.max(0, contentHeight - h)
  if widgets.hover(app, x, y, w, h) and app.wheel then
    offset = offset - app.wheel.dy * 48
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

  if maxOffset > 12 and id ~= "nest_eggs" then
    local barH = math.max(20, h * (h / contentHeight))
    local barY = y + (h - barH) * (offset / maxOffset)
    theme.setColor(theme.colors.textDim, 0.35)
    love.graphics.rectangle("fill", x + w - 4, barY, 3, barH)
  end
end

function widgets.modalFrame(app, title, subtitle, width, height, opts)
  opts = opts or {}
  love.graphics.setColor(0, 0, 0, 0.76)
  love.graphics.rectangle("fill", 0, 0, 1280, 720)
  local x = (1280 - width) / 2
  local y = (720 - height) / 2
  theme.panel(x, y, width, height, {
    color = opts.color or theme.colors.panel,
    borderColor = opts.borderColor or theme.colors.border,
    radius = 0,
    shadowSize = 7,
    borderWidth = 3,
  })
  theme.goldBar(x + 12, y + 12, width - 24, 44, title, {
    icon = opts.icon,
    font = 18,
  })
  if subtitle then
    theme.setFont(10)
    theme.setColor(theme.colors.textDim, 1)
    love.graphics.printf(subtitle, x + 24, y + 64, width - 48, "left")
  end
  return x, y
end

function widgets.drawTooltip(app)
  if not app.tooltip then
    return
  end
  theme.setFont(10)
  local font = theme.fontFor(10)
  local maxWidth = 300
  local _, lines = font:getWrap(app.tooltip, maxWidth)
  local textHeight = #lines * font:getHeight()
  local width = math.min(maxWidth, font:getWidth(app.tooltip) + 4) + 16
  local height = textHeight + 14
  local x = math.min(app.mouse.x + 16, 1280 - width - 8)
  local y = math.min(app.mouse.y + 18, 720 - height - 8)
  theme.panel(x, y, width, height, {
    color = theme.colors.panel,
    borderColor = theme.colors.goldDark,
    shadowSize = 3,
    borderWidth = 2,
  })
  theme.setColor(theme.colors.text, 1)
  love.graphics.printf(app.tooltip, x + 8, y + 7, width - 16, "left")
end

function widgets.dimButton(app, x, y, w, h, label, onClick)
  return widgets.button(app, x, y, w, h, label, { style = "ghost", onClick = onClick })
end

function widgets.emptyState(x, y, w, h, title, body)
  theme.panel(x, y, w, h, {
    color = theme.colors.panel2,
    borderColor = theme.colors.borderSoft,
    shadowSize = 0,
    borderWidth = 1,
  })
  theme.setFont(14)
  theme.setColor(theme.colors.textDim, 1)
  love.graphics.printf(title, x + 16, y + h / 2 - 26, w - 32, "center")
  theme.setFont(10)
  theme.setColor(theme.colors.muted, 1)
  love.graphics.printf(body or "", x + 16, y + h / 2 + 2, w - 32, "center")
end

return widgets
