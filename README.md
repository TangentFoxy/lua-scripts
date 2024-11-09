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
This script is only intended for personal use. Do not use it to infringe on copyright.

```
Usage:

  make-epub.lua <config (JSON file)> [action]

If "." is used instead of a JSON file, every JSON file in the current directory
will be used to make multiple ebooks back-to-back.

[action]: If not specified, all steps will be taken in order (except cleanall).
            download:  All pages will be downloaded to their own HTML files.
            convert:   Each page is converted to Markdown.
            concat:    A file is created for each section out of its pages.
            markdown:  Metadata frontmatter and Markdown section files will be
                       concatenated into a single Markdown file.
            epub:      Markdown file will be converted to an ePub using pandoc.
            cleanpage: All page files will be deleted, along with their extra
                       directories.
            cleanall:  Deletes everything except the config file and ePub.

Requirements:
- Binaries:      pandoc, curl
```

The JSON config spec has two major variations ("Book" and "Anthology").

The following is shared:
- `authors`: (Optional) Array of Strings: Author names. First in the list is used as a byline in the final output. (Legacy: An `author` string works as well. If this exists, it will be first.)
- `title`: (Optional) String: Title of book.
- `base_file_name`: (Optional) String: Alternate final file name. (Default: "`title` by `author`" or just "`title`".)
- `keywords`: Array of Strings: Keywords/Tags. (I'm not sure what the difference is in the final output so it goes in both.)
- `sections`: **See "Book"/"Anthology" variations.** (I call LitErotica's stories sections - because they are often part of a larger whole.)
- `section_titles`: (Optional) Array of Strings: The titles to be used for Table of Contents / headings. (If `sections.naming` is specified, `section_titles` will be ignored.)
- `extract_titles`: (Optional) Boolean: Titles will be extracted from the first page of every section. (Note: This is compatible with `sections.automatic_naming`, but it can create repeated titles.)
- `lazy_titling`: (Optional) Boolean: URLs will be used to generate section titles. (Warning: This process is likely to create janky titles. Note: This is compatible with `sections.automatic_naming`, but it can create repeated titles.)
- `page_counts`: Array of Integers: The number of pages on LitErotica per "story". (I call them sections because this script was made to put together story series originally.)

#### Variation: Book
- `base_url`: String: A partial URL that is the beginning of the URL used for each section (story) on LitErotica. (This script currently only works for stories that end in a padded two-digit number.) (Technically optional if `first_section_url` is specified, and `sections.start` and `sections.finish` are both `1`.)
- `first_section_url`: (Optional) String: Some stories don't have the same URL structure for their first section. This allows you to specify its full URL.
- `sections`: Object defining which sections to download, and what to call them (ie. Chapters, Parts, ..).
  - `start`: (Optional) Number: Where to start. (`1` is the default, since it is the most common.)
  - `finish`: Number: Where to end.
  - `naming`: (Optional) String: How to name sections in the final output. The result is `[naming] [#]` (using section numbers). (If not specified, sections will not have headings.)
  - `automatic_naming`: (Optional) Boolean: If any line matches "Prologue" or "Chapter #" (any number), it will be made into a heading. (Note: This does not override `naming`. Both can be used together.) (Other patterns will be added as I find them.)

Example:
```json
{
  "authors": ["Name"],
  "title": "Book",
  "base_file_name": "Book",
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
- `section_titles`: (**Required**) Array of Strings: The titles to be used for Table of Contents / headings. (Must be in the same order as `sections`.)

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
