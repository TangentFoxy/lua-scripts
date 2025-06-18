#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local argparse = utility.require("argparse")

local parser = argparse():description("Converts everything in the local directory to webm, placed in \"./2webm-output\".")
parser:argument("threads", "Number of threads ffmpeg will be assigned."):convert(tonumber):args("?")
local options = parser:parse()



utility.required_program("ffmpeg")

local for_files = utility.ls()
os.execute("mkdir 2webm-output")

for_files(function(file_name)
  local _, name, extension = utility.split_path_components(file_name)
  if extension then
    name = name:sub(1, -(#extension + 2))
  end

  local command
  if options.threads then
    command = "ffmpeg -threads " .. options.threads .. " -i \"" .. file_name .. "\" -threads " .. options.threads .. " \"2webm-output/" .. name .. ".webm\""
  else
    command = "ffmpeg -i \"" .. file_name .. "\" \"2webm-output/" .. name .. ".webm\""
  end

  os.execute(command)
end)
