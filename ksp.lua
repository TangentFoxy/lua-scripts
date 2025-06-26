#!/usr/bin/env luajit

-- NOTE it is assumed all mods use ModuleManager and that it remains in place

local installed_location = "GameData"
local disabled_location = "GameData.disabled"

local mods = {
  ["stock"] = { "Squad", },
  ["DLC"] = { "SquadExpansion", },

  ["Airplane Plus"] = { "AirplanePlus", "Firespitter", },
  ["Atmosphere Autopilot"] = { "AtmosphereAutopilot", "KSPUpgradeScriptFix.dll", },
  ["Environmental Visual Enhancements"] = { "BoulderCo", "EnvironmentalVisualEnhancements", },
  ["Feline Utility Rover"] = { "KerbetrotterLtd", "KSPModFileLocalizer.dll", },
  ["Kerbal Construction Time"] = {
    "000_ClickThroughBlocker", "001_ToolbarControl", "KerbalConstructionTime",
    "MagiCore", "SpaceTuxLibrary",
  },
  ["Kerbal Insurance Agency"] = { "Guard13007", "SlowCPU", },
  ["KerbinSide"] = {
    "CustomPreLaunchChecks", "KerbalKonstructs", "KerbinSideRemastered",
  },
  ["OhScrap!"] = { "OhScrap", "ScrapYard" },
  ["Scatterer"] = { "Scatterer", "ScattererAtmosphereCache", }, -- 2nd item is generated on first run
  ["Snacks"] = { "WildBlueIndustries" },
  ["Stockalike Station Parts Expansion Redux"] = {
    "B9PartSwitch", "NearFutureProps", "StationPartsExpansionRedux",
    "StationPartsExpansionReduxIVAs",
  },
  ["Waterfall FX"] = { "StockWaterfallEffects", "Waterfall", },
}
local lists = {
  ["default"] = {
    -- "stock", "DLC",
    "Atmosphere Autopilot", "Environmental Visual Enhancements",
    "KerbalKrashSystem", "Scatterer", "Trajectories", "Waterfall FX",
  },
  ["daily career"] = {
    -- "stock", "DLC",
    "Atmosphere Autopilot", "Environmental Visual Enhancements",
    "KerbalKrashSystem", "Scatterer", "Trajectories", "Waterfall FX",

    "Airplane Plus", "CommunityTechTree", "Grounded",
    "Kerbal Construction Time", "Kerbal Insurance Agency", "KSPSecondaryMotion",
    "OhScrap!", "ScienceAlert", "Snacks",

    -- "DMagicOrbitalScience", "ESLDBeacons", "Feline Utility Rover", "KerbinSide", "kOS",
  },
}

local selected_list = table.concat(arg, " ")
local list = lists[selected_list]
assert(list, "'" .. selected_list .. "' is not a valid list.")

-- convert list selection into a hashtable of names for all needed files
--  (this handles duplicated names from dependencies)
local file_names_hashtable = {}
for _, mod_name in ipairs(list) do
  local mod_list = mods[mod_name]
  if mod_list then
    for _, mod_name in ipairs(mod_list) do
      file_names_hashtable[mod_name] = true
    end
  else
    file_names_hashtable[mod_name] = true
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

move_list(file_names_list, disabled_location, installed_location)
os.execute("./KSP.app/Contents/MacOS/KSP")
move_list(file_names_list, installed_location, disabled_location)
