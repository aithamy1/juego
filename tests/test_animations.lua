local config = require("src.game.config")
local render = require("src.render.dino")

local function makeDino(species)
  return {
    id = 1,
    species = species,
    mutation = "ninguna",
    genes = {
      pattern = "liso",
      primaryColor = "verde",
      secondaryColor = "crema",
      crest = "ninguna",
    },
  }
end

local function gridText(grid)
  local parts = {}
  for y = 1, #grid do
    parts[y] = table.concat(grid[y])
  end
  return table.concat(parts, "\n")
end

local function countPixels(grid)
  local total = 0
  for y = 1, #grid do
    for x = 1, #grid[y] do
      if grid[y][x] ~= "." then
        total = total + 1
      end
    end
  end
  return total
end

return function(t)
  t.test("cada especie tiene un ciclo de marcha propio", function()
    local seen = {}
    for _, species in ipairs(config.speciesOrder) do
      local style = render.walkStyle(species)
      t.assertTrue(style ~= nil, "falta el estilo de " .. species)
      t.assertTrue(style.frames >= 6, "pocos fotogramas en " .. species)
      t.assertTrue(style.fps > 0, "fps inválido en " .. species)
      t.assertTrue(
        style.tail ~= nil or style.head ~= nil or style.wings ~= nil
          or style.shear ~= nil or (style.legs ~= nil and #style.legs > 0),
        "sin partes animadas en " .. species
      )
      t.assertTrue(seen[style] == nil, "estilo repetido en " .. species)
      seen[style] = true
    end
  end)

  t.test("la marcha cambia de fotograma y conserva el cuerpo", function()
    for _, species in ipairs(config.speciesOrder) do
      local dino = makeDino(species)
      local style = render.walkStyle(species)
      local base = render.walkGrid(dino, 1)
      local baseCount = countPixels(base)
      t.assertTrue(baseCount > 300, "sprite vacío en " .. species)
      local texts = {}
      for frame = 1, style.frames do
        local grid = render.walkGrid(dino, frame)
        local count = countPixels(grid)
        t.assertTrue(count >= baseCount * 0.85, "se pierden píxeles en " .. species .. " f" .. frame)
        t.assertTrue(count <= baseCount * 1.10, "se duplican píxeles en " .. species .. " f" .. frame)
        texts[frame] = gridText(grid)
      end
      local distinct = 0
      for frame = 1, style.frames do
        if texts[frame] ~= texts[1] then
          distinct = distinct + 1
        end
      end
      t.assertTrue(distinct >= 3, "la animación de " .. species .. " apenas cambia")
    end
  end)

  t.test("el fotograma avanza con el tiempo y vuelve a empezar", function()
    for _, species in ipairs(config.speciesOrder) do
      local style = render.walkStyle(species)
      local first = render.walkFrame(species, 0, 0, 1)
      local nextFrame = render.walkFrame(species, 1 / style.fps, 0, 1)
      t.assertEqual(first, 1, "fotograma inicial de " .. species)
      t.assertTrue(nextFrame ~= first, "el fotograma no avanza en " .. species)
      local looped = render.walkFrame(species, style.frames / style.fps, 0, 1)
      t.assertEqual(looped, first, "el ciclo no se cierra en " .. species)
    end
  end)
end
