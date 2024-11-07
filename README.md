# .lua-files
Personally convenient Lua scripts to add to my path.

## Installation
1. Put this folder somewhere.
2. Add that somewhere to your path. (On Windows, search for Environment Variables (it's "part of" Control Panel) and use the UI to add them to System variables.)
3. (On Windows) Add `.LUA` to PATHEXT.

## Scripts
- `2webm.lua`: Converts everything in the working directory to .webm files.
- `llm.lua`: (Windows only!) A very WIP script for working with LLMs through WSL using [ollama](https://github.com/jmorganca/ollama).
- `print-arguments.lua`: For testing how a Lua script receives arguments, because this can be platform-specific.
- `storage-statistics.lua`: Prints a variety of statistics about the files within the current directory. Requires LFS.
- `test.lua`: (Dev Test) Used repeatedly while working on these scripts to verify minor details I'm forgetful about.
- `utility-functions.lua`: (Library) Required for many of these scripts to run.
- `video-dl.lua`: A few premade command lines for using `yt-dlp` to download what I want quicker.

### make-epub.lua
The JSON config spec has two major variations ("Book" and "Anthology").

The following is shared:
- `authors`: (Optional) Array of Strings: Author names. First in the list is used as a byline in the final output. (Legacy: An `author` string works as well. If this exists, it will be first.)
- `title`: (Optional) String: Title of book.
- `keywords`: Array of Strings: Keywords/Tags. (I'm not sure what the difference is in the final output so it goes in both.)
- `sections`: \! See "Book"/"Anthology" variations. (I call LitErotica's stories sections - because they are often part of a larger whole.)
- `page_counts`: Array of Integers: The number of pages on LitErotica per "story". (I call them sections because this script was made to put together story series originally.)

#### Variation: Book
- `base_url`: String: A partial URL that is the beginning of the URL used for each section (story) on LitErotica. (This script currently only works for stories that end in a padded two-digit number.)
- `first_section_url`: String: Some stories don't have the same URL structure for their first section. This allows you to specify its full URL.
- `sections`: Object defining which sections to download, and what to call them (ie. Chapters, Parts, ..).
  - `start`: (Optional) Number: Where to start. (`1` is the default, since it is the most common.)
  - `finish`: Number: Where to end.
  - `naming`: (Optional) String: How to name sections in the final output. The result is `[naming] [#]` (using section numbers). If not specified, there will be no Table of Contents.
  - `automatic_naming`: (Optional) Boolean: If any line matches "Prologue" or "Chapter #" (any number), it will be made into a heading. (Note: This does not override `naming`. Both can be used together.)

Example:
```json
{
  "authors": ["Name"],
  "title": "Book",
  "keywords": ["erotica", "fantasy"],
  "base_url": "https://www.literotica.com/s/title-ch-",
  "first_section_url": "https://www.literotica.com/s/title",
  "sections": {
    "start": 1,
    "finish": 4,
    "naming": "Chapter",
    "automatic_naming": true
  },
  "page_counts": [1, 5, 3, 3]
}
```

#### Variation: Anthology
- `manually_specified_sections`: (Optional) Boolean, must be `true`. Technically not required as the script is capable of figuring out you are using this variation, but *should be* included.
- `sections`: Array of Strings: A complete URL for each story.
- `section_titles`: (Optional) Array of Strings: The titles to be used for Table of Contents / headings. (Must be in the same order as `sections`.)

Example:
```json
{
  "authors": ["Name"],
  "title": "Anthology",
  "keywords": ["LitErotica", "erotica"],
  "manually_specified_sections": true,
  "sections": [
    "https://www.literotica.com/s/unique-title",
    "https://www.literotica.com/s/another-title"
  ],
  "section_titles": [
    "Unique Title",
    "Another Title"
  ],
  "page_counts": [5, 2]
}
```
