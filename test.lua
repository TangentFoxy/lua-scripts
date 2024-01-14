#!/usr/bin/env luajit

-- if utility-functions.lua has an error, this won't show it, so for testing purposes, I don't use it here
-- local error_occurred, utility = pcall(function() return dofile(arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)") .. "utility-functions.lua") end) if not error_occurred then error("\n\nThis script is installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n") end
utility = dofile(arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)") .. "utility-functions.lua")

print("---")

-- local value = os.execute("where ffmpeg")
-- print(value, type(value))
utility.required_program("ffmpeg")

print("---")
