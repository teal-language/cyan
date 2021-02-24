local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local debug = _tl_compat and _tl_compat.debug or debug; local os = _tl_compat and _tl_compat.os or os; local table = _tl_compat and _tl_compat.table or table; local xpcall = _tl_compat and _tl_compat.xpcall or xpcall; local argparse = require("argparse")
local command = require("cyan.command")
local common = require("cyan.tlcommon")
local log = require("cyan.log")

local parser = argparse("cyan", "The Teal build system")

local function forward_arg(fn)
   return function(a, key, val)
      if type(a[key]) == "table" then
         table.insert(a[key], val)
      else
         a[key] = val
      end
      fn(val)
   end
end

parser:option("-l --preload", "Execute the equivalent of require('modulename') before processing Teal files."):
argname("<modulename>"):
count("*")

parser:option("-I --include-dir", "Prepend this directory to the module search path."):
argname("<directory>"):
count("*")

parser:option("--wdisable", "Disable the given kind of warning. Use '--wdisable all' to disable all warnings"):
argname("<warning>"):
count("*"):
action(forward_arg(common.disable_warning))

parser:option("--werror", "Promote the given kind of warning to an error. Use '--werror all' to promote all warnings to errors"):
argname("<warning>"):
count("*"):
action(forward_arg(common.promote_warning))

parser:option("--gen-compat", "Generate compatibility code for targeting different Lua VM versions."):
choices({ "off", "optional", "required" }):
default("optional"):
defmode("a")

parser:option("--gen-target", "Minimum targeted Lua version for generated code."):
choices({ "5.1", "5.3" })

parser:flag("-q --quiet", "Do not print information messages to stdout. Errors may still be printed to stderr.")

parser:command_target("command")

command.new({
   name = "help",
   exec = function()
      log.info(parser:get_help())
      return 0
   end,
})

parser:flag("-h --help"):
action(function() os.exit(command.get("help").exec()) end)

require("cyan.commands.initialize")
require("cyan.commands.check-gen")
require("cyan.commands.run")
require("cyan.commands.build")

command.register_all(parser)

local args
do
   local ok, res = parser:pparse()
   if not ok then
      log.err(res)
      log.info(parser:get_usage())
      os.exit(1)
   end
   args = res
end
local cmd = command.get(args["command"])

if args.quiet then
   log.info = function() end
   log.warn = function() end
end

local exit = 1
do
   local ok, res = xpcall(function()
      exit = cmd.exec(args)
   end, debug.traceback)
   if not ok then
      log.err("Error executing command\n   ", res)
      os.exit(2)
   end
end
os.exit(exit)