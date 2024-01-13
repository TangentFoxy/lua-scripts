
function os.command(command)
  local file = assert(io.popen(command, 'r'))
  local output = assert(file:read('*a'))
  file:close()
  return output
end

function string.trim6(s)
  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

print("---")

-- local home = os.command("echo %userprofile%")
-- home = string.trim6(home)
-- print(home)

-- local dolphin_cheese = os.command("wsl -- ollama run dolphin-mixtral \"Say only the word 'cheese'.\"")
-- local dolphin_cheese = os.command("wsl")
-- os.execute("C:\\Windows\\System32\\wsl.exe")
-- local dolphin_cheese = os.command("echo %path%")
-- local dolphin_cheese = os.command("where wsl")
-- print(dolphin_cheese)

-- print(os.command("bash -c \"$PATH\""))
-- os.execute("bash -c \"ollama help\"")

-- runs but doesn't return anything?
-- local dolphin_cheese = os.command("pwsh -Command wsl -- ollama run dolphin-mixtral \"Say only the word 'cheese'.\"")
-- print(dolphin)

-- os.execute("pwsh -Command wsl -- ollama run dolphin-mixtral \"Say only the word 'cheese'.\"")

-- this will output to file in the correct place :D
os.execute("pwsh -Command wsl --exec \"ollama run dolphin-mixtral \\\"Say only the word 'cheese'.\\\"\" > test-output-file.txt")

print("---")
