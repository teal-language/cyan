---@brief
--- The command line driver
---
--- This is not a module to be used and requiring it will attempt to start the cli and call os.exit
local argparse <const> = require("argparse")
local tl <const> = require("tl")

local cs <const> = require("cyan.colorstring")
local command <const> = require("cyan.command")
local common <const> = require("cyan.tlcommon")
local config <const> = require("cyan.config")
local fs <const> = require("cyan.fs")
local log <const> = require("cyan.log")
local script <const> = require("cyan.script")
local util <const> = require("cyan.util")

local keys <const>, from <const>, sort <const>, ivalues <const>
   = util.tab.keys, util.tab.from, util.tab.sort, util.tab.ivalues

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
      :action(script.disable)

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
local starting_dir <const> = fs.cwd()
local config_path <const> = config.find()
if config_path then
   local config_dir <const> = config_path:copy()
   table.remove(config_dir)

   fs.chdir(config_dir)
end

local loaded_config <const>, config_errors <const>, config_warnings <const>
   = config.load()

if common.report_config_errors(config_errors, config_warnings) then
   os.exit(1)
end

if loaded_config then
   command.merge_args_into_config(loaded_config, args)

   if loaded_config.scripts then
      for fname, hooks in pairs(loaded_config.scripts) do
         for hook in ivalues(hooks) do
            if hook:find(command.running.name .. ":", 1, true) then
               local ok <const>, err <const> = script.load(fname, hooks)
               if not ok then
                  log.err("loading script ", cs.highlight(cs.colors.file, fname), "\n", err)
                  os.exit(1)
               end
               break
            end
         end
      end
   end
end

local ok <const>, res <const> = xpcall(function()
   exit = cmd.exec(args, loaded_config, starting_dir)
end, debug.traceback as function()) as (boolean, string)
if not ok then
   log.err("Error executing command\n   ", res)
   os.exit(2)
end
os.exit(exit)
