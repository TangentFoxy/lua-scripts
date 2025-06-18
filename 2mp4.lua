#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local argparse = utility.require("argparse")

local parser = argparse():description("Converts everything in the local directory to mp4, placed in \"./2mp4-output\".")
-- BUG argparse will not set the default number of threads I told it to (this is outdated anyhow)
-- parser:argument("threads", "Number of threads ffmpeg will be assigned."):default(1):defmode("arg"):convert(tonumber):args("?")
parser:argument("threads", "Number of threads ffmpeg will be assigned."):convert(tonumber):args("?")
local options = parser:parse()



utility.required_program("ffmpeg")

local for_files = utility.ls()
os.execute("mkdir 2mp4-output")

for_files(function(file_name)
  local _, name, extension = utility.split_path_components(file_name)
  if extension then
    name = name:sub(1, -(#extension + 2))
  end

  local command
  if options.threads then
    command = "ffmpeg -threads " .. options.threads .. " -i \"" .. file_name .. "\" -threads " .. options.threads .. " \"2mp4-output/" .. name .. ".mp4\""
  else
    command = "ffmpeg -i \"" .. file_name .. "\" \"2mp4-output/" .. name .. ".mp4\""
  end

  os.execute(command)
end)
