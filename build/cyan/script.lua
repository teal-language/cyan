local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local coroutine = _tl_compat and _tl_compat.coroutine or coroutine; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack
local tl = require("tl")

local command = require("cyan.command")
local sandbox = require("cyan.sandbox")
local fs = require("cyan.fs")
local cs = require("cyan.colorstring")
local log = require("cyan.log")

local Script = {}





local script = {}

function script.is_valid(x)
   if type(x) ~= "table" then
      return nil, "script did not return a table"
   end

   local maybe = {
      run_on = (x).run_on,
      exec = (x).exec,
   }

   if not maybe.exec or type(maybe.exec) ~= "function" then
      return nil, "script 'exec' field is required and must be a function"
   end
   if not maybe.run_on or type(maybe.run_on) ~= "table" then
      return nil, "script 'run_on' field is required and must be a {string}"
   end
   for _, v in ipairs(maybe.run_on) do
      if not (type(v) == "string") then
         return nil, "script 'run_on' field must be a {string}"
      end
   end

   return maybe
end

local loaded = {}

function script.load(path)
   local ok, res
   local p = fs.path.new(path)
   do
      local box, err
      local _, ext = fs.extension_split(p)
      if ext == ".tl" then
         local r = tl.process(path)


         if #r.syntax_errors > 0 then
            return nil, "Script has syntax errors"
         elseif #r.type_errors > 0 then
            return nil, "Script has type errors"
         end
         box, err = sandbox.from_string(tl.pretty_print_ast(r.ast), path, _G)
      else
         box, err = sandbox.from_file(path, _G)
      end
      if not box then
         return nil, err
      end
      ok, err = box:run()
      if not ok then
         return nil, err
      end
      res = box:result()
   end

   local s, err = script.is_valid(res)
   if not s then
      return nil, err
   end
   s.source = p
   table.insert(loaded, s)

   return true
end

local function has_hook(s, name)
   for _, h in ipairs(s) do
      if h == name then
         return true
      end
   end
end





function script.emitter(name, ...)
   assert(name, "Cannot emit nil hook")
   assert(command.running, "Attempt to emit_hook with no running command")
   assert(
   has_hook(command.running.script_hooks, name),
   "Command '" .. command.running.name .. "' emitted an unregistered hook: '" .. tostring(name) .. "'")

   name = command.running.name .. ":" .. name
   local args = { ... }
   return coroutine.wrap(function()
      for _, s in ipairs(loaded) do
         if has_hook(s.run_on, name) then
            local box = sandbox.new(function()
               s.exec(name, _tl_table_unpack(args))
            end)
            local ok, err = box:run()
            coroutine.yield(s.source, ok, err)
         end
      end
   end)
end



function script.emit_hook(name, ...)
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