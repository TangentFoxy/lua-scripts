#!/usr/bin/env luajit

local help = [[Usage:

  make-epub.lua <config (JSON file)> [action]

If "." is used instead of a JSON file, every JSON file in the current directory
will be used to make multiple ebooks back-to-back.

[action]: If not specified, all steps will be taken in order (except cleanall).
            download:  All pages will be downloaded to their own HTML files.
            convert:   Each page is converted to Markdown.
            concat:    A file is created for each section out of its pages.
            markdown:  Metadata frontmatter and Markdown section files will be
                       concatenated into a single Markdown file.
            epub:      Markdown file will be converted to an ePub using pandoc.
            cleanpage: All page files will be deleted, along with their extra
                       directories.
            cleanall:  Deletes everything except the config file and ePub.

Requirements:
- Lua libraries: htmlparser, dkjson (or compatible)
- Binaries:      pandoc, curl

For how to write a configuration and examples, see the .lua-files README:
  https://github.com/TangentFoxy/.lua-files#make-epublua
]]

local success, utility = pcall(function()
  return dofile((arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "utility-functions.lua")
end)
if not success then
  print("\n\n" .. tostring(utility))
  error("\n\nThis script may be installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n")
end

local path_separator = utility.path_separator
local copyright_warning = "This ebook was created by an automated tool for personal use. It cannot be distributed or sold without permission of copyright holder(s). (If you did not make this ebook, you may be infringing.)\n\n"

-- also checks for errors TODO make it check for ALL required elements and error if any are missing!
local function load_config(config_file_text)
  local json = utility.require("json")

  config = json.decode(config_file_text)
  config.config_file_text = config_file_text

  if not config.authors then
    config.authors = {} -- at least have an empty table so it doesn't error below TODO verify that this is actually true
  end

  if not config.keywords then
    config.keywords = {} -- TODO test if it will work empty
  end

  if config.author then -- old style single author will be prepended to authors list
    table.insert(config.authors, 1, config.author)
  end

  -- if only using a single section
  if config.first_section_url and not config.base_url then
    config.base_url = config.first_section_url -- prevent errors due to required item being missing
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
  -- TODO use enquote
  local function stringify_list(list)
    local output = utility.escape_quotes(list[1]):enquote()
    for i = 2, #list do
      output = output .. ", " .. utility.escape_quotes(list[i]):enquote()
    end
    return output
  end

  local keywords_string = stringify_list(config.keywords)
  local metadata = {
    "---",
    "title: " .. utility.escape_quotes(config.title):enquote(),
    "author: [" .. stringify_list(config.authors) .. "]",
    "keywords: [" .. keywords_string .. "]",
    "tags: [" .. keywords_string .. "]",
    "---",
    "",
  }

  return table.concat(metadata, "\n") .. "\n"
end

-- TODO since this is called many times across the program, make load_config SET this within the config and use that instead!
local function get_base_file_name(config)
  -- TODO move make_safe_file_name to utility
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

  return make_safe_file_name(config.base_file_name or base_file_name)
end

local function download_pages(config)
  local htmlparser = utility.require("htmlparser")
  utility.required_program("curl")
  local working_dir = get_base_file_name(config)

  os.execute("mkdir " .. working_dir:enquote())
  for section = config.sections.start, config.sections.finish do
    local section_dir = working_dir .. path_separator .. tostring(section) .. path_separator
    os.execute("mkdir " .. section_dir:sub(1, -2):enquote())

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

      local temporary_html_file_name = utility.tmp_file_name()
      os.execute("curl " .. download_url:enquote() .. " > " .. temporary_html_file_name)

      local html_file, err = io.open(temporary_html_file_name, "r")
      if not html_file then error("Could not download " .. download_url:enquote()) end
      local raw_html = html_file:read("*a")
      html_file:close()
      os.execute("rm " .. temporary_html_file_name)

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

local function convert_pages(config)
  utility.required_program("pandoc")
  local working_dir = get_base_file_name(config)

  for section = config.sections.start, config.sections.finish do
    local section_dir = working_dir .. path_separator .. tostring(section) .. path_separator

    for page = 1, config.page_counts[section - (config.sections.start - 1)] do
      local page_file_name_base = section_dir .. page
      os.execute("pandoc --from html --to markdown " .. (page_file_name_base .. ".html"):enquote() .. " -o " .. (page_file_name_base .. ".md"):enquote())
    end
  end
end

local function concatenate_pages(config)
  local working_dir = get_base_file_name(config)

  for section = config.sections.start, config.sections.finish do
    local section_dir = working_dir .. path_separator .. tostring(section) .. path_separator
    local section_file, err = io.open(working_dir .. path_separator .. tostring(section) .. ".md", "w")
    if not section_file then error(err) end

    for page = 1, config.page_counts[section - (config.sections.start - 1)] do
      local page_file, err = io.open(section_dir .. page .. ".md", "r")
      if not page_file then error(err) end
      if config.sections.automatic_naming then
        local naming_patterns = {
          "^Prologue$",
          "^Chapter %d+$",
        }
        local line = page_file:read("*line")
        while line do
          for _, pattern in ipairs(naming_patterns) do
            if line:find(pattern) then
              line = "# " .. line
            end
          end
          section_file:write(line .. "\n")
          line = page_file:read("*line")
        end
      else
        section_file:write(page_file:read("*a"))
      end
      section_file:write("\n") -- guarantees no accidental line collisions
      page_file:close()
    end
  end
end

local function write_markdown_file(config)
  local working_dir = get_base_file_name(config)

  local markdown_file, err = io.open(get_base_file_name(config) .. ".md", "w")
  if not markdown_file then error(err) end
  markdown_file:write(format_metadata(config))
  markdown_file:write(copyright_warning)

  for section = config.sections.start, config.sections.finish do
    if config.sections.naming then
      markdown_file:write("\n\n# " .. config.sections.naming .. " " .. tostring(section))
    elseif config.section_titles then
      markdown_file:write("\n\n# " .. config.section_titles[section])
    end
    markdown_file:write("\n\n")

    local section_file_name = working_dir .. path_separator .. tostring(section)
    local section_file, err = io.open(section_file_name .. ".md", "r")
    if not section_file then error(err) end
    markdown_file:write(section_file:read("*a"))
    section_file:close()
  end

  markdown_file:write("# Ebook Creation Metadata\n\n")
  markdown_file:write(copyright_warning)
  markdown_file:write("This ebook was created using the following config:\n\n")
  markdown_file:write("```json\n" .. config.config_file_text .. "\n```\n")
  markdown_file:close()
end

local function make_epub(config)
  utility.required_program("pandoc")
  local output_dir = "All ePubs"
  os.execute("mkdir " .. output_dir:enquote())

  local base_file_name = get_base_file_name(config)
  os.execute("pandoc --from markdown --to epub " .. (base_file_name .. ".md"):enquote() .. " -o " .. (output_dir .. path_separator .. base_file_name .. ".epub"):enquote() .. " --toc=true")
end

local function rm_page_files(config)
  local working_dir = get_base_file_name(config)
  os.execute("sleep 1") -- attempt to fix #14

  for section = config.sections.start, config.sections.finish do
    local section_dir = working_dir .. path_separator .. tostring(section)
    os.execute(utility.recursive_remove_command .. section_dir:enquote())
  end
end

local function rm_all(config)
  local working_dir = get_base_file_name(config)

  os.execute(utility.recursive_remove_command .. working_dir:enquote())
  os.execute("rm " .. (get_base_file_name(config) .. ".md"):enquote())
end

local function argparse(arguments, positional_arguments)
  local recognized_arguments = {}
  for index, argument in ipairs(arguments) do
    for _, help in ipairs({"-h", "--help", "/?", "/help", "help"}) do
      if argument == help then
        print(help)
        return nil
      end
    end
    if positional_arguments[index] then
      recognized_arguments[positional_arguments[index]] = argument
    end
  end
  return recognized_arguments
end

local function main(arguments)
  local config_file, err = io.open(arguments.json_file_name, "r")
  if not config_file then error(err) end
  local config = load_config(config_file:read("*all"))
  config_file:close()

  local actions = {
    download = download_pages,
    convert = convert_pages,
    concat = concatenate_pages,
    markdown = write_markdown_file,
    epub = make_epub,
    cleanpage = rm_page_files,
    cleanall = rm_all,
  }

  if arguments.action then
    if actions[arguments.action] then
      actions[arguments.action](config)
    else
      print(help)
      error("\nInvalid action specified.")
    end
  else
    print("\nDownloading pages...\n")
    download_pages(config)
    print("\nConverting pages...\n")
    convert_pages(config)
    print("\nConcatenating pages...\n")
    concatenate_pages(config)
    print("\nRemoving page files...\n")
    rm_page_files(config)
    print("\nWriting Markdown file...\n")
    write_markdown_file(config)
    print("\nMaking ePub...\n")
    make_epub(config)
    print("\nDone!\n")
  end
end

local positional_arguments = {"json_file_name", "action"}
local arguments = argparse(arg, positional_arguments)
if not arguments.json_file_name then
  print(help)
  error("\nA config file name/path must be specified.")
end

if arguments.json_file_name == "." then
  utility.ls(".")(function(file_name)
    if file_name:find(".json$") then
      arguments.json_file_name = file_name
      main(arguments)
    end
  end)
else
  main(arguments)
end
