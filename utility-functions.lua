math.randomseed(os.time())

local utility = {}

if package.config:sub(1, 1) == "\\" then
  utility.OS = "Windows"
else
  utility.OS = "UNIX-like"
end

-- TODO look for popen command and fall back to outputting to file if its unavailable (this should always output a warning!)
function os.capture(command)
  local file = assert(io.popen(command, 'r'))
  local output = assert(file:read('*all'))
  file:close()
  return output
end

-- always uses outputting to a temporary file to guarantee safety
function os.capture_safe(command, tmp_file_name)
  local file_name = tmp_file_name or utility.tmp_file_name()
  os.execute(command .. " > " .. file_name)

  local file = io.open(file_name, "r")
  local output = file:read("*all")
  file:close()
  os.execute("rm " .. file_name) -- NOTE may not work on all systems, I have a version somewhere that always does
  return output
end

-- trim6 from Lua users wiki (best all-round pure Lua performance)
function string.trim(s)
  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

-- TODO: This needs to use which on a non-Windows platform.
-- NOTE: This will sometimes print errors that do not matter. Windows, am I right?
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

utility.tmp_file_name = function()
  return ".tmp." .. utility.uuid()
end

utility.escape_quotes = function(input)
  -- the order of these commands is important and must be preserved
  input = input:gsub("\\", "\\\\")
  input = input:gsub("\"", "\\\"")
  return input
end

utility.ls = function(path)
  local command
  if utility.OS == "Windows" then
    command = "dir /w /b"
  else
    command = "ls -1"
  end

  local tmp_file_name = utility.tmp_file_name()
  local output = os.capture_safe(command, tmp_file_name)
  -- local output = os.capture_safe(command)
  -- output = output:trim() -- verifying that even without trailing newlines, the gmatch below will work
  -- print(output .. "\n---") -- DEBUG

  return function(fn)
    for line in output:gmatch("[^\r\n]+") do
      if line ~= tmp_file_name then -- exclude temporary file name
        fn(line)
      end
    end
  end
end

return utility
