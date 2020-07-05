local helpers = require("spec_helper")

describe("cliargs - arguments", function()
  local cli

  before_each(function()
    cli = require("../src.cliargs.core")()
  end)

  describe('defining arguments', function()
    it('works', function()
      assert.has_no_errors(function()
        cli:argument('PATH', 'path to a file')
      end)
    end)

    it('requires a key', function()
      assert.error_matches(function()
        cli:argument()
      end, 'Key and description are mandatory arguments')
    end)

    it('requires a description', function()
      assert.error_matches(function()
        cli:argument('PATH')
      end, 'Key and description are mandatory arguments')
    end)

    it('rejects a bad callback', function()
      assert.error_matches(function()
        cli:argument('PATH', 'path to a file', 'lolol')
      end, 'Callback argument must be a function')
    end)

    it('rejects duplicate arguments', function()
      cli:argument('PATH', 'path to a file')

      assert.error_matches(function()
        cli:argument('PATH', '...')
      end, 'Duplicate argument')
    end)
  end)

  describe('parsing arguments', function()
    it('works with a single argument', function()
      cli:argument('PATH', 'path to a file')

      local args = helpers.parse(cli, '/some/where')

      assert.equal(args.PATH, '/some/where')
    end)

    it('works with multiple arguments', function()
      cli:argument('INPUT', 'path to the input file')
      cli:argument('OUTPUT', 'path to the output file')

      local args = helpers.parse(cli, '/some/where /some/where/else')

      assert.equal(args.INPUT, '/some/where')
      assert.equal(args.OUTPUT, '/some/where/else')
    end)

    it('bails on missing arguments', function()
      cli:argument('INPUT', 'path to the input file')
      cli:argument('OUTPUT', 'path to the output file')

      local _, err = helpers.parse(cli, '/some/where')
      assert.matches('bad number of arguments', err)
    end)

    it('bails on too many arguments', function()
      cli:argument('INPUT', 'path to the input file')

      local _, err = helpers.parse(cli, 'foo bar')

      assert.matches('bad number of arguments', err)
    end)
  end)

  describe('@callback', function()
    local call_args
    local function capture(key, value, altkey)
      table.insert(call_args, { key, value, altkey })
    end

    before_each(function()
      call_args = {}
    end)

    context('given a single argument', function()
      before_each(function()
        cli:argument('PATH', 'path to a file', capture)
      end)

      it('invokes the callback when the argument is parsed', function()
        helpers.parse(cli, '/some/where')

        assert.equal(call_args[1][1], 'PATH')
        assert.equal(call_args[1][2], '/some/where')
        assert.equal(call_args[1][3], nil)
      end)
    end)

    context('given multiple arguments', function()
      before_each(function()
        cli:argument('INPUT', '...', capture)
        cli:argument('OUTPUT', '...', capture)
      end)

      it('invokes the callback for each argument parsed', function()
        helpers.parse(cli, '/some/where /some/where/else')

        assert.equal(call_args[1][1], 'INPUT')
        assert.equal(call_args[1][2], '/some/where')
        assert.equal(call_args[2][1], 'OUTPUT')
        assert.equal(call_args[2][2], '/some/where/else')
      end)
    end)
  end)
end)