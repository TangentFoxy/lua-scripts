#!/usr/bin/env luajit

-- Partially written by ChatGPT using GPT-3.5, with corrections and modifications by me.
-- Do whatever the hell you want with it.

local lfs = require "lfs"

-- Function to get the filesize of a given file
local function get_filesize(filepath)
  local file = io.open(filepath, "rb")
  if file then
    local size = file:seek("end")
    file:close()
    return size
  else
    return nil
  end
end

-- Function to recursively traverse directories, get file sizes, and file paths
local function traverse_directory(path)
  local files = {}

  for entry in lfs.dir(path) do
    if entry ~= "." and entry ~= ".." then
      local full_path = path..'\\'..entry
      local attributes = lfs.attributes(full_path)

      if attributes and attributes.mode == "file" then
        local size = get_filesize(full_path)

        if size then
          -- print(full_path, size, "bytes")
          files[full_path] = size
        else
          print("File not found or inaccessible:", full_path)
        end
      elseif attributes and attributes.mode == "directory" then
        local subdir_files = traverse_directory(full_path)
        for path, size in pairs(subdir_files) do
          files[path] = size
        end
      end
    end
  end

  return files
end



local paths = {} -- becomes a hashtable of hashtables of full_path = file_size
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
  -- check each full path for matching size (we assume its the same file if its the same size AND name)
  local sizes = {}
  local known_size = nil
  local paths_checked = 0
  for path_start, full_path_table in pairs(paths) do
    local global_path = path_start .. subpath:sub(2)
    local size = full_path_table[global_path]
    if size then
      sizes[global_path] = size
      if not known_size then
        known_size = size
      elseif known_size ~= size then
        known_size = math.inf -- we signal with an impossible size that all sizes do not match
      end
      paths_checked = paths_checked + 1
    end
  end
  if known_size == math.inf then
    local output_text = {}
    for global_path, size in pairs(sizes) do
      table.insert(output_text, global_path .. ": " .. size .. " bytes")
    end
    print(subpath .. " has different sizes!\n" .. table.concat(output_text,"\n") .. "\n")
  elseif paths_checked < 2 then
    -- print(subpath .. " is unique!\n" .. next(sizes) .. "\n")
    print(next(sizes) .. " is unique!\n")
  end
end
