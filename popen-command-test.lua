#!/usr/bin/env luajit

-- ollama install command: curl https://ollama.ai/install.sh | sh

local error_occurred, utility = pcall(function() return dofile(arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)") .. "utility-functions.lua") end) if not error_occurred then error("\n\nThis script is installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n") end
-- util.required_program("wsl") -- This fails on my system, necessitating a special function to run commands in WSL.
utility.required_program("pwsh") -- Apparently this is and isn't PowerShell. Isn't the future amazing?

-- On my system, it is impossible to call wsl directly from Lua. No idea why.
local function wsl_command(command, get_output)
  local file_name = utility.tmp_file_name()
  local output

  command = "pwsh -Command wsl --exec \"" .. utility.escape_quotes(command) .. "\""

  if get_output then
    command = command .. " > " .. file_name
  end

  os.execute(command)

  if get_output then
    local file = io.open(file_name, "r")
    local output = file:read("*all")
    file:close()
    os.execute("rm " .. file_name) -- TODO replace with version I know works from somewhere else
    return output:trim()
  end
end

local function query_model(model, prompt)
  local command = "ollama run " .. model .. " \"" .. utility.escape_quotes(prompt) .. "\""
  return wsl_command(command, true)
end

local function query_dolphin(prompt)
  query_model("dolphin-mixtral", prompt)
end
-- print(query_dolphin("Say only the word 'cheese'."))

-- TEMPORARY creation, need to make this system able to manage models automatically or semi-automatically
wsl_command("ollama create curt --file ")

print(query_model("curt", "How are you?"))
