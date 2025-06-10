#!/usr/bin/env luajit

-- according to PiL 8.1, setting LUA_PATH should make require work, but it doesn't
--   https://www.lua.org/pil/8.1.html
print((arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")))
for k,v in pairs(arg) do print(k,v) end

for k,v in pairs(package) do print(k,v) end

-- finally, something that works consistently!
package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "?.lua;" .. package.path
require "a-script"

-- LUA_PATH=(arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "?.lua"
-- print(LUA_PATH)
-- require "a-script"

-- dofile((arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "a-script.lua")

if true then return end

local success, utility = pcall(function()
  return dofile((arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "utility-functions.lua")
end)
if not success then
  print("\n\n" .. tostring(utility))
  error("\n\nThis script may be installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n")
end

local json = utility.require("json")
local tab = {2, 5, 3, 1, 1}
print(json.encode(tab))
