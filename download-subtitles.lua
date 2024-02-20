#!/usr/bin/env luajit

local source = arg[1]
assert(source and #source > 0, "Specify a URL!")

local function make_safe(file_name)
  -- return file_name:gsub("[%w%s%_%-%,%.%[%]%(%)%'%+]", "") -- this is the literal opposite of what I needed, oops
  -- return file_name:gsub("[%\"%:%\\%!%@%#%$%%%^%&%*%=%{%}%|%;%<%>%?%/]", "") -- this should handle everything but I'm not certain! :D

  file_name = file_name:gsub("[%\"%:%\\%!%@%#%$%%%^%*%=%{%}%|%;%<%>%?%/]", "") -- everything except the &
  file_name = file_name:gsub(" %&", ",")   -- replacing & with a comma works for 99% of things
  file_name = file_name:gsub("%&", ",")    -- replacing & with a comma works for 99% of things
  file_name = file_name:gsub("[%s+]", " ") -- more than one space in succession should be a single space
  return file_name
end

local function download_subtitle(id, file_name)
  os.execute("sleep 6") -- up-front in case chromium isn't ready / delay from previous download to prevent rate limit issues
  os.execute("chromium \"https://www.downloadyoutubesubtitles.com/?u=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3D" .. id .. "\"")
  os.execute("sleep 12")
  os.execute("curl \"https://www.downloadyoutubesubtitles.com/get2.php?i=" .. id .. "&format=txt&hl=en&a=\" > \"./subtitles/" .. (file_name or id) .. ".txt\"")
end

os.execute("pwsh -command chromium") -- open browser first, to make sure it is ready by the time we start using it

os.execute("yt-dlp --flat-playlist --print-to-file \"%(id)s=%(title)s\" videos.txt --skip-download \"" .. source .. "\"")
os.execute("mkdir subtitles")

local videos = {}

local file = io.open("videos.txt", "r")
assert(file, "videos.txt doesn't exist.. somehow")
for line in file:lines() do
  local i, j = line:find("%=")
  videos[#videos + 1] = {
    id = line:sub(1, i - 1),
    title = line:sub(j + 1),
  }
end
file:close()

for index, video in ipairs(videos) do
  print(index, #videos, video.title)
  download_subtitle(video.id, make_safe(video.title))
end
