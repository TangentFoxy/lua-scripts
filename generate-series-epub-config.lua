#!/usr/bin/env luajit

-- INPUT: A URL to a series page on LitErotica.
-- OUTPUT: A mostly-ready config for make-epub.lua based on that series.
-- Unfortunately, will produces minified JSON.

local success, utility = pcall(function()
  return dofile((arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "utility-functions.lua")
end)
if not success then
  print("\n\n" .. tostring(utility))
  error("\n\nThis script may be installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n")
end

local htmlparser = utility.require("htmlparser")
local json = utility.require("json")

local download_url = arg[1]
local config = {
  authors = {},
  sections = {},
  extract_titles = true,
  automatic_naming = true,
  -- page_counts = {}, -- using discover_page_counts now!
  discover_page_counts = true,
  source_url = download_url, -- not a feature of make-epub, but useful to keep around
}

local temporary_html_file_name = utility.tmp_file_name()
os.execute("curl " .. download_url:enquote() .. " > " .. temporary_html_file_name)

-- NOTE this is hardcoded for literotica

utility.open(temporary_html_file_name, "r", "Could not download " .. download_url:enquote())(function(html_file)
  local raw_html = html_file:read("*all")
  local parser = htmlparser.parse(raw_html, 100000)

  config.authors[1] = parser:select(".y_eS > .y_eU")[1]:getcontent()
  config.title = parser:select(".headline")[1]:getcontent()
  config.title = config.title:gsub("&#x27;", "'")

  local sections = parser:select(".series__works > .br_ri")
  for index, value in ipairs(sections) do
    config.sections[index] = value:select(".br_rj")[1].attributes.href
  end
end)
os.execute("rm " .. temporary_html_file_name)

-- save "final" config
config.base_file_name = utility.make_safe_file_name(config.base_file_name or (config.title .. " by " .. config.authors[1]))
utility.open(config.base_file_name .. ".json", "w")(function(config_file)
  config_file:write(json.encode(config) .. "\n")
end)

-- print("! YOU MUST MANUALLY ADD THE CORRECT VALUES TO PAGE_COUNTS !")
