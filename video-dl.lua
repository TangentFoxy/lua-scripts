#!/usr/bin/env luajit

local helptext = [[
Actions:
  video:               Highest quality video (maximum 720p).
  backup, clone, copy: English subtitles (including automatic subtitles),
                       thumbnail, description, highest quality video (max 720p).
  music, audio:        Highest quality audio only.
  metadata, meta:      English subtitles (including automatic subtitles),
                       thumbnail, description.
]]

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local argparse = utility.require("argparse")

local parser = argparse():description("Download media and metadata from anything supported by YT-DLP."):epilog(helptext)
parser:argument("action", "What media and/or metadata to select."):choices{"video", "backup", "clone", "copy", "music", "audio", "metadata", "meta"}
  :default("video"):defmode("arg"):args("?")
parser:flag("--file", "The URL specified is actually a file of one URL per line to be processed.")
parser:argument("url", "Source URL. Can be from anywhere supported by YT-DLP."):args(1)
local options = parser:parse()

-- BUG even though this is specified as an optional argument, argparse won't handle it correctly
if not options.action then options.action = "video" end



utility.required_program("yt-dlp")

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

if options.file then
  pcall(function()
    for line in io.lines(options.url) do
      execute[options.action](line)
    end
  end)
else
  execute[options.action](options.url)
end
