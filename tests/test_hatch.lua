local config = require("src.game.config")
local rng = require("src.game.rng")
local hatch = require("src.game.hatch")

local function fakeState(seed, luck)
  return {
    rng = rng.new(seed),
    pity = { rare = 0, legendary = 0, mutation = 0 },
    upgrades = { luck = luck or 0 },
  }
end

local function baseEntries()
  local weights = hatch.baseWeights()
  local entries = {}
  for _, key in ipairs(config.rarityOrder) do
    entries[#entries + 1] = { value = key, weight = weights[key] }
  end
  return entries
end

return function(t)
  t.test("100.000 tiradas base coinciden con config.rates", function()
    local r = rng.new(20260101)
    local counts = {}
    for _, key in ipairs(config.rarityOrder) do
      counts[key] = 0
    end
    local total = 100000
    for _ = 1, total do
      local rarity = rng.weighted(r, baseEntries())
      counts[rarity] = counts[rarity] + 1
    end
    t.assertNear(counts.common / total, 0.60, 0.008, "común")
    t.assertNear(counts.uncommon / total, 0.25, 0.006, "poco común")
    t.assertNear(counts.rare / total, 0.10, 0.004, "raro")
    t.assertNear(counts.epic / total, 0.04, 0.003, "épico")
    t.assertNear(counts.legendary / total, 0.01, 0.002, "legendario")
  end)

  t.test("100.000 huevos con pity mantienen tasas razonables", function()
    local s = fakeState(20260102)
    local counts = {}
    for _, key in ipairs(config.rarityOrder) do
      counts[key] = 0
    end
    local total = 100000
    for _ = 1, total do
      local rarity = hatch.rollRarity(s)
      counts[rarity] = counts[rarity] + 1
    end
    t.assertNear(counts.common / total, 0.60, 0.012, "común con pity")
    t.assertNear(counts.uncommon / total, 0.25, 0.012, "poco común con pity")
    t.assertNear(counts.rare / total, 0.10, 0.010, "raro con pity")
    t.assertNear(counts.epic / total, 0.04, 0.008, "épico con pity")
    t.assertNear(counts.legendary / total, 0.01, 0.008, "legendario con pity")
  end)

  t.test("la garantía de raro nunca supera rareAt", function()
    local s = fakeState(20260103)
    local gap = 0
    local maxGap = 0
    for _ = 1, 20000 do
      local rarity = hatch.rollRarity(s)
      gap = gap + 1
      if hatch.rarityIndex(rarity) >= hatch.rarityIndex("rare") then
        maxGap = math.max(maxGap, gap)
        gap = 0
      end
    end
    t.assertLessOrEqual(maxGap, config.rates.pity.rareAt, "racha sin raro")
  end)

  t.test("la garantía de legendario nunca supera legendaryAt", function()
    local s = fakeState(20260104)
    local gap = 0
    local maxGap = 0
    for _ = 1, 50000 do
      local rarity = hatch.rollRarity(s)
      gap = gap + 1
      if rarity == "legendary" then
        maxGap = math.max(maxGap, gap)
        gap = 0
      end
    end
    t.assertLessOrEqual(maxGap, config.rates.pity.legendaryAt, "racha sin legendario")
  end)

  t.test("la garantía de mutación nunca supera mutationAt", function()
    local s = fakeState(20260105)
    local gap = 0
    local maxGap = 0
    for _ = 1, 50000 do
      local mutation = hatch.rollMutation(s)
      gap = gap + 1
      if mutation then
        maxGap = math.max(maxGap, gap)
        gap = 0
      end
    end
    t.assertLessOrEqual(maxGap, config.rates.pity.mutationAt, "racha sin mutación")
  end)

  t.test("las garantías se activan en el umbral exacto", function()
    local s = fakeState(20260106)
    s.pity.rare = config.rates.pity.rareAt - 1
    local rarity = hatch.rollRarity(s)
    t.assertTrue(hatch.rarityIndex(rarity) >= hatch.rarityIndex("rare"))
    t.assertEqual(s.pity.rare, 0)

    local s2 = fakeState(20260107)
    s2.pity.legendary = config.rates.pity.legendaryAt - 1
    local rarity2, flags2 = hatch.rollRarity(s2)
    t.assertEqual(rarity2, "legendary")
    t.assertTrue(flags2.legendary)
    t.assertEqual(s2.pity.legendary, 0)

    local s3 = fakeState(20260108)
    s3.pity.mutation = config.rates.pity.mutationAt - 1
    local mutation, guaranteed = hatch.rollMutation(s3)
    t.assertTrue(mutation ~= nil)
    t.assertTrue(guaranteed)
    t.assertEqual(s3.pity.mutation, 0)
  end)

  t.test("la mejora de suerte sube el peso de raro o superior", function()
    local low = fakeState(1, 0)
    local high = fakeState(1, 10)
    local lowWeights = hatch.effectiveWeights(low)
    local highWeights = hatch.effectiveWeights(high)
    t.assertTrue(highWeights.rare > lowWeights.rare)
    t.assertTrue(highWeights.legendary > lowWeights.legendary)
    local sum = 0
    for _, key in ipairs(config.rarityOrder) do
      sum = sum + highWeights[key]
    end
    t.assertNear(sum, 1, 1e-9, "suma normalizada")
  end)

  t.test("la elección legendaria ofrece dos especies distintas", function()
    local s = fakeState(20260109)
    for _ = 1, 1000 do
      local choices = hatch.legendaryChoices(s)
      t.assertEqual(#choices, 2)
      t.assertTrue(choices[1] ~= choices[2], "especies repetidas")
    end
  end)

  t.test("el panel de mutaciones suma la probabilidad configurada", function()
    local s = fakeState(20260110)
    local list = hatch.mutationTable(s)
    local sum = 0
    for _, entry in ipairs(list) do
      sum = sum + entry.chance
    end
    t.assertNear(sum, config.rates.mutationChance, 1e-9, "suma de mutaciones")
    t.assertEqual(#list, #config.mutationOrder)
  end)

  t.test("la instantánea de probabilidades marca las garantías", function()
    local s = fakeState(20260111)
    s.pity.rare = config.rates.pity.rareAt - 2
    s.pity.legendary = config.rates.pity.legendaryAt - 1
    s.pity.mutation = config.rates.pity.mutationAt - 1
    local snap = hatch.snapshot(s)
    t.assertTrue(snap.pity.legendaryGuaranteed)
    t.assertTrue(snap.pity.mutationGuaranteed)
    t.assertEqual(snap.pity.legendaryIn, 1)
    t.assertEqual(snap.mutationChance, 1)
  end)
end
