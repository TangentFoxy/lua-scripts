#!/usr/bin/env luajit

-- Partially written by ChatGPT using GPT-3.5, with fixes/mods by Tangent Fox.
-- Do whatever the hell you want with it.

-- Previously only tested on Windows.
-- Now should work on any system, even if LuaFileSystem isn't installed!

local path_separator = package.config:sub(1, 1)

local success, lfs = pcall(function() return require "lfs" end)

if not success then
  math.randomseed(os.time())

  local system
  if path_separator == "\\" then
    system = {
      temp = "C:\\Windows\\Temp\\",
      list = "dir /w /b",
    }
  else
    system = {
      temp = "/tmp/",
      list = "ls -1a",
    }
  end

  lfs = {
    dir = function(path)
      local file_name = system.temp .. math.random()
      os.execute(system.list .. " \"" .. path .. "\" > \"" .. file_name .. "\"")
      local file = io.open(file_name, "r")
      local output = file:read("*all")
      file:close()
      os.execute("rm \"" .. file_name .. "\"")
      return output:gmatch("[^\r\n]+")
    end,
    attributes = function(path)
      local file = io.open(path, "r")
      if file then
        local _, error_message = file:read(1) -- defaults to reading a whole line, so we read 1 byte instead
        file:close()
        if error_message == "Is a directory" then
          return { mode = "directory" }
        end
        return { mode = "file" }
      else
        return { mode = "directory" }
      end
    end,
  }
end



-- Function to recursively traverse directories, get file paths
local function traverse_directory(path)
  local files = {}

  for entry in lfs.dir(path) do
    if entry ~= "." and entry ~= ".." then
      local full_path = path .. path_separator .. entry
      local attributes = lfs.attributes(full_path)

      if attributes and attributes.mode == "file" then
        files[path] = true

      elseif attributes and attributes.mode == "directory" then
        local subdir_files = traverse_directory(full_path)
        for path in pairs(subdir_files) do
          files[path] = true
        end
      end
    end
  end

  return files
end



local paths = {} -- becomes a hashtable of hashtables of full_path = true
for _, path in ipairs(arg) do
  -- powershell handles quotes, so I assume each argument is a full valid path
  paths[path] = traverse_directory(path)
end

local file_names = {} -- a hashtable of unique file names, numerical values indicating how many times the file name exists
for path_start, full_path_table in pairs(paths) do
  for path in pairs(full_path_table) do
    local current_name = path:match("^[.+\\]*(.+)$") -- not sure if this is correct :D
    if file_names[current_name] then
      file_names[current_name] = file_names[current_name] + 1
    else
      file_names[current_name] = 1
    end
  end
end

for current_name, occurrences in pairs(file_names) do
  if occurrences ~= 1 then
    print(current_name .. " occurs " .. occurrences .. " times!")
  end
end
