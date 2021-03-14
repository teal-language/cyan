local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local debug = _tl_compat and _tl_compat.debug or debug; local os = _tl_compat and _tl_compat.os or os; local xpcall = _tl_compat and _tl_compat.xpcall or xpcall; local argparse = require("argparse")
local command = require("cyan.command")
local log = require("cyan.log")

local parser = argparse("cyan", "The Teal build system")

parser:option("-l --preload", "Execute the equivalent of require('modulename') before processing Teal files."):
argname("<modulename>"):
count("*")

parser:option("-I --include-dir", "Prepend this directory to the module search path."):
argname("<directory>"):
count("*")

parser:option("--wdisable", "Disable the given kind of warning. Use '--wdisable all' to disable all warnings"):
argname("<warning>"):
count("*")

parser:option("--werror", "Promote the given kind of warning to an error. Use '--werror all' to promote all warnings to errors"):
argname("<warning>"):
count("*")

parser:option("--gen-compat", "Generate compatibility code for targeting different Lua VM versions."):
choices({ "off", "optional", "required" }):
default("optional"):
defmode("a")

parser:option("--gen-target", "Minimum targeted Lua version for generated code."):
choices({ "5.1", "5.3" })

parser:flag("-q --quiet", "Do not print information messages to stdout. Errors may still be printed to stderr.")

parser:flag("--no-script", "Do not run any scripts."):
action(function() require("cyan.script").emit_hook = function() return true end end)

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
require("cyan.commands.warnings")

command.register_all(parser)

local Args = command.Command.Args
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
local cmd = assert(command.get(args.command))
command.running = cmd

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