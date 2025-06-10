#!/usr/bin/env luajit

-- INPUT: A URL to an author's page on LitErotica.
-- OUTPUT: A mostly-ready config for make-epub.lua based on all of that author's stories.
-- WARNING: Due to caching issues with LitErotica, this can miss entries you see, or include entries you don't see! :D
-- WARNING: Includes ALL series entries, and may include entries out of order (LitErotica doesn't always display these correctly).
-- Produces an extra list of series if the author has series listed. Outputs minified JSON, sorry.

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
  series = {}, -- not recognized by make-epub.lua, but useful to keep
  source_url = download_url, -- not a feature of make-epub, but useful to keep around
}

local temporary_html_file_name = utility.tmp_file_name()
os.execute("curl " .. download_url:enquote() .. " > " .. temporary_html_file_name)

-- NOTE this is hardcoded for literotica

utility.open(temporary_html_file_name, "r", "Could not download " .. download_url:enquote())(function(html_file)
  local raw_html = html_file:read("*all")
  local parser = htmlparser.parse(raw_html, 100000)

  config.authors[1] = parser:select("._header_title_dcvym_56")[1]:getcontent()
  -- config.title = parser:select(".headline")[1]:getcontent()
  config.title = config.authors[1] .. "'s Collected Works"

  local sections = parser:select("._item_title_zx1nh_223")
  for _, value in ipairs(sections) do
    local href = value.attributes.href
    if href:find("literotica%.com/series/se/") then -- series are saved in an extra list (that make-epub.lua doesn't understand)
      config.series[#config.series + 1] = href
    else
      config.sections[#config.sections + 1] = href
    end
  end
end)
os.execute("rm " .. temporary_html_file_name)

if not next(config.series) then config.series = nil end -- remove series if unused

-- save "final" config
config.base_file_name = utility.make_safe_file_name(config.base_file_name or config.title)
utility.open(config.base_file_name .. ".json", "w")(function(config_file)
  config_file:write(json.encode(config) .. "\n")
end)

if config.series then
  print("! SERIES WERE FOUND ON THIS PAGE !\n  These are included in sections, may not be in the right order,\n  and a separate list of series was also exported.")
end
-- print("! YOU MUST MANUALLY ADD THE CORRECT VALUES TO PAGE_COUNTS !")
