#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

local htmlparser = require "htmlparser"
local json = require "json"

utility.required_program("pandoc")

local options = utility.open(arg[1], "r", function(file)
  return json.decode(file:read("*all"))
end)

local function equal_array_lengths(...)
  local arg = {...}
  for i = 2, #arg do
    if #arg[i] ~= #arg[1] then
      return false
    end
  end
  return true
end

utility.open(options.index_file, "r", function(file)
  local html_text = file:read("*all")
  local parser = htmlparser.parse(html_text, 100000)

  local titles = parser:select(options.title_pattern)
  local links = parser:select(options.link_pattern)
  local date = parser:select(options.date_pattern)
  local metadata = parser:select(options.metadata_pattern)

  if not equal_array_lengths(titles, links, date, metadata) then
    local output = {
      "\n", "Selectors did not get the same number of items across each type.",
      #titles, #links, #date, #metadata,
      "",
    }
    error(table.concat(output, "\n"))
  end

  os.execute("mkdir -p Stories")
  os.execute("mkdir -p \"All ePubs\"")

  for index in ipairs(titles) do
    local page = {
      title = titles[index]:getcontent(),
      link = links[index].attributes.href,
      date = date[index]:getcontent(),
      metadata = metadata[index]:getcontent(),
    }

    local output = "<h1>" .. page.title .. "</h1>\n"
    output = output .. "<p>" .. page.date .. " " .. page.metadata .. "</p>\n"

    local html_text = utility.curl_read(page.link)
    local parser = htmlparser.parse(html_text, 10000)
    local content = parser:select(options.content_pattern)
    output = output .. content[1]:getcontent() .. "\n"

    page.base_file_name = utility.make_safe_file_name(page.title)
    local html_file_path = ("Stories" .. utility.path_separator .. page.base_file_name .. ".html")
    local epub_file_path = ("All ePubs" .. utility.path_separator .. page.base_file_name .. ".epub")
    utility.open(html_file_path, "w", function(file)
      file:write(output)
    end)

    utility.open("metadata.yaml", "w", function(file)
      file:write("---\ntitle: \"" .. page.title .. "\"\nauthor:\n")
      for _, author in ipairs(options.authors) do
        file:write("- " .. author:enquote() .. "\n")
      end
      file:write("---\n")
    end)
    os.execute("pandoc --metadata-file metadata.yaml --from html --to epub " .. html_file_path:enquote() .. " -o " .. epub_file_path:enquote() .. " --toc=true")

    os.execute("sleep " .. tostring(math.random(5)))
  end
end)

os.execute("rm metadata.yaml")
