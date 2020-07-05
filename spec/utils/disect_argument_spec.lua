local disect_argument = require('../src.cliargs.utils.disect_argument')

require("spec_helper")

describe("utils::disect_argument", function()
  local function assert_disect(pattern, expected)
    it("works with '" .. pattern .. "'", function()
      local symbol, key, value, negated = disect_argument(pattern)

      assert.equal(symbol, expected[1])
      assert.equal(key, expected[2])
      assert.equal(value, expected[3])
      assert.equal(negated, expected[4])
    end)
  end

  -- flags
  assert_disect("", { nil, nil, nil, false })
  assert_disect("-q", { '-', 'q', nil, false })
  assert_disect("--quiet", { '--', 'quiet', nil, false })

  -- -- -- -- flag negation
  assert_disect("--no-quiet", { '--', 'quiet', nil, true })
  assert_disect("--no-q", { '--', 'q', nil, true })

  -- -- options
  assert_disect("-v=VALUE", { '-', 'v', 'VALUE', false })
  assert_disect("--value=VALUE", { '--', 'value', 'VALUE', false })
  assert_disect('--value=with whitespace', { '--', 'value', 'with whitespace', false })

  -- -- end-of-options indicator
  assert_disect('--', { '--', nil, nil, false })

  -- -- values
  assert_disect('value', { nil, nil, 'value', false })
  assert_disect('/path/to/something', { nil, nil, '/path/to/something', false })
  assert_disect('oops-look-at--me', { nil, nil, 'oops-look-at--me', false })
end)
