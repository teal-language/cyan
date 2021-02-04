
-- Common interface for commands to implement

local config <const> = require("teal-cli.config")
local argparse <const> = require("argparse")

local record Command
   name: string
   exec: function(): number -- return value is the exit code
   description: string

   argparse: function(argparse.Command)
end

local command <const> = {
   Command = Command,
}

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

