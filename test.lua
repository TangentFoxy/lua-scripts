#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

-- NOTE add current test case here
local config = utility.get_config()
config.test_value = true -- both making sure the new locks appear to work, and that saving new data still works
utility.save_config()
