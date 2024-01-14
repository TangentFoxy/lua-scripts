# .lua-files
It's like dotfiles, but no, it's just Lua scripts I find useful.

## Scripts
- `2webm.lua`: Converts everything in the working directory to .webm files.
- `llm.lua`: (Windows only!) A very WIP script for working with LLMs through WSL using [ollama](https://github.com/jmorganca/ollama).
- `print-arguments.lua`: For testing how a Lua script receives arguments, because this can be platform-specific.
- `storage-statistics.lua`: Prints a variety of statistics about the files within the current directory. Requires LFS.
- `test.lua`: (Dev Test) Used repeatedly while working on these scripts to verify minor details I'm forgetful about.
- `utility-functions.lua`: (Library) Required for many of these scripts to run.
- `video-dl.lua`: A few premade command lines for using `yt-dlp` to download what I want quicker.

## Installation
1. Put this folder somewhere.
2. Add that somewhere to your path. (On Windows, search for Environment Variables (it's "part of" Control Panel) and use the UI to add them to System variables.)
3. (On Windows) Add `.LUA` to PATHEXT.
