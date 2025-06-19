#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

-- arg[1] would need to be "make-epub.lua" to do what this was previously doing
utility.ls(".")(function(file_name)
  os.execute("luajit " .. utility.path .. arg[1] .. " " .. file_name:enquote())
end)
