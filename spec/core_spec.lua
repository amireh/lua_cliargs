local helpers = require "spec_helper"

describe("cliargs::core", function()
  local cli

  before_each(function()
    cli = require("cliargs.core")()
  end)

  describe('#parse', function()
    context('when invoked without the arguments table', function()
      local global_arg

      before_each(function()
        global_arg = _G['arg']
      end)

      after_each(function()
        _G['arg'] = global_arg
      end)

      it('uses the global _G["arg"] one', function()
        _G["arg"] = {"--quiet"}

        cli:option('--quiet', '...')

        assert.equal(cli:parse().quiet, true)
      end)
    end)

    it('does not mutate the argument table', function()
      local arguments = { "--quiet" }
      cli:option('--quiet', '...')

      cli:parse(arguments)

      assert.equal(#arguments, 1)
      assert.equal(arguments[1], "--quiet")
    end)

    it("generates the help listing but does not print it to STDOUT", function()
      local res, err = cli:parse({'--help'})

      assert.equal(type(res), "nil")
      assert.equal(type(err), "string")
    end)

    it("returns error strings but does not print them to STDOUT", function()
      local res, err = cli:parse({ "arg1" })

      assert.equal(type(res), "nil")
      assert.equal(type(err), "string")
    end)

    describe('displaying the help listing', function()
      local res, err

      before_each(function()
        cli:argument('INPUT', '...')
        cli:flag('--quiet', '...')
      end)

      after_each(function()
        assert.equal(type(res), "nil")
        assert.equal(type(err), "string")
        assert.equal(err, cli.printer.generate_help_and_usage())
      end)

      it('works with --help in the beginning', function()
        res, err = helpers.parse(cli, '--help something')
      end)

      it('works with --help in the end of options', function()
        res, err = helpers.parse(cli, '--quiet --help something')
      end)

      it('works with --help after an argument', function()
        res, err = helpers.parse(cli, '--quiet something --help')
      end)
    end)
  end)

  describe('#parse - the --__DUMP__ special option', function()
    it('dumps the state and errors out', function()
      stub(cli.printer, 'print')

      cli:argument('OUTPUT', '...')
      cli:splat('INPUTS', '...', nil, 5)
      cli:option('-c, --compress=VALUE', '...')
      cli:flag('-q, --quiet', '...', true)

      local _, err = cli:parse({'--__DUMP__', '/tmp/out', '/tmp/in.1', '/tmp/in.2', '/tmp/in.3' })

      assert.matches('======= Provided command line =============', err)
    end)
  end)

  describe('#redefine_default', function()
    it('allows me to change the default for an optargument', function()
      cli:splat('ROOT', '...', 'foo', 1)
      assert.equal(cli:parse({}).ROOT, 'foo')

      cli:redefine_default('ROOT', 'bar')
      assert.equal(cli:parse({}).ROOT, 'bar')
    end)

    it('allows me to change the default for an option', function()
      cli:option('-c, --compress=VALUE', '...', 'lzma')
      assert.equal(cli:parse({}).compress, 'lzma')

      cli:redefine_default('compress', 'bz2')
      assert.equal(cli:parse({}).compress, 'bz2')
    end)

    it('allows me to change the default for a flag', function()
      cli:flag('-q, --quiet', '...', false)
      assert.equal(cli:parse({}).quiet, false)

      cli:redefine_default('quiet', true)
      assert.equal(cli:parse({}).quiet, true)
    end)
  end)

  describe('#load_defaults', function()
    local args, err

    before_each(function()
      cli:option('-c, --compress=VALUE', '...', 'lzma')
      cli:flag('-q, --quiet', '...', false)
    end)

    it('works', function()
      cli:load_defaults({
        compress = 'bz2',
        quiet = true
      })

      args, err = cli:parse({})

      assert.equal(err, nil)
      assert.same(args, {
        c = 'bz2',
        compress = 'bz2',
        q = true,
        quiet = true
      })
    end)

    context('when @strict is not true', function()
      it('ignores keys that could not be mapped', function()
        cli:load_defaults({
          compress = 'bz2',
          quiet = true,
          what = 'woot!'
        })

        args, err = cli:parse({})

        assert.equal(err, nil)
        assert.same(args, {
          c = 'bz2',
          compress = 'bz2',
          q = true,
          quiet = true
        })
      end)
    end)

    context('when @strict is true', function()
      it('returns an error message if a key could not be mapped', function()
        args, err = cli:load_defaults({
          what = 'woot!'
        }, true)

        assert.equal(args, nil)
        assert.equal(err, "Unrecognized option with the key 'what'")
      end)
    end)
  end)
end)