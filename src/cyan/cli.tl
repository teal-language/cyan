---@brief
--- The command line driver
---
--- This is not a module to be used and requiring it will attempt to start the cli and call os.exit
local argparse <const> = require("argparse")
local tl <const> = require("tl")

local command <const> = require("cyan.command")
local common <const> = require("cyan.tlcommon")
local config <const> = require("cyan.config")
local fs <const> = require("cyan.fs")
local log <const> = require("cyan.log")
local script <const> = require("cyan.script")
local util <const> = require("cyan.util")

local keys <const>, from <const>, sort <const>, ivalues <const>
   = util.tab.keys, util.tab.from, util.tab.sort_in_place, util.tab.ivalues

local parser <const> = argparse("cyan", "The Teal build system")
parser:add_help(false)

parser:option("-l --preload", "Execute the equivalent of require('modulename') before processing Teal files.")
      :argname("<modulename>")
      :count("*")

parser:option("--global-env-def", "Load <module-name> before typechecking. Use this to define types provided by your environment.")
      :argname("<module-name>")
      :count("?")

parser:option("-I --include-dir", "Prepend this directory to the module search path.")
      :argname("<directory>")
      :count("*")

local warnings <const>: {string} = sort(from(keys(tl.warning_kinds))) as {string}
table.insert(warnings, "all")
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
      :choices({ "5.1", "5.3", "5.4" })

parser:flag("--no-script", "Do not run any scripts.")
      :action(script.disable)

parser:mutex(
   parser:flag("-q --quiet", "Do not print information messages to stdout. Errors may still be printed to stderr. (Same as --verbosity quiet)."),
   parser:option("-v --verbosity", "Set verbosity of logging.")
         :choices(log.verbosities)
         :action(function(_: argparse.Args, __: string, val: string|boolean|{string})
            log.set_verbosity(val as log.Verbosity)
         end)
)

parser:option("-s --source-dir", "Override the source directory.")
parser:option("-b --build-dir", "Override the build directory.")

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

command.new{
   name = "version",
   description = [[Print version information and exit]],
   exec = function(): integer
      log.info(
         "Cyan version: ", require("cyan.meta").version, "\n",
         "Teal version: ", tl.version(), "\n",
         " Lua version: ", _VERSION
      )
      return 0
   end
}

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

log.debug("Arguments: ", args)

local exit: integer = 1
local starting_dir <const> = fs.cwd()
local config_path <const> = config.find()
if config_path then
   local config_dir <const> = config_path:copy()
   table.remove(config_dir)
   log.debug("Changing directory into: ", config_dir)
   fs.chdir(config_dir)
end

local loaded_config, config_errors <const>, config_warnings <const>
   = config.load()

if common.report_config_errors(config_errors, config_warnings) then
   os.exit(1)
end

if not loaded_config then
   loaded_config = {}
end
command.merge_args_into_config(loaded_config, args)

if loaded_config.scripts then
   for hook, filenames in pairs(loaded_config.scripts[command.running.name] or {}) do
      if filenames is string then
         filenames = { filenames }
      end
      for f in ivalues(filenames as {string}) do
         log.debug("registering file '", f, "' for ", command.running.name, ":", hook)
         script.register(f, command.running.name, hook)
      end
   end
end

do
   local ok <const>, err <const> = script.ensure_loaded_for_command(command.running.name)
   if not ok then
      if err is tl.Result then
         common.report_result(err, loaded_config)
      else
         log.err("Could not load script: ", err)
      end
      os.exit(1)
   end
   log.debug("loaded scripts for command: ", command.running.name)
end

local ok <const>, res <const> = xpcall(function()
   exit = cmd.exec(args, loaded_config, starting_dir)
end, debug.traceback as function()) as (boolean, string)
if not ok then
   log.err("Error executing command\n   ", res)
   os.exit(2)
end
os.exit(exit)
