local subject = require('../src.cliargs.utils.wordwrap')

describe("utils::wordwrap", function()
  it("should work", function()
    -- takes: text, size, padding
    local text = "123456789 123456789 123456789!"
    local expected, result

    result = subject(text, 10)
    expected = { "123456789", "123456789", "123456789!" }
    assert.is.same(result, expected)

    -- exact length + 1 overflow
    result = subject(text, 9)
    expected = { "123456789", "123456789", "123456789", "!" }
    assert.is.same(result, expected)

    result = subject(text, 9, true)
    expected = { "123456789", "123456789", "123456789!" }
    assert.is.same(result, expected)

    result = subject(text, 8)
    expected = { "12345678", "9", "12345678", "9", "12345678", "9!" }
    assert.is.same(result, expected)
  end)
end)
