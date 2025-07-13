#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

local created = {}

utility.ls(".", function(file_name)
  if file_name:find("%.MP4") then
    local folder = tonumber(file_name:sub(9-3, 9-1)) -- sequence number
    if not created[folder] then
      created[folder] = true
      os.execute("mkdir " .. folder)
    end
    os.execute(utility.commands.move .. file_name .. " " .. folder)
  end
end)
