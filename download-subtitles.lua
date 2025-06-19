#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local argparse = utility.require("argparse")

local parser = argparse():description("Downloads subtitles for all videos within a playlist to \"subtitles\" directory.")
parser:argument("source", "URL of playlist to download subtitles for (channels work too)."):args(1)
local options = parser:parse()



utility.required_program("chromium")
utility.required_program("yt-dlp")
utility.required_program("curl")

local function download_subtitle(id, file_name)
  os.execute("sleep 6") -- up-front in case chromium isn't ready / delay from previous download to prevent rate limit issues
  os.execute("chromium \"https://www.downloadyoutubesubtitles.com/?u=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3D" .. id .. "\"")
  os.execute("sleep 12")
  os.execute("curl \"https://www.downloadyoutubesubtitles.com/get2.php?i=" .. id .. "&format=txt&hl=en&a=\" > \"./subtitles/" .. (file_name or id) .. ".txt\"")
end

-- open browser first, to make sure it is ready by the time we start using it
if utility.OS == "Windows" then
  os.execute("pwsh -command chromium")
else
  os.execute("chromium &")
end

os.execute("yt-dlp --flat-playlist --print-to-file \"%(id)s=%(title)s\" videos.txt --skip-download \"" .. options.source .. "\"")
os.execute("mkdir subtitles")

local videos = {}

utility.open("videos.txt", "r")(function(file)
  for line in file:lines() do
    local i, j = line:find("%=")
    videos[#videos + 1] = {
      id = line:sub(1, i - 1),
      title = line:sub(j + 1),
    }
  end
end)

for index, video in ipairs(videos) do
  print(index, #videos, video.title)
  download_subtitle(video.id, utility.make_safe_file_name(video.title))
end
