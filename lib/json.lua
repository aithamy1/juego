-- JSON mínimo y determinista (claves ordenadas), sin dependencias de LÖVE.
local json = {}

local escapeMap = {
  ['"'] = '\\"',
  ["\\"] = "\\\\",
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t",
}

local function escapeString(str)
  return '"' .. str:gsub('[%z\1-\31\\"]', function(char)
    local mapped = escapeMap[char]
    if mapped then
      return mapped
    end
    return string.format("\\u%04x", string.byte(char))
  end) .. '"'
end

local function isArray(tbl)
  local max = 0
  local count = 0
  for key in pairs(tbl) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return false
    end
    if key > max then
      max = key
    end
    count = count + 1
  end
  return max == count
end

local function encodeValue(value, out)
  local kind = type(value)
  if value == nil then
    out[#out + 1] = "null"
  elseif kind == "boolean" then
    out[#out + 1] = value and "true" or "false"
  elseif kind == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      error("JSON: número no finito")
    end
    if value == 0 then
      out[#out + 1] = "0"
    elseif value == math.floor(value) and math.abs(value) < 1e15 then
      out[#out + 1] = string.format("%d", value)
    else
      out[#out + 1] = string.format("%.14g", value)
    end
  elseif kind == "string" then
    out[#out + 1] = escapeString(value)
  elseif kind == "table" then
    if isArray(value) then
      out[#out + 1] = "["
      for i = 1, #value do
        if i > 1 then
          out[#out + 1] = ","
        end
        encodeValue(value[i], out)
      end
      out[#out + 1] = "]"
    else
      local keys = {}
      for key in pairs(value) do
        if type(key) ~= "string" then
          error("JSON: clave no textual")
        end
        keys[#keys + 1] = key
      end
      table.sort(keys)
      out[#out + 1] = "{"
      for i, key in ipairs(keys) do
        if i > 1 then
          out[#out + 1] = ","
        end
        out[#out + 1] = escapeString(key)
        out[#out + 1] = ":"
        encodeValue(value[key], out)
      end
      out[#out + 1] = "}"
    end
  else
    error("JSON: tipo no serializable: " .. kind)
  end
end

function json.encode(value)
  local out = {}
  encodeValue(value, out)
  return table.concat(out)
end

-- Decodificador
local function utf8Char(code)
  if code < 0x80 then
    return string.char(code)
  elseif code < 0x800 then
    return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
  elseif code < 0x10000 then
    return string.char(
      0xE0 + math.floor(code / 0x1000),
      0x80 + math.floor(code / 0x40) % 0x40,
      0x80 + code % 0x40
    )
  end
  return string.char(
    0xF0 + math.floor(code / 0x40000),
    0x80 + math.floor(code / 0x1000) % 0x40,
    0x80 + math.floor(code / 0x40) % 0x40,
    0x80 + code % 0x40
  )
end

local Parser = {}
Parser.__index = Parser

function Parser:error(message)
  error(string.format("JSON: %s en la posición %d", message, self.pos))
end

function Parser:skipWhitespace()
  while true do
    local char = self.text:sub(self.pos, self.pos)
    if char == " " or char == "\n" or char == "\r" or char == "\t" then
      self.pos = self.pos + 1
    else
      return
    end
  end
end

function Parser:parseString()
  if self.text:sub(self.pos, self.pos) ~= '"' then
    self:error("se esperaba una cadena")
  end
  self.pos = self.pos + 1
  local out = {}
  while true do
    local char = self.text:sub(self.pos, self.pos)
    if char == "" then
      self:error("cadena sin cerrar")
    elseif char == '"' then
      self.pos = self.pos + 1
      return table.concat(out)
    elseif char == "\\" then
      local escape = self.text:sub(self.pos + 1, self.pos + 1)
      self.pos = self.pos + 2
      if escape == '"' or escape == "\\" or escape == "/" then
        out[#out + 1] = escape
      elseif escape == "b" then
        out[#out + 1] = "\b"
      elseif escape == "f" then
        out[#out + 1] = "\f"
      elseif escape == "n" then
        out[#out + 1] = "\n"
      elseif escape == "r" then
        out[#out + 1] = "\r"
      elseif escape == "t" then
        out[#out + 1] = "\t"
      elseif escape == "u" then
        local hex = self.text:sub(self.pos, self.pos + 3)
        if not hex:match("^%x%x%x%x$") then
          self:error("escape unicode inválido")
        end
        self.pos = self.pos + 4
        out[#out + 1] = utf8Char(tonumber(hex, 16))
      else
        self:error("escape inválido")
      end
    else
      out[#out + 1] = char
      self.pos = self.pos + 1
    end
  end
end

function Parser:parseNumber()
  local start = self.pos
  if self.text:sub(self.pos, self.pos) == "-" then
    self.pos = self.pos + 1
  end
  while self.text:sub(self.pos, self.pos):match("%d") do
    self.pos = self.pos + 1
  end
  if self.text:sub(self.pos, self.pos) == "." then
    self.pos = self.pos + 1
    while self.text:sub(self.pos, self.pos):match("%d") do
      self.pos = self.pos + 1
    end
  end
  local exponent = self.text:sub(self.pos, self.pos)
  if exponent == "e" or exponent == "E" then
    self.pos = self.pos + 1
    local sign = self.text:sub(self.pos, self.pos)
    if sign == "+" or sign == "-" then
      self.pos = self.pos + 1
    end
    while self.text:sub(self.pos, self.pos):match("%d") do
      self.pos = self.pos + 1
    end
  end
  local raw = self.text:sub(start, self.pos - 1)
  local number = tonumber(raw)
  if not number then
    self:error("número inválido")
  end
  return number
end

function Parser:parseArray()
  self.pos = self.pos + 1
  local out = {}
  self:skipWhitespace()
  if self.text:sub(self.pos, self.pos) == "]" then
    self.pos = self.pos + 1
    return out
  end
  while true do
    self:skipWhitespace()
    out[#out + 1] = self:parseValue()
    self:skipWhitespace()
    local char = self.text:sub(self.pos, self.pos)
    if char == "]" then
      self.pos = self.pos + 1
      return out
    elseif char == "," then
      self.pos = self.pos + 1
    else
      self:error("se esperaba , o ]")
    end
  end
end

function Parser:parseObject()
  self.pos = self.pos + 1
  local out = {}
  self:skipWhitespace()
  if self.text:sub(self.pos, self.pos) == "}" then
    self.pos = self.pos + 1
    return out
  end
  while true do
    self:skipWhitespace()
    local key = self:parseString()
    self:skipWhitespace()
    if self.text:sub(self.pos, self.pos) ~= ":" then
      self:error("se esperaba :")
    end
    self.pos = self.pos + 1
    self:skipWhitespace()
    out[key] = self:parseValue()
    self:skipWhitespace()
    local char = self.text:sub(self.pos, self.pos)
    if char == "}" then
      self.pos = self.pos + 1
      return out
    elseif char == "," then
      self.pos = self.pos + 1
    else
      self:error("se esperaba , o }")
    end
  end
end

function Parser:parseValue()
  self:skipWhitespace()
  local char = self.text:sub(self.pos, self.pos)
  if char == '"' then
    return self:parseString()
  elseif char == "{" then
    return self:parseObject()
  elseif char == "[" then
    return self:parseArray()
  elseif char == "t" and self.text:sub(self.pos, self.pos + 3) == "true" then
    self.pos = self.pos + 4
    return true
  elseif char == "f" and self.text:sub(self.pos, self.pos + 4) == "false" then
    self.pos = self.pos + 5
    return false
  elseif char == "n" and self.text:sub(self.pos, self.pos + 3) == "null" then
    self.pos = self.pos + 4
    return nil
  elseif char == "-" or char:match("%d") then
    return self:parseNumber()
  end
  self:error("valor inesperado")
end

function json.decode(text)
  if type(text) ~= "string" then
    error("JSON: se esperaba una cadena")
  end
  local parser = setmetatable({ text = text, pos = 1 }, Parser)
  local value = parser:parseValue()
  parser:skipWhitespace()
  if parser.pos <= #text then
    parser:error("contenido sobrante")
  end
  return value
end

return json
