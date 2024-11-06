#!/usr/bin/env luajit

local success, utility = pcall(function()
  return dofile((arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "utility-functions.lua")
end)
if not success then
  print("\n\n" .. tostring(utility))
  error("\n\nThis script may be installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n")
end

print("---")

local commands = {
  "llm run dolphin-mixtral \"How are you?\"",
  "llm run curt \"How are you?\"",
  "llm run curt2 \"How are you?\"",
  "llm run synx \"How are you?\"",
  "llm run synx \"Describe actions you would take as a synx.\"",
  "llm run synx \"Describe a synx.\"",
  "llm run synx \"What are you?\""
}

-- local llm = loadfile(utility.path .. "llm.lua")

for _, command in ipairs(commands) do
  -- print("\n\n\nTEST START", command .. "\n\n\n")

  -- print(command:rep(5, "\n"))

  for i = 1, 5 do
    -- os.execute(command)
    -- loadfile(utility.path .. "llm.lua")(command:sub(5))

    -- command = command:sub(5)
    -- local tab = {}
    -- for argument in command:gmatch("%S+") do
    --   table.insert(tab, argument)
    -- end
    -- llm(unpack(tab))

    -- print("\nOUTPUT ENDS\n")

    -- error("\n\ntmp break\n\n")


    -- print(command)
    os.execute("echo " .. command .. " >> .run-this-shit.ps1")
  end
end

-- os.execute("echo " .. commands[1] .. " >> .run-this-shit.ps1")
os.execute("pwsh .run-this-shit.ps1")
os.execute("rm .run-this-shit.ps1")

print("---")
