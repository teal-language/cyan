local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local debug = _tl_compat and _tl_compat.debug or debug; local os = _tl_compat and _tl_compat.os or os; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local xpcall = _tl_compat and _tl_compat.xpcall or xpcall



local argparse = require("argparse")
local tl = require("tl")

local command = require("cyan.command")
local common = require("cyan.tlcommon")
local config = require("cyan.config")
local fs = require("cyan.fs")
local log = require("cyan.log")
local script = require("cyan.script")
local util = require("cyan.util")

local keys, from, sort, ivalues =
util.tab.keys, util.tab.from, util.tab.sort_in_place, util.tab.ivalues

local parser = argparse("cyan", "The Teal build system")
parser:add_help(false)

parser:option("-l --preload", "Execute the equivalent of require('modulename') before processing Teal files."):
argname("<modulename>"):
count("*")

parser:option("--global-env-def", "Load <dtlfilename> before typechecking. Use this to define types provided by your environment."):
argname("<dtlfilename>"):
count("?")

parser:option("-I --include-dir", "Prepend this directory to the module search path."):
argname("<directory>"):
count("*")

local warnings = sort(from(keys(tl.warning_kinds)))
parser:option("--wdisable", "Disable the given kind of warning. Use '--wdisable all' to disable all warnings"):
argname("<warning>"):
choices(warnings):
count("*")

parser:option("--werror", "Promote the given kind of warning to an error. Use '--werror all' to promote all warnings to errors"):
argname("<warning>"):
choices(warnings):
count("*")

parser:option("--gen-compat", "Generate compatibility code for targeting different Lua VM versions."):
choices({ "off", "optional", "required" }):
default("optional"):
defmode("a")

parser:option("--gen-target", "Minimum targeted Lua version for generated code."):
choices({ "5.1", "5.3" })

parser:flag("-q --quiet", "Do not print information messages to stdout. Errors may still be printed to stderr.")

parser:flag("--no-script", "Do not run any scripts."):
action(script.disable)

parser:command_target("command")

command.new({
   name = "help",
   description = [[Show this message and exit]],
   exec = function()
      log.info(parser:get_help())
      return 0
   end,
})

parser:flag("-h --help", "Show this help message and exit"):
action(function()
   os.exit(command.get("help").exec())
end)

command.new({
   name = "version",
   description = [[Print version information and exit]],
   exec = function()
      log.info(
      "Cyan version: ", require("cyan.meta").version, "\n",
      "Teal version: ", tl.version(), "\n",
      " Lua version: ", _VERSION)

      return 0
   end,
})

require("cyan.commands.initialize")
require("cyan.commands.check-gen")
require("cyan.commands.run")
require("cyan.commands.build")
require("cyan.commands.warnings")

command.register_all(parser)

local Args = command.Args
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
local starting_dir = fs.cwd()
local config_path = config.find()
if config_path then
   local config_dir = config_path:copy()
   table.remove(config_dir)

   fs.chdir(config_dir)
end

local loaded_config, config_errors, config_warnings =
config.load()

if common.report_config_errors(config_errors, config_warnings) then
   os.exit(1)
end

if loaded_config then
   command.merge_args_into_config(loaded_config, args)

   if loaded_config.scripts then
      for fname, hooks in pairs(loaded_config.scripts) do
         for hook in ivalues(hooks) do
            if hook:find(command.running.name .. ":", 1, true) then
               local ok, res = script.load(fname, hooks)
               if not ok then
                  if type(res) == "string" then
                     log.err("Could not load script: ", res)
                  else
                     common.report_result(res, loaded_config);
                  end
                  os.exit(1)
               end
               break
            end
         end
      end
   end
end

local ok, res = xpcall(function()
   exit = cmd.exec(args, loaded_config, starting_dir)
end, debug.traceback)
if not ok then
   log.err("Error executing command\n   ", res)
   os.exit(2)
end
os.exit(exit)