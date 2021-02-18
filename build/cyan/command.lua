local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs


local tl = require("tl")
local argparse = require("argparse")

local Command = {Args = {}, }
























local command = {
   Command = Command,
}

local commands = {}

function command.new(cmd)
   if not cmd.name then
      error("Attempt to create a command without a 'name: string' field", 2)
   end
   if commands[cmd.name] then
      error("Attempt to overwrite command '" .. cmd.name .. "'", 2)
   end

   commands[cmd.name] = cmd
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

return command
