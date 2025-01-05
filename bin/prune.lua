#!/usr/bin/env lua

-- Advanced features using only standard Lua libraries
local arg = require('arg')
local os = require('os')
local io = require('io')
local table = require('table')

-- Terminal colors using ANSI escape sequences
local colors = {
  red = "\27[31m",
  green = "\27[32m",
  yellow = "\27[33m",
  blue = "\27[34m",
  reset = "\27[0m",
  bold = "\27[1m"
}

-- Smart argument parser using Lua patterns
local function parse_args()
  local args = {
    min_size = 3096,
    yes = false
  }

  local i = 1
  while i <= #arg do
    if arg[i]:match("^%-m") or arg[i]:match("^%-%-min%-size") then
      args.min_size = tonumber(arg[i + 1]) or args.min_size
      i = i + 2
    elseif arg[i]:match("^%-y") or arg[i]:match("^%-%-yes") then
      args.yes = true
      i = i + 1
    else
      i = i + 1
    end
  end
  return args
end

-- Get terminal width (works on Unix-like systems)
local function get_terminal_width()
  local handle = io.popen("tput cols")
  if handle then
    local width = tonumber(handle:read("*n")) or 80
    handle:close()
    return width
  end
end

-- Smart size formatter using locale-aware number formatting
local function format_size(kb)
  local function comma_value(amount)
    local formatted = tostring(amount)
    local k
    while true do
      formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
      if k == 0 then break end
    end
    return formatted
  end

  return comma_value(kb) .. " KB"
end

-- Center text
local function center(text, width)
  local padding = math.floor((width - #text) / 2)
  return string.rep(" ", padding) .. text
end

-- Main script with error handling
local ok, err = pcall(function()
  local args = parse_args()
  local width = get_terminal_width()

  -- Collect directories using iterator pattern
  local dirs = {}
  local find = assert(io.popen("find . -type d -exec du -sk {} +"))
  for line in find:lines() do
    local size, path = line:match("(%d+)%s+(.*)")
    size = tonumber(size)
    if size < args.min_size
        and path ~= "."
        and not path:match("%.[^/]*(stfolder)")
        and not path:match("%.[^/]*(git)") then
      table.insert(dirs, { path = path, size = size })
    end
  end
  find:close()

  -- Sort by size
  table.sort(dirs, function(a, b) return a.size < b.size end)

  if #dirs == 0 then
    io.stderr:write(string.format("No directories below %s\n",
      format_size(args.min_size)))
    os.exit(1)
  end

  -- Pretty output
  print(string.rep("─", width))
  print(center("Small Directories", width))
  print(string.rep("─", width))
  print(string.format("Found %d directories below %s\n",
    #dirs, format_size(args.min_size)))

  -- Print directories with size-based coloring
  for _, dir in ipairs(dirs) do
    local color = dir.size < args.min_size / 2 and colors.red or colors.yellow
    print(string.format("%s%-12s%s │ %s",
      color,
      format_size(dir.size),
      colors.reset,
      dir.path))
  end
  print()

  if args.yes or io.write("Delete these directories? [y/N] ") and
      io.read():lower() == "y" then
    print("\nDeleting directories...")
    for _, dir in ipairs(dirs) do
      print(string.format("%sDeleting%s %s",
        colors.yellow, colors.reset, dir.path))
      os.execute(string.format("rm -rf %q", dir.path))
    end
    print(string.format("\n%sOperation completed.%s",
      colors.green, colors.reset))
  else
    print(string.format("\n%sOperation canceled.%s",
      colors.blue, colors.reset))
  end
end)

if not ok then
  io.stderr:write(string.format("%sError:%s %s\n",
    colors.red, colors.reset, err))
  os.exit(1)
end
