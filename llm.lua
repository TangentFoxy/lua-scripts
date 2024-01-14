#!/usr/bin/env luajit

-- local args = {...}
-- for k,v in pairs(args) do
--   print(k,v)
-- end
-- error("break Beat")

-- local arg = {...} -- for some reason, this is suddenly the only way I can pass arguments from another script

-- for k,v in pairs(arg) do
--   print(k,v)
-- end
-- print("\n\n")
-- error("tmp break")

local help = [[Usage:

  llm.lua <action> [...]

<action>: What is desired.
            create, pull, download, install <model>: Creates a model from local
              <model> Modelfile. If that doesn't exist, uses ollama pull to
              download the <model> specified.
            query, run [model] [input]: Runs a model. Defaults to using
              dolphin-mixtral when [model] is not specified. If [input] is not
              specified, opens in interactive mode. [input] cannot be the name
              of an existing model alone (that would just open the model
              interactively). Cannot download a model (a non-existing model
              name is treated as input).
            help: Print this helptext.
]]

if arg[1] and arg[1]:find("help") then
  print(help)
  return false
end

local error_occurred, utility = pcall(function() return dofile(arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)") .. "utility-functions.lua") end) if not error_occurred then error("\n\nThis script is installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n") end
-- local utility = dofile(arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)") .. "utility-functions.lua"

-- util.required_program("wsl") -- This fails on my system, necessitating a special function to run commands in WSL.
-- I have no idea how to check for ollama being installed through WSL, else that check would be here.
utility.required_program("pwsh") -- Apparently this is AND isn't PowerShell. Isn't the future amazing?

local action = arg[1]



-- On my system, it is impossible to call wsl directly from Lua. No idea why.
local function wsl_command(command, get_output) -- defaults to getting the output
  -- print("wsl running:", command)
  local command = "pwsh -Command wsl --exec \"" .. utility.escape_quotes(command) .. "\""

  local output
  if get_output or (get_output == nil) then
    output = os.capture_safe(command)
    return output:trim()
  else
    os.execute(command)
  end
end

-- TODO make this check against existant models and error if you try to query a non-existant model
local function query_model(model, prompt)
  if prompt then
    return wsl_command("ollama run " .. model .. " --nowordwrap \"" .. utility.escape_quotes(prompt) .. "\"")
  else
    return wsl_command("ollama run " .. model, false)
  end
end

local function get_models()
  local raw_list = wsl_command("ollama list")

  -- TODO export to utility if this works
  local function lines(text, fn)
    for line in text:gmatch("[^\r\n]+") do
      fn(line)
    end
  end

  local list = {}
  lines(raw_list, function(line)
    local name = line:gmatch("%S+")() -- thanks to https://lua-users.org/wiki/SplitJoin
    if name ~= "NAME" then -- this is kinda a real shitty way to just ignore the first line :D
      table.insert(list, name)
    end
  end)

  return list
end

local function model_exists(model)
  local models = get_models()
  for _, name in ipairs(models) do
    if model == name:sub(1, name:find(":") - 1) then -- ignore tags!
      return true
    end
  end
  return false
end



local execute = {
  create = function()
    local model = arg[2]
    if not model then print("A model name must be specified.") return false end
    -- check for conflicts, then search local modelfiles -> create from local, then try a pull command, else return false

    if model_exists(model) then
      print("A model called \"" .. model .. "\" already exists.")
      return false
    end

    local search_path = utility.path .. "ollama-modelfiles"
    if utility.OS == "Windows" then
      search_path = search_path .. "\\"
    else
      search_path = search_path .. "/"
    end

    local success
    utility.ls(search_path)(function(file_name)
      if model == file_name then
        -- WSL can't comprehend a Windows path and treads it as a local path extension, so we must modify the path
        search_path = search_path:gsub("\\", "/"):gsub("(%a):", function(capture) return "/mnt/" .. capture:lower() end) -- thanks to https://www.lua.org/pil/20.3.html
        local output = wsl_command("ollama create " .. model .. " --file " .. search_path .. model)
        print(output)

        if output:find("success") then
          success = true
        else
          success = false
        end
      end
    end)
    if type(success) ~= nil then return success end

    local output = (wsl_command("ollama pull " .. model)):trim()
    print(output)
    if output:find("Error") then
      return false
    else
      return true
    end
  end,
  query = function()
    local model = arg[2]
    local query = {}
    for i = 3, #arg do
      table.insert(query, arg[i])
    end
    query = table.concat(query, " ")

    -- verify we've selected a model
    if model then
      if not model_exists(model) then
        query = model .. " " .. query
        model = "dolphin-mixtral"
      end
    else
      model = "dolphin-mixtral"
    end

    -- enter interactive mode or send prompt?
    if query == "" then
      return query_model(model)
    else
      print(query_model(model, query))
      return true
    end
  end,
}
execute.pull = execute.create
execute.download = execute.create
execute.install = execute.create
execute.run = execute.query

if execute[action] then
  execute[action]()
else
  print("Invalid <action>")
  print("Received:", "action", action)
end



-- ollama install command: curl https://ollama.ai/install.sh | sh

-- print(query_dolphin("Say only the word 'cheese'."))

-- print(query_model("curt", "How are you?"))
