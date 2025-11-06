# lua-scripts
Personally convenient Lua scripts to add to my path.

## Installation
1. Put this folder somewhere.
2. Add that somewhere to your path. There is a shell script here for that purpose. (On Windows, search for Environment Variables (it's "part of" Control Panel) and use the UI to add them to System variables. Add `.LUA` to PATHEXT.)

## Config
A `config.json` file in this directory can be used to hold private information and default settings.

Settings per script are stored under a key based on that script's name, or for shared values, based on a library or program's name.
- Right now the exception to this is `fa_cookie_string` which needs to be set to a string `curl` can interpret as cookies for a logged-in FurAffinity user. Practically, this means something that looks like `a=<secret>; b=<secret>; sz=<secret>`.
  - This will be moved to a `curl` object.

## Scripts
- [ ] This list needs to be updated, quite badly.
- `2webm.lua`: Converts everything in the working directory to .webm files.
- `llm.lua`: (Windows only!) A very WIP script for working with LLMs through WSL using [ollama](https://github.com/jmorganca/ollama).
- `print-arguments.lua`: For testing how a Lua script receives arguments, because this can be platform-specific.
- `storage-statistics.lua`: Prints a variety of statistics about the files within the current directory. Requires LFS.
- `test.lua`: (Dev Test) Used repeatedly while working on these scripts to verify minor details I'm forgetful about.
- `utility-functions.lua`: (Library) Required for many of these scripts to run.
- `video-dl.lua`: A few premade command lines for using `yt-dlp` to download what I want quicker.

### 2epub-config.lua
A utility to help automate the creation of configuration files for make-epub.
It accepts a single argument, which can be an author's page (of the form
https://www.literotica.com/authors/USERNAME/works/stories),  a series (like
https://www.literotica.com/series/se/IDENTIFIER), or a file of URLs to the first
pages of individual stories to make an anthology (if a line doesn't start with
"http", it will be used as the title).

For configs based on an author, a third argument being passed instructs the
script to keep everything in one file instead of making separate entries for
each series. This can cause issues due to UI inconsistencies on LitErotica.

Due to caching issues, sometimes there can be mismatches between what you see in
a browser and what this script pulls down. The output JSON is minified due to
the library I'm using. (I may swap this out in the future.)

### make-epub.lua
This script is only intended for personal use. Do not use it to infringe on copyright.

This information is somewhat outdated. The script itself has more info.

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

[flag]: If "--continue" is passed, script will continue with the default order
          of actions from the action specified.

Requirements:
- Binaries:      pandoc, curl
```

The JSON config spec has two major variations ("Book" and "Anthology").

The following is shared:
- `authors`: (Optional) Array of Strings: Author names. First in the list is used as a byline in the final output. (Legacy: An `author` string works as well. If this exists, it will be first.)
- `title`: (Optional) String: Title of book.
- `cover_image_path`: (Optional) String: Path to an image to use for the cover. (Due to a bug in Pandoc, this must not contain spaces!)
- `base_file_name`: (Optional) String: Alternate final file name. (Default: "`title` by `author`" or just "`title`".)
- `keywords`: Array of Strings: Keywords/Tags. (I'm not sure what the difference is in the final output so it goes in both.)
- `sections`: **See "Book"/"Anthology" variations.** (I call LitErotica's stories sections - because they are often part of a larger whole.)
- `section_titles`: (Optional) Array of Strings: The titles to be used for Table of Contents / headings. (If `sections.naming` is specified, `section_titles` will be ignored.)
- `extract_titles`: (Optional) Boolean: Titles will be extracted from the first page of every section. (Note: This is compatible with `sections.automatic_naming`, but it can create repeated titles.)
- `lazy_titling`: (Optional) Boolean: URLs will be used to generate section titles. (Warning: This process is likely to create janky titles. Note: This is compatible with `sections.automatic_naming`, but it can create repeated titles.)
- `page_counts`: Array of Integers: The number of pages on LitErotica per "story". (I call them sections because this script was made to put together story series originally.)
- `custom_content_selector`: For supported domains, a different selector can be used for the main content.
- `description` OR `frontmatter_raw`: (Optional) String: A description to be inserted after the copyright warning. (Technically, since this is put in the final markdown file raw, you can shove other things in here too, if you want to insert content before the first part of story text.) (`description` is intended to go within the copyright warning block, `frontmatter_raw` expects you to use a heading for a custom block.)
- `backmatter_raw`: (Optional) String: A place to put content after the last part, before the ebook creation metadata. You should start this with a chapter heading to prevent it being tacked into the last part!
- `domains`: (Optional) See make-epub.lua to understand the format. This allows you to overwrite or add new processing options for different domains, so that this script can be used for some places I haven't tried to use it for.

#### Variation: Book
- `base_url`: String: A partial URL that is the beginning of the URL used for each section (story) on LitErotica. (This script currently only works for stories that end in a padded two-digit number.) (Technically optional if `first_section_url` is specified, and `sections.start` and `sections.finish` are both `1`.)
- `first_section_url`: (Optional) String: Some stories don't have the same URL structure for their first section. This allows you to specify its full URL.
- `sections`: Object defining which sections to download, and what to call them (ie. Chapters, Parts, ..).
  - `start`: (Optional) Number: Where to start. (`1` is the default, since it is the most common.)
  - `finish`: Number: Where to end.
  - `naming`: (Optional) String: How to name sections in the final output. The result is `[naming] [#]` (using section numbers). (If not specified, sections will not have headings.)
  - `automatic_naming`: (Optional) Boolean: If any line matches "Prologue", "Epilogue", or "Chapter #" (any number), it will be made into a heading. (Note: This does not override `naming`. Both can be used together.) (Other patterns will be added as I find them.)

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
- `automatic_naming`: (Optional) Boolean: Will match a single line against common patterns denoting the beginning of a chapter and add a heading on such lines. It's the same as `sections.automatic_naming` above.

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
