#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local argparse = utility.require("argparse")

local parser = argparse():description("Converts everything in the local directory to pdf, placed in \"./2pdf-output\".")
local options = parser:parse()

if utility.OS == "Windows" then
  local config = utility.get_config()
  if not (config["2pdf.lua"] and config["2pdf.lua"].first_run) then
    print("The first time pandoc is run on Windows, a dialog box may open.")
    print("  If it does, uncheck \"always show this\" and click \"Install\".")
    print("Press enter to continue. This warning will not appear again.")
    io.read("*line")
    config["2pdf.lua"] = config["2pdf.lua"] or {}
    config["2pdf.lua"].first_run = true
    utility.save_config()
  end
end



utility.required_program("pandoc")

local for_files = utility.ls()
os.execute("mkdir 2pdf-output")

for_files(function(file_name)
  local _, name, extension = utility.split_path_components(file_name)
  if extension then
    name = name:sub(1, -(#extension + 2))
  end

  os.execute("pandoc \"" .. file_name .. "\" -o \"2pdf-output/" .. name .. ".pdf\"")
end)
