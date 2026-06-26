#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local argparse = utility.require("argparse")

local parser = argparse():description("Converts everything in the local directory to mp3, placed in \"./2mp3-output\".")
local options = parser:parse()



utility.required_program("ffmpeg")

local for_files = utility.ls()
os.execute("mkdir 2mp3-output")

for_files(function(file_name)
  local _, name, extension = utility.split_path_components(file_name)
  if extension then
    name = name:sub(1, -(#extension + 2))
  end

  local command = "ffmpeg -i \"" .. file_name .. "\" -acodec mp3 \"2mp3-output/" .. name .. ".mp3\""

  os.execute(command)
end)
