math.randomseed(os.time())

-- TODO look for popen command and fall back to outputting to file if its unavailable
function os.command(command)
  local file = assert(io.popen(command, 'r'))
  local output = assert(file:read('*a'))
  file:close()
  return output
end

-- trim6 from Lua users wiki (best all-round pure Lua performance)
function string.trim(s)
  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

local utility = {}

-- NOTE: This will print errors sometimes. :D
utility.required_program = function(name)
  if os.execute("where " .. tostring(name)) ~= 0 then
    error(tostring(name) .. " must be installed and in the path")
  end
end

-- modified from my fork of lume
utility.uuid = function()
  local fn = function(x)
    local r = math.random(16) - 1
    r = (x == "x") and (r + 1) or (r % 4) + 9
    return ("0123456789abcdef"):sub(r, r)
  end
  return (("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"):gsub("[xy]", fn))
end

utility.escape_quotes = function(input)
  input = input:gsub("\\", "\\\\")
  input = input:gsub("\"", "\\\"")
  return input
end

return utility
