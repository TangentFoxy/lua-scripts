# .lua-files
It's like dotfiles, but no, it's just Lua scripts I find useful.

## Scripts
- `popen-command-test.lua`: A badly-named WIP script for working with LLMs through WSL using [ollama](https://github.com/jmorganca/ollama).
- `print-arguments.lua`: For testing how a Lua script receives arguments. (It can be platform-specific.)
- `test.lua`: (Dev Test) Used repeatedly while working on these scripts to verify minor details I'm forgetful about.
- `utility-functions.lua`: (Library) Required for many of these scripts to run.
- `video-dl.lua`: A few premade command lines for using `yt-dlp` to download what I want quicker.

## Installation
1. Put this folder somewhere.
2. Add that somewhere to your path. (On Windows, search for Environment Variables (it's "part of" Control Panel) and use the UI to add them to System variables.)
3. (On Windows) Add `.LUA` to PATHEXT.
