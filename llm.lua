#!/usr/bin/env luajit

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
-- util.required_program("wsl") -- This fails on my system, necessitating a special function to run commands in WSL.
-- I have no idea how to check for ollama being installed through WSL, else that check would be here.
utility.required_program("pwsh") -- Apparently this is AND isn't PowerShell. Isn't the future amazing?

local action = arg[1]



-- On my system, it is impossible to call wsl directly from Lua. No idea why.
local function wsl_command(command, get_output)
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
    if model == name then
      return true
    end
  end
  return false
end



local execute = {
  create = function()
    -- check for conflicts, then search local modelfiles -> create from local, then try a pull command, else return false
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

-- TEMPORARY creation, need to make this system able to manage models automatically or semi-automatically
-- wsl_command("ollama create curt --file ")

-- print(query_model("curt", "How are you?"))
