-- TO USE, PUT THE INTERIOR OF THIS FUNCTION IN YOUR FILE
--  this only works if that file is in the same directory as this one - but works no matter where it was called from
local function _example_load()
  local success, utility = pcall(function()
    return dofile((arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "utility-functions.lua")
  end)
  if not success then
    print("\n\n" .. tostring(utility))
    error("\n\nThis script may be installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n")
  end
end

math.randomseed(os.time())

local utility = {}

if package.config:sub(1, 1) == "\\" then
  utility.OS = "Windows"
  utility.path_separator = "\\"
  utility.recursive_remove_command = "rmdir /s /q "
else
  utility.OS = "UNIX-like"
  utility.path_separator = "/"
  utility.recursive_remove_command = "rm -r "
end

utility.path = arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)") -- inspired by discussion in https://stackoverflow.com/q/6380820

-- always uses outputting to a temporary file to guarantee safety
function utility.capture_safe(command, tmp_file_name)
  local file_name = tmp_file_name or utility.tmp_file_name()
  os.execute(command .. " > " .. file_name)

  local file = io.open(file_name, "r")
  local output = file:read("*all")
  file:close()
  os.execute("rm " .. file_name) -- NOTE may not work on all systems, I have a version somewhere that always does
  return output
end

function utility.capture(command)
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

-- NOTE DEPRECATED (I shouldn't pollute default namespaces unless it really makes things work better, like with string functions)
os.capture_safe = utility.capture_safe
os.capture = utility.capture

-- trim6 from Lua users wiki (best all-round pure Lua performance)
function string.trim(s)
  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

function string.enquote(s)
  return "\"" .. s .. "\""
end

local function escape_special_characters(s)
  local special_characters = "[()%%.[^$%]*+%-?]"
  if s == nil then return end
  return (s:gsub(special_characters, "%%%1"))
end

function string.gsplit(s, delimiter)
  delimiter = delimiter or ","
  if s:sub(-#delimiter) ~= delimiter then s = s .. delimiter end
  return s:gmatch("(.-)" .. escape_special_characters(delimiter))
end

function string.split(s, delimiter)
  local result = {}
  for item in s:gsplit(delimiter) do
    result[#result + 1] = item
  end
  return result
end

utility.require = function(name)
  local success, package_or_err = pcall(function()
    return dofile(utility.path .. name .. ".lua")
  end)
  if success then
    return package_or_err
  else
    print("\n\n" .. tostring(package_or_err))
    error("\n\nThis script may be installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n")
  end
end

-- errors if specified program isn't in the path
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
  return "." .. utility.uuid() .. ".tmp"
end

utility.make_safe_file_name = function(file_name)
  file_name = file_name:gsub("[%\"%:%\\%!%@%#%$%%%^%*%=%{%}%|%;%<%>%?%/]", "") -- everything except the &
  file_name = file_name:gsub(" %&", ",")   -- replacing & with a comma works for 99% of things
  file_name = file_name:gsub("%&", ",")    -- replacing & with a comma works for 99% of things
  file_name = file_name:gsub("[%s+]", " ") -- more than one space in succession should be a single space
  return file_name
end

-- io.open, but errors are immediately thrown, and the file is closed for you
utility.open = function(file_name, mode, custom_error_message)
  local file, err = io.open(file_name, mode)
  if not file then error(custom_error_message or err) end
  return function(fn)
    local success, result_or_error = pcall(function() return fn(file) end)
    file:close()
    if not success then
      error(result_or_error) -- custom_error_message is only for when the file doesn't exist, this function should not hide *your* errors
    end
    return result_or_error
  end
end

utility.escape_quotes = function(input)
  -- the order of these commands is important and must be preserved
  input = input:gsub("\\", "\\\\")
  input = input:gsub("\"", "\\\"")
  return input
end

-- Example, print all items in this directory: utility.ls(".")(print)
utility.ls = function(path)
  local command
  if utility.OS == "Windows" then
    command = "dir /w /b"
  else
    command = "ls -1"
  end
  if path then
    command = command .. " \"" .. path .. "\""
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

utility.exists = function(file_name)
  local file = io.open(file_name, "r")
  if file then file:close() return true else return false end
end

local config
utility.get_config = function()
  if not config then
    local config_path = utility.path .. "config.json"
    if utility.exists(config_path) then
      utility.open(config_path, "r")(function(config_file)
        local json = utility.require("json")
        config = json.decode(config_file:read("*all"))
      end)
    else
      config = {}
    end
  end
  return config
end

utility.save_config = function()
  if config then
    utility.open(utility.path .. "config.json", "w")(function(config_file)
      local json = utility.require("json")
      config_file:write(json.encode(config))
    end)
  end
end

return utility
