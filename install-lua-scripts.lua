#!/usr/bin/env luajit

-- FAILURE
--   so if this is run locally, it can't install the path because it doesn't know where it is due to a bug in Lua
--   if it is already in the path, and thus can be run via 'install-lua-scripts.lua', then it can add itself to the path
--   so this obviously fails completely

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

-- NOTE: I have no idea if this will work on Windows (but it shouldn't matter)
if utility.path == "./" then
  print("This script must be run as \"install-lua-scripts.lua\"!\n(not \"./install-lua-scripts.lua\")")
  return false
end

local current_path = utility.capture("echo $PATH")
if current_path:find(utility.path:sub(1, -2), 1, true) then
  print("lua-scripts is already in your $PATH.")
else
  os.execute("echo \"export PATH=\\$PATH:$PWD\" >> ~/.bashrc")
  print("lua-scripts has been added to your $PATH.")
  print("WARNING: The current shell will not update its $PATH due to a bug. :D")
end
