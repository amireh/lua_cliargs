local helpers = require "spec_helper"

describe("integration: parsing", function()
  local cli

  before_each(function()
    cli = require("../src.cliargs.core")()
  end)

  it('is a no-op when no arguments or options are defined', function()
    assert.are.same(helpers.parse(cli, ''), {})
  end)

  context('given a set of arguments', function()
    it('works when all are passed in', function()
      cli:argument('FOO', '...')
      cli:argument('BAR', '...')

      local args = helpers.parse(cli, 'foo bar')

      assert.same(args, { FOO = "foo", BAR = "bar" })
    end)
  end)

  context('given an argument and a splat', function()
    before_each(function()
      cli:argument('FOO', '...')
      cli:splat('BAR', '...', nil, 2)
    end)

    it('works when only the argument is passed in', function()
      local args = helpers.parse(cli, 'foo')

      assert.same(args, { FOO = "foo", BAR = {} })
    end)

    it('works when both are passed in', function()
      local args = helpers.parse(cli, 'foo bar')

      assert.same(args, { FOO = "foo", BAR = { "bar" } })
    end)

    it('works when both are passed in with repetition for the splat', function()
      local args = helpers.parse(cli, 'foo bar zoo')

      assert.same(args, { FOO = "foo", BAR = { "bar", "zoo" } })
    end)
  end)

  context('given a set of options', function()
    it('works when nothing is passed in', function()
      cli:option('--foo FOO', '...')
      cli:option('--bar BAR', '...')

      local args = helpers.parse(cli, '')

      assert.same(args, {})
    end)

    it('works when they are passed in', function()
      cli:option('-f, --foo FOO', '...')
      cli:option('--bar BAR', '...')

      local args = helpers.parse(cli, '-f something --bar=BAZ')

      assert.same(args, {
        f = "something",
        foo = "something",
        bar = "BAZ"
      })
    end)
  end)

  context('given arguments, options, and flags', function()
    before_each(function()
      cli:argument('FOO', '...')
      cli:option('--input=SOURCE', '...')
      cli:flag('--quiet', '...')
    end)

    it('works when nothing but arguments are passed in', function()
      local args = helpers.parse(cli, 'asdf')

      assert.same(args, {
        FOO = 'asdf',
        input = nil,
        quiet = nil
      })
    end)

    it('works when arguments and options are passed in', function()
      local args = helpers.parse(cli, '--input /tmp/file asdf')

      assert.same(args, {
        FOO = 'asdf',
        input = '/tmp/file',
        quiet = nil
      })
    end)

    it('works when everything is passed in', function()
      local args = helpers.parse(cli, '--input /tmp/file --quiet asdf')

      assert.same(args, {
        FOO = 'asdf',
        input = '/tmp/file',
        quiet = true
      })
    end)

    it('works when an option comes after an argument', function()
      local args, err = helpers.parse(cli, 'asdf --quiet')

      assert.equal(err, nil)
      assert.same(args, {
        FOO = 'asdf',
        quiet = true
      })
    end)
  end)

  describe('using -- to separate options from arguments', function()
    before_each(function()
      cli:argument('INPUT', '...')
      cli:splat('OUTPUT', '...', nil, 1)
      cli:flag('--verbose', '...')
      cli:flag('--quiet', '...')
    end)

    it('works', function()
      local args = helpers.parse(cli, '--verbose -- --input -d')

      assert.same(args, {
        INPUT = "--input",
        OUTPUT = "-d",
        verbose = true,
        quiet = nil
      })
    end)

    it('does not actually parse an option if it comes after --', function()
      local args = helpers.parse(cli, '-- --input --quiet')

      assert.same(args, {
        INPUT = "--input",
        OUTPUT = "--quiet",
        verbose = nil,
        quiet = nil
      })
    end)
  end)
end)