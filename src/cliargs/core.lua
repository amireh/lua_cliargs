local _

-- ------- --
-- Helpers --
-- ------- --

local disect = require('cliargs.utils.disect')
local printer = require('cliargs.printer')

local function is_callable(fn)
  return type(fn) == "function" or (getmetatable(fn) or {}).__call
end

-- Used internally to lookup an entry using either its short or expanded keys
local function lookup(_cli, k, ek, argtable)
  local t = argtable or _cli.optional

  for _,entry in ipairs(t) do
    if k  and entry.key == k then
      return entry
    end

    if ek and entry.expanded_key == ek then
      return entry
    end

    if entry.has_no_flag then
      if ek and ("no-"..entry.expanded_key) == ek then return entry end
    end
  end

  return nil
end

-- -------- --
-- CLI Main --
-- -------- --
return function()
  local cli = {}
  local data = {
    name = "",
    description = "",
    required = {},
    optional = {},
    optargument = {maxcount = 0},
    colsz = { 0, 0 }, -- column width, help text. Set to 0 for auto detect
  }

  local function on_error(msg, noprint)
    local full_msg = data.name .. ": error: " .. msg .. '; re-run with --help for usage.'

    if not noprint then
      print(full_msg)
    end

    return nil, full_msg
  end

  -- Used internally to add an option
  local function really_add_option(_cli, k, expanded_key, v, label, desc, default, callback)
    local flag = (v == nil) -- no value, so it's a flag
    local has_no_flag = flag and (expanded_key and expanded_key:find('^%[no%-]') ~= nil)
    local ek = has_no_flag and expanded_key:sub(6) or expanded_key

    -- guard against duplicates
    if lookup(_cli, k, ek) then
      error("Duplicate option: " .. (k or ek) .. ", please rename one of them.")
    end

    if has_no_flag and lookup(_cli, nil, "no-"..ek) then
      error("Duplicate option: " .. ("no-"..ek) .. ", please rename one of them.")
    end

    -- below description of full entry record, nils included for reference
    local entry = {
      key = k,
      expanded_key = ek,
      desc = desc,
      default = default,
      label = label,
      flag = flag,
      has_no_flag = has_no_flag,
      value = default,
      callback = callback,
    }

    table.insert(_cli.optional, entry)
  end

  -- ------------------------------------------------------------------------ --
  -- PUBLIC API
  -- ------------------------------------------------------------------------ --

  --- Assigns the name of the program which will be used for logging.
  function cli:set_name(name)
    data.name = name
  end

  --- Write down a brief, 1-liner description of what the program does.
  function cli:set_description(description)
    data.description = description
  end

  --- Defines a required argument.
  --- Required arguments have no special notation and are order-sensitive.
  --- *Note:* the value will be stored in `args[@key]`.
  --- *Aliases: `add_argument`*
  ---
  --- ### Parameters
  --- 1. **key**: the argument's "name" that will be displayed to the user
  --- 2. **desc**: a description of the argument
  --- 3. **callback**: *optional*; specify a function to call when this argument is parsed (the default is nil)
  ---
  --- ### Usage example
  --- The following will parse the argument (if specified) and set its value in `args["root"]`:
  --- `cli:add_arg("root", "path to where root scripts can be found")`
  function cli:add_argument(key, desc, callback)
    assert(type(key) == "string" and type(desc) == "string", "Key and description are mandatory arguments (Strings)")
    assert(is_callable(callback) or callback == nil, "Callback argument: expected a function or nil")

    if lookup(data, key, nil, data.required) then
      error("Duplicate argument: " .. key .. ", please rename one of them.")
    end

    table.insert(data.required, { key = key, desc = desc, value = nil, callback = callback })
  end

  --- Defines an optional argument (or more than one).
  --- There can be only 1 optional argument, and it has to be the last one on the argumentlist.
  --- *Note:* the value will be stored in `args[@key]`. The value will be a 'string' if 'maxcount == 1',
  --- or a table if 'maxcount > 1'
  ---
  --- ### Parameters
  --- 1. **key**: the argument's "name" that will be displayed to the user
  --- 2. **desc**: a description of the argument
  --- 3. **default**: *optional*; specify a default value (the default is nil)
  --- 4. **maxcount**: *optional*; specify the maximum number of occurences allowed (default is 1)
  --- 5. **callback**: *optional*; specify a function to call when this argument is parsed (the default is nil)
  ---
  --- ### Usage example
  --- The following will parse the argument (if specified) and set its value in `args["root"]`:
  --- `cli:add_arg("root", "path to where root scripts can be found", "", 2)`
  --- The value returned will be a table with at least 1 entry and a maximum of 2 entries
  function cli:optarg(key, desc, default, maxcount, callback)
    assert(type(key) == "string" and type(desc) == "string", "Key and description are mandatory arguments (Strings)")
    assert(type(default) == "string" or default == nil, "Default value must either be omitted or be a string")
    maxcount = maxcount or 1
    maxcount = tonumber(maxcount)
    assert(maxcount and maxcount>0 and maxcount<1000,"Maxcount must be a number from 1 to 999")
    assert(is_callable(callback) or callback == nil, "Callback argument: expected a function or nil")

    data.optargument = {
      key = key,
      desc = desc,
      default = default,
      maxcount = maxcount,
      value = nil,
      callback = callback
    }
  end

  --- Defines an option.
  --- Optional arguments can use 3 different notations, and can accept a value.
  --- *Aliases: `add_option`*
  ---
  --- ### Parameters
  --- 1. **key**: the argument identifier, can be either `-key`, or `-key, --expanded-key`:
  --- if the first notation is used then a value can be defined after a space (`'-key VALUE'`),
  --- if the 2nd notation is used then a value can be defined after an `=` (`'-key, --expanded-key=VALUE'`).
  --- As a final option it is possible to only use the expanded key (eg. `'--expanded-key'`) both with and
  --- without a value specified.
  --- 2. **desc**: a description for the argument to be shown in --help
  --- 3. **default**: *optional*; specify a default value (the default is nil)
  --- 4. **callback**: *optional*; specify a function to call when this option is parsed (the default is nil)
  ---
  --- ### Usage example
  --- The following option will be stored in `args["i"]` and `args["input"]` with a default value of `my_file.txt`:
  --- `cli:add_option("-i, --input=FILE", "path to the input file", "my_file.txt")`
  function cli:add_option(key, desc, default, callback)
    -- parameterize the key if needed, possible variations:
    -- 1. -key
    -- 2. -key VALUE
    -- 3. -key, --expanded
    -- 4. -key, --expanded=VALUE
    -- 5. -key --expanded
    -- 6. -key --expanded=VALUE
    -- 7. --expanded
    -- 8. --expanded=VALUE

    assert(type(key) == "string" and type(desc) == "string", "Key and description are mandatory arguments (Strings)")
    assert(is_callable(callback) or callback == nil, "Callback argument: expected a function or nil")
    assert(
      (
        type(default) == "string"
        or default == nil
        or type(default) == "boolean"
        or (type(default) == "table" and next(default) == nil)
      ),
      "Default argument: expected a string, nil, or {}"
    )

    local k, ek, v = disect(key)

    -- set defaults
    if v == nil and type(default) ~= "boolean" then default = nil end

    really_add_option(data, k, ek, v, key, desc, default, callback)
  end

  --- Define a flag argument (on/off). This is a convenience helper for cli.add_opt().
  --- See cli.add_opt() for more information.
  ---
  --- ### Parameters
  -- 1. **key**: the argument's key
  -- 2. **desc**: a description of the argument to be displayed in the help listing
  -- 3. **default**: *optional*; specify a default value (the default is nil)
  -- 4. **callback**: *optional*; specify a function to call when this flag is parsed (the default is nil)
  function cli:add_flag(key, desc, default, callback)
    if type(default) == "function" then
      callback = default
      default = nil
    end
    assert(default == nil or type(default) == "boolean", "Default argument: expected a boolean, nil")

    local k, ek, v = disect(key)

    if v ~= nil then
      error("A flag type option cannot have a value set: " .. key)
    end

    really_add_option(data, k, ek, nil, key, desc, default, callback)
  end

  --- Parses the arguments found in #arg and returns a table with the populated values.
  --- (NOTE: after succesful parsing, the module will delete itdata to free resources)
  --- *Aliases: `parse_args`*
  ---
  --- ### Parameters
  --- 1. **arguments**: set this to arg
  --- 2. **noprint**: set this flag to prevent any information (error or help info) from being printed
  --- 3. **dump**: set this flag to dump the parsed variables for debugging purposes, alternatively
  --- set the first option to --__DUMP__ (option with 2 trailing and leading underscores) to dump at runtime.
  ---
  --- ### Returns
  --- 1. a table containing the keys specified when the arguments were defined along with the parsed values,
  --- or nil + error message (--help option is considered an error and returns nil + help message)
  function cli:parse(arguments, noprint, dump)
    if type(arguments) ~= "table" then
      -- optional 'arguments' was not provided, so shift remaining arguments
      noprint, dump, arguments = arguments, noprint, nil
    end

    if not arguments then
      arguments = arg or {}
    end

    -- clone args, don't mutate the original set:
    local args = {}
    for k,v in pairs(arguments) do
      args[k] = v
    end

    -- starts with --help? display the help listing and abort!
    if args[1] and (args[1] == "--help" or args[1] == "-h") then
      return nil, data:print_help(noprint)
    end

    -- starts with --__DUMP__; set dump to true to dump the parsed arguments
    if dump == nil then
      if args[1] and args[1] == "--__DUMP__" then
        dump = true
        table.remove(args, 1)  -- delete it to prevent further parsing
      end
    end

    while args[1] do
      local entry = nil
      local opt = args[1]
      local optpref, optkey, optkey2, optval
      _, _, optpref, optkey = opt:find("^(%-[%-]?)(.+)")   -- split PREFIX & NAME+VALUE
      if optkey then
        _, _, optkey2, optval = optkey:find("(.-)[=](.+)")       -- split value and key
        if optval then
          optkey = optkey2
        end
      end

      if not optpref then
        break   -- no optional prefix, so options are done
      end

      if opt == "--" then
        table.remove(args, 1)
        break   -- end of options
      end

      if optkey:sub(-1,-1) == "=" then  -- check on a blank value eg. --insert=
        optval = ""
        optkey = optkey:sub(1,-2)
      end

      if optkey then
        entry = lookup(
          data,
          optpref == '-' and optkey or nil,
          optpref == '--' and optkey or nil
        )
      end

      if not optkey or not entry then
        local option_type = optval and "option" or "flag"
        return on_error("unknown/bad " .. option_type .. ": " .. opt, noprint)
      end

      table.remove(args,1)
      if optpref == "-" then
        if optval then
          return on_error("short option does not allow value through '=': "..opt, noprint)
        end
        if entry.flag then
          optval = true
        else
          -- not a flag, value is in the next argument
          optval = args[1]
          table.remove(args, 1)
        end
      elseif optpref == "--" then
        -- using the expanded-key notation
        entry = lookup(data, nil, optkey)

        if entry then
          if entry.flag then
            if optval then
              return on_error("flag --" .. optkey .. " does not take a value", noprint)
            else
              optval = not entry.has_no_flag or (optkey:sub(1,3) ~= "no-")
            end
          else
            if not optval then
              -- value is in the next argument
              optval = args[1]
              table.remove(args, 1)
            end
          end
        else
          return on_error("unknown/bad flag: " .. opt, noprint)
        end
      end

      if type(entry.value) == 'table' then
        table.insert(entry.value, optval)
      else
        entry.value = optval
      end

      -- invoke the option's parse-callback, if any
      if entry.callback then
        local altkey = entry.key

        if optkey == entry.key then
          altkey = entry.expanded_key
        else
          optkey = entry.expanded_key
        end

        local status, err = entry.callback(optkey, optval, altkey, opt)
        if status == nil and err then
          return on_error(err, noprint)
        end
      end
    end

    -- missing any required arguments, or too many?
    if #args < #data.required or #args > #data.required + data.optargument.maxcount then
      if data.optargument.maxcount > 0 then
        return on_error("bad number of arguments: " .. #data.required .."-" .. #data.required + data.optargument.maxcount .. " argument(s) must be specified, not " .. #args, noprint)
      else
        return on_error("bad number of arguments: " .. #data.required .. " argument(s) must be specified, not " .. #args, noprint)
      end
    end

    -- deal with required args here
    for _, entry in ipairs(data.required) do
      entry.value = args[1]
      if entry.callback then
        local status, err = entry.callback(entry.key, entry.value)
        if status == nil and err then
          return on_error(err, noprint)
        end
      end
      table.remove(args, 1)
    end
    -- deal with the last optional argument
    while args[1] do
      if data.optargument.maxcount > 1 then
        data.optargument.value = data.optargument.value or {}
        table.insert(data.optargument.value, args[1])
      else
        data.optargument.value = args[1]
      end
      if data.optargument.callback then
        local status, err = data.optargument.callback(data.optargument.key, args[1])
        if status == nil and err then
          return on_error(err, noprint)
        end
      end
      table.remove(args,1)
    end
    -- if necessary set the defaults for the last optional argument here
    if data.optargument.maxcount > 0 and not data.optargument.value then
      if data.optargument.maxcount == 1 then
        data.optargument.value = data.optargument.default
      else
        data.optargument.value = { data.optargument.default }
      end
    end

    -- populate the results table
    local results = {}
    if data.optargument.maxcount > 0 then
      results[data.optargument.key] = data.optargument.value
    end
    for _, entry in pairs(data.required) do
      results[entry.key] = entry.value
    end
    for _, entry in pairs(data.optional) do
      if entry.key then results[entry.key] = entry.value end
      if entry.expanded_key then results[entry.expanded_key] = entry.value end
    end

    if dump then
      printer.dump_internal_state(data)

      return on_error("commandline dump created as requested per '--__DUMP__' option", noprint)
    end


    return results
  end


  --- Prints the USAGE heading.
  ---
  --- ### Parameters
   ---1. **noprint**: set this flag to prevent the line from being printed
  ---
  --- ### Returns
  --- 1. a string with the USAGE message.
  function cli:print_usage(noprint)
    local msg = printer.generate_usage(data)

    if not noprint then
      print(msg)
    end

    return msg
  end

  --- Prints the HELP information.
  ---
  --- ### Parameters
  --- 1. **noprint**: set this flag to prevent the information from being printed
  ---
  --- ### Returns
  --- 1. a string with the HELP message.
  function cli:print_help(noprint)
    local msg = printer.generate_help(data)

    if not noprint then
      print(msg)
    end

    return msg
  end

  -- TODO: move to printer
  --
  --- Sets the amount of space allocated to the argument keys and descriptions in the help listing.
  --- The sizes are used for wrapping long argument keys and descriptions.
  --- ### Parameters
  --- 1. **key_cols**: the number of columns assigned to the argument keys, set to 0 to auto detect (default: 0)
  --- 1. **desc_cols**: the number of columns assigned to the argument descriptions, set to 0 to auto set the total width to 72 (default: 0)
  function cli:set_colsz(key_cols, desc_cols)
    data.colsz = { key_cols or data.colsz[1], desc_cols or data.colsz[2] }
  end

  return cli
end