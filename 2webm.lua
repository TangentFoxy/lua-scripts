#!/usr/bin/env luajit
-- any2webm.lua
-- Requires ffmpeg
-- Place in a directory with video files and they will all slowly be converted to webm files.

-- OS must be detected to choose list command
local ls
if package.config:sub(1,1) == "\\" then
  ls = "dir /w /b > files.txt"
else
  ls = "ls -1 > files.txt"
end

os.execute(ls)

os.execute("mkdir any2webm-output")

for line in io.lines("files.txt") do
  if line:find("%.") and line ~= "files.txt" and line ~= "any2webm.lua" then
    os.execute("ffmpeg -threads 1 -i \"" .. line .. "\" -threads 1 \"any2webm-output/" .. line .. ".webm\"")
  end
end

os.execute("rm files.txt")
