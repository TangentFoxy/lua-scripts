local success, utility = pcall(function()
  return dofile((arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "utility-functions.lua")
end)
if not success then
  print("\n\n" .. tostring(utility))
  error("\n\nThis script may be installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n")
end

-- arg[1] would need to be "make-epub.lua" to do what this was previously doing
utility.ls(".")(function(file_name)
  os.execute("lua " .. utility.path .. arg[1] .. " " .. file_name:enquote())
end)
