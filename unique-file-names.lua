#!/usr/bin/env luajit

-- Partially written by ChatGPT using GPT-3.5, with corrections and modifications by me.
-- Do whatever the hell you want with it.

local lfs = require "lfs"

-- Function to recursively traverse directories, get file paths
local function traverse_directory(path)
  local files = {}

  for entry in lfs.dir(path) do
    if entry ~= "." and entry ~= ".." then
      local full_path = path..'\\'..entry
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
