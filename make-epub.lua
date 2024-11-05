#!/usr/bin/env luajit

local help = [[Usage:

  make-epub.lua <config (JSON file)> [action]

[action]: If not specified, all steps will be taken in order.
            download: All pages will be downloaded to their own HTML files.
            concat:   A file will be created for each section out of its pages.
            convert:  Each section is converted to Markdown.
            markdown: Metadata frontmatter and Markdown section files will be
                      concatenated into a single Markdown file.
            epub:     Markdown file will be converted to an ePub using pandoc.

Requirements:
- Lua libraries: htmlparser, dkjson (or compatible)
- Binaries:      pandoc, curl

Configuration example:
  {
    "author": "Name",
    "title": "Book",
    "keywords": ["fantasy", "dragon", "isekai"],
    "base_url": "https://www.literotica.com/s/title-ch-",
    "first_section_url": "https://www.literotica.com/s/title",
    "sections": {
      "start": 1,
      "finish": 5,
      "naming": "Chapter"
    },
    "page_counts": [1, 5, 3]
  }
]]

local function checkreq(name, display)
  local success, library = pcall(function() return require(name) end)
  if not success then
    error("'" .. (display or name) .. "' missing or failed to load.")
  else
    return library
  end
end

-- local htmlparser = checkreq("htmlparser") -- so that this can be used for its non-HTML functions without htmlparser installed, this check is delayed
-- local cjson = checkreq('cjson', 'lua-cjson') -- I can't be bothered to figure out why I can't install CJSON on Windows right now
local cjson = require("json") -- TEMPORARY LOCAL WRONG NAME AAA
-- pandoc and curl are also required

local path_separator = "\\" -- temporarily hard-forcing Windows because it's being SUCH A PILE OF GARBAGE

-- also checks for errors
-- TODO make it check for required elements and error if any are missing!
local function get_config()
  if not arg[1] then
    print(help)
    error("\nA config file name/path must be specified.")
  elseif arg[1] == "-h" or arg[1] == "--help" then
    error(help)
  end

  local file, err = io.open(arg[1], "r")
  if not file then error(err) end
  config = cjson.decode(file:read("*a"))
  file:close()

  if #config.page_counts ~= config.sections.finish - config.sections.start + 1 then
    error("Number of page_counts does not match number of sections.")
  end

  return config
end

local function format_metadata(config)
  local function escape_quotes(str)
    return str:gsub("\"", "\\\"")
  end

  local function stringify_list(list)
    local output = "\"" .. escape_quotes(list[1]) .. "\""
    for i = 2, #list do
      output = output .. ", \"" .. escape_quotes(list[1]) .. "\""
    end
    return output
  end

  local keywords_string = stringify_list(config.keywords)
  local metadata = {
    "---",
    "title: \"" .. escape_quotes(config.title) .. "\"",
    "author:",
    "- \"" .. escape_quotes(config.author) .. "\"",
    "keywords: [" .. keywords_string .. "]",
    "tags: [" .. keywords_string .. "]",
    "---",
    "",
  }

  return table.concat(metadata, "\n") .. "\n"
end

local function download_pages(config)
  math.randomseed(os.time()) -- for randomized temporary file name and timings to avoid rate limiting
  -- local htmlparser = checkreq("htmlparser") -- despite being installed adjacent to this script, it is failing to load - turns out I was directed to the WRONG VERSION
  local htmlparser = require "htmlparser"
  -- TODO add check for curl here

  os.execute("mkdir Sections")
  for section = config.sections.start, config.sections.finish do
    local section_dir = "Sections" .. path_separator .. tostring(section) .. path_separator
    os.execute("mkdir " .. section_dir:sub(1, -2))

    local section_url
    if section == 1 and config.first_section_url then
      section_url = config.first_section_url
    else
      section_url = config.base_url .. string.format("%02i", section) -- leftpad 2
    end

    for page = 1, config.page_counts[section - (config.sections.start - 1)] do
      local download_url
      if page == 1 then
        download_url = section_url
      else
        download_url = section_url .. "?page=" .. tostring(page)
      end

      local html_file_name = ".tmp." .. tostring(math.random()) .. ".html"
      os.execute("curl \"" ..download_url .. "\" > " .. html_file_name)

      local html_file, err = io.open(html_file_name, "r")
      if not html_file then error("Could not download \"" .. download_url .. "\"") end
      local raw_html = html_file:read("*a")
      html_file:close()
      os.execute("rm " .. html_file_name)

      local parser = htmlparser.parse(raw_html)
      local content_tag = parser:select(".article > div > div") -- TODO add other selectors!
      local text = content_tag[1]:getcontent()

      local page_file, err = io.open(section_dir .. page .. ".html", "w")
      if not page_file then error(err) end
      page_file:write(text .. "\n")
      page_file:close()

      os.execute("sleep " .. tostring(math.random(5))) -- avoid rate limiting
    end
  end
end

local function concatenate_pages(config)
  for section = config.sections.start, config.sections.finish do
    local section_dir = "Sections" ..path_separator .. tostring(section) .. path_separator
    local section_file, err = io.open("Sections" .. path_separator .. tostring(section) .. ".html", "w")
    if not section_file then error(err) end

    for page = 1, config.page_counts[section - (config.sections.start - 1)] do
      local page_file, err = io.open(section_dir .. page .. ".html", "r")
      if not page_file then error(err) end
      section_file:write(page_file:read("*a") .. "\n")
      page_file:close()
    end
  end
end

local function get_base_file_name(config)
  local function make_safe_file_name(file_name)
    file_name = file_name:gsub("[%\"%:%\\%!%@%#%$%%%^%*%=%{%}%|%;%<%>%?%/]", "") -- everything except the &
    file_name = file_name:gsub(" %&", ",")   -- replacing & with a comma works for 99% of things
    file_name = file_name:gsub("%&", ",")    -- replacing & with a comma works for 99% of things
    file_name = file_name:gsub("[%s+]", " ") -- more than one space in succession should be a single space
    return file_name
  end

  local base_file_name
  if config.title and config.author then
    base_file_name = config.title .. " by " .. config.author
  elseif config.title then
    base_file_name = config.title
  else
    base_file_name = "Book"
  end

  return make_safe_file_name(base_file_name)
end

local function convert_sections(config)
  for section = config.sections.start, config.sections.finish do
    local section_file_name = "Sections" .. path_separator .. tostring(section)
    os.execute("pandoc \"" .. section_file_name .. ".html\" -o \"" .. section_file_name .. ".md\"")
  end
end

local function write_markdown_file(config)
  local markdown_file, err = io.open(get_base_file_name(config) .. ".md", "w")
  if not markdown_file then error(err) end
  markdown_file:write(format_metadata(config))

  for section = config.sections.start, config.sections.finish do
    markdown_file:write("\n\n# " .. config.sections.naming .. " " .. tostring(section) .. "\n\n")

    local section_file_name = "Sections" .. path_separator .. tostring(section)
    local section_file, err = io.open(section_file_name .. ".md", "r")
    if not section_file then error(err) end
    markdown_file:write(section_file:read("*a"))
    section_file:close()
  end

  markdown_file:close()
end

local function make_epub(config)
  -- TODO check for pandoc being installed
  local base_file_name = get_base_file_name(config)
  os.execute("pandoc \"" .. base_file_name .. ".md\" -o \"" .. base_file_name .. ".epub\" --toc=true")
end

local execute = {
  download = download_pages,
  concat = concatenate_pages,
  convert = convert_sections,
  markdown = write_markdown_file,
  epub = make_epub,
}

local config = get_config()

local action = arg[2]
if action then
  if execute[action] then
    execute[action](config)
  else
    print(help)
  end
else
  print("\nDownloading pages...\n")
  download_pages(config)
  print("\nConcatenating pages...\n")
  concatenate_pages(config)
  print("\nConverting sections...\n")
  convert_sections(config)
  print("\nWriting Markdown file...\n")
  write_markdown_file(config)
  print("\nMaking ePub...\n")
  make_epub(config)
  print("\nDone!\n")
end
