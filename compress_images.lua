#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

local image_extensions = { "png", "jpg", "jpeg", "gif", }

os.execute("mkdir compressed-images")
utility.ls(".", function(file_name)
  local process_file = false
  local _, bare_file_name, file_extension = utility.split_path_components(file_name)
  if file_extension then
    file_extension = file_extension:lower()
    for _, extension in ipairs(image_extensions) do
      if file_extension  == extension then
        process_file = true
        break
      end
    end
  end
  if process_file then
    os.execute("magick " file_name:enquote() .. " -quality 75 " .. ("compressed-images/" .. bare_file_name:sub(1, -(#file_extension + 2)) .. ".jpg"):enquote())
  end
end)
