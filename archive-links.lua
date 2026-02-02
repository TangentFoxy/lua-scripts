#!/usr/bin/env luajit
math.randomseed(os.time())

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local argparse = utility.require("argparse")
local json = utility.require("dkjson")

local parser = argparse():description("Takes a JSON file of links and uses archiving services to preserve them."):help_max_width(80)
parser:argument("json", "The JSON file."):args(1)

local options = parser:parse()

local links = utility.open(options.json, "r", function(file)
  return json.decode(file:read("*all"))
end)

local blacklist = {   -- these are URLs which are themselves archives
  "://web%.archive%.org/web/",
  "://archive%.is/",
  "://preservetube%.com/watch%?v%=",
  "://ghostarchive%.org/archive/",
}

local concurrency, iteration = 4, 0   -- used to slow rate of opening links

local link_count = 0
for _ in pairs(links) do
  link_count = link_count + 1
end

local day = os.date("%Y-%m-%d")   -- don't repeat archives on the same day

local urls_tried = {}   -- URLs to try in Internet Archive after main loop

for url, value in pairs(links) do
  local function quick_archive()
    if not value then
      return
    end

    if type(value) ~= "table" then
      value = {}
      links[url] = value
    end

    if value.blacklisted or value.disabled then
      return
    end
    if value.last_attempt == day then
      return
    end

    for _, fragment in ipairs(blacklist) do
      if url:find(fragment) then
        print(url:enquote() .. " cannot be archived, marking it as such.")
        value.blacklisted = true
        return
      end
    end

    if url:find("://youtube.com/watch?v=") then
      value.preservetube_export = true
    end

    if value.preservetube_export then
      os.execute("open " .. ("https://preservetube.com/save?url=" .. url):enquote())
    else
      urls_tried[#urls_tried + 1] = url -- this is so Internet Archive can be started after the initial loop
    end

    os.execute("open " .. ("https://archive.is/submit/?url=" .. url):enquote())

    value.last_attempt = day

    iteration = iteration + 1
    if iteration % concurrency == 0 then
      print(iteration .. "/" .. link_count .. " opened. Press enter to continue.")
      io.read("*line")
    end
  end

  quick_archive()
end

-- because Internet Archive is much slower, we save now and don't worry about how well it goes
utility.open(options.json, "w", function(file)
  file:write(json.encode(links, { indent = true }))
  file:write("\n")
end)

for index, url in ipairs(urls_tried) do
  print("Archiving " .. index .. "/" .. #urls_tried .. "...")
  local command = "spn.sh -qns -f ./data "
  if access_key then
    command = command .. "-a " .. access_key:enquote() .. " "
  end
  os.execute(command .. url)
end
