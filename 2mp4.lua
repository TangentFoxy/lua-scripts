#!/usr/bin/env luajit

local help = [[Usage:

  2mp4.lua [threads=1]

Converts everything in the local directory to mp4, placed in "./2mp4-output".
(Defaults to using only a single thread to reduce impact on the system.)

[threads]: Number of threads ffmpeg will be assigned.
           If a non-number value, ffmpeg's -threads flag will not be used.
]]

if arg[1] and arg[1]:find("help") then
  print(help)
  return false
end

local success, utility = pcall(function()
  return dofile((arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "utility-functions.lua")
end)
if not success then
  print("\n\n" .. tostring(utility))
  error("\n\nThis script may be installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n")
end

utility.required_program("ffmpeg")

local threads = tonumber(arg[1]) or arg[1] or 1

local for_files = utility.ls()
os.execute("mkdir 2mp4-output")

for_files(function(file_name)
  local command
  if type(threads) == "number" then
    command = "ffmpeg -threads " .. threads .. " -i \"" .. file_name .. "\" -threads " .. threads .. " \"2mp4-output/" .. file_name .. ".mp4\""
  else
    command = "ffmpeg -i \"" .. file_name .. "\" \"2mp4-output/" .. file_name .. ".mp4\""
  end

  os.execute(command)
end)
