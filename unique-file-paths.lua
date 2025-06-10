#!/usr/bin/env luajit

-- Partially written by ChatGPT using GPT-3.5, with corrections and modifications by me.
-- Do whatever the hell you want with it.

-- Note: For some reason, "." is always detected as a duplicated path in all directories selected.

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

local subpaths = {} -- a hashtable of all unique subpaths
for path_start, full_path_table in pairs(paths) do
  for path in pairs(full_path_table) do
    local local_path = "." .. path:sub(#path_start + 1)
    subpaths[local_path] = true
  end
end

for subpath in pairs(subpaths) do
  local known_paths = {}
  local paths_found = 0
  for path_start, full_path_table in pairs(paths) do
    local global_path = path_start .. subpath:sub(2)
    if full_path_table[global_path] then
      paths_found = paths_found + 1
      known_paths[global_path] = true
    end
  end
  if paths_found == 1 then
    -- print("UNIQUE: " .. next(known_paths))
    local _ = nil
  else
    local output_text = {}
    for global_path in pairs(known_paths) do
      table.insert(output_text, global_path)
    end
    print(subpath .. " exists " .. paths_found .." times!\n" .. table.concat(output_text, "\n")) -- the extra \n at the end is kept intentionally
  end
end
