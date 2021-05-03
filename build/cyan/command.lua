local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs



local tl = require("tl")
local argparse = require("argparse")

local config = require("cyan.config")
local fs = require("cyan.fs")
local util = require("cyan.util")

local merge_list = util.tab.merge_list

local Args = {}






















local CommandFn = {}



local Command = {}






local command = {
   running = nil,
   Command = Command,
   CommandFn = CommandFn,
   Args = Args,
}

local commands = {}
local hooks = {}






function command.new(cmd)
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



function command.register_all(p)
   for name, cmd in pairs(commands) do
      local c = p:command(name, cmd.description)
      if cmd.argparse then
         cmd.argparse(c)
      end
   end
end





function command.get(name)
   return commands[name]
end



function command.merge_args_into_config(cfg, args)
   args = args or {}

   cfg.global_env_def = args.global_env_def or cfg.global_env_def

   cfg.include_dir = merge_list(cfg.include_dir, args.include_dir)
   cfg.disable_warnings = merge_list(cfg.disable_warnings, args.wdisable)
   cfg.warning_error = merge_list(cfg.warning_error, args.werror)

   cfg.gen_compat = args.gen_compat or cfg.gen_compat
   cfg.gen_target = args.gen_target or cfg.gen_target
end

return command