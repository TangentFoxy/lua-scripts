#!/usr/bin/env luajit

-- created referencing https://github.com/JCGdev/Newpipe-CSV-Fixer/blob/main/images/example.png
--  and https://juandarr.github.io/json-youtube-export/ for formatting

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local json = require "dkjson"
local argparse = utility.require("argparse")

local parser = argparse():description("Convert invidious JSON export format to NewPipe JSON export format, badly."):help_max_width(80)
parser:argument("input", "input file name"):args(1)
parser:argument("output", "output file name (default: newpipe-subscriptions.json)"):args("?") -- argparse defaults don't work :D
local options = parser:parse()

if not options.output then
  options.output = "newpipe-subscriptions.json"
end

local input = utility.open(options.input, "r", function(file)
  return json.decode(file:read("*all"))
end)

local output = {
  app_version = "0.21.9",
  app_version_int = 975,
  subscriptions = {},
}

for _, identifier in ipairs(input.subscriptions) do
  output.subscriptions[#output.subscriptions + 1] = {
    service_id = identifier,
    url = "https://www.youtube.com/channel/" .. identifier,
    name = "N/A",   -- hopefully this doesn't matter
  }
end

utility.open(options.output, "w", function(file)
  file:write(json.encode(output, { indent = true }))
  file:write("\n")
end)
