local success, utility = pcall(function()
  return dofile((arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "utility-functions.lua")
end)
if not success then
  print("\n\n" .. tostring(utility))
  error("\n\nThis script may be installed improperly. Follow instructions at:\n\thttps://github.com/TangentFoxy/.lua-files#installation\n")
end

utility.ls(".")(function(file_name)
  if file_name:find("%.json$") then
    os.execute("lua C:\\Users\\Public\\.lua-files\\make-epub.lua \"" .. file_name .. "\"")
    os.execute("sleep " .. math.random(5))
  end
end)
