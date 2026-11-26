-- Serialización pura. La lectura/escritura del archivo la hace main.lua.
local json = require("lib.json")
local config = require("src.game.config")
local state = require("src.game.state")

local save = {}

local migrations = {
  -- De una versión sin campo version a la 1.
  [0] = function(data)
    data.version = 1
    return data
  end,
}

function save.encode(currentState)
  currentState.version = config.saveVersion
  return json.encode(currentState)
end

function save.decode(text)
  local ok, data = pcall(json.decode, text)
  if not ok then
    return nil, "El guardado no es JSON válido: " .. tostring(data)
  end
  if type(data) ~= "table" then
    return nil, "El guardado no contiene un objeto."
  end
  if data.version ~= nil and type(data.version) ~= "number" then
    return nil, "La versión del guardado no es válida."
  end
  if data.version and data.version > config.saveVersion then
    return nil, "El guardado pertenece a una versión más nueva del juego."
  end
  local version = data.version or 0
  while version < config.saveVersion do
    local migrate = migrations[version]
    if not migrate then
      return nil, "No hay migración para la versión " .. tostring(version) .. "."
    end
    migrate(data)
    version = data.version
  end
  local normalized, normalizeError = pcall(state.normalize, data)
  if not normalized then
    return nil, "El guardado tiene datos inválidos: " .. tostring(normalizeError)
  end
  return data
end

function save.migrate(data)
  return save.decode(json.encode(data))
end

return save
