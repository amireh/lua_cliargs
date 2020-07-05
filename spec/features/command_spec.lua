describe("cliargs - commands", function()
  local cli

  before_each(function()
    cli = require("../src.cliargs.core")()
  end)

  describe('defining commands', function()
    it('works', function()
      assert.has_no_errors(function()
        cli:command('run', '...')
      end)
    end)
  end)

  describe('running commands', function()
    context('given an action callback', function()
      local cmd
      local action

      before_each(function()
        action = stub()

        cmd = cli:command('run', '...')
        cmd:action(action)
      end)

      it('works with no arguments', function()
        cli:parse({'run'})
      end)

      it('runs the command parser and passes on the args to the command', function()
        cmd:argument('ROOT', '...')

        cli:parse({'run', '/some/path'})

        assert.stub(action).called_with({ ROOT ='/some/path' })
      end)

      it('propagates parsing errors', function()
        local _, err = cli:parse({'run', 'some_undefined_arg'})

        assert.match("bad number of arguments", err)
      end)
    end)

    context('given a command file', function()
      local cmd

      before_each(function()
        cmd = cli:command('run', '...')
        cmd:file('spec/fixtures/test-command.lua')
      end)

      it('works with no arguments', function()
        cli:parse({'run'})
      end)

      it('returns an error on bad file', function()
        cmd:file('foo')

        assert.error_matches(function()
          cli:parse({'run'})
        end, 'cannot open foo');
      end)

      it('passes on arguments to the command', function()
        cmd:argument('ROOT', '...')

        local res, err = cli:parse({'run', '/some/path'})

        assert.equal(nil, err);
        assert.equal(res.ROOT, '/some/path')
      end)

      it('propagates parsing errors', function()
        cmd:argument('ROOT', '...')

        local res, err = cli:parse({'run', '/some/path', 'foo'})

        assert.equal(nil, res);
        assert.match('bad number of arguments', err)
      end)
    end)
  end)
end)