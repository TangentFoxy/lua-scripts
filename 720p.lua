#!/usr/bin/env luajit

local help = [[Usage:

  720p.lua [tune=film] [threads=1]

Converts everything in the local directory to 720p MP4s, placed in
"./720p-output". (Defaults to using only a single thread to reduce impact on
the system.)

[tune]:    Improve encoding by specifying type of video. "film" is the default.
           Can be "grain" for grainy sources, "animation", or "stillimage".
[threads]: Number of threads ffmpeg will be assigned.
           If a non-number value, ffmpeg's -threads flag will not be used.
]]

if arg[1] and arg[1]:find("help") then
  print(help)
  return false
end

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

utility.required_program("ffmpeg")

local tune
if arg[2] then
  tune = arg[1]
  arg[1] = arg[2]
end
local threads = tonumber(arg[1]) or arg[1] or 1

local tunes = { "film", "grain", "animation", "stillimage", }
local valid_tune = false
for _, tune_option in ipairs(tunes) do
  if tune == tune_option then
    valid_tune = true
    break
  end
end
if not valid_tune then
  tune = "film"
end

local for_files = utility.ls()
os.execute("mkdir 720p-output")

for_files(function(file_name)
  local command
  if type(threads) == "number" then
    command = "ffmpeg -threads " .. threads .. " -i \"" .. file_name .. "\" -vf scale=1280:-2 -threads " .. threads .. " -tune " .. tune .. " -crf 28 \"720p-output/" .. file_name .. ".mp4\""
  else
    command = "ffmpeg -i \"" .. file_name .. "\" -vf scale=1280:-2 -tune " .. tune .. " -crf 28 \"720p-output/" .. file_name .. ".mp4\""
  end

  os.execute(command)
end)
