#!/usr/bin/env luajit
math.randomseed(os.time())

local version = "0.11.5"
local user_agent = "-A \"pool2epub/" .. version .. "\""

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local json = require "dkjson"
local argparse = utility.require("argparse")

utility.required_program("magick")
utility.required_program("pandoc")

-- set pool2epub.auth_query_string to "?login=USERNAME&api_key=APIKEY" to access account-restricted images
local pool2epub_settings = utility.get_config("skip_lock").pool2epub

local parser = argparse():description("Make an ebook of images from an e926 pool."):help_max_width(80)
parser:argument("url", "Pool URL (can have .json or it can be missing)"):args("?")
parser:flag("--discard-description", "Descriptions will not be included in output.")
parser:flag("--save-json", "Save all JSON data obtained to all_posts.json")
parser:mutex(
  parser:flag("--retry-images", "Retry failed downloads using a previous failed_posts.json"),
  parser:flag("--epub-only", "Only run the epub conversion. (Useful for manually correct ebooks.)"),
  parser:flag("--process-images", "Rerun image processing (and export epub).")
)
parser:argument("author", "Author of the work."):args("?")

local options = parser:parse()

if options.url and options.url:sub(-5) ~= ".json" then
  options.url = options.url .. ".json"
end

if not options.author then options.author = "" end



local function export_epub()
  print("Exporting epub!")
  os.execute("pandoc text.md -o ebook.epub")
end

local function get_json(url)
  if pool2epub_settings and pool2epub_settings.auth_query_string then
    url = url .. pool2epub_settings.auth_query_string
  end

  local text = utility.curl_read(url, user_agent)
  return json.decode(text)
end

local function process_images()
  print("\n Processing images. It is safe to start another instance of this script now. \n")
  local processed_posts = {} -- indexed by MD5

  utility.ls("raw_images")(function(file_name)
    local _, _, file_extension = utility.split_path_components(file_name)
    local base_name = file_name:sub(1, -#file_extension-2)

    if file_extension == "jpg" or file_extension == "png" then
      local export_file_name = "processed_images/" .. base_name .. ".jpg"
      processed_posts[base_name] = true -- it is processed whether or not we are handling it in this moment (this assumption may be dangerous)
      if not utility.is_file(export_file_name) then
        os.execute("magick " .. ("raw_images" .. utility.path_separator .. file_name):enquote() .. " -quality 50% " .. export_file_name:enquote())
      end
    elseif file_extension == "gif" then
      os.execute("cp raw_images" .. utility.path_separator .. file_name .. " processed_images" .. utility.path_separator .. file_name)
    end
  end)

  return processed_posts
end

local function save_failed_images(failed_posts)
  local failure_count = 0
  for md5, post in pairs(failed_posts) do
    failure_count = failure_count + 1
  end

  print("\n Warning! Failed to obtain " .. failure_count .. " images! \n")

  utility.open("failed_posts.json", "w", function(file)
    file:write(json.encode(failed_posts, { indent = true }))
    file:write("\n")
  end)
  print("Post data for failed images is in failed_posts.json")
end

local function retry_images()
  local failed_posts = utility.open("failed_posts.json", "r", function(file)
    return json.decode(file:read("*all"))
  end)

  for md5, post in pairs(failed_posts) do
    local function act(md5, post)
      if post.flags.deleted then
        print("MD5 " .. md5 .. " was deleted. Cannot automatically obtain.")
        if post.sources then
          for _, source in ipairs(post.sources) do
            print("  " .. source)
          end
        end
        os.execute("sleep 1")
        return
      end

      if not post.file.url then
        print("MD5 " .. md5 .. " is unavailable? Cannot automatically obtain.")
        if post.sources then
          for _, source in ipairs(post.sources) do
            print("  " .. source)
          end
        end
        os.execute("sleep 1")
        return
      end

      os.execute("curl " .. user_agent .. " -o raw_images/" .. post.file.md5 .. "." .. post.file.ext .. " " .. post.file.url)
      os.execute("sleep " .. math.random(1, 3)) -- slow access rate
    end

    act(md5, post)
  end

  local processed_posts = process_images() -- indexed by MD5

  -- check for resolvable failures
  for md5, post in pairs(processed_posts) do
    failed_posts[md5] = nil
  end

  for md5, post in pairs(failed_posts) do
    if post.file.url then
      print(md5 .. " failed to download, but should've succeeded. Use --retry-images again.")
    end
  end

  if next(failed_posts) then
    save_failed_images(failed_posts)
  else
    export_epub()
    os.execute("rm failed_posts.json")
  end
end

local function main()
  os.execute("mkdir raw_images")
  os.execute("mkdir processed_images")

  local base_url = options.url:sub(1, options.url:find("/pools"))

  local pool = get_json(options.url)
  -- utility.print_table(pool) -- DEBUG

  local lines = {
    "---",
    "title: " .. utility.escape_quotes_and_escapes(pool.name:gsub("_", " ")):enquote(),
    "author: [" .. options.author:enquote() .. "]",
    "publisher: " .. ("pool2epub.lua/" .. version):enquote(),
    "source: " .. options.url:enquote(),
    "---",
    "",
  }

  -- both indexed by MD5
  local all_posts = {}
  local failed_posts = {}

  -- obtain images and metadata
  for _, identifier in ipairs(pool.post_ids) do
    local function act(identifier)
      local post = get_json(base_url .. "posts/" .. identifier .. ".json").post
      all_posts[post.file.md5] = post

      if post.file.ext == "gif" then
        lines[#lines + 1] = "![](processed_images/" .. post.file.md5 .. ".gif)"
      else
        lines[#lines + 1] = "![](processed_images/" .. post.file.md5 .. ".jpg)"
      end
      if not options.discard_description then
        lines[#lines + 1] = "\n" .. post.description .. "\n"
      end

      if post.flags.deleted then
        lines[#lines + 1] = "Deleted post: #" .. identifier .. " (MD5: " .. post.file.md5 .. ")\n"
        failed_posts[post.file.md5] = post
        os.execute("sleep 1")
        return
      end

      if not post.file.url then
        lines[#lines + 1] = "Post missing download URL: #" .. identifier .. " (MD5: " .. post.file.md5 .. ")\n"
        failed_posts[post.file.md5] = post
        os.execute("sleep 1")
        return
      end

      os.execute("sleep 1")
      os.execute("curl " .. user_agent .. " -o raw_images/" .. post.file.md5 .. "." .. post.file.ext .. " " .. post.file.url)
      os.execute("sleep " .. math.random(1, 3)) -- slow access rate
    end

    act(identifier)
  end

  -- process images
  local processed_posts = process_images() -- indexed by MD5

  -- warn about missed images and make sure they are in failed_posts
  for md5, post in pairs(all_posts) do
    if (not processed_posts[md5]) or (not failed_posts[md5]) then
      failed_posts[md5] = post
      print(md5 .. " failed to download, but should've succeeded.")
    end
  end

  -- save data and convert
  if options.save_json then
    utility.open("all_posts.json", "w", function(file)
      file:write(json.encode(all_posts, { indent = true }))
      file:write("\n")
    end)
  end

  if next(failed_posts) then
    save_failed_images(failed_posts)
  end

  utility.open("text.md", "w", function(file)
    file:write(table.concat(lines, "\n"))
    file:write("\n")
  end)

  export_epub()
end

if options.retry_images then
  retry_images()
elseif options.epub_only then
  export_epub()
elseif options.process_images then
  process_images()
  export_epub()
else
  if not options.url then
    print("\n A URL must be specified. \n")
    os.exit(1)
  end

  main()
end
