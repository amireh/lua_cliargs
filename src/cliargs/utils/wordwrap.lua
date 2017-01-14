local split = require('cliargs.utils.split')

local function buildline(words, size, overflow)
  -- if overflow is set, a word longer than size, will overflow the size
  -- otherwise it will be chopped in line-length pieces
  local line = ""
  if string.len(words[1]) > size then
    -- word longer than line
    if overflow then
      line = words[1]
      table.remove(words, 1)
    else
      line = words[1]:sub(1, size)
      words[1] = words[1]:sub(size + 1, -1)
    end
  else
    while words[1] and (#line + string.len(words[1]) + 1 <= size) or (line == "" and #words[1] == size) do
      if line == "" then
        line = words[1]
      else
        line = line .. " " .. words[1]
      end
      table.remove(words, 1)
    end
  end
  return line, words
end

local function wordwrap(str, size, pad, overflow, newline_char)
  -- if overflow is set, then words longer than a line will overflow
  -- otherwise, they'll be chopped in pieces
  pad = pad or 0
  newline_char = newline_char or '\n'

  local line
  local out = ""
  local padstr = string.rep(" ", pad)
  local words = split(str, ' ')

  while words[1] do
    line, words = buildline(words, size, overflow)
    if out == "" then
      out = padstr .. line
    else
        out = out .. newline_char .. padstr .. line
    end
  end

  return out
end

return wordwrap