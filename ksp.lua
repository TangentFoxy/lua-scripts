#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local json = utility.require("dkjson")

local function os_move(source, destination)
  os.execute(utility.commands.move .. source:enquote() .. " " .. destination:enquote())
end

local function find_orphan_mods(mods)
  local mod_files_hashtable = {}
  for name, mod in pairs(mods) do
    if mod == true then
      mod_files_hashtable[name] = true
    elseif mod.list and (not mod.missing) then
      for _, name in ipairs(mod.list) do
        mod_files_hashtable[name] = true
      end
      -- mod.dependencies uses the name you provide rather than the directory name, so it is out of place here
      -- if mod.dependencies then
      --   for _, name in ipairs(mod.dependencies) do
      --     mod_files_hashtable[name] = true
      --   end
      -- end
    else
      for _, name in ipairs(mod) do
        mod_files_hashtable[name] = true
      end
    end
  end
  local found_files_hashtable = {}
  local ignored_files = utility.enumerate{".", "..", ".DS_Store"}
  utility.ls("Mods", function(file_name)
    if ignored_files[file_name] then return end
    found_files_hashtable[file_name] = true
    if not mod_files_hashtable[file_name] then
      print(file_name:enquote() .. " is present, but unlisted.")
    end
  end)
  for name in pairs(mod_files_hashtable) do
    if not found_files_hashtable[name] then
      print(name:enquote() .. " is listed, but missing.")
    end
  end
end

-- ModuleManager should always be present in GameData
local function module_manager_check()
  local found = false
  utility.ls("GameData", function(file_name)
    if file_name:find("ModuleManager") then
      found = true
    end
  end)
  assert(found, "ModuleManager must be present in GameData.")
end
module_manager_check()

local function load_instance_file()
  local file = io.open("instance.json")
  assert(file, "instance.json must in KSP's root directory.")
  local text = file:read("*all")
  local data = json.decode(text)
  return data.mods, data.instances
end
local mods, instances = load_instance_file()



local selected_instance = table.concat(arg, " ")
assert(#selected_instance > 0, "Call ksp.lua with an instance's name.")

if selected_instance == "--find-orphans" then
  find_orphan_mods(mods)
  os.exit()
end

local instance = instances[selected_instance]
assert(instance, selected_instance:enquote() .. " is not a named instance.")



-- select dependencies
local dependencies = {}
for _, name in ipairs(instance.mods or {}) do
  local list = type(mods[name]) == "table" and mods[name].dependencies
  if list then
    for _, name in ipairs(list) do
      dependencies[name] = true
    end
  end
end
for name in pairs(dependencies) do
  instance.mods[#instance.mods + 1] = name
end

-- prepare mod move commands
local start_move_queue, cleanup_move_queue = {}, {}
for _, name in ipairs(instance.mods or {}) do
  local mod = mods[name]
  assert(mod, "Mod " .. name:enquote() .. " is not defined.")
  if mod == true then
    start_move_queue["Mods/" .. name] = "GameData"
    cleanup_move_queue["GameData/" .. name] = "Mods"
  elseif mod.subdirectory then
    os.execute("mkdir -p " .. mod.subdirectory:enquote()) -- WARNING may not work multiplatform
    for _, name in ipairs(mod.list) do
      start_move_queue["Mods/" .. name] = mod.subdirectory
      cleanup_move_queue[subdirectory .. utility.path_separator .. name] = "Mods"
    end
  elseif mod.list then
    for _, name in ipairs(mod.list) do
      start_move_queue["Mods/" .. name] = "GameData"
      cleanup_move_queue["GameData/" .. name] = "Mods"
    end
  else
    for _, name in ipairs(mod) do
      start_move_queue["Mods/" .. name] = "GameData"
      cleanup_move_queue["GameData/" .. name] = "Mods"
    end
  end

  if type(mod) == "table" then
    if mod.incomplete then
      print("Mod " .. name:enquote() .. " is marked as incomplete and will not work correctly.")
    end
    if mod.missing then
      print("Mod " .. name:enquote() .. " is marked as missing.")
    end
    if mod.broken then
      print("Mod " .. name:enquote() .. " is marked as broken and may not work correctly.")
    end
  end
end

for _, name in ipairs(instance.saves or {}) do
  start_move_queue["InstanceSaves/" .. name] = "saves"
  cleanup_move_queue["saves/" .. name] = "InstanceSaves"
end



for source, destination in pairs(start_move_queue) do
  os_move(source, destination)
end

os.execute("./KSP.app/Contents/MacOS/KSP") -- TODO fix for multiplatform

for source, destination in pairs(cleanup_move_queue) do
  os_move(source, destination)
end
