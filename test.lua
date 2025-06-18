#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

-- NOTE add current test case here
local file_name = "/some/path/file.ext"
local path, name, extension = utility.split_path_components(file_name)
print(path, name, extension)
print(name:sub(1, -(#extension + 2)))
