#!/usr/bin/env luajit
math.randomseed(os.time())

local version = "0.1.0"

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local argparse = utility.require("argparse")

utility.required_program("magick")
utility.required_program("pandoc")

local parser = argparse():description("Make an ebook of images from a folder full of sequentially named files."):help_max_width(80)
parser:argument("title", "Title of resultant ebook."):args(1)
parser:argument("author", "Author of resultant ebook."):args(1)

local options = parser:parse()

local lines = {
  "---",
  "title: " .. utility.escape_quotes_and_escapes(options.title):enquote(),
  "author: [" .. utility.escape_quotes_and_escapes(options.author):enquote() .. "]",
  "publisher: " .. ("comic_builder.lua/" .. version):enquote(),
  "---",
  "",
}

os.execute("mkdir raw_images")
os.execute("mkdir processed_images")

print("Press enter after images have been placed in 'raw_images'. ")
io.read("*line")

utility.ls("raw_images")(function(file_name)
  local _, _, file_extension = utility.split_path_components(file_name)
  local base_name = file_name:sub(1, -#file_extension-2)

  if file_extension == "jpg" or file_extension == "jpeg" or file_extension == "png" then
    local export_file_name = "processed_images/" .. base_name .. ".jpg"
    if not utility.is_file(export_file_name) then
      os.execute("magick " .. ("raw_images" .. utility.path_separator .. file_name):enquote() .. " -quality 50% " .. export_file_name:enquote())
      lines[#lines + 1] = "![](" .. export_file_name .. ")"
    end
  elseif file_extension == "gif" then
    os.execute("cp raw_images" .. utility.path_separator .. file_name .. " processed_images" .. utility.path_separator .. file_name)
    lines[#lines + 1] = "![](processed_images/" .. file_name .. ")"
  end
end)

utility.open("text.md", "w", function(file)
  file:write(table.concat(lines, "\n"))
  file:write("\n")
end)

os.execute("pandoc text.md -o ebook.epub")
