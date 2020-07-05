describe("Testing cliargs library parsing commandlines", function()
  local cli

  before_each(function()
    cli = require("../src.cliargs.core")()
  end)

  -- TODO, move to feature specs
  describe("Tests argument parsing with callback", function()
    local cb = {}

    local function callback(key, value)
      cb.key, cb.value = key, value
      return true
    end

    local function callback_arg(key, value)
      table.insert(cb, { key = key, value = value })
      return true
    end

    local function callback_fail(key)
      return nil, "bad argument for " .. key
    end

    before_each(function()
      cb = {}
    end)

    it("tests one required argument", function()
      cli:argument("ARG", "arg description", callback)
      local expected = { ARG = "arg_val" }
      local result = cli:parse({ "arg_val" })
      assert.are.same(expected, result)
      assert.are.equal("ARG", cb.key)
      assert.are.equal("arg_val", cb.value)
    end)

    it("tests required argument callback returning error", function()
      cli:argument("ARG", "arg description", callback_fail)

      local _, err = cli:parse({ "arg_val" })
      assert.matches('bad argument for ARG', err)
    end)

    it("tests many required arguments", function()
      cli:argument("ARG1", "arg1 description", callback_arg)
      cli:argument("ARG2", "arg2 description", callback_arg)
      cli:argument("ARG3", "arg3 description", callback_arg)
      local expected = { ARG1 = "arg1_val", ARG2 = "arg2_val", ARG3 = "arg3_val" }
      local result = cli:parse({ "arg1_val", "arg2_val", "arg3_val" })
      assert.are.same(expected, result)
      assert.are.same({ key = "ARG1", value = "arg1_val"}, cb[1])
      assert.are.same({ key = "ARG2", value = "arg2_val"}, cb[2])
      assert.are.same({ key = "ARG3", value = "arg3_val"}, cb[3])
    end)

    it("tests one optional argument", function()
      cli:splat("OPTARG", "optional arg description", nil, 1, callback)
      local expected = { OPTARG = "opt_arg" }
      local result = cli:parse({ "opt_arg" })
      assert.are.same(expected, result)
      assert.are.equal("OPTARG", cb.key)
      assert.are.equal("opt_arg", cb.value)
    end)

    it("tests optional argument callback returning error", function()
      cli:set_name('myapp')
      cli:splat("OPTARG", "optinoal arg description", nil, 1, callback_fail)

      local _, err = cli:parse({ "opt_arg" })
      assert.matches('bad argument for OPTARG', err)
    end)

    it("tests many optional arguments", function()
      cli:splat("OPTARG", "optional arg description", nil, 3, callback_arg)
      local expected = { OPTARG = { "opt_arg1", "opt_arg2", "opt_arg3" } }
      local result = cli:parse({ "opt_arg1", "opt_arg2", "opt_arg3" })
      assert.are.same(expected, result)
      assert.are.same({ key = "OPTARG", value = "opt_arg1"}, cb[1])
      assert.are.same({ key = "OPTARG", value = "opt_arg2"}, cb[2])
      assert.are.same({ key = "OPTARG", value = "opt_arg3"}, cb[3])
    end)
  end)
end)
