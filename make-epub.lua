#!/usr/bin/env luajit

local help = [[Usage:

  make-epub.lua <config (JSON file)> [action]

[action]: If not specified, all steps will be taken in order (except clean*).
            download:  All pages will be downloaded to their own HTML files.
            concat:    A file is created for each section out of its pages.
            convert:   Each section is converted to Markdown.
            markdown:  Metadata frontmatter and Markdown section files will be
                       concatenated into a single Markdown file.
            epub:      Markdown file will be converted to an ePub using pandoc.
            cleanhtml: All HTML files will be deleted, along with their extra
                       directories.
            cleanall:  Deletes everything except the ePub.

Requirements:
- Lua libraries: htmlparser, dkjson (or compatible)
- Binaries:      pandoc, curl

Configuration example(s):
  {
    "authors": ["Name"],
    "title": "Book",
    "keywords": ["erotica", "fantasy"],
    "base_url": "https://www.literotica.com/s/title-ch-",
    "first_section_url": "https://www.literotica.com/s/title",
    "sections": {
      "start": 1,
      "finish": 4,
      "naming": "Chapter"
    },
    "page_counts": [1, 5, 3, 3]
  }

  {
    "authors": ["Name"],
    "title": "Anthology",
    "keywords": ["LitErotica", "erotica"],
    "manually_specified_sections": true,
    "sections": [
      "https://www.literotica.com/s/unique-title",
      "https://www.literotica.com/s/another-title"
    ],
    "section_titles": [
      "Unique Title",
      "Another Title"
    ],
    "page_counts": [5, 2]
  }

  For an explanation of these examples, see the .lua-files README.
]]

local success, utility = pcall(function()
  return dofile((arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "utility-functions.lua")
end)
if not success then
  print("\n\n" .. tostring(utility))
  error("\n\nThis script may be installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n")
end

local json = utility.require("json")

-- TODO utility.path_separator should be a thing
local path_separator
if utility.OS == "Windows" then
  path_separator = "\\"
else
  path_separator = "/"
end

-- also checks for errors
-- TODO make it check for required elements and error if any are missing!
local function get_config()
  -- TODO arg checking REALLY should not be here
  if not arg[1] then
    print(help)
    error("\nA config file name/path must be specified.")
  elseif arg[1] == "-h" or arg[1] == "--help" then
    error(help) -- I strongly dislike using an error to print a help message instead of gracefully exiting..
  end

  local file, err = io.open(arg[1], "r")
  if not file then error(err) end
  config = json.decode(file:read("*a"))
  file:close()

  -- authors wasn't being loaded correctly and I accidentally fixed it while trying to find what was wrong..
  -- for k,v in pairs(config) do
  --   print(k,v)
  -- end
  -- print("config done")

  if not config.authors then
    config.authors = {} -- at least have an empty table so it doesn't error below
  end

  if config.author then -- old style single author will be prepended to authors list
    table.insert(config.authors, 1, config.author)
  end

  if not config.keywords then
    config.keywords = {} -- TODO test if it will work empty
  end

  -- detecting manually specified sections and flagging it to the rest of the script
  if config.sections[1] then
    config.sections.start = 1
    config.sections.finish = #config.sections
    config.manually_specified_sections = true -- decided to make this part of the config spec, but it's set here again just in case
    config.base_url = "http://example.com/"   -- must be defined to prevent errors; it will be manipulated and ignored in this use case
  end

  if not config.sections.start then
    config.sections.start = 1 -- the first one can be optional since the common use case is ALL OF THEM
  end

  if #config.page_counts ~= config.sections.finish - config.sections.start + 1 then
    error("Number of page_counts does not match number of sections.")
  end

  if config.section_titles and #config.section_titles ~= config.sections.finish - config.sections.start + 1 then
    error("Number of section_titles does not match number of sections.")
  end

  return config
end

local function format_metadata(config)
  local function stringify_list(list)
    local output = "\"" .. utility.escape_quotes(list[1]) .. "\""
    for i = 2, #list do
      output = output .. ", \"" .. utility.escape_quotes(list[i]) .. "\""
    end
    return output
  end

  local keywords_string = stringify_list(config.keywords)
  local metadata = {
    "---",
    "title: \"" .. utility.escape_quotes(config.title) .. "\"",
    "author: [" .. stringify_list(config.authors) .. "]",
    "keywords: [" .. keywords_string .. "]",
    "tags: [" .. keywords_string .. "]",
    "---",
    "",
  }

  return table.concat(metadata, "\n") .. "\n"
end

local function download_pages(config)
  local htmlparser = utility.require("htmlparser")
  utility.required_program("curl")

  os.execute("mkdir Sections")
  for section = config.sections.start, config.sections.finish do
    local section_dir = "Sections" .. path_separator .. tostring(section) .. path_separator
    os.execute("mkdir " .. section_dir:sub(1, -2))

    local section_url
    if section == 1 and config.first_section_url then
      section_url = config.first_section_url
    else
      section_url = config.base_url .. string.format("%02i", section) -- leftpad 2 (This will eventually cause problems.)
    end

    if config.manually_specified_sections then
      section_url = config.sections[section]
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
      local content_tag = parser:select(".article > div > div") -- TODO add ability to set selector in config!
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
  -- TODO move this function to utility
  local function make_safe_file_name(file_name)
    file_name = file_name:gsub("[%\"%:%\\%!%@%#%$%%%^%*%=%{%}%|%;%<%>%?%/]", "") -- everything except the &
    file_name = file_name:gsub(" %&", ",")   -- replacing & with a comma works for 99% of things
    file_name = file_name:gsub("%&", ",")    -- replacing & with a comma works for 99% of things
    file_name = file_name:gsub("[%s+]", " ") -- more than one space in succession should be a single space
    return file_name
  end

  local base_file_name
  if config.title and config.authors[1] then
    -- first author in list gets top billing (this is problematic in anthologies unless an editor is the first entry)
    base_file_name = config.title .. " by " .. config.authors[1]
  elseif config.title then
    base_file_name = config.title
  else
    base_file_name = "Book"
  end

  return make_safe_file_name(base_file_name)
end

local function convert_sections(config)
  utility.required_program("pandoc")
  for section = config.sections.start, config.sections.finish do
    local section_file_name = "Sections" .. path_separator .. tostring(section)
    os.execute("pandoc --from html --to markdown \"" .. section_file_name .. ".html\" -o \"" .. section_file_name .. ".md\"")
  end
end

local function write_markdown_file(config)
  local markdown_file, err = io.open(get_base_file_name(config) .. ".md", "w")
  if not markdown_file then error(err) end
  markdown_file:write(format_metadata(config))

  for section = config.sections.start, config.sections.finish do
    if config.sections.naming then
      markdown_file:write("\n\n# " .. config.sections.naming .. " " .. tostring(section))
    elseif config.section_titles then
      markdown_file:write("\n\n# " .. config.section_titles[section])
    end
    markdown_file:write("\n\n")

    local section_file_name = "Sections" .. path_separator .. tostring(section)
    local section_file, err = io.open(section_file_name .. ".md", "r")
    if not section_file then error(err) end
    markdown_file:write(section_file:read("*a"))
    section_file:close()
  end

  markdown_file:close()
end

local function make_epub(config)
  utility.required_program("pandoc")
  local base_file_name = get_base_file_name(config)
  os.execute("pandoc --from markdown --to epub \"" .. base_file_name .. ".md\" -o \"" .. base_file_name .. ".epub\" --toc=true")
end

local function rm_html_files(config)
  os.execute("sleep 1") -- attempt to fix #14

  for section = config.sections.start, config.sections.finish do
    local section_dir = "Sections" .. path_separator .. tostring(section)
    os.execute("rm " .. section_dir .. ".html")

    for page = 1, config.page_counts[section - (config.sections.start - 1)] do
      os.execute("rm " .. section_dir .. path_separator .. page .. ".html")
    end

    os.execute("rmdir " .. section_dir)
  end
end

local function rm_all(config)
  rm_html_files(config)

  for section = config.sections.start, config.sections.finish do
    local section_file_name = "Sections" .. path_separator .. tostring(section) .. ".md"
    os.execute("rm " .. section_file_name)
  end

  os.execute("rmdir Sections")
  os.execute("rm \"" .. get_base_file_name(config) .. ".md\"")
end

local execute = {
  download = download_pages,
  concat = concatenate_pages,
  convert = convert_sections,
  markdown = write_markdown_file,
  epub = make_epub,
  cleanhtml = rm_html_files,
  cleanall = rm_all,
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
  -- print("\nRemoving HTML files...\n")
  -- rm_html_files(config)
  print("\nDone!\n")
end
