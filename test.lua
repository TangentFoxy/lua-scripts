#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

-- NOTE add current test case here
utility.open("2webm.lua", "r")(function(file)
  file:close() -- double closing a file handle shouldn't error... right? Nope! It errors!
end)
