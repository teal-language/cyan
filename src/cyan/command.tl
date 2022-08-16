
---@brief
--- The common interface for commands to implement

local tl <const> = require("tl")
local argparse <const> = require("argparse")

local config <const> = require("cyan.config")
local fs <const> = require("cyan.fs")
local log <const> = require("cyan.log")
local util <const> = require("cyan.util")

local merge_list <const>, sort <const>, from <const>, keys <const>, contains <const>
   = util.tab.merge_list, util.tab.sort_in_place, util.tab.from, util.tab.keys, util.tab.contains

local record Args
   command: string
   include_dir: {string}
   wdisable: {string}
   werror: {string}
   gen_compat: tl.CompatMode
   gen_target: tl.TargetMode
   quiet: boolean
   global_env_def: string
   verbosity: log.Verbosity

   -- TODO: it might not be too hard to auto generate these with a script
   -- TODO: These should be in some sort of subtype/interface made by the commands
   files: {string}
   output: string
   script: {string}

   update_all: boolean
   check_only: boolean
   prune: boolean

   directory: string
   source_dir: string
   build_dir: string
   force: boolean
end

local type CommandFn = function(Args, config.Config, fs.Path): integer

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
}

local commands <const>: {string:Command} = {}
local hooks <const>: {string:boolean} = {}

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
      for _, h in ipairs(cmd.script_hooks) do
         hooks[cmd.name .. ":" .. h] = true
      end
   end
end

---@desc
--- Install all commands created with `command.new` into the given parser
function command.register_all(p: argparse.Parser)
   for name, cmd in pairs(commands) do
      local c <const> = p:command(name, cmd.description)
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

local all_warnings <const> = sort(from(keys(tl.warning_kinds)))

---@desc
--- Merge the relevant entries of the provided command arguments into the provided config table
function command.merge_args_into_config(cfg: config.Config, args: Args)
   args = args or {}

   cfg.global_env_def = args.global_env_def or cfg.global_env_def

   cfg.include_dir = merge_list(cfg.include_dir, args.include_dir)
   if contains(args.wdisable, "all") then
      cfg.disable_warnings = all_warnings
   else
      cfg.disable_warnings = merge_list(cfg.disable_warnings, args.wdisable as {tl.WarningKind})
   end
   if contains(args.werror, "all") then
      cfg.warning_error = all_warnings
   else
      cfg.warning_error = merge_list(cfg.warning_error, args.werror as {tl.WarningKind})
   end

   cfg.source_dir = args.source_dir or cfg.source_dir
   cfg.build_dir = args.build_dir or cfg.build_dir

   cfg.gen_compat = args.gen_compat or cfg.gen_compat
   cfg.gen_target = args.gen_target or cfg.gen_target
end

return command

