#!/usr/bin/env luajit

-- OS must be detected to choose list and move commands
local ls, move
if package.config:sub(1,1) == "\\" then
  ls = "dir /w /b > files.txt"
  move = "move"
else
  ls = "ls -1 > files.txt"
  move = "mv"
end

os.execute(ls)

local file = io.open("files.txt")
local created = {}

-- put in table of tables (folder organization)
-- go through whole structure making folders and moving files
for line in file:lines() do
  if line:find("%.MP4") then
    local folder = tonumber(line:sub(9-3, 9-1)) -- sequence number
    if not created[folder] then
      created[folder] = true
      os.execute("mkdir "..folder)
    end
    os.execute(move .. " "..line.." "..folder)
  end
end

os.remove("files.txt")
