#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local argparse = utility.require("argparse")

local parser = argparse():description("Converts everything in the local directory to 720p mp4s, placed in \"./720p-output\".")
-- BUG argparse won't assign a default tune; and won't accept multiple optional arguments even though their required forms makes it obvious which is which
-- parser:argument("tune", "Improve encoding by specifying type of video. \"grain\" is for grainy film. Others are self-explanatory.")
--   :choices{"film", "grain", "animation", "stillimage"}:default("film"):defmode("arg"):args("?")
parser:argument("threads", "Number of threads ffmpeg will be assigned."):convert(tonumber):args("?")
parser:option("--tune", "Improve encoding by specifying type of video. \"grain\" is for grainy film. Others are self-explanatory.")
  :choices{"film", "grain", "animation", "stillimage"}:default("film"):defmode("arg"):args("?")
local options = parser:parse()

options.tune = options.tune[1] or "film"
print(options.tune)



utility.required_program("ffmpeg")

local for_files = utility.ls()
os.execute("mkdir 720p-output")

for_files(function(file_name)
  local _, name, extension = utility.split_path_components(file_name)
  if extension then
    name = name:sub(1, -(#extension + 2))
  end

  local command
  if options.threads then
    command = "ffmpeg -threads " .. options.threads .. " -i \"" .. file_name .. "\" -vf scale=1280:-2 -threads " .. options.threads .. " -tune " .. options.tune .. " -crf 28 \"720p-output/" .. name .. ".mp4\""
  else
    command = "ffmpeg -i \"" .. file_name .. "\" -vf scale=1280:-2 -tune " .. options.tune .. " -crf 28 \"720p-output/" .. name .. ".mp4\""
  end

  os.execute(command)
end)
