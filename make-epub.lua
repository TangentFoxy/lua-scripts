#!/usr/bin/env luajit

local help = [[Usage:

  make-epub.lua <config (JSON file)> [action] [flag]

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

[flag]: If "--continue" is passed, script will continue with the default order
          of actions from the action specified.

Requirements:
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
local copyright_warning = "This ebook was created by an automated tool for personal use. It cannot be distributed or sold without permission of its copyright holder(s). (If you did not make this ebook, you may be infringing.)\n\n"

local domain_customizations = {
  ["literotica%.com/s/"] = {
    name = "literotica.com",
    content_selector = ".article > div > div",
    title_selector = ".headline",
    conversion_method = "standard",
  },
  ["archiveofourown%.org/works/"] = {
    name = "archiveofourown.org",
    content_selector = "div#workskin",
    conversion_method = "plaintext",
  },
  ["furaffinity%.net/view/"] = {
    name = "furaffinity.net",
    content_selector = "div.submission-writing > center > div",
    -- title_selector = "div.submission-title > h2",   -- because an extra paragraph tag is used, this breaks
    conversion_method = "standard",
  },
}

-- also checks for errors TODO make it check for ALL required elements and error if any are missing!
local function load_config(config_file_text)
  local json = utility.require("json")

  config = json.decode(config_file_text)
  config.config_file_text = config_file_text

  -- domain is not detected here, because when manually specifying sections, different sections can come from different domains

  if not config.authors then
    config.authors = {} -- at least have an empty table so it doesn't error below TODO verify that this is actually true
  end

  if not config.keywords then
    config.keywords = {}
  end

  if config.author then -- old style single author will be prepended to authors list
    table.insert(config.authors, 1, config.author)
  end

  -- if only using a single section
  if config.first_section_url and not config.base_url then
    config.base_url = config.first_section_url -- prevent errors due to required item being missing
  end

  if not config.sections then
    config.sections = {} -- I've decided to allow empty sections (defaults to 1 section, for single story ebooks)
  end

  if config.automatic_naming then
    config.sections.automatic_naming = true
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

  if not config.sections.finish then
    config.sections.finish = 1
  end

  if config.section_titles and #config.section_titles ~= config.sections.finish - config.sections.start + 1 then
    error("Number of section_titles does not match number of sections.")
  end

  -- make page_counts optional for single-page downloads
  if not config.page_counts then
    config.page_counts = {}
    for _ = config.sections.start, config.sections.finish do
      table.insert(config.page_counts, 1)
    end
  end

  if #config.page_counts ~= config.sections.finish - config.sections.start + 1 then
    error("Number of page_counts does not match number of sections.")
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
  config.base_file_name = utility.make_safe_file_name(config.base_file_name or base_file_name)

  return config
end

local function format_metadata(config)
  local function stringify_list(list)
    if not list or not list[1] then return "" end
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
    "publisher: " .. ("make-epub.lua"):enquote(),
    "---",
    "",
  }

  if config.cover_image_path then
    table.insert(metadata, 6, "cover-image: " .. config.cover_image_path:enquote())
  end

  return table.concat(metadata, "\n") .. "\n"
end

local function get_section_url(config, section)
  local section_url
  if section == 1 and config.first_section_url then
    section_url = config.first_section_url
  else
    section_url = config.base_url .. string.format("%02i", section) -- leftpad 2 (NOTE: This will eventually cause problems.)
  end

  if config.manually_specified_sections then
    section_url = config.sections[section]
  end

  return section_url
end

local function get_current_domain(url)
  local current_domain
  for domain_pattern, customizations_table in pairs(domain_customizations) do
    if url:find(domain_pattern) then
      current_domain = customizations_table
      break
    end
  end

  -- NOTE/TODO this doesn't allow specifying custom selectors, which should overwrite and ignore this error
  if not current_domain then
    error("\nThe domain of " .. url:enquote() .. " is not supported.\n")
  end

  return current_domain
end

local function download_pages(config)
  print("\nDownloading pages...\n")
  local htmlparser = utility.require("htmlparser")
  utility.required_program("curl")
  local working_dir = config.base_file_name

  os.execute("mkdir " .. working_dir:enquote())
  for section = config.sections.start, config.sections.finish do
    local section_dir = working_dir .. path_separator .. tostring(section) .. path_separator
    os.execute("mkdir " .. section_dir:sub(1, -2):enquote())

    local section_url = get_section_url(config, section)
    -- domain detected here so that multi-domain parts can be put in the same config
    local current_domain = get_current_domain(section_url)

    for page = 1, config.page_counts[section - (config.sections.start - 1)] do
      local download_url
      if page == 1 then
        download_url = section_url
      else
        download_url = section_url .. "?page=" .. tostring(page)
      end

      local temporary_html_file_name = utility.tmp_file_name()
      if current_domain.name == "furaffinity.net" then
        local fa_cookie_string = assert(utility.get_config().fa_cookie_string, "You are missing FurAffinity cookies in config. See .lua-files README.")
        os.execute("curl --cookie " .. fa_cookie_string:enquote() .. " " .. download_url:enquote() .. " > " .. temporary_html_file_name)
      else
        os.execute("curl " .. download_url:enquote() .. " > " .. temporary_html_file_name)
      end

      utility.open(temporary_html_file_name, "r", "Could not download " .. download_url:enquote())(function(html_file)
        local raw_html = html_file:read("*all")

        local parser = htmlparser.parse(raw_html, 100000)
        local content_tag = parser:select(current_domain.content_selector)
        local text = content_tag[1]:getcontent()

        if page == 1 and config.extract_titles then
          if current_domain.title_selector then
            text = parser:select(current_domain.title_selector)[1]:gettext() .. text
          end
        end

        utility.open(section_dir .. page .. ".html", "w")(function(page_file)
          page_file:write(text .. "\n")
        end)
      end)

      os.execute("rm " .. temporary_html_file_name)
      os.execute("sleep " .. tostring(math.random(5))) -- avoid rate limiting
    end
  end
end

local function convert_pages(config)
  print("\nConverting pages...\n")
  utility.required_program("pandoc")
  local working_dir = config.base_file_name

  for section = config.sections.start, config.sections.finish do
    local section_dir = working_dir .. path_separator .. tostring(section) .. path_separator

    local current_domain = get_current_domain(get_section_url(config, section))

    for page = 1, config.page_counts[section - (config.sections.start - 1)] do
      local page_file_name_base = section_dir .. page
      if current_domain.conversion_method == "standard" then
        os.execute("pandoc --from html --to markdown " .. (page_file_name_base .. ".html"):enquote() .. " -o " .. (page_file_name_base .. ".md"):enquote())
      elseif current_domain.conversion_method == "plaintext" then
        local plaintext_reader_path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "pandoc_plaintext_reader.lua"
        os.execute("pandoc --from html --to plain " .. (page_file_name_base .. ".html"):enquote() .. " -o " .. (page_file_name_base .. ".txt"):enquote())
        os.execute("pandoc --from " .. plaintext_reader_path:enquote() .. " --to markdown " .. (page_file_name_base .. ".txt"):enquote() .. " -o " .. (page_file_name_base .. ".md"):enquote())
      else
        error("\nInternal Error: Invalid conversion_method. This is an error with make-epub.lua itself. Please report this error.\n")
      end
    end
  end
end

local function concatenate_pages(config)
  print("\nConcatenating pages...\n")
  local working_dir = config.base_file_name

  for section = config.sections.start, config.sections.finish do
    local section_dir = working_dir .. path_separator .. tostring(section) .. path_separator
    utility.open(working_dir .. path_separator .. tostring(section) .. ".md", "w")(function(section_file)
      for page = 1, config.page_counts[section - (config.sections.start - 1)] do
        utility.open(section_dir .. page .. ".md", "r")(function(page_file)
          if config.sections.automatic_naming then
            local naming_patterns = {
              "^Prologue$",
              "^Chapter %d+$",
              "^Chapter %d+: [%w%s]+$",
              "^%*%*CHAPTER ",
              "^Epilogue$",
              "^Epilog$",
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
            section_file:write(page_file:read("*all"))
          end
          section_file:write("\n") -- guarantees no accidental line collisions
        end)
      end
    end)
  end
end

local function write_markdown_file(config)
  print("\nWriting Markdown file...\n")
  local working_dir = config.base_file_name

  utility.open(config.base_file_name .. ".md", "w")(function(markdown_file)
    markdown_file:write(format_metadata(config))
    markdown_file:write(copyright_warning)

    for section = config.sections.start, config.sections.finish do
      if config.sections.naming then
        markdown_file:write("\n\n# " .. config.sections.naming .. " " .. tostring(section))
      elseif config.section_titles then
        markdown_file:write("\n\n# " .. config.section_titles[section])
      elseif config.lazy_titling then
        local section_url = get_section_url(config, section)
        local current_domain = get_current_domain(section_url)

        if current_domain.name == "literotica.com" then
          local title_parts = section_url:sub(30):gsplit("-")
          while tonumber(title_parts[#title_parts]) do
            title_parts[#title_parts] = nil
          end
          local last_part = title_parts[#title_parts]
          if last_part == "ch" or last_part == "pt" then
            title_parts[#title_parts] = nil
          end
          for index, part in ipairs(title_parts) do
            title_parts[index] = part:sub(1, 1):upper() .. part:sub(2)
          end
          markdown_file:write("\n\n# " .. table.concat(title_parts, " "))
        end
      end
      markdown_file:write("\n\n")

      local section_file_name = working_dir .. path_separator .. tostring(section)
      utility.open(section_file_name .. ".md", "r")(function(section_file)
        markdown_file:write(section_file:read("*all"))
      end)
    end

    markdown_file:write("\n\n# Ebook Creation Metadata\n\n")
    markdown_file:write(copyright_warning)
    markdown_file:write("This ebook was created using the following config:\n\n")
    markdown_file:write("```json\n" .. config.config_file_text .. "\n```\n")
  end)
end

local function make_epub(config)
  print("\nMaking ePub...\n")
  utility.required_program("pandoc")
  local output_dir = "All ePubs"
  os.execute("mkdir " .. output_dir:enquote())

  local markdown_file_name = config.base_file_name .. ".md"
  local epub_file_name = output_dir .. path_separator .. config.base_file_name .. ".epub"
  local pandoc_command = "pandoc --from markdown --to epub " .. markdown_file_name:enquote() .. " -o " .. epub_file_name:enquote() .. " --toc=true"
  if config.cover_image_path then
    pandoc_command = pandoc_command .. " --epub-cover-image=" .. config.cover_image_path:enquote()
  end
  os.execute(pandoc_command)
end

local function rm_page_files(config)
  print("\nRemoving page files...\n")
  local working_dir = config.base_file_name

  for section = config.sections.start, config.sections.finish do
    local section_dir = working_dir .. path_separator .. tostring(section)
    os.execute(utility.recursive_remove_command .. section_dir:enquote())
  end
end

local function rm_all(config)
  print("\nRemoving all extra files...\n")
  local working_dir = config.base_file_name

  os.execute(utility.recursive_remove_command .. working_dir:enquote())
  os.execute("rm " .. (config.base_file_name .. ".md"):enquote())
end

local function argparse(arguments, positional_arguments)
  local recognized_arguments = {}
  for index, argument in ipairs(arguments) do
    for _, help_command in ipairs({"-h", "--help", "/?", "/help", "help"}) do
      if argument == help_command then
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
  local config = utility.open(arguments.json_file_name, "r")(function(config_file)
    return load_config(config_file:read("*all"))
  end)

  if config.base_url:find("fanfiction%.net/s/") then
    if os.execute("fichub_cli --version") ~= 0 then
      error("Run \"pip install -U fichub-cli\" to be able to download FanFiction.Net ebooks.\n\n")
    end

    local output_dir = "All ePubs"
    os.execute("mkdir " .. output_dir:enquote())
    return os.execute("fichub_cli -u " .. config.base_url .. " -o " .. output_dir:enquote())
  end

  local actions = {
    download = download_pages,
    convert = convert_pages,
    concat = concatenate_pages,
    markdown = write_markdown_file,
    epub = make_epub,
    cleanpage = rm_page_files,
    cleanall = rm_all,
  }
  local default_action_order = {
    "download",
    "convert",
    "concat",
    "cleanpage",
    "markdown",
    "epub",
  }

  if arguments.action then
    if actions[arguments.action] then
      actions[arguments.action](config)
      if arguments.flag == "--continue" then
        local starting_point_reached = false
        for _, action in ipairs(default_action_order) do
          if starting_point_reached then
            actions[action](config)
          elseif action == arguments.action then
            starting_point_reached = true
          end
        end
      end
    else
      print(help)
      error("\nInvalid action specified.")
    end
  else
    for _, action in ipairs(default_action_order) do
      actions[action](config)
    end
  end
  print("\nDone!\n")
  return true
end

local positional_arguments = {"json_file_name", "action", "flag"}
local arguments = argparse(arg, positional_arguments)
if not arguments then return end -- help text must've been printed, exit
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
  return main(arguments)
end
