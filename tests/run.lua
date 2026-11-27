package.path = "./?.lua;./?/init.lua;" .. package.path

local harness = require("tests.harness")

local suites = {
  "tests.test_rng",
  "tests.test_genetics",
  "tests.test_hatch",
  "tests.test_economy",
  "tests.test_save",
  "tests.test_state",
  "tests.test_progression",
  "tests.test_sprites",
  "tests.test_animations",
}

for _, suite in ipairs(suites) do
  io.write("\n" .. suite .. "\n")
  require(suite)(harness)
end

harness.run()
