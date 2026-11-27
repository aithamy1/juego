local config = require("src.game.config")
local audio = require("src.audio.audio")

local RATE = 22050

local function withFakeLove(fn)
  local previous = love
  local dataList = {}
  local sources = {}

  love = {
    sound = {
      newSoundData = function(samples, rate)
        local data = {
          sampleCount = samples,
          rate = rate,
          min = 0,
          max = 0,
          written = 0,
        }
        function data:setSample(_, value)
          self.written = self.written + 1
          if value < self.min then self.min = value end
          if value > self.max then self.max = value end
        end
        dataList[#dataList + 1] = data
        return data
      end,
    },
    audio = {
      newSource = function(data)
        local source = { data = data, volume = 1, pitch = 1, playing = false }
        function source:setLooping(value) self.looping = value end
        function source:setVolume(value) self.volume = value end
        function source:setPitch(value) self.pitch = value end
        function source:play() self.playing = true end
        function source:stop() self.playing = false end
        function source:pause() self.playing = false end
        function source:isPlaying() return self.playing end
        sources[#sources + 1] = source
        return source
      end,
    },
  }

  local ok, err = pcall(fn, dataList, sources)
  love = previous
  if not ok then
    error(err, 0)
  end
end

local function sourceForDuration(dataList, sources, duration)
  for _, data in ipairs(dataList) do
    if math.abs(data.sampleCount - duration * RATE) <= 2 then
      for _, source in ipairs(sources) do
        if source.data == data then
          return source
        end
      end
    end
  end
  return nil
end

return function(t)
  t.test("cada especie tiene una llamada propia", function()
    local signatures = {}
    for _, species in ipairs(config.speciesOrder) do
      local info = audio.callInfo(species)
      t.assertTrue(info ~= nil, "falta la llamada de " .. species)
      t.assertTrue(info.duration >= 0.4 and info.duration <= 1.6, "duración de " .. species)
      t.assertTrue(info.high > info.low, "registro de " .. species)
      local signature = info.family .. "|" .. string.format("%.2f", info.duration)
      t.assertTrue(signatures[signature] == nil, "llamada repetida en " .. species)
      signatures[signature] = true
    end
  end)

  t.test("las llamadas se sintetizan, respetan el volumen y se reproducen", function()
    withFakeLove(function(dataList, sources)
      local ok, err = audio.load()
      t.assertTrue(ok, "audio.load falló: " .. tostring(err))
      t.assertTrue(#dataList >= 3 + #config.speciesOrder, "faltan buffers de audio")

      for _, species in ipairs(config.speciesOrder) do
        local info = audio.callInfo(species)
        local data = nil
        for _, candidate in ipairs(dataList) do
          if math.abs(candidate.sampleCount - info.duration * RATE) <= 2 then
            data = candidate
            break
          end
        end
        t.assertTrue(data ~= nil, "no se generó el audio de " .. species)
        t.assertEqual(data.written, data.sampleCount, "muestras escritas de " .. species)
        t.assertTrue(data.max - data.min > 0.2, "señal vacía en " .. species)
      end

      audio.update(0.016, { sfx = true, music = false, musicVolume = 100, sfxVolume = 50 })
      local expectedPitch = 1 + ((4 % 7) - 3) * 0.01
      for _, species in ipairs(config.speciesOrder) do
        local info = audio.callInfo(species)
        local source = sourceForDuration(dataList, sources, info.duration)
        t.assertTrue(source ~= nil, "falta la fuente de " .. species)
        source.playing = false
        audio.playSpecies(species, 4)
        t.assertTrue(source.playing, "no se reproduce " .. species)
        t.assertNear(source.pitch, expectedPitch, 0.0001, "tono de " .. species)
        t.assertTrue(source.volume > 0, "volumen de " .. species)
      end

      audio.update(0.016, { sfx = false, music = false, musicVolume = 100, sfxVolume = 100 })
      local source = sourceForDuration(dataList, sources, audio.callInfo("trex").duration)
      source.playing = false
      audio.playSpecies("trex", 1)
      t.assertFalse(source.playing, "los efectos silenciados no deben sonar")
    end)
  end)
end
