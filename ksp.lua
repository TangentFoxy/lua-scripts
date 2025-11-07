#!/usr/bin/env luajit

-- NOTE it is assumed all mods use ModuleManager; it remains in place in GameData

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local json = utility.require("dkjson")

local file = io.open("Mods/mods.json")
local text = file:read("*all")
local data = json.decode(text)

local mods = data.mods
local lists = data.lists



local selected_list = table.concat(arg, " ")
assert(#selected_list > 0, "Call ksp.lua with a named mod list.")

local list = lists[selected_list]
assert(list, "'" .. selected_list .. "' is not a defined list.")



-- convert list selection into a hashtable of names for all needed files
--  (this handles duplicated names from dependencies)
local file_names_hashtable = {}
for _, mod_name in ipairs(list) do
  if type(mod_name) == "string" then
    local mod_list = mods[mod_name]
    if mod_list then
      for _, mod_name in ipairs(mod_list) do
        if type(mod_name) == "string" then
          file_names_hashtable[mod_name] = true
        end
      end
    else
      file_names_hashtable[mod_name] = true
    end
  end
end

local file_names_list = {}
for mod_name in pairs(file_names_hashtable) do
  table.insert(file_names_list, mod_name)
end

local function move_list(list, a, b)
  local function os_move(a, b)
    os.execute("mv \"" .. a .. "\" \"" .. b .. "\"")
  end

  for _, mod_name in ipairs(list) do
    os_move(a .. "/" .. mod_name, b .. "/")
  end
end

move_list(file_names_list, "Mods", "GameData")
os.execute("./KSP.app/Contents/MacOS/KSP")
move_list(file_names_list, "GameData", "Mods")
