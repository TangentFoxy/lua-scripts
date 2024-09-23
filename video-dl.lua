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

IMPORTANT: Expects Firefox to be installed with a YouTube account logged in to get cookies from.
]]

if os.execute("where yt-dlp") ~= 0 then
  error("yt-dlp must be installed and in the path")
end

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

local execute = {
  backup = function(url)
    os.execute("yt-dlp --retries 100 --write-sub --write-auto-sub --sub-lang \"en.*\" --write-thumbnail --write-description -f \"bestvideo[height<=720]+bestaudio/best[height<=720]\" \"" .. url .."\" --cookies-from-browser \"firefox\"")
  end,
  music = function(url)
    os.execute("yt-dlp --retries 100 -x --audio-quality 0 \"" .. url .."\" --cookies-from-browser \"firefox\"")
  end,
  metadata = function(url)
    os.execute("yt-dlp --retries 100 --write-sub --write-auto-sub --sub-lang \"en.*\" --write-thumbnail --write-description --skip-download \"" .. url .."\" --cookies-from-browser \"firefox\"")
  end,
  video = function(url)
    os.execute("yt-dlp --retries 100 -f \"bestvideo[height<=720]+bestaudio/best[height<=720]\" \"" .. url .. "\" --cookies-from-browser \"firefox\"")
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
