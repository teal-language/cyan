---@brief
--- The common interface for commands to implement

local tl <const> = require("tl")
local argparse <const> = require("argparse")

local config <const> = require("cyan.config")
local invocation_context <const> = require("cyan.invocation-context")
--local lexical_path <const> = require("lexical-path")
--local log <const> = require("cyan.log")
local util <const> = require("cyan.util")

local keys <const>, from <const>, sort <const>, ivalues <const>
   = util.tab.keys, util.tab.from, util.tab.sort_in_place, util.tab.ivalues

local interface Args
   command: string
end

---@desc
--- Options for commands that emit compiler warnings
local interface WarningOptions is Args
   wdisable: {tl.WarningKind}
   werror: {tl.WarningKind}
end

---@desc
--- Options for commands that type check teal files
local interface CheckOptions is WarningOptions
   include_dir: {string}
   global_env_def: string
end

---@desc
--- Options for commands that generate lua files
local interface GenOptions is Args
   gen_compat: tl.GenCompat
   gen_target: tl.GenTarget
end

local type CommandFn = function(Args, config.Config, invocation_context.InvocationContext): integer

---@desc
--- The interface
local record Command
   name: string
   description: string
   argparse: function(argparse.Command)
   script_hooks: {string}
   exec: CommandFn
end
local command <const> = {
   running: Command = nil,
   Command = Command,
   CommandFn = CommandFn,
   Args = Args,
   CheckOptions = CheckOptions,
   GenOptions = GenOptions,
   WarningOptions = WarningOptions,
}

local commands <const>: {string:Command} = {}
local hooks <const>: {string:boolean} = {}

---@desc
--- Add options to `cmd` corresponding to `CheckOptions`: `--global-env-def` and `--include-dir`
function command.add_check_options(cmd: argparse.Command)
   cmd:option("--global-env-def", "Load <module-name> before typechecking. Use this to define types provided by your environment.")
      :argname("<module-name>")
      :count("?")

   cmd:option("-I --include-dir", "Prepend this directory to the module search path.")
      :argname("<directory>")
      :count("*")
end

local warning_option_values <const> = sort(from(keys(tl.warning_kinds as {string:boolean})))
table.insert(warning_option_values, "all")

---@desc
--- Convert lists of strings to a set of `tl.WarningKind`
---
--- If any entry is the string `"all"`, a set with every warning kind set
function command.convert_to_warning_set(...: {string}): {tl.WarningKind:boolean}
   local result <const> = {}
   for i = 1, select("#", ...) do
      for kind in ivalues((select(i, ...))) do
         if kind == "all" then
            for k in pairs(tl.warning_kinds) do
               result[k] = true
            end
            return result
         end
         if tl.warning_kinds[kind as tl.WarningKind] then
            result[kind as tl.WarningKind] = true
         end
      end
   end
   return result
end

---@desc
--- Add options to `cmd` corresponding to `WarningOptions`: `--werror` and `--wdisable`
function command.add_warning_options(cmd: argparse.Command)
   cmd:option("--wdisable", "Disable the given kind of warning. Use '--wdisable all' to disable all warnings")
      :argname("<warning>")
      :choices(warning_option_values)
      :count("*")

   cmd:option("--werror", "Promote the given kind of warning to an error. Use '--werror all' to promote all warnings to errors")
      :argname("<warning>")
      :choices(warning_option_values)
      :count("*")
end

---@desc
--- Add options to `cmd` corresponding to `GenOptions`: `--gen-compat` and `--gen-target`
function command.add_gen_options(cmd: argparse.Command)
   cmd:option("--gen-compat", "Generate compatibility code for targeting different Lua VM versions.")
      :choices({ "off", "optional", "required" })
      :default("optional")
      :defmode("a")

   cmd:option("--gen-target", "Minimum targeted Lua version for generated code.")
      :choices({ "5.1", "5.3", "5.4" })
end

---@desc
--- Create a new command
---
--- This is stored in an internal cache and will do nothing unless
--- `command.register_all` is called afterwards
function command.new(cmd: Command)
   if not cmd.name then
      error("Attempt to create a command without a 'name: string' field", 2)
   end
   if commands[cmd.name] then
      error("Attempt to overwrite command '" .. cmd.name .. "'", 2)
   end

   commands[cmd.name] = cmd
   if cmd.script_hooks then
      for h in ivalues(cmd.script_hooks) do
         hooks[cmd.name .. ":" .. h] = true
      end
   end
end

---@desc
--- Install all commands created with `command.new` into the given parser
function command.register_all(p: argparse.Parser)
   for name, cmd in pairs(commands) do
      local c <const> = p:command(name, cmd.description, nil)
      if cmd.argparse then
         cmd.argparse(c)
      end
   end
end

---@desc
--- Get a command that was created with `command.new`
---
--- Works whether or not `command.register_all` was called
function command.get(name: string): Command
   return commands[name]
end

return command
