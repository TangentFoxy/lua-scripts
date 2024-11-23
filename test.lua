#!/usr/bin/env luajit

local success, utility = pcall(function()
  return dofile((arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "utility-functions.lua")
end)
if not success then
  print("\n\n" .. tostring(utility))
  error("\n\nThis script may be installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n")
end

local htmlparser = utility.require("htmlparser")
utility.open("test.html", "r")(function(html_file)
  local raw_html = html_file:read("*all")

  local parser = htmlparser.parse(raw_html)
  -- local parser = htmlparser.parse(raw_html, 100000)
  local content_tag = parser:select("div#workskin")
  print(content_tag, content_tag[1])

  local text = content_tag[1]:getcontent()
end)
