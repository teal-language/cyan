local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs; local table = _tl_compat and _tl_compat.table or table


local tl = require("tl")
local argparse = require("argparse")

local config = require("cyan.config")
local invocation_context = require("cyan.invocation-context")


local util = require("cyan.util")

local keys, from, sort, ivalues =
util.tab.keys, util.tab.from, util.tab.sort_in_place, util.tab.ivalues






























local Command = {}






local command = {
   running = nil,
   Command = Command,
   CommandFn = CommandFn,
   Args = Args,
   CheckOptions = CheckOptions,
   GenOptions = GenOptions,
   WarningOptions = WarningOptions,
}

local commands = {}
local hooks = {}



function command.add_check_options(cmd)
   cmd:option("--global-env-def", "Load <module-name> before typechecking. Use this to define types provided by your environment."):
   argname("<module-name>"):
   count("?")

   cmd:option("-I --include-dir", "Prepend this directory to the module search path."):
   argname("<directory>"):
   count("*")
end

local warning_option_values = sort(from(keys(tl.warning_kinds)))
table.insert(warning_option_values, "all")





function command.convert_to_warning_set(...)
   local result = {}
   for i = 1, select("#", ...) do
      for kind in ivalues((select(i, ...))) do
         if kind == "all" then
            for k in pairs(tl.warning_kinds) do
               result[k] = true
            end
            return result
         end
         if tl.warning_kinds[kind] then
            result[kind] = true
         end
      end
   end
   return result
end



function command.add_warning_options(cmd)
   cmd:option("--wdisable", "Disable the given kind of warning. Use '--wdisable all' to disable all warnings"):
   argname("<warning>"):
   choices(warning_option_values):
   count("*")

   cmd:option("--werror", "Promote the given kind of warning to an error. Use '--werror all' to promote all warnings to errors"):
   argname("<warning>"):
   choices(warning_option_values):
   count("*")
end



function command.add_gen_options(cmd)
   cmd:option("--gen-compat", "Generate compatibility code for targeting different Lua VM versions."):
   choices({ "off", "optional", "required" }):
   default("optional"):
   defmode("a")

   cmd:option("--gen-target", "Minimum targeted Lua version for generated code."):
   choices({ "5.1", "5.3", "5.4" })
end






function command.new(cmd)
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



function command.register_all(p)
   for name, cmd in pairs(commands) do
      local c = p:command(name, cmd.description, nil)
      if cmd.argparse then
         cmd.argparse(c)
      end
   end
end





function command.get(name)
   return commands[name]
end

return command
