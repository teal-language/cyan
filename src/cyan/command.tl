
-- The common interface for commands to implement

local tl <const> = require("tl")
local argparse <const> = require("argparse")

local record command
   record Command
      record Args
         command: string
         preload: {string}
         include_dir: {string}
         wdisable: {string}
         werror: {string}
         gen_compat: tl.CompatMode
         gen_target: tl.TargetMode
         quiet: boolean
         preload_modules: {string}

         -- These should be in some sort of subtype/interface made by the commands
         files: {string}
         output: string
         script: {string}

         update_all: boolean

         directory: string
         source_dir: string
         build_dir: string
         force: boolean
      end

      name: string
      description: string
      argparse: function(argparse.Command)
      exec: function(Args): number -- return value is the exit code
   end
end
local type Command = command.Command

local commands <const>: {string:Command} = {}

function command.new(cmd: Command)
   if not cmd.name then
      error("Attempt to create a command without a 'name: string' field", 2)
   end
   if commands[cmd.name] then
      error("Attempt to overwrite command '" .. cmd.name .. "'", 2)
   end

   commands[cmd.name] = cmd
end

function command.register_all(p: argparse.Parser)
   for name, cmd in pairs(commands) do
      local c <const> = p:command(name, cmd.description)
      if cmd.argparse then
         cmd.argparse(c)
      end
   end
end

function command.get(name: string): Command
   return commands[name]
end

return command

