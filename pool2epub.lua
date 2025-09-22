#!/usr/bin/env luajit
math.randomseed(os.time())

local version = "0.8"
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
parser:argument("url", "Pool URL (can have .json or it can be missing)"):args(1)
parser:flag("--discard-description", "Descriptions will not be included in output.")
parser:flag("--save-json", "Save all JSON data obtained to all_posts.json")
parser:argument("author", "Author of the work."):args("?")

local options = parser:parse()

if options.url:sub(-5) ~= ".json" then
  options.url = options.url .. ".json"
end

if not options.author then options.author = "" end

local base_url = options.url:sub(1, options.url:find("/pools"))



local function get_json(url)
  if pool2epub_settings and pool2epub_settings.auth_query_string then
    url = url .. pool2epub_settings.auth_query_string
  end

  local text = utility.curl_read(url, user_agent)
  return json.decode(text)
end



os.execute("mkdir raw_images")
os.execute("mkdir processed_images")

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

    lines[#lines + 1] = "![](processed_images/" .. post.file.md5 .. ".jpg)"
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



print("\n Processing images. It is safe to start another instance of this script now. \n")

-- process images
local processed_posts = {} -- indexed by MD5
utility.ls("raw_images")(function(file_name)
  local _, _, file_extension = utility.split_path_components(file_name)
  local base_name = file_name:sub(1, -#file_extension-2)

  if file_extension == "jpg" or file_extension == "png" then
    local export_file_name = "processed_images/" .. base_name .. ".jpg"
    if not utility.is_file(export_file_name) then
      os.execute("magick " .. ("raw_images" .. utility.path_separator .. file_name):enquote() .. " -quality 50% " .. export_file_name:enquote())
      processed_posts[base_name] = true
    end
  end
end)

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
  print("\n Warning! Failed to obtain images! \n")
  utility.open("failed_posts.json", "w", function(file)
    file:write(json.encode(failed_posts, { indent = true }))
    file:write("\n")
  end)
  print("Post data for failed images is in failed_posts.json")
end

utility.open("text.md", "w", function(file)
  file:write(table.concat(lines, "\n"))
  file:write("\n")
end)

os.execute("pandoc text.md -o ebook.epub")
