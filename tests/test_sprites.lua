local sprites = require("src.render.dino_sprites")
local config = require("src.game.config")

return function(t)
  t.test("cada especie tiene una plantilla de 64x40 con contorno", function()
    for _, species in ipairs(config.speciesOrder) do
      local raw = sprites[species]
      t.assertTrue(type(raw) == "string", "falta la plantilla de " .. species)
      raw = raw:gsub("^%s*\n", ""):gsub("\n%s*$", "")
      local rows = {}
      for line in raw:gmatch("[^\n]+") do
        rows[#rows + 1] = line
      end
      t.assertEqual(#rows, 40, "filas de " .. species)
      for i, line in ipairs(rows) do
        t.assertEqual(#line, 64, "ancho de " .. species .. " fila " .. i)
        t.assertTrue(line:match("^[%.obnsflgqhyew]+$") ~= nil, "caracteres de " .. species .. " fila " .. i)
      end
      t.assertTrue(raw:find("b", 1, true) ~= nil, "cuerpo de " .. species)
      t.assertTrue(raw:find("o", 1, true) ~= nil, "contorno de " .. species)
      t.assertTrue(raw:find("e", 1, true) ~= nil, "ojo de " .. species)
    end
  end)
end
