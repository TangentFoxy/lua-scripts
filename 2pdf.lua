#!/usr/bin/env luajit

-- The first time this is run (on Windows), a dialog will appear.
--  Uncheck the "always show this" thing and click Install.

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

local for_files = utility.ls()
os.execute("mkdir 2pdf-output")

for_files(function(file_name)
  local name_sans_extension = file_name:sub(1, -5) -- temporarily hardcoding expectation that the input file has a 3-digit file extension
  os.execute("pandoc \"" .. file_name .. "\" -o \"2pdf-output/" .. name_sans_extension .. ".pdf\"")
end)
