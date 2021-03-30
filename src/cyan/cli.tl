local argparse <const> = require("argparse")
local tl <const> = require("tl")
local command <const> = require("cyan.command")
local log <const> = require("cyan.log")
local util <const> = require("cyan.util")
local keys <const>, from <const>, sort <const>
   = util.tab.keys, util.tab.from, util.tab.sort

local parser <const> = argparse("cyan", "The Teal build system")
parser:add_help(false)

parser:option("-l --preload", "Execute the equivalent of require('modulename') before processing Teal files.")
      :argname("<modulename>")
      :count("*")

parser:option("-I --include-dir", "Prepend this directory to the module search path.")
      :argname("<directory>")
      :count("*")

local warnings <const> = sort(from(keys(tl.warning_kinds)))
parser:option("--wdisable", "Disable the given kind of warning. Use '--wdisable all' to disable all warnings")
      :argname("<warning>")
      :choices(warnings)
      :count("*")

parser:option("--werror", "Promote the given kind of warning to an error. Use '--werror all' to promote all warnings to errors")
      :argname("<warning>")
      :choices(warnings)
      :count("*")

parser:option("--gen-compat", "Generate compatibility code for targeting different Lua VM versions.")
      :choices({ "off", "optional", "required" })
      :default("optional")
      :defmode("a")

parser:option("--gen-target", "Minimum targeted Lua version for generated code.")
      :choices({ "5.1", "5.3" })

parser:flag("-q --quiet", "Do not print information messages to stdout. Errors may still be printed to stderr.")

parser:flag("--no-script", "Do not run any scripts.")
      :action(function() require("cyan.script").emit_hook = function(): boolean, string return true end end)

parser:command_target("command")

command.new{
   name = "help",
   description = [[Show this message and exit]],
   exec = function(): integer
      log.info(parser:get_help())
      return 0
   end,
}

parser:flag("-h --help", "Show this help message and exit")
      :action(function()
         os.exit(command.get("help").exec())
      end)

require("cyan.commands.initialize")
require("cyan.commands.check-gen")
require("cyan.commands.run")
require("cyan.commands.build")
require("cyan.commands.warnings")

command.register_all(parser)

local type Args = command.Args
local args: Args
do
   local ok <const>, res <const> = parser:pparse()
   if not ok then
      log.err(res)
      log.info(parser:get_usage())
      os.exit(1)
   end
   args = res as Args
end
local cmd <const> = assert(command.get(args.command))
command.running = cmd

if args.quiet then
   log.info = function() end
   log.warn = function() end
end

local exit: integer = 1
do
   local ok <const>, res <const> = xpcall(function()
      exit = cmd.exec(args)
   end, debug.traceback as function()) as (boolean, string)
   if not ok then
      log.err("Error executing command\n   ", res)
      os.exit(2)
   end
end
os.exit(exit)

