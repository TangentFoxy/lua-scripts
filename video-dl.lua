#!/usr/bin/env luajit

local help = [[Usage:

  video-dl.lua [action] [--file] <url>

[action]: What is desired.
            video (default): Highest quality video (maximum 720p).
            backup, clone, copy: English subtitles (including automatic
              subtitles), thumbnail, description, highest quality video
              (maximum 720p).
            music, audio: Highest quality audio only.
            metadata, meta: English subtitles (including automatic
              subtitles), thumbnail, description.
[--file]: <url> is actually a file of URLs to open and execute [action]
            on each.
<url>:    Source. YouTube URL expected, but should work with anything
            yt-dlp works with.
]]

local success, utility = pcall(function()
  return dofile((arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "utility-functions.lua")
end)
if not success then
  print("\n\n" .. tostring(utility))
  error("\n\nThis script may be installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n")
end

utility.required_program("yt-dlp")

local action, url

if #arg < 2 then
  if arg[1]:find("help") then
    print(help)
    return false
  end
  action = "video"
  url = arg[1]
else
  action = arg[1]
  url = arg[2]
  -- "--file" is handled just before execution
end

local core_command = "yt-dlp --retries 100 "
local metadata_options = "--write-sub --write-auto-sub --sub-lang \"en.*\" --write-thumbnail --write-description "
local quality_ceiling_720 = "-f \"bestvideo[height<=720]+bestaudio/best[height<=720]\" "

local execute = {
  backup = function(url)
    os.execute(core_command .. metadata_options .. quality_ceiling_720 .. url:enquote())
  end,
  music = function(url)
    os.execute(core_command .. "-x --audio-quality 0 " .. url:enquote())
  end,
  metadata = function(url)
    os.execute(core_command .. metadata_options .. "--skip-download " .. url:enquote())
  end,
  video = function(url)
    os.execute(core_command .. quality_ceiling_720 .. url:enquote())
  end,
}
execute.clone = execute.backup
execute.copy = execute.backup
execute.audio = execute.music
execute.meta = execute.metadata

if execute[action] then
  if url == "--file" then
    pcall(function()
      for line in io.lines(arg[3]) do
        execute[action](line)
      end
    end)
  else
    execute[action](url)
  end
else
  print("Invalid [action]")
  print("Received:", "action", action, "url", url)
  return false
end
