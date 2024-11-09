#!/usr/bin/env luajit

local success, utility = pcall(function()
  return dofile((arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "utility-functions.lua")
end)
if not success then
  print("\n\n" .. tostring(utility))
  error("\n\nThis script may be installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n")
end

local htmlparser = utility.require("htmlparser")
utility.open("TEST.html", "r")(function(html_file)
  local raw_html = html_file:read("*all")

  local parser = htmlparser.parse(raw_html)
  local content_tag = parser:select(".article > div > div") -- TODO add ability to set selector in config!
  local text = content_tag[1]:getcontent()

  local title_tag = parser:select(".headline")
  print(title_tag[1]:gettext())
end)
