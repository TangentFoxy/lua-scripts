#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

local media_extensions = { "mp4", "png", "jpg", "jpeg", "gif", "webm", }

os.execute("mkdir non-image")
utility.ls(".", function(file_name)
  local move_file = true
  local _, _, file_extension = utility.split_path_components(file_name)
  if file_extension then
    file_extension = file_extension:lower()
    for _, media_extension in ipairs(media_extensions) do
      if file_extension  == media_extension then
        move_file = false
        break
      end
    end
  end
  if move_file then
    -- I think mv works on windows though...
    os.execute(utility.commands.move .. file_name:enquote() .. "non-image/")
  end
end)
