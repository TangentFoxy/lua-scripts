-- install command: curl https://ollama.ai/install.sh | sh

util = require("utility-functions")
-- util.required_program("wsl") -- This fails on my system.
util.required_program("pwsh") -- Apparently this is and isn't PowerShell. Isn't the future amazing?

-- On my system, it is impossible to call wsl directly from Lua. No idea why.
local function wsl_command(command, output_return)
  local file_name = ".tmp." .. util.uuid()
  local output

  command = "pwsh -Command wsl --exec \"" .. util.escape_quotes(command) .. "\""

  if output_return then
    command = command .. " > " .. file_name
  end

  os.execute(command)

  if output_return then
    local file = io.open(file_name, "r")
    local output = file:read("*a")
    file:close()
    os.execute("rm " .. file_name) -- TODO replace with version I know works from somewhere else
    return output
  end
end

local function query_dolphin(prompt)
  local command = "ollama run dolphin-mixtral \"" .. util.escape_quotes(prompt) .. "\""
  return wsl_command(command, true)
  -- TODO trim the above

  -- os.execute("pwsh -Command wsl --exec \"ollama run dolphin-mixtral \\\"Say only the word 'cheese'.\\\"\" > test-output-file.txt")
end

print(query_dolphin("Say only the word 'cheese'."))
