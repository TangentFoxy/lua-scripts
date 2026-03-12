#!/usr/bin/env luajit
math.randomseed(os.time())

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local json = require "dkjson"
local argparse = utility.require("argparse")

local parser = argparse():description("Manages a local database of books."):help_max_width(80)
local add = parser:command("add", "add a book")
add:argument("title", "book title"):args(1)
add:argument("author", "book author(s) (' & ' separator)"):args(1)
add:argument("pages", "book page count"):args(1):convert(tonumber)

local tbr = parser:command("tbr", "manage to-be-read list")
local add = tbr:command("add", "add a book") add:argument("title", "book title"):args(1)
local remove = tbr:command("remove rm", "remove a book") remove:argument("title", "book title"):args(1)
tbr:command("show", "show the to-be-read list")

local reading = parser:command("reading", "manage reading progress")
local start = reading:command("start", "start a book") start:argument("title", "book title"):args(1)
local pages = reading:command("progress pages", "set progress on a book") pages:argument("title", "book title"):args(1) pages:argument("pages", "book page count"):args(1):convert(tonumber)
local finish = reading:command("finish", "finish a book") finish:argument("title", "book title"):args(1)
local show = reading:command("show", "show reading progress")
show:argument("order", "sort order"):choices{"nearly-finished", "least-read", "shortest", "longest"}:default("nearly-finished"):defmode("arg"):args("?") -- WARNING defaults don't actually work

local options = parser:parse()

if options.show and not options.order then
  options.order = "nearly-finished" -- workaround for broken default setting :\
end



-- NOTE uncomment to debug argparse results
-- for k,v in pairs(options) do print(k,v) end
-- if true then os.exit() end
-- NOTE comment out to actually use the fucking script



-- used for show commands' output
local list = {}
local orders = {
  ["nearly-finished"] = function(A, B) return A.pages / A.total_pages > B.pages / B.total_pages end,
  ["least-read"] = function(A, B) return A.pages / A.total_pages < B.pages / B.total_pages end,
  ["shortest"] = function(A, B) return A.total_pages < B.total_pages end,
  ["longest"] = function(A, B) return A.total_pages > B.total_pages end,
}



local data = utility.open("books.json", "r", function(file) return json.decode(file:read("*all")) end)
for title, value in pairs(data.tbr) do
  if value == true then
    data.tbr[title] = math.random()
  end
end

if options.tbr then
  if options.add then
    if not data.tbr[options.title] then
      data.tbr[options.title] = math.random() -- make a unique order even at same priority more likely
    end
    data.tbr[options.title] = data.tbr[options.title] + 1
  elseif options.remove then
    data.tbr[options.title] = nil
  elseif options.show then
    for title, value in pairs(data.tbr) do
      list[#list + 1] = { title = title, priority = value, }
    end
    table.sort(list, function(A, B) return A.priority > B.priority end)
    for _, book in ipairs(list) do
      print(book.title, math.floor(book.priority))
    end
  end
elseif options.reading then
  if options.start then
    data.reading[options.title] = 0
  elseif options.progress then
    data.reading[options.title] = options.pages
  elseif options.finish then
    data.reading[options.title] = data.books[options.title].pages
  elseif options.show then
    for title, pages in pairs(data.reading) do
      if pages ~= data.books[title].pages then
        list[#list + 1] = { title = title, pages = pages, total_pages = data.books[title].pages, }
      end
    end
    table.sort(list, orders[options.order])
    for _, book in ipairs(list) do
      print(book.title, book.pages .. "/" .. book.total_pages, string.format("%.1f", book.pages / book.total_pages * 100) .. "%")
    end
  end
elseif options.add then
  data.books[options.title] = { author = options.author, pages = options.pages, }
end

if not options.show then
  utility.open("books.json", "w", function(file)
    file:write(json.encode(data, { indent = true }))
    file:write("\n")
  end)
end
