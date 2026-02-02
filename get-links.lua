#!/usr/bin/env luajit
math.randomseed(os.time())

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local argparse = utility.require("argparse")
local htmlparser = utility.require("htmlparser")
local json = utility.require("dkjson")

local parser = argparse():description("Get all links from a URL (and optionally add them to a JSON file)."):help_max_width(80)
parser:argument("url", "The URL"):args(1)
parser:argument("json", "A JSON file to add the links to."):args("?")

local options = parser:parse()

local extant_links = {}
if options.json and utility.path_exists(options.json) then
  utility.open(options.json, "r", function(file)
    extant_links = json.decode(file:read("*all"))
  end)
end

local text = utility.curl_read(options.url)
local root = htmlparser.parse(text)

local links = root:select("a")

local domain
local breakpoint = options.url:find("/", 10)

if breakpoint then
  domain = options.url:sub(1, breakpoint - 1)
else
  domain = options.url
end

for _, a in ipairs(links) do
  local href = a.attributes and a.attributes.href
  if href then
    if href:sub(1, 1) == "/" then
      href = domain .. href
    end
    if extant_links[href] == nil then -- only add entries that don't exist!
      extant_links[href] = true
    end
  end
end

if options.json then
  utility.open(options.json, "w", function(file)
    file:write(json.encode(extant_links, { indent = true }))
    file:write("\n")
  end)
else
  for url in pairs(extant_links) do
    print(url)
  end
end
