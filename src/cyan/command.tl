
---@brief
--- The common interface for commands to implement

local tl <const> = require("tl")
local argparse <const> = require("argparse")

local record Args
   command: string
   include_dir: {string}
   wdisable: {string}
   werror: {string}
   gen_compat: tl.CompatMode
   gen_target: tl.TargetMode
   quiet: boolean
   global_env_def: string

   -- TODO: These should be in some sort of subtype/interface made by the commands
   files: {string}
   output: string
   script: {string}

   update_all: boolean

   directory: string
   source_dir: string
   build_dir: string
   force: boolean
end

---@desc
--- The interface
local record Command
   name: string
   description: string
   argparse: function(argparse.Command)
   script_hooks: {string}
   exec: function(Args): integer -- return value is the exit code
end
local command <const> = {
   running: Command = nil,
   Command = Command,
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

return command

