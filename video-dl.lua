#!/usr/bin/env luajit

local help = [[Usage:

  video-dl.lua [action] <url>

[action]: What is desired.
            video (default): Highest quality video (maximum 720p).
            backup, clone, copy: English subtitles (including automatic
              subtitles), thumbnail, description, highest quality video
              (maximum 720p).
            music, audio: Highest quality audio only.
            metadata, meta: English subtitles (including automatic
              subtitles), thumbnail, description.
<url>:    Source. YouTube URL expected, but should work with anything
            yt-dlp works with.
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
end

local execute = {
  backup = function()
    os.execute("yt-dlp --retries 100 --write-sub --write-auto-sub --sub-lang \"en.*\" --write-thumbnail --write-description -f \"bestvideo[height<=720]+bestaudio/best[height<=720]\" \"" .. url .."\"")
  end,
  music = function()
    os.execute("yt-dlp --retries 100 -x --audio-quality 0 \"" .. url .."\"")
  end,
  metadata = function()
    os.execute("yt-dlp --retries 100 --write-sub --write-auto-sub --sub-lang \"en.*\" --write-thumbnail --write-description --skip-download \"" .. url .."\"")
  end,
  video = function()
    os.execute("yt-dlp --retries 100 -f \"bestvideo[height<=720]+bestaudio/best[height<=720]\" \"" .. url .. "\"")
  end,
}
execute.clone = execute.backup
execute.copy = execute.backup
execute.audio = execute.music
execute.meta = execute.metadata

if execute[action] then
  execute[action]()
else
  print("Invalid <action>")
  print("Received:", "action", action, "url", url)
end
