local source = "URL"

os.execute("yt-dlp --flat-playlist --print-to-file \"%(id)s\" download-list.txt --skip-download \"" .. source .. "\"")
os.execute("yt-dlp --flat-playlist --print-to-file \"%(id)s=%(title)s\" VIDEO-TITLES.txt --skip-download \"" .. source .. "\"")
os.execute("mkdir subtitles")

for line in io.lines("download-list.txt") do
  os.execute("chromium \"https://www.downloadyoutubesubtitles.com/?u=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3D" .. line .. "\"")
  os.execute("sleep 12")
  os.execute("curl \"https://www.downloadyoutubesubtitles.com/get2.php?i=" .. line .. "&format=txt&hl=en&a=\" > \"./subtitles/" .. line .. ".txt\"")
  os.execute("sleep 6")
end
