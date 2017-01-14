local helpers = require("spec_helper")

describe("cliargs - splat arguments", function()
  local cli

  before_each(function()
    cli = require("cliargs.core")()
  end)

  describe('defining the splat arg', function()
    it('works', function()
      assert.has_no_error(function()
        cli:splat('SPLAT', 'some repeatable arg')
      end)
    end)

    it('requires a key', function()
      assert.error_matches(function()
        cli:splat()
      end, 'Key and description are mandatory arguments')
    end)

    it('requires a description', function()
      assert.error_matches(function()
        cli:splat('SPLAT')
      end, 'Key and description are mandatory arguments')
    end)

    it('rejects multiple definitions', function()
      cli:splat('SPLAT', 'some repeatable arg')

      assert.error_matches(function()
        cli:splat('SOME_SPLAT', 'some repeatable arg')
      end, 'Only one splat')
    end)

    it('rejects repetition count less than 0', function()
      assert.error_matches(function()
        cli:splat('SOME_SPLAT', 'some repeatable arg', nil, -1)
      end, 'Maxcount must be a number equal to or greater than 0')
    end)
  end)

  describe('default value', function()
    it('allows me to define a default value', function()
      cli:splat('SPLAT', 'some repeatable arg', 'foo')
    end)

    context('when only 1 occurrence is allowed', function()
      before_each(function()
        cli:splat('SPLAT', 'some repeatable arg', 'foo', 1)
      end)

      it('uses the default value when nothing is passed in', function()
        assert.equal(helpers.parse(cli, '').SPLAT, 'foo')
      end)
    end)

    context('when more than 1 occurrence is allowed', function()
      before_each(function()
        cli:splat('SPLAT', 'some repeatable arg', 'foo', 3)
      end)

      it('uses the default value only once when nothing is passed in', function()
        assert.same(helpers.parse(cli, '').SPLAT, { 'foo' })
      end)

      it('does not use the default value if something was passed in at least once', function()
        assert.same(helpers.parse(cli, 'asdf').SPLAT, { 'asdf' })
      end)
    end)
  end)

  describe('repetition count', function()
    it('accepts a repetition count', function()
      assert.has_no_error(function()
        cli:splat('SPLAT', 'some repeatable arg', nil, 2)
      end)
    end)

    it('appends the values to a list', function()
      cli:splat('SPLAT', 'some repeatable arg', nil, 2)
      local args = helpers.parse(cli, 'a b')

      assert.equal(#args.SPLAT, 2)
      assert.equal(args.SPLAT[1], 'a')
      assert.equal(args.SPLAT[2], 'b')
    end)

    it('bails if more values were passed than acceptable', function()
      cli:splat('SPLAT', 'foobar', nil, 2)

      local _, err = helpers.parse(cli, 'a b c')
      assert.matches("bad number of arguments", err)
    end)
  end)

  context("given a splatarg as the only argument/option", function()
    it("works", function()
      cli:splat('SPLAT', 'foobar', nil, 1)

      local args = helpers.parse(cli, 'asdf')

      assert.equal(type(args.SPLAT), "string")
      assert.equal(args.SPLAT, "asdf")
    end)
  end)

  describe('@callback', function()
    it('invokes the callback every time a value for the splat arg is parsed', function()
      local call_args = {}

      cli:splat('SPLAT', 'foobar', nil, nil, function(_, value)
        table.insert(call_args, value)
      end)

      helpers.parse(cli, 'a b')

      assert.equal(#call_args, 2)
      assert.equal(call_args[1], 'a')
      assert.equal(call_args[2], 'b')
    end)
  end)
end)