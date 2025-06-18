#!/usr/bin/env luajit

local helptext = [[
Actions:
  download:  All pages will be downloaded to their own HTML files.
  convert:   Each page is converted to Markdown.
  concat:    A file is created for each section out of its pages.
  markdown:  Metadata frontmatter and Markdown section files will be
             concatenated into a single Markdown file.
  epub:      Markdown file will be converted to an ePub using pandoc.
  cleanpage: All page files will be deleted, along with their extra directories.
  cleanall:  Deletes everything except the config file and ePub.

For basic examples and the config format, see README:
  https://github.com/TangentFoxy/lua-scripts#make-epublua
]]

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local argparse = utility.require("argparse")

local parser = argparse():description("Makes ebooks based on JSON configurations."):epilog(helptext)
parser:argument("config", "JSON config file. If \".\", will run on all JSON files in the current directory."):args(1)
parser:argument("action", "If not specified, all actions except \"cleanall\" will be taken in order.")
  :choices{"download", "convert", "concat", "markdown", "epub", "cleanpage", "cleanall"}:args("?")
parser:flag("--halt", "Stop after completing the specified action."):overwrite(false)
local options = parser:parse()



utility.required_program("pandoc")
utility.required_program("curl")

local path_separator = utility.path_separator
local copyright_warning = "This ebook was created by an automated tool for personal use. It cannot be distributed or sold without permission of its copyright holder(s). (If you did not make this ebook, you may be infringing.)\n\n"

local domain_customizations = {
  ["www%.literotica%.com/s/"] = {
    name = "literotica.com",
    content_selector = ".article > div > div",
    title_selector = ".headline",
    conversion_method = "standard",
  },
  ["spanish%.literotica%.com/s/"] = { -- this doesn't seem to work, and I have no idea why not
    name = "spanish.literotica.com",
    content_selector = ".article > div > div",
    title_selector = "._title_jwt1s_446",
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

local absurdly_high_number = 1e13

-- also checks for errors TODO make it check for ALL required elements and error if any are missing!
local function load_config(config_file_text)
  local json = utility.require("json")

  config = json.decode(config_file_text)
  config.config_file_text = config_file_text

  -- domain is not detected here, because when manually specifying sections, different sections can come from different domains
  -- but if the config adds its own definition(s), those need to be incorporated right away!
  --  and yes, this allows overwriting and that is intentional!
  if config.domains then
    for key, value in pairs(config.domains) do
      domain_customizations[key] = value
    end
  end

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
    if config.discover_page_counts then
      config.first_run = true
      for _ = config.sections.start, config.sections.finish do
        table.insert(config.page_counts, absurdly_high_number)
      end
    else
      for _ = config.sections.start, config.sections.finish do
        table.insert(config.page_counts, 1)
      end
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
    local output = utility.escape_quotes_and_escapes(list[1]):enquote()
    for i = 2, #list do
      output = output .. ", " .. utility.escape_quotes_and_escapes(list[i]):enquote()
    end
    return output
  end

  local keywords_string = stringify_list(config.keywords)
  local metadata = {
    "---",
    "title: " .. utility.escape_quotes_and_escapes(config.title):enquote(),
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
  --   NOTE I've been using this script successfully with custom selectors without this error occurring
  if not current_domain then
    error("\nThe domain of " .. url:enquote() .. " is not supported.\n")
  end

  return current_domain
end

local function get_section_dir(config, section)
  return config.base_file_name .. path_separator .. tostring(section) .. path_separator
end

local function download_pages(config)
  print("\nDownloading pages...\n")
  local htmlparser = utility.require("htmlparser")
  utility.required_program("curl")

  os.execute("mkdir " .. config.base_file_name:enquote())
  for section = config.sections.start, config.sections.finish do
    local section_dir = get_section_dir(config, section)
    if not utility.file_exists(section_dir:sub(1, -2) .. ".md") then
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

        local temporary_html_file_name
        if config.discover_page_counts then
          local exists
          temporary_html_file_name = utility.tmp_file_name()
          os.execute("curl -I " ..download_url:enquote() .. " > " .. temporary_html_file_name)
          utility.open(temporary_html_file_name, "r", "Could not receive HEAD request: " .. download_url:enquote())(function(html_file)
            local raw_html = html_file:read("*all")
            if raw_html:find("404 Not Found") or raw_html:find("HTTP/2 404") then
              exists = false
            else
              exists = true
            end
          end)
          os.execute("rm " .. temporary_html_file_name)
          if not exists then
            config.page_counts[section - (config.sections.start - 1)] = page - 1
            break
          end
        end

        temporary_html_file_name = utility.tmp_file_name()
        if current_domain.name == "furaffinity.net" then
          local fa_cookie_string = assert(utility.get_config().fa_cookie_string, "You are missing FurAffinity cookies in config. See .lua-files README.")
          os.execute("curl --cookie " .. fa_cookie_string:enquote() .. " " .. download_url:enquote() .. " > " .. temporary_html_file_name)
        else
          os.execute("curl " .. download_url:enquote() .. " > " .. temporary_html_file_name)
        end

        utility.open(temporary_html_file_name, "r", "Could not download " .. download_url:enquote())(function(html_file)
          local raw_html = html_file:read("*all")

          local parser = htmlparser.parse(raw_html, 100000)
          local content_tag = parser:select(config.custom_content_selector or current_domain.content_selector)
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
end

local function check_page_counts(config, section, section_dir)
  -- if discover_page_counts was used and the script was interrupted, could be in a weird state
  if config.page_counts[section - (config.sections.start - 1)] == absurdly_high_number then
    local _pages = {}
    utility.ls(section_dir)(function(item)
      local _number = tonumber(item)
      if _number then
        table.insert(_pages, _number)
      end
    end)
    table.sort(_pages)
    config.page_counts[section - (config.sections.start - 1)] = _pages[#_pages]
  end
end

local function convert_pages(config)
  print("\nConverting pages...\n")
  utility.required_program("pandoc")

  for section = config.sections.start, config.sections.finish do
    local section_dir = get_section_dir(config, section)
    if not utility.file_exists(section_dir:sub(1, -2) .. ".md") then
      local current_domain = get_current_domain(get_section_url(config, section))

      check_page_counts(config, section, section_dir)

      for page = 1, config.page_counts[section - (config.sections.start - 1)] do
        local page_file_name_base = section_dir .. page
        if current_domain.conversion_method == "standard" then
          os.execute("pandoc --from html --to markdown " .. (page_file_name_base .. ".html"):enquote() .. " -o " .. (page_file_name_base .. ".md"):enquote())
        elseif current_domain.conversion_method == "plaintext" then
          local plaintext_reader_path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. utility.path_separator .. "pandoc_plaintext_reader.lua"
          os.execute("pandoc --from html --to plain " .. (page_file_name_base .. ".html"):enquote() .. " -o " .. (page_file_name_base .. ".txt"):enquote())
          os.execute("pandoc --from " .. plaintext_reader_path:enquote() .. " --to markdown " .. (page_file_name_base .. ".txt"):enquote() .. " -o " .. (page_file_name_base .. ".md"):enquote())
        else
          error("\nInternal Error: Invalid conversion_method. This is an error with make-epub.lua itself. Please report this error.\n")
        end
      end
    end
  end
end

local function concatenate_pages(config)
  print("\nConcatenating pages...\n")

  for section = config.sections.start, config.sections.finish do
    local section_dir = get_section_dir(config, section)
    if not utility.file_exists(section_dir:sub(1, -2) .. ".md") then
      utility.open(section_dir:sub(1, -2) .. ".md", "w")(function(section_file)
        check_page_counts(config, section, section_dir)
        for page = 1, config.page_counts[section - (config.sections.start - 1)] do
          utility.open(section_dir .. page .. ".md", "r")(function(page_file)
            if config.sections.automatic_naming then
              local naming_patterns = {
                "^Prologue$",
                "^Chapter %d+$",
                "^Chapter %d+: [%w%s]+$",
                "^%*%*CHAPTER ",
                "^%*%*Chapter ",
                "^%*%*%*%*Chapter ",
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
end

local function write_markdown_file(config)
  print("\nWriting Markdown file...\n")

  utility.open(config.base_file_name .. ".md", "w")(function(markdown_file)
    markdown_file:write(format_metadata(config))
    markdown_file:write(copyright_warning)

    if config.frontmatter_raw then
      markdown_file:write("\n\n" .. tostring(config.frontmatter_raw))
    end

    if config.description then
      markdown_file:write("\n\n---\n\n" .. tostring(config.description))
    end

    for section = config.sections.start, config.sections.finish do
      if config.sections.naming then
        markdown_file:write("\n\n# " .. config.sections.naming .. " " .. tostring(section))
      elseif config.section_titles then
        markdown_file:write("\n\n# " .. config.section_titles[section])
      elseif config.lazy_titling then
        local section_url = get_section_url(config, section)
        local current_domain = get_current_domain(section_url)

        if current_domain.name:find("literotica") then
          local title_parts
          if current_domain.name == "literotica.com" then
            title_parts = section_url:sub(30):gsplit("-")
          elseif current_domain.name == "spanish.literotica.com" then
            title_parts = section_url:sub(34):gsplit("-")
          else
            error("Invalid subdomain.")
          end
          while tonumber(title_parts[#title_parts]) do -- remove trailing numbers
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

      local section_file_name = get_section_dir(config, section):sub(1, -2) .. ".md"
      utility.open(section_file_name, "r")(function(section_file)
        markdown_file:write(section_file:read("*all"))
      end)
    end

    if config.backmatter_raw then
      markdown_file:write("\n\n" .. tostring(config.backmatter_raw))
    end

    markdown_file:write("\n\n# Ebook Creation Metadata\n\n")
    markdown_file:write(copyright_warning)
    markdown_file:write("This ebook was created using the following config:\n\n")
    markdown_file:write("```json\n" .. config.config_file_text .. "\n```\n")
    if config.discover_page_counts and config.first_run then
      local json = utility.require("json")
      markdown_file:write("page_counts were calculated/discovered:\n\n")
      markdown_file:write("```json\n" .. json.encode(config.page_counts) .. "\n```\n")
    end
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

  for section = config.sections.start, config.sections.finish do
    local section_dir = get_section_dir(config, section)
    os.execute(utility.commands.recursive_remove .. section_dir:sub(1, -2):enquote())
  end
end

local function rm_all(config)
  print("\nRemoving all extra files...\n")

  os.execute(utility.commands.recursive_remove .. config.base_file_name:enquote())
  os.execute("rm " .. (config.base_file_name .. ".md"):enquote())
end

local function main(arguments)
  local config = utility.open(arguments.config, "r")(function(config_file)
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
      if not arguments.halt then
        local starting_point_reached = false
        for _, action in ipairs(default_action_order) do
          if starting_point_reached then
            actions[action](config)
          elseif action == arguments.action then
            starting_point_reached = true
          end
        end
      end
    end
  else
    for _, action in ipairs(default_action_order) do
      actions[action](config)
    end
  end
  print("\nDone!\n")
  return true
end

if options.config == "." then
  utility.ls(".")(function(file_name)
    if file_name:find(".json$") then
      options.config = file_name
      main(options)
    end
  end)
else
  main(options)
end
