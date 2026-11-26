-- PRNG mulberry32 con semilla y contador, sin dependencias de LÖVE.
local bit = require("bit")

local rng = {}

local TWO32 = 4294967296
local MASK32 = 0xFFFFFFFF

local function normalize(x)
  return math.floor(math.abs(x)) % TWO32
end

-- Multiplicación de 32 bits módulo 2^32 sin perder precisión en doubles.
local function mul32(a, b)
  a = a % TWO32
  b = b % TWO32
  local al = a % 65536
  local ah = math.floor(a / 65536)
  local bl = b % 65536
  local bh = math.floor(b / 65536)
  local low = al * bl
  local mid = ah * bl + al * bh + math.floor(low / 65536)
  return (low % 65536) + (mid % 65536) * 65536
end

local function nextFloat(r)
  r.state = (r.state + 0x6D2B79F5) % TWO32
  local t = r.state
  t = mul32(bit.bxor(t, bit.rshift(t, 15)), bit.bor(t, 1))
  local inner = mul32(bit.bxor(t, bit.rshift(t, 7)), bit.bor(t, 61))
  t = bit.bxor(t, (t + inner) % TWO32) % TWO32
  t = bit.bxor(t, bit.rshift(t, 14)) % TWO32
  t = bit.band(t, MASK32) % TWO32
  r.count = r.count + 1
  return t / TWO32
end

function rng.new(seed, state, count)
  local s = normalize(seed or os.time())
  return {
    seed = s,
    state = state and normalize(state) or s,
    count = math.max(0, math.floor(count or 0)),
  }
end

function rng.next(r)
  return nextFloat(r)
end

function rng.float(r, min, max)
  min = min or 0
  max = max or 1
  return min + (max - min) * nextFloat(r)
end

function rng.int(r, min, max)
  if max < min then
    min, max = max, min
  end
  return min + math.floor(nextFloat(r) * (max - min + 1))
end

function rng.chance(r, probability)
  if probability <= 0 then
    return false
  end
  if probability >= 1 then
    return true
  end
  return nextFloat(r) < probability
end

function rng.pick(r, list)
  if #list == 0 then
    return nil
  end
  return list[rng.int(r, 1, #list)]
end

-- entries: { {value=..., weight=...}, ... }
function rng.weighted(r, entries)
  local total = 0
  for i = 1, #entries do
    local w = entries[i].weight or 0
    if w > 0 then
      total = total + w
    end
  end
  if total <= 0 then
    return nil
  end
  local roll = nextFloat(r) * total
  local acc = 0
  for i = 1, #entries do
    local w = entries[i].weight or 0
    if w > 0 then
      acc = acc + w
      if roll < acc then
        return entries[i].value, entries[i]
      end
    end
  end
  for i = #entries, 1, -1 do
    if (entries[i].weight or 0) > 0 then
      return entries[i].value, entries[i]
    end
  end
  return nil
end

function rng.shuffle(r, list)
  for i = #list, 2, -1 do
    local j = rng.int(r, 1, i)
    list[i], list[j] = list[j], list[i]
  end
  return list
end

function rng.copy(r)
  return { seed = r.seed, state = r.state, count = r.count }
end

return rng
