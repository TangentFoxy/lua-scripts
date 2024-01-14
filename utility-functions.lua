math.randomseed(os.time())

local utility = {}

if package.config:sub(1, 1) == "\\" then
  utility.OS = "Windows"
else
  utility.OS = "UNIX-like"
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

function os.capture(command)
  if io.popen then
    local file = assert(io.popen(command, 'r'))
    local output = assert(file:read('*all'))
    file:close()
    return output
  else
    print("WARNING: io.popen not available, using a temporary file to receive output from:\n", command)
    return os.capture_safe(command)
  end
end

-- trim6 from Lua users wiki (best all-round pure Lua performance)
function string.trim(s)
  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

utility.required_program = function(name)
  local command
  if utility.OS == "Windows" then
    command = "where " -- NOTE: This will print a path when it works. :\ Windows, am I right?
  else
    command = "which "
  end

  -- TODO verify this works on Linux / macOS
  if os.execute(command .. tostring(name)) ~= 0 then
    error("\n\n" .. tostring(name) .. " must be installed and in the path\n")
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
  if path then
    command = command .. "\"" .. path .. "\""
  end

  local tmp_file_name = utility.tmp_file_name()
  local output = os.capture_safe(command, tmp_file_name)

  return function(fn)
    for line in output:gmatch("[^\r\n]+") do -- thanks to https://stackoverflow.com/a/32847589
      if line ~= tmp_file_name then -- exclude temporary file name
        fn(line)
      end
    end
  end
end

return utility
