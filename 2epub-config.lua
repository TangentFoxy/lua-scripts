#!/usr/bin/env luajit

-- this script only works for LitErotica.com
--   replaces the generate scripts, can take a list of individual stories to make an anthology, an authors' works page, or a series page
--   author works are further split into series and a "Collected Works" for one-shots, unless a 2nd argument is passed

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

local htmlparser = utility.require("htmlparser")
local json = utility.require("json")

local base_config = {
  authors = {},
  sections = {},
  extract_titles = true,
  automatic_naming = true,
  discover_page_counts = true,
}
local config = utility.deepcopy(base_config) -- I know, I know, I'm doing state management (wrong)

local url_patterns = {
  series = "literotica%.com/series/se/",
  author = "literotica%.com/authors/",
  single = "literotica%.com/s/",
}

local function save()
  if #config.sections == 0 then
    print("! WARNING: Exporting a config with no sections. !\n  " .. config.base_file_name:enquote())
  end
  utility.open(config.base_file_name .. ".json", "w")(function(file)
    file:write(json.encode(config) .. "\n")
  end)
end

local function get_parser_from_url(download_url)
  local parser
  local temporary_html_file_name = utility.tmp_file_name()
  os.execute("curl " ..download_url:enquote() .. " > " .. temporary_html_file_name)
  utility.open(temporary_html_file_name, "r", "Could not download " .. download_url:enquote())(function(file)
    local raw_html = file:read("*all")
    parser = htmlparser.parse(raw_html, 100000)
  end)
  os.execute("rm " ..temporary_html_file_name)
  return parser
end

local function anthology(file_name)
  local _, _, extension = utility.split_path_components(file_name) -- extract base_file_name
  config.base_file_name = file_name
  if extension then
    config.base_file_name = file_name:sub(1, -(#extension+2)) -- TODO fix this, seems to be adding ".\\" or ".\" in front ?
  end
  config.title = config.base_file_name -- fallback title

  config.authors[1] = "Multiple Authors"
  config.extract_titles = nil
  config.section_titles = {}
  local unique_authors = {}

  utility.open(file_name, "r")(function(file)
    local download_url = file:read("*line")

    -- if not a URL, it's "the" title
    if download_url:sub(1, 4) ~= "http" then
      config.title = download_url
      download_url = file:read("*line")
    end

    while download_url do
      if #download_url > 0 then
        local parser = get_parser_from_url(download_url)

        local author = parser:select(".y_eS > .y_eU")[1]:getcontent()
        if not unique_authors[author] then
          table.insert(config.authors, author)
          unique_authors[author] = true
        end
        table.insert(config.sections, download_url)
        local section_title = parser:select(".headline")[1]:getcontent():gsub("&#x27;", "'")
        table.insert(config.section_titles, section_title)

        os.execute("sleep " .. tostring(math.random(5)))
      end

      download_url = file:read("*line")
    end
  end)

  if #config.authors == 2 then -- if single author, remove "Multiple Authors"
    table.remove(config.authors, 1)
  end

  save()
end

local function series(download_url)
  config.source_url = download_url

  local parser = get_parser_from_url(download_url)

  config.authors[1] = parser:select(".y_eS > .y_eU")[1]:getcontent()
  config.title = parser:select(".headline")[1]:getcontent():gsub("&#x27;", "'"):gsub("&amp;", "&"):gsub("’", "'")

  local sections = parser:select(".series__works > .br_ri")
  for index, value in ipairs(sections) do
    config.sections[index] = value:select(".br_rj")[1].attributes.href
  end

  config.base_file_name = utility.make_safe_file_name(config.title:gsub("&", "and") .. " by " .. config.authors[1])
  save()
end

local function single(download_url)
  config.source_url = download_url

  local parser = get_parser_from_url(download_url)

  config.authors[1] = parser:select(".y_eS > .y_eU")[1]:getcontent()
  config.title = parser:select(".headline")[1]:getcontent():gsub("&#x27;", "'"):gsub("&amp;", "&"):gsub("’", "'")

  config.sections[1] = download_url

  config.base_file_name = utility.make_safe_file_name(config.title:gsub("&", "and") .. " by " .. config.authors[1])
  save()
end

local function author(download_url, all_in_one)
  config.series = {}
  config.source_url = download_url

  local parser = get_parser_from_url(download_url)
  config.authors[1] = parser:select("._header_title_1rw38_66")[1]:getcontent() -- commit 1127e75 should have been this
  -- config.title = parser:select(".headline")[1]:getcontent() -- NOTE doesn't work, not sure why
  config.title = "Collected Works of " .. config.authors[1]

  local sections = parser:select("._item_title_zx1nh_223")
  for _, value in ipairs(sections) do
    local section_url = value.attributes.href
    if section_url:find(url_patterns.series) then -- series saved in extra list
      table.insert(config.series, section_url)
    else
      table.insert(config.sections, section_url)
    end
  end

  config.base_file_name = utility.make_safe_file_name(config.title)

  if next(config.series) then
    if all_in_one then
      print("! SERIES MAY NOT BE HANDLED CORRECTLY !")
    else
      -- this is VERY hack
      local original_config = config
      local sections_to_remove = {}
      for _, section_url in ipairs(original_config.series) do
        -- os.execute("lua " .. arg[0] .. " " .. section_url:enquote()) -- can't look into the sub-configs this way! we don't know their file names
        config = utility.deepcopy(base_config)
        series(section_url)
        os.execute("sleep " .. math.random(5))
        for _, extra_url in ipairs(config.sections) do
          sections_to_remove[extra_url] = true
        end
      end
      config = original_config
      for i = #config.sections, 1, -1 do
        if sections_to_remove[config.sections[i]] then
          table.remove(config.sections, i)
        end
      end
      config.series_removed = true -- I just think it'll be useful to have this reminder
    end
  else
    config.series = nil
  end

  save()
end

-- main
local source, split = arg[1], arg[2]
if utility.file_exists(source) then
  anthology(source)
elseif source:find(url_patterns.author) then
  if not source:find("/works/stories") then
    error(source .. " is missing /works/stories")
    -- /all pages redirect away from themselves, eliminating the point of having that be a URL endpoint..
  end
  author(source, split)
elseif source:find(url_patterns.series) then
  series(source)
elseif source:find(url_patterns.single) then
  single(source)
else
  error("\n\n Could not parse input! \n\n")
end
