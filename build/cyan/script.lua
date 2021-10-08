local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local coroutine = _tl_compat and _tl_compat.coroutine or coroutine; local math = _tl_compat and _tl_compat.math or math; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack



local tl = require("tl")

local command = require("cyan.command")
local cs = require("cyan.colorstring")
local fs = require("cyan.fs")
local log = require("cyan.log")
local sandbox = require("cyan.sandbox")
local util = require("cyan.util")

local ivalues = util.tab.ivalues

local Script = {}





local script = {}
local loaded = {}

local function exec_wrapper(box)
   return function()
      local ok, err = box:run()
      if not ok then
         return nil, err
      end
      local res = box:result()
      if res ~= nil and
         type(res) ~= "number" or
         type(res) == "number" and res ~= math.floor(res) then

         return nil, "Script did not return an integer"
      end
      return 0
   end
end







function script.load(path, flags)
   log.extra("Loading script: ", cs.highlight(cs.colors.file, path))
   local p = fs.path.new(path)

   local box, err
   local _, ext = fs.extension_split(p)
   if ext == ".tl" then
      local result = tl.process(path)
      if #result.syntax_errors > 0 or
         #result.type_errors > 0 then
         return nil, result
      end
      box, err = sandbox.from_string(tl.pretty_print_ast(result.ast), path, _G)
   else
      box, err = sandbox.from_file(path, _G)
   end
   if not box then
      return nil, err
   end

   local set = {}
   for v in ivalues(flags) do
      set[v] = true
   end

   table.insert(loaded, {
      exec = exec_wrapper(box),
      run_on = set,
      source = p,
   })
   return true
end

local function list_contains_string(list, str)
   for val in ivalues(list) do
      if val == str then
         return true
      end
   end
   return false
end





function script.emitter(name, ...)
   assert(name, "Cannot emit nil hook")
   assert(command.running, "Attempt to emit_hook with no running command")
   assert(
   list_contains_string(command.running.script_hooks, name),
   "Command '" .. command.running.name .. "' emitted an unregistered hook: '" .. tostring(name) .. "'")

   name = command.running.name .. ":" .. name
   local args = { n = select("#", ...), ... }
   return coroutine.wrap(function()
      for loaded_script in ivalues(loaded) do
         if loaded_script.run_on[name] then
            local res, err = loaded_script.exec(name, _tl_table_unpack(args, 1, args.n))
            coroutine.yield(
            loaded_script.source:copy(),
            res == 0,
            err)

         end
      end
   end)
end




function script.emit_hook(name, ...)
   log.extra("Emitting hook: '", name, "'")
   log.debug("             ^ With ", select("#", ...), " argument(s): ", ...)
   for s, ok, err in script.emitter(name, ...) do
      if ok then
         log.info("Ran script ", cs.highlight(cs.colors.file, s:to_real_path()))
      else
         log.err("Error in script ", cs.highlight(cs.colors.file, s:to_real_path()), ":\n   ", err)
         return false, err
      end
   end
   return true
end



function script.disable()
   script.emit_hook = function() return true end
   script.emitter = function() end
   script.load = function() return true end
end

return script