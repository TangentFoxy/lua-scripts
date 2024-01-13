#!/usr/bin/env luajit

for key, value in pairs(arg) do
  print(key, value)
  -- -n to -1 is FIRST the interpreter path and THEN variables passed to it in order
  -- 0 is the path to the file being executed
  -- 1+ are arguments.
  --   powershell handles quotes, cmd does not even pass arguments
end

-- os.execute("sleep 5")
