local helpers = require 'spec_helper'
local trim = helpers.trim

describe('printer', function()
  local cli

  before_each(function()
    cli = require("../src.cliargs.core")()
  end)

  describe('#generate_usage', function()
    local function assert_msg(expected_msg)
      local actual_msg = cli.printer.generate_usage()

      assert.equal(trim(expected_msg), trim(actual_msg))
    end

    it('works with 0 arguments', function()
      assert_msg 'Usage:'
    end)

    it('works with 1 argument', function()
      cli:argument('INPUT', 'path to the input file')

      assert_msg [==[
        Usage: [--] INPUT
      ]==]
    end)

    it('works with 2+ arguments', function()
      cli:argument('INPUT', '...')
      cli:argument('OUTPUT', '...')

      assert_msg [==[
        Usage: [--] INPUT OUTPUT
      ]==]
    end)

    it('prints the app name', function()
      cli:set_name('foo')
      assert_msg 'Usage: foo'
    end)

    it('prints options', function()
      cli:option('--foo=VALUE', '...')

      assert_msg [==[
        Usage: [OPTIONS]
      ]==]
    end)

    it('prints flags', function()
      cli:flag('--foo', '...')

      assert_msg [==[
        Usage: [OPTIONS]
      ]==]
    end)

    it('prints a splat arg with reptitions == 1', function()
      cli:splat('OUTPUT', '...', nil, 1)

      assert_msg [==[
        Usage: [--] [OUTPUT]
      ]==]
    end)

    it('prints a splat arg with reptitions == 2', function()
      cli:splat('OUTPUT', '...', nil, 2)

      assert_msg [==[
        Usage: [--] [OUTPUT-1 [OUTPUT-2]]
      ]==]
    end)

    it('prints a splat arg with reptitions > 2', function()
      cli:splat('OUTPUT', '...', nil, 5)

      assert_msg [==[
        Usage: [--] [OUTPUT-1 [OUTPUT-2 [...]]]
      ]==]
    end)
  end)

  describe('#generate_help', function()
    local function assert_msg(expected_msg)
      local actual_msg = cli.printer.generate_help()

      assert.equal(trim(expected_msg), trim(actual_msg))
    end

    it('works with nothing', function()
      assert_msg ''
    end)

    it('works with 1 argument', function()
      cli:argument('INPUT', 'path to the input file')

      assert_msg [==[
        ARGUMENTS:
          INPUT path to the input file (required)
      ]==]
    end)

    it('works with 2+ arguments', function()
      cli:argument('INPUT', 'path to the input file')
      cli:argument('OUTPUT', 'path to the output file')

      assert_msg [==[
        ARGUMENTS:
          INPUT  path to the input file (required)
          OUTPUT path to the output file (required)
      ]==]
    end)

    it('works with 1 option', function()
      cli:option('--compress=VALUE', 'compression algorithm to use')

      assert_msg [==[
        OPTIONS:
          --compress=VALUE compression algorithm to use
      ]==]
    end)

    it("prints an option's default value", function()
      cli:option('--compress=VALUE', 'compression algorithm to use', 'lzma')

      assert_msg [==[
        OPTIONS:
          --compress=VALUE compression algorithm to use (default: lzma)
      ]==]
    end)

    it("prints a repeatable option", function()
      cli:option('--compress=VALUE', 'compression algorithm to use', { 'lzma' })

      assert_msg [==[
        OPTIONS:
          --compress=VALUE compression algorithm to use (default: [])
      ]==]
    end)

    it('works with many options', function()
      cli:option('--compress=VALUE', 'compression algorithm to use')
      cli:option('-u, --url=URL', '...')

      assert_msg [==[
        OPTIONS:
          --compress=VALUE compression algorithm to use
          -u, --url=URL    ...
      ]==]
    end)

    context('given a flag', function()
      it('prints it under OPTIONS', function()
        cli:flag('-q, --quiet', '...')

        assert_msg [==[
          OPTIONS:
            -q, --quiet ...
        ]==]
      end)
    end)

    context('given a flag with a default value but is not negatable', function()
      it('does not print "on" or "off"', function()
        cli:flag('--quiet', '...', true)

        assert_msg [==[
          OPTIONS:
            --quiet ...
        ]==]
      end)
    end)

    context('given a negatable flag', function()
      it('prints it along with its default value', function()
        cli:flag('--[no-]quiet', '...', true)
        cli:flag('--[no-]debug', '...', false)

        assert_msg [==[
          OPTIONS:
            --[no-]quiet ... (default: on)
            --[no-]debug ... (default: off)
        ]==]
      end)
    end)

    context('given a splat arg', function()
      it('prints it with a repetition of 1', function()
        cli:splat("INPUTS", "directories to read from")
        assert_msg [==[
          ARGUMENTS:
            INPUTS directories to read from (optional)
        ]==]
      end)

      it('prints it with a repetition of > 1', function()
        cli:splat("INPUTS", "directories to read from", nil, 3)
        assert_msg [==[
          ARGUMENTS:
            INPUTS directories to read from (optional)
        ]==]
      end)

      it('prints it without a default value', function()
        cli:splat("INPUTS", "directories to read from")
        assert_msg [==[
          ARGUMENTS:
            INPUTS directories to read from (optional)
        ]==]
      end)

      it('prints it with a default value', function()
        cli:splat("INPUTS", "directories to read from", 'foo')
        assert_msg [==[
          ARGUMENTS:
            INPUTS directories to read from (optional, default: foo)
        ]==]
      end)
    end)
  end)

  describe('#dump_internal_state', function()
    local original_arg

    before_each(function()
      original_arg = _G['arg']
      _G['arg'] = { 'spec/printer_spec.lua' }
    end)

    after_each(function()
      _G['arg'] = original_arg
    end)

    it('works', function()
      cli:argument('OUTPUT', '...')
      cli:splat('INPUTS', '...', nil, 100)
      cli:option('-c, --compress=VALUE', '...')
      cli:flag('-q, --quiet', '...', true)

      assert.equal(trim [==[
        ======= Provided command line =============

        Number of arguments:
          1 = 'spec/printer_spec.lua'

        ======= Parsed command line ===============

        Arguments:
          OUTPUT                 => 'nil'

        Optional arguments:INPUTS; allowed are 100 arguments

        Optional parameters:
          -c, --compress=VALUE   => nil (nil)
          -q, --quiet            => nil (nil)

        ===========================================
      ]==], trim(cli.printer.dump_internal_state({})))
    end)

    it('does not fail with an optarg of 1 reptitions', function()
      cli:splat('INPUTS', '...', nil, 1)
      cli.printer.dump_internal_state({})
    end)

    it('does not fail with an optarg of many reptitions', function()
      cli:splat('INPUTS', '...', nil, 5)
      cli.printer.dump_internal_state({})
    end)
  end)
end)