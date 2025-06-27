#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local argparse = utility.require("argparse")
local json = utility.require("dkjson")

local parser = argparse():help_max_width(80)
local create = parser:command("create", "create a model from a modelfile, or pull a model")
create:argument("model", "model name/tag"):args(1)
create:argument("modelfile", "modelfile"):args("?")
local run = parser:command("run", "run a model")
run:argument("model", "the model to run"):args(1)
run:argument("input", "input text to send (if not present, opens interactive mode)"):args("*")
local queue = parser:command("queue", "add queries to the queue")
queue:argument("model", "the model to run"):args(1)
queue:argument("input", "input text to send"):args("1+")
local background = parser:command("background", "run queries in the queue")
background:argument("maximum", "maximum number of queries to execute"):args("?")
local options = parser:parse()

-- concatenate input if needed
if options.input then
  if #options.input == 1 then
    options.input = options.input[1]
  elseif #options.input > 1 then
    options.input = table.concat(options.input, " ")
  else
    options.input = nil
  end
end

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



local queue_file_name = "llm-data.json"

local function get_queue()
  utility.get_lock(queue_file_name)
  local queue
  pcall(function()
    utility.open(queue_file_name, "r", function(file)
      queue = json.decode(file:read("*all"))
    end)
  end)

  if not queue then queue = {} end

  return queue
end

local function save_queue(queue)
  utility.open(queue_file_name, "w", function(file)
    file:write(json.encode(queue, { indent = true }))
    file:write("\n")
  end)
  utility.release_lock(queue_file_name)
end



local function queue_query(model, input)
  local queue = get_queue()
  queue[#queue + 1] = { model = model, input = input, status = "waiting", }
  save_queue(queue)
end

local function background(maximum)
  local function next_query(queue)
    for id, query in ipairs(queue) do
      if query.status == "waiting" then
        query.status = "running"
        return id, query
      end
    end
  end

  local count = 0
  repeat
    local queue = get_queue()
    if not maximum then maximum = #queue end
    local id, selected = next_query(queue)
    save_queue(queue)

    if selected then
      local result = utility.capture("luajit " .. utility.path .. "llm.lua run " .. selected.model .. " " .. selected.input:enquote())
      local queue = get_queue()
      queue[id].status = "finished"
      queue[id].result = result
      save_queue(queue)

      count = count + 1
    else
      return -- nothing left to do!
    end
  until count == maximum
end



if options.create then
  create_model(options.model, options.modelfile)
elseif options.run then
  print(query_model(options.model, options.input))
elseif options.queue then
  queue_query(options.model, options.input)
elseif options.background then
  background(options.maximum)
else
  print(parser:get_help()) -- should be impossible to get here
end
