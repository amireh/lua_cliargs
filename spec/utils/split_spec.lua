local subject = require('../src.cliargs.utils.split')

describe("utils::split", function()
  it("should work", function()
    -- takes: str, split-char
    local expected, result

    result = subject("hello,world",",")
    expected = {"hello", "world"}
    assert.is.same(result, expected)

    result = subject("hello,world,",",")
    expected = {"hello", "world"}
    assert.is.same(result, expected)

    result = subject("hello",",")
    expected = {"hello"}
    assert.is.same(result, expected)

    result = subject("",",")
    expected = {}
    assert.is.same(result, expected)
  end)
end)
