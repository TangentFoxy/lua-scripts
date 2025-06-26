#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local argparse = utility.require("argparse")

local parser = argparse()
parser:argument("action", "create/pull/download/install to set up models/modelfiles; query/run to run a model"):args(1)
  :choices{"create", "pull", "download", "install", "query", "run"}
parser:argument("model", "model name/tag"):args(1)
parser:argument("input", "create/pull/download/install: modelfile, query/run: input text to send (if not present, opens in interactive mode)"):args("*")
local options = parser:parse()

utility.required_program("ollama")

local function query_model(model, prompt)
  if prompt then
    return utility.capture("ollama run " .. model .. " --nowordwrap " .. prompt:enquote())
  else -- interactive
    return os.execute("ollama run " .. model)
  end
end

local function create_model(model, modelfile)
  if not modelfile then modelfile = model end
  if utility.file_exists(modelfile) then
    return os.execute("ollama create " .. model .. " --file " .. modelfile:enquote())
  else
    return os.execute("ollama pull " .. model)
  end
end

local execute = {
  create = create_model, pull = create_model, download = create_model, install = create_model,
  query = query_model, run = query_model,
}

if #options.input == 1 then
  options.input = options.input[1]
elseif #options.input > 1 then
  options.input = table.concat(options.input, " ")
else
  options.input = nil
end

if execute[options.action] then
  print(execute[options.action](options.model, options.input))
end
