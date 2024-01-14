#!/usr/bin/env luajit

-- if utility-functions.lua has an error, this won't show it, so for testing purposes, I don't use it here
-- local error_occurred, utility = pcall(function() return require("utility-functions") end) if not error_occurred then error("This script is installed improperly. Follow instructions at https://github.com/TangentFoxy/.lua-files#installation") end
-- utility = require("utility-functions")


print("---")

local error_occurred, utility = pcall(function() return dofile(arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)") .. "utility-functions.lua") end) if not error_occurred then error("\n\nThis script is installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n") end
print("Success?")

-- local error_occurred, utility = pcall(
--   function()
--     local path = arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")
--     return require(path .. "utility-functions")
--   end)
-- if not error_occurred then
--   error("\n\nThis script is installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n")
-- end

-- local path = arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")
-- utility = dofile(path .. "utility-functions.lua")
-- print(utility)
for k,v in pairs(utility) do
  print(k,v)
end

print("---")
