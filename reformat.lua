#!/usr/bin/env luajit

local helptext = [[Usage:

  reformat.lua <title> <author>

PowerShell: Quotes will be turned into a single argument. Backslashes don't
            escape spaces.
]]

local title, author
if #arg ~= 2 then
  print(helptext)
  return false
else
  title = arg[1]
  author = arg[2]
end

os.execute("dir /w /b > files.txt")
-- os.execute("touch .reformatted.md")
os.execute("mkdir output-files")
os.execute("mkdir output-files\\epub")
os.execute("mkdir output-files\\md")

local file
local current_line_count = 0
local lines_per_volume_target = 18000 -- no hard limit to avoid cutting in the middle of an episode; this limit led to 330 to 415 pages across 25 volumes
local current_volume = 1

local titles = {}
pcall(function()
  for line in io.lines("VIDEO-TITLES.txt") do
    local split = line:find("=")
    if split then
      titles[line:sub(1, split - 1)] = line:sub(split + 1)
    end
  end
end)

local function format_and_output_file(file_name)
  local id = file_name:sub(1, -5)
  local output_title = id
  if titles[id] then
    output_title = titles[id]
  end
  file:write("# " .. output_title .. "\n\n")
  local lines = {}
  local max_line_length = 0

  -- strip extra spaces, find the maximum line length
  for line in io.lines(file_name) do
    local line_length = #line
    if line_length > 0 then
      table.insert(lines, line)
    end
    if line_length > max_line_length then
      max_line_length = line_length
    end
  end

  -- try to make reasonable assumptions about paragraphs
  local paragraph_lines_length_target = 4
  local maximum_paragraph_lines = 24
  local current_paragraph_line_count = 0

  for line_number, line in ipairs(lines) do
    local line_length = #line
    if line_number == #lines then
      file:write(line .. "\n\n")
    else
      file:write(line .. " ")
    end
    current_paragraph_line_count = current_paragraph_line_count + 1
    if current_paragraph_line_count >= maximum_paragraph_lines then
      file:write("\n\n")
      current_paragraph_line_count = 0
    elseif line:sub(-1) == "." then
      if line_length < max_line_length / 2 or current_paragraph_line_count >= paragraph_lines_length_target then
        file:write("\n\n")
        current_paragraph_line_count = 0
      end
    end
  end

  file:write("\n\n")
  return #lines
end

local function end_book()
  file:close()
  current_line_count = 0
  local full_title = title .. ", vol." .. current_volume
  os.execute("pandoc ./.reformatted.md -o \"./output-files/epub/" .. full_title .. ".epub\" --metadata title=\"" .. full_title .. "\" --metadata author=\"" .. author .. "\" --toc=true")
  os.execute("mv ./.reformatted.md \"./output-files/md/" .. full_title .. ".md\"")
  current_volume = current_volume + 1
  file = io.open(".reformatted.md", "w")
end

file = io.open(".reformatted.md", "w")

for file_name in io.lines("files.txt") do
  if file_name ~= "files.txt" and file_name:find("%.txt") and file_name ~= "VIDEO-TITLES.txt" then
    current_line_count = current_line_count + format_and_output_file(file_name)
  end
  if current_line_count >= lines_per_volume_target then
    end_book()
  end
end

if current_line_count ~= 0 then
  end_book()
else
  file:close()
  os.execute("rm .reformatted.md")
end

os.execute("rm files.txt")
