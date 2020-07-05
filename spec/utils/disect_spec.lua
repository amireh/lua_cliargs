local disect = require('../src.cliargs.utils.disect')

describe("utils::disect", function()
  local function assert_disect(pattern, expected)
    it("works with '" .. pattern .. "'", function()
      local k, ek, v = disect(pattern)

      assert.equal(k, expected[1])
      assert.equal(ek, expected[2])
      assert.equal(v, expected[3])
    end)
  end

  assert_disect("-q", { 'q', nil, nil })
  assert_disect("-Wno-unsigned", { 'Wno-unsigned', nil, nil })
  assert_disect("-q, --quiet", { 'q', 'quiet', nil })
  assert_disect("-q --quiet", { 'q', 'quiet', nil })

  -- now with value indicators
  assert_disect("-v VALUE", { 'v', nil, 'VALUE' })
  assert_disect("-v=VALUE", { 'v', nil, 'VALUE' })

  assert_disect("--value VALUE", { nil, 'value', 'VALUE' })
  assert_disect("--value=VALUE", { nil, 'value', 'VALUE' })

  assert_disect("-v --value=VALUE", { 'v', 'value', 'VALUE' })
  assert_disect("-v --value VALUE", { 'v', 'value', 'VALUE' })
  assert_disect("-v, --value=VALUE", { 'v', 'value', 'VALUE' })
  assert_disect("-v, --value VALUE", { 'v', 'value', 'VALUE' })
end)
