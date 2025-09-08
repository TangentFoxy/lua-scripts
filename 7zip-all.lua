#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

utility.ls()(function(file_name)
  -- print(file_name:sub(-3) == ".7z", utility.is_file(file_name .. ".7z")) -- DEBUG
  if file_name == "." or file_name == ".." then return end

  -- skip already compressed items and don't double-compress
  if file_name:sub(-3) == ".7z" or utility.is_file(file_name .. ".7z") then
    return
  end

  -- print("7z a \"" .. file_name .. ".7z\" " .. file_name:enquote()) -- DEBUG
  os.execute("7z a \"" .. file_name .. ".7z\" " .. file_name:enquote())
end)
