local helpers = require("spec_helper")

describe("cliargs - options", function()
  local cli

  before_each(function()
    cli = require("../src.cliargs.core")()
  end)

  describe('defining options', function()
    it('requires a key', function()
      assert.error_matches(function()
        cli:option()
      end, 'Key and description are mandatory arguments')
    end)

    it('requires a description', function()
      assert.error_matches(function()
        cli:option('--url=URL')
      end, 'Key and description are mandatory arguments')
    end)

    it('works', function()
      assert.has_no_errors(function()
        cli:option('--url=URL', '...')
      end)
    end)

    it('rejects a duplicate option', function()
      cli:option('--url=URL', '...')

      assert.error_matches(function()
        cli:option('--url=URL', '...')
      end, 'Duplicate')
    end)
  end)

  it('works with only a short key: -u VALUE', function()
    cli:option('-u VALUE', '...')
    assert.equal(helpers.parse(cli, '-u something').u, 'something')
  end)

  it('works with only an expanded key: --url=VALUE', function()
    cli:option('--url=VALUE', '...')
    assert.equal(helpers.parse(cli, '--url=something').url, 'something')
  end)

  it('works with only an expanded key using space as a delimiter: --url VALUE', function()
    cli:option('--url VALUE', '...')
    assert.equal(helpers.parse(cli, '--url something').url, 'something')
  end)

  it('works with both: -u, --url=VALUE', function()
    cli:option('-u, --url=VALUE', '...')
    assert.equal(helpers.parse(cli, '--url=something').url, 'something')
    assert.equal(helpers.parse(cli, '-u=something').url, 'something')
  end)

  it('works with both keys and no comma between them: -u --url VALUE', function()
    cli:option('-u --url=VALUE', '...')
    assert.equal(helpers.parse(cli, '--url something').url, 'something')
    assert.equal(helpers.parse(cli, '-u    something').url, 'something')
  end)

  context('given no value indicator (an implicit flag, e.g. --quiet)', function()
    it('proxies to #flag', function()
      stub(cli, 'flag')

      cli:option('-q', '...')

      assert.stub(cli.flag).was.called();
    end)
  end)

  describe('parsing', function()
    before_each(function()
      cli:option('-s, --source=SOURCE', '...')
    end)

    context('using a -short key and space as a delimiter', function()
      it('works', function()
        local args = helpers.parse(cli, '-s /foo/**/*.lua')
        assert.equal(args.source, '/foo/**/*.lua')
      end)
    end)

    context('using a -short key and = as a delimiter', function()
      it('works', function()
        local args = helpers.parse(cli, '-s=/foo/**/*.lua')
        assert.equal(args.source, '/foo/**/*.lua')
      end)
    end)

    context('using an --expanded-key and space as a delimiter', function()
      it('works', function()
        local args = helpers.parse(cli, '--source /foo/**/*.lua')
        assert.equal(args.source, '/foo/**/*.lua')
      end)
    end)

    context('using an --expanded-key and = as a delimiter', function()
      it('works', function()
        local args = helpers.parse(cli, '--source=/foo/**/*.lua')
        assert.equal(args.source, '/foo/**/*.lua')
      end)
    end)

    context('for an option with a short key longer than 1 char', function()
      before_each(function()
        cli:option('-Xassembler OPTIONS', '...')
      end)

      it('works', function()
        local args = helpers.parse(cli, '-Xassembler foo')
        assert.equal(args.Xassembler, 'foo')
      end)
    end)

    context('given multiple values', function()
      before_each(function()
        cli:option('-k, --key=OPTIONS', '...', {})
      end)

      it('works', function()
        local args = helpers.parse(cli, '-k 1 --key=3 -k asdf')

        assert.equal(type(args.k), 'table')
        assert.equal(#args.k, 3)
        assert.equal(args.k[1], '1')
        assert.equal(args.k[2], '3')
        assert.equal(args.k[3], 'asdf')
      end)
    end)

    context('given an unknown option', function()
      it('bails', function()
        local _, err = helpers.parse(cli, '--asdf=jkl;', true)
        assert.matches('unknown', err)
      end)
    end)

    it('bails if no value was passed', function()
      local _, err = helpers.parse(cli, '-s')
      assert.matches("option %-s requires a value to be set", err)
    end)
  end)

  describe('parsing with a default value', function()
    it('accepts a nil', function()
      cli:option('--compress=VALUE', '...', nil)
      assert.equal(helpers.parse(cli, '').compress, nil)
    end)

    it('accepts a string', function()
      cli:option('--compress=VALUE', '...', 'lzma')
      assert.equal(helpers.parse(cli, '').compress, 'lzma')
    end)

    it('accepts a number', function()
      cli:option('--count=VALUE', '...', 5)
      assert.equal(helpers.parse(cli, '').count, 5)
    end)

    it('accepts a boolean', function()
      cli:option('--quiet=VALUE', '...', true)
      assert.equal(helpers.parse(cli, '').quiet, true)
    end)

    it('accepts an empty table', function()
      cli:option('--sources=VALUE', '...', {})
      assert.same(helpers.parse(cli, '').sources, {})
    end)

    it('lets me override/reset the default value', function()
      cli:option('--compress=URL', '...', 'lzma')
      assert.equal(helpers.parse(cli, '--compress=').compress, nil)
    end)
  end)

  describe('@callback', function()
    local call_args
    local function capture(key, value, altkey)
      table.insert(call_args, { key, value, altkey })
    end

    context('given a single option', function()
      before_each(function()
        call_args = {}

        cli:option('-c, --compress=VALUE', '...', nil, capture)
      end)

      it('invokes the callback when the option is parsed', function()
        helpers.parse(cli, '--compress=lzma')

        assert.equal(call_args[1][1], 'compress')
        assert.equal(call_args[1][2], 'lzma')
        assert.equal(call_args[1][3], 'c')
      end)

      it('invokes the callback with the latest value when the option is a list', function()
        cli:option('--tags=VALUE', '...', {}, capture)

        helpers.parse(cli, '--tags only --tags foo')

        assert.equal(call_args[1][1], 'tags')
        assert.equal(call_args[1][2], 'only')
        assert.equal(call_args[1][3], nil)

        assert.equal(call_args[2][1], 'tags')
        assert.equal(call_args[2][2], 'foo')
        assert.equal(call_args[2][3], nil)
      end)
    end)

    context('when the callback returns an error message', function()
      it('propagates the error', function()
        cli:option('-c, --compress=VALUE', '...', nil, function()
          return nil, ">>> bad argument <<<"
        end)

        local _, err = helpers.parse(cli, '-c lzma', true)
        assert.equal('>>> bad argument <<<', err)
      end)
    end)

    context('given multiple options', function()
      before_each(function()
        call_args = {}

        cli:option('-c, --compress=VALUE', '...', nil, capture)
        cli:option('--input=PATH', '...', nil, capture)
      end)

      it('invokes the callback for each option parsed', function()
        helpers.parse(cli, '-c lzma --input=/tmp')

        assert.equal(call_args[1][1], 'c')
        assert.equal(call_args[1][2], 'lzma')
        assert.equal(call_args[1][3], 'compress')

        assert.equal(call_args[2][1], 'input')
        assert.equal(call_args[2][2], '/tmp')
        assert.equal(call_args[2][3], nil)
      end)
    end)
  end)
end)