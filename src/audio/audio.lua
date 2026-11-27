-- Audio procedural: música y efectos generados al arrancar, sin archivos externos.
-- Solo esta capa usa love.audio y love.sound.
local audio = {}

local RATE = 22050
local TAU = math.pi * 2
local MUSIC_VOLUME = 0.32

local musicSource
local crackSource
local hatchSource
local ready = false
local musicGain = 0
local duckGain = 1
local duckTimer = 0
local sfxEnabled = true

local function clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

local function midi(note)
  return 440 * 2 ^ ((note - 69) / 12)
end

local function noiseAt(index, seed)
  local value = math.sin(index * 12.9898 + seed * 78.233) * 43758.5453
  return (value - math.floor(value)) * 2 - 1
end

local function oscillator(kind, phase)
  phase = phase - math.floor(phase)
  if kind == "sine" then
    return math.sin(phase * TAU)
  elseif kind == "tri" then
    return 4 * math.abs(phase - 0.5) - 1
  elseif kind == "softsquare" then
    local base = math.sin(phase * TAU)
    return base + 0.30 * math.sin(phase * TAU * 3) + 0.10 * math.sin(phase * TAU * 5)
  elseif kind == "epiano" then
    return math.sin(phase * TAU) * 0.72
      + math.sin(phase * TAU * 2) * 0.20
      + math.sin(phase * TAU * 3) * 0.06
  end
  return math.sin(phase * TAU)
end

local function makeBuffer(seconds)
  local samples = math.max(1, math.floor(seconds * RATE))
  local buffer = {}
  for i = 1, samples do
    buffer[i] = 0
  end
  return buffer, samples
end

local function addTone(buffer, startSeconds, duration, frequency, amplitude, opts)
  opts = opts or {}
  local samples = #buffer
  local first = math.floor(startSeconds * RATE)
  local count = math.floor(duration * RATE)
  if count <= 0 then return end
  local attack = opts.attack or 0.008
  local release = opts.release or 0.08
  local decay = opts.decay or 0
  local detune = opts.detune or 0
  local vibrato = opts.vibrato or 0
  local kind = opts.wave or "tri"
  for j = 0, count - 1 do
    local t = j / RATE
    local envelope
    if t < attack then
      envelope = t / attack
    else
      envelope = 1
    end
    local remaining = (count - j) / RATE
    if remaining < release then
      envelope = envelope * math.max(0, remaining / release)
    end
    if decay > 0 then
      envelope = envelope * math.exp(-decay * t)
    end
    local f = frequency
    if vibrato > 0 then
      f = f * (1 + vibrato * math.sin(TAU * 4.5 * t))
    end
    local phase = t * f
    local sample = oscillator(kind, phase)
    if detune > 0 then
      sample = sample * 0.65 + oscillator(kind, phase * (1 + detune)) * 0.35
    end
    local index = (first + j) % samples + 1
    buffer[index] = buffer[index] + sample * amplitude * envelope
  end
end

-- Barrido de frecuencia con vibrato y trémolo, para llamadas y rugidos.
local function addSweep(buffer, startSeconds, duration, fromHz, toHz, amplitude, opts)
  opts = opts or {}
  local samples = #buffer
  local first = math.floor(startSeconds * RATE)
  local count = math.floor(duration * RATE)
  if count <= 0 then return end
  local attack = opts.attack or 0.02
  local release = opts.release or 0.12
  local bend = opts.bend or 1
  local vibrato = opts.vibrato or 0
  local vibratoRate = opts.vibratoRate or 5
  local tremolo = opts.tremolo or 0
  local tremoloRate = opts.tremoloRate or 20
  local detune = opts.detune or 0
  local kind = opts.wave or "tri"
  local phase = 0
  for j = 0, count - 1 do
    local t = j / RATE
    local u = t / duration
    local f = fromHz + (toHz - fromHz) * (u ^ bend)
    if vibrato > 0 then
      f = f * (1 + vibrato * math.sin(TAU * vibratoRate * t))
    end
    phase = phase + f / RATE
    local sample = oscillator(kind, phase)
    if detune > 0 then
      sample = sample * 0.68 + oscillator(kind, phase * (1 + detune)) * 0.32
    end
    local envelope
    if t < attack then
      envelope = t / attack
    else
      envelope = 1
    end
    if t > duration - release then
      envelope = envelope * math.max(0, (duration - t) / release)
    end
    if opts.decay then
      envelope = envelope * math.exp(-opts.decay * t)
    end
    if tremolo > 0 then
      envelope = envelope * (1 - tremolo * 0.5 * (1 - math.cos(TAU * tremoloRate * t)))
    end
    local index = (first + j) % samples + 1
    buffer[index] = buffer[index] + sample * amplitude * envelope
  end
end

local function addNoise(buffer, startSeconds, duration, amplitude, decay, seed)
  local samples = #buffer
  local first = math.floor(startSeconds * RATE)
  local count = math.floor(duration * RATE)
  if count <= 0 then return end
  local low = 0
  for j = 0, count - 1 do
    local t = j / RATE
    local raw = noiseAt(first + j, seed)
    low = low * 0.55 + raw * 0.45
    local envelope = math.exp(-decay * t) * math.max(0, 1 - t / duration)
    local index = (first + j) % samples + 1
    buffer[index] = buffer[index] + low * amplitude * envelope
  end
end

local function addKick(buffer, startSeconds, amplitude)
  local samples = #buffer
  local first = math.floor(startSeconds * RATE)
  local count = math.floor(0.18 * RATE)
  local phase = 0
  for j = 0, count - 1 do
    local t = j / RATE
    local frequency = 116 * math.exp(-t * 19) + 42
    phase = phase + frequency / RATE
    local envelope = math.exp(-t * 20)
    local index = (first + j) % samples + 1
    buffer[index] = buffer[index] + math.sin(phase * TAU) * amplitude * envelope
  end
end

local function warmLoop(buffer, samples)
  local coefficient = 0.55
  local previous = 0
  for i = 1, samples do
    previous = previous + coefficient * (buffer[i] - previous)
  end
  for i = 1, samples do
    previous = previous + coefficient * (buffer[i] - previous)
    buffer[i] = previous
  end
end

local function toSoundData(buffer, samples, peakTarget)
  local peak = 0
  for i = 1, samples do
    local value = math.abs(buffer[i])
    if value > peak then
      peak = value
    end
  end
  local gain = peak > 0 and peakTarget / peak or 1
  local data = love.sound.newSoundData(samples, RATE, 16, 1)
  for i = 1, samples do
    data:setSample(i - 1, clamp(buffer[i] * gain, -1, 1))
  end
  return data
end

-- Bucle lento en Do mayor: pad cálido, bajo suave y melodía con eco.
local function buildMusic()
  local beat = 60 / 72
  local bar = beat * 4
  local bars = 8
  local buffer, samples = makeBuffer(bar * bars)
  local chords = {
    { root = 48, notes = { 60, 64, 67, 71 } }, -- Cmaj7
    { root = 45, notes = { 57, 60, 64, 67 } }, -- Am7
    { root = 41, notes = { 53, 57, 60, 64 } }, -- Fmaj7
    { root = 43, notes = { 55, 59, 62, 64 } }, -- G6
    { root = 41, notes = { 53, 57, 60, 64 } }, -- Fmaj7
    { root = 45, notes = { 57, 60, 64, 67 } }, -- Am7
    { root = 50, notes = { 62, 65, 69, 72 } }, -- Dm7
    { root = 43, notes = { 55, 59, 62, 64 } }, -- G6
  }

  for barIndex = 1, bars do
    local chord = chords[barIndex]
    local start = (barIndex - 1) * bar

    for _, note in ipairs(chord.notes) do
      addTone(buffer, start, bar * 1.04, midi(note), 0.030, {
        wave = "sine",
        attack = 0.90,
        release = 1.10,
        detune = 0.0025,
      })
    end

    addTone(buffer, start, bar * 0.95, midi(chord.root), 0.070, {
      wave = "sine",
      attack = 0.08,
      release = 0.50,
    })
    addTone(buffer, start + 2 * beat, beat * 1.20, midi(chord.root), 0.038, {
      wave = "tri",
      attack = 0.02,
      decay = 1.5,
      release = 0.25,
    })

    addTone(buffer, start + 1.5 * beat, beat * 0.90, midi(chord.notes[2] + 12), 0.018, {
      wave = "epiano",
      attack = 0.01,
      decay = 2.2,
      release = 0.40,
    })
    addTone(buffer, start + 3 * beat, beat * 0.80, midi(chord.notes[3] + 12), 0.014, {
      wave = "epiano",
      attack = 0.01,
      decay = 2.5,
      release = 0.40,
    })

    addNoise(buffer, start + beat, 0.16, 0.010, 16, 31 + barIndex)
    addNoise(buffer, start + 3 * beat, 0.16, 0.008, 18, 41 + barIndex)
  end

  local melody = {
    { bar = 1, beat = 0, note = 76, duration = 2.0 },
    { bar = 1, beat = 2.5, note = 71, duration = 1.4 },
    { bar = 2, beat = 0, note = 72, duration = 1.6 },
    { bar = 2, beat = 2.0, note = 69, duration = 2.0 },
    { bar = 3, beat = 0, note = 69, duration = 1.5 },
    { bar = 3, beat = 2.0, note = 76, duration = 2.0 },
    { bar = 4, beat = 0.5, note = 74, duration = 1.5 },
    { bar = 4, beat = 2.5, note = 71, duration = 1.5 },
    { bar = 5, beat = 0, note = 72, duration = 2.0 },
    { bar = 5, beat = 2.5, note = 67, duration = 1.3 },
    { bar = 6, beat = 0, note = 76, duration = 1.5 },
    { bar = 6, beat = 2.0, note = 72, duration = 2.0 },
    { bar = 7, beat = 0, note = 74, duration = 1.5 },
    { bar = 7, beat = 2.0, note = 69, duration = 2.0 },
    { bar = 8, beat = 0, note = 71, duration = 1.4 },
    { bar = 8, beat = 1.8, note = 67, duration = 1.4 },
    { bar = 8, beat = 3.0, note = 74, duration = 1.0 },
  }
  for _, note in ipairs(melody) do
    local start = (note.bar - 1) * bar + note.beat * beat
    addTone(buffer, start, note.duration * beat, midi(note.note), 0.055, {
      wave = "epiano",
      attack = 0.02,
      decay = 0.8,
      release = 0.50,
      vibrato = 0.0015,
    })
    addTone(buffer, start + 0.42, note.duration * beat * 0.80, midi(note.note), 0.015, {
      wave = "epiano",
      attack = 0.05,
      decay = 1.2,
      release = 0.60,
    })
  end

  warmLoop(buffer, samples)
  return toSoundData(buffer, samples, 0.76)
end

local function buildCrack()
  local buffer, samples = makeBuffer(0.11)
  for i = 1, samples do
    local t = (i - 1) / RATE
    local envelope = math.exp(-t * 34)
    local burst = noiseAt(i, 3) * 0.48
    local tick = math.sin(TAU * (780 - 2600 * t) * t) * 0.52
    buffer[i] = (burst + tick) * envelope
  end
  return toSoundData(buffer, samples, 0.85)
end

local function buildHatch()
  local buffer, samples = makeBuffer(1.45)

  -- Rotura de cáscara y golpe grave.
  addNoise(buffer, 0, 0.30, 0.60, 17, 29)
  addKick(buffer, 0.015, 0.22)

  -- Acorde cálido y arpegio ascendente de La menor.
  local chord = { 57, 64, 69, 72 }
  for _, note in ipairs(chord) do
    addTone(buffer, 0.10, 1.15, midi(note), 0.045, {
      wave = "sine",
      attack = 0.05,
      release = 0.45,
      detune = 0.004,
    })
  end
  local sparkle = { 69, 72, 76, 81, 84, 88, 93 }
  for index, note in ipairs(sparkle) do
    addTone(buffer, 0.12 + index * 0.055, 0.85, midi(note), 0.095, {
      wave = "tri",
      attack = 0.006,
      decay = 3.2,
      release = 0.35,
    })
  end

  addNoise(buffer, 0.10, 0.75, 0.055, 4.2, 47)
  return toSoundData(buffer, samples, 0.92)
end

-- Llamadas de cada especie: graves y largas para los grandes, agudas y cortas
-- para los pequeños. Se generan al arrancar, como el resto del audio.
local function buildTRexCall()
  local buffer, samples = makeBuffer(1.35)
  addSweep(buffer, 0.00, 1.10, 96, 54, 0.55, {
    wave = "tri", attack = 0.05, release = 0.35,
    vibrato = 0.030, vibratoRate = 4.2,
    tremolo = 0.35, tremoloRate = 18,
    detune = 0.012,
  })
  addSweep(buffer, 0.04, 1.00, 144, 82, 0.22, {
    wave = "softsquare", attack = 0.08, release = 0.28,
    vibrato = 0.022, vibratoRate = 5.2, detune = 0.010,
  })
  addSweep(buffer, 0.00, 0.85, 48, 36, 0.30, {
    wave = "sine", attack = 0.08, release = 0.35,
  })
  addNoise(buffer, 0.02, 0.95, 0.10, 2.4, 71)
  return toSoundData(buffer, samples, 0.95)
end

local function buildTriceratopsCall()
  local buffer, samples = makeBuffer(0.95)
  addSweep(buffer, 0.00, 0.78, 152, 112, 0.50, {
    wave = "softsquare", attack = 0.04, release = 0.24,
    vibrato = 0.018, vibratoRate = 5.0,
    tremolo = 0.18, tremoloRate = 13,
  })
  addSweep(buffer, 0.02, 0.72, 76, 58, 0.30, {
    wave = "sine", attack = 0.06, release = 0.28,
  })
  addNoise(buffer, 0.00, 0.55, 0.055, 4.0, 73)
  return toSoundData(buffer, samples, 0.90)
end

local function buildStegosaurusCall()
  local buffer, samples = makeBuffer(0.82)
  addSweep(buffer, 0.00, 0.26, 104, 76, 0.50, {
    wave = "tri", attack = 0.025, release = 0.09,
    tremolo = 0.55, tremoloRate = 26,
  })
  addSweep(buffer, 0.33, 0.28, 96, 68, 0.42, {
    wave = "tri", attack = 0.025, release = 0.10,
    tremolo = 0.50, tremoloRate = 22,
  })
  addNoise(buffer, 0.00, 0.60, 0.10, 5.0, 76)
  addSweep(buffer, 0.00, 0.55, 52, 44, 0.18, {
    wave = "sine", attack = 0.03, release = 0.18,
  })
  return toSoundData(buffer, samples, 0.92)
end

local function buildAnkylosaurusCall()
  local buffer, samples = makeBuffer(0.62)
  addSweep(buffer, 0.00, 0.40, 128, 92, 0.45, {
    wave = "softsquare", attack = 0.02, release = 0.16,
    tremolo = 0.55, tremoloRate = 30,
  })
  addNoise(buffer, 0.02, 0.50, 0.16, 6.0, 79)
  addSweep(buffer, 0.04, 0.30, 64, 54, 0.24, {
    wave = "sine", attack = 0.02, release = 0.12,
  })
  return toSoundData(buffer, samples, 0.90)
end

local function buildParasaurolophusCall()
  local buffer, samples = makeBuffer(1.02)
  addSweep(buffer, 0.00, 0.55, 180, 242, 0.42, {
    wave = "tri", attack = 0.05, release = 0.06,
    vibrato = 0.010, vibratoRate = 5.5,
  })
  addSweep(buffer, 0.50, 0.50, 242, 164, 0.42, {
    wave = "tri", attack = 0.02, release = 0.18,
    vibrato = 0.018, vibratoRate = 6.0,
  })
  addSweep(buffer, 0.00, 0.98, 90, 82, 0.20, {
    wave = "sine", attack = 0.06, release = 0.20,
  })
  addNoise(buffer, 0.02, 0.70, 0.030, 3.0, 83)
  return toSoundData(buffer, samples, 0.90)
end

local function buildVelociraptorCall()
  local buffer, samples = makeBuffer(0.52)
  addSweep(buffer, 0.00, 0.20, 860, 1480, 0.40, {
    wave = "tri", attack = 0.004, release = 0.04,
    vibrato = 0.040, vibratoRate = 20,
  })
  addSweep(buffer, 0.19, 0.26, 1420, 900, 0.32, {
    wave = "tri", attack = 0.004, release = 0.09,
    vibrato = 0.050, vibratoRate = 24,
  })
  addNoise(buffer, 0.00, 0.36, 0.10, 9.0, 89)
  return toSoundData(buffer, samples, 0.85)
end

local function buildPteranodonCall()
  local buffer, samples = makeBuffer(0.58)
  addSweep(buffer, 0.00, 0.46, 640, 420, 0.38, {
    wave = "softsquare", attack = 0.006, release = 0.16,
    vibrato = 0.050, vibratoRate = 30,
  })
  addSweep(buffer, 0.02, 0.42, 960, 690, 0.14, {
    wave = "tri", attack = 0.005, release = 0.14,
    vibrato = 0.060, vibratoRate = 34,
  })
  addNoise(buffer, 0.00, 0.42, 0.15, 7.0, 97)
  return toSoundData(buffer, samples, 0.88)
end

local callBuilders = {
  trex = buildTRexCall,
  triceratops = buildTriceratopsCall,
  stegosaurus = buildStegosaurusCall,
  ankylosaurus = buildAnkylosaurusCall,
  parasaurolophus = buildParasaurolophusCall,
  velociraptor = buildVelociraptorCall,
  pteranodon = buildPteranodonCall,
}

local callMeta = {
  trex = { duration = 1.35, low = 48, high = 144, family = "rugido", volume = 0.62, duck = 0.45 },
  triceratops = { duration = 0.95, low = 58, high = 152, family = "bramido", volume = 0.58, duck = 0.28 },
  stegosaurus = { duration = 0.82, low = 44, high = 104, family = "gruñido", volume = 0.55, duck = 0.22 },
  ankylosaurus = { duration = 0.62, low = 54, high = 128, family = "resoplido", volume = 0.55, duck = 0.22 },
  parasaurolophus = { duration = 1.02, low = 82, high = 242, family = "bocina", volume = 0.60, duck = 0.30 },
  velociraptor = { duration = 0.52, low = 860, high = 1480, family = "chillido", volume = 0.50, duck = 0.20 },
  pteranodon = { duration = 0.58, low = 420, high = 960, family = "graznido", volume = 0.50, duck = 0.20 },
}

local speciesSources = {}
local sfxVolume = 1

function audio.load()
  if ready then
    return true
  end
  local ok, err = pcall(function()
    musicSource = love.audio.newSource(buildMusic(), "static")
    musicSource:setLooping(true)
    musicSource:setVolume(0)
    crackSource = love.audio.newSource(buildCrack(), "static")
    crackSource:setVolume(0.72)
    hatchSource = love.audio.newSource(buildHatch(), "static")
    hatchSource:setVolume(0.85)
    for species, builder in pairs(callBuilders) do
      local okCall, source = pcall(function()
        local callSource = love.audio.newSource(builder(), "static")
        callSource:setVolume(callMeta[species].volume)
        return callSource
      end)
      if okCall then
        speciesSources[species] = source
      end
    end
  end)
  if not ok then
    return false, tostring(err)
  end
  ready = true
  return true
end

function audio.update(dt, settings)
  if not ready then return end
  settings = settings or {}
  sfxEnabled = settings.sfx ~= false

  if not sfxEnabled then
    for _, source in pairs(speciesSources) do
      if source:isPlaying() then
        source:stop()
      end
    end
  end

  local wanted = settings.music ~= false
  local speed = wanted and 2.2 or 5.0
  musicGain = musicGain + ((wanted and 1 or 0) - musicGain) * math.min(1, dt * speed)
  if wanted and musicGain > 0.001 and not musicSource:isPlaying() then
    musicSource:play()
  end
  if not wanted and musicGain < 0.01 then
    if musicSource:isPlaying() then
      musicSource:pause()
    end
    musicGain = 0
  end

  if duckTimer > 0 then
    duckTimer = math.max(0, duckTimer - dt)
    duckGain = 0.38
  else
    duckGain = duckGain + (1 - duckGain) * math.min(1, dt * 1.6)
  end

  local musicScale = (settings.musicVolume or 100) / 100
  sfxVolume = (settings.sfxVolume or 100) / 100
  local sfxScale = sfxVolume
  musicSource:setVolume(MUSIC_VOLUME * musicGain * duckGain * musicScale)
  if crackSource then
    crackSource:setVolume(0.72 * sfxScale)
  end
  if hatchSource then
    hatchSource:setVolume(0.85 * sfxScale)
  end
  for species, source in pairs(speciesSources) do
    local meta = callMeta[species]
    source:setVolume((meta and meta.volume or 0.55) * sfxScale)
  end
end

function audio.playCrack(stage)
  if not ready or not sfxEnabled or not crackSource then return end
  crackSource:stop()
  crackSource:setPitch(0.92 + (stage or 1) * 0.045)
  crackSource:play()
end

function audio.playHatch(rarity)
  if not ready or not sfxEnabled or not hatchSource then return end
  local pitch = ({
    common = 0.96,
    uncommon = 1.00,
    rare = 1.04,
    epic = 1.08,
    legendary = 1.12,
  })[rarity] or 1.00
  hatchSource:stop()
  hatchSource:setPitch(pitch)
  hatchSource:play()
  duckTimer = 0.85
end

function audio.playSpecies(species, seed)
  if not ready or not sfxEnabled or sfxVolume <= 0 then return end
  local source = speciesSources[species] or speciesSources.triceratops
  if not source then return end
  local meta = callMeta[species] or callMeta.triceratops
  local pitch = 1
  if seed then
    pitch = pitch + ((seed % 7) - 3) * 0.01
  end
  source:stop()
  source:setPitch(pitch)
  source:setVolume((meta.volume or 0.55) * sfxVolume)
  source:play()
  duckTimer = math.max(duckTimer, meta.duck or 0.25)
end

function audio.callInfo(species)
  return callMeta[species]
end

function audio.isReady()
  return ready
end

return audio
