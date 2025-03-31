local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local coroutine = _tl_compat and _tl_compat.coroutine or coroutine; local math = _tl_compat and _tl_compat.math or math; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack; local type = type



local tl = require("tl")

local command = require("cyan.command")
local decoration = require("cyan.decoration")
local lexical_path = require("lexical-path")
local log = require("cyan.log")
local sandbox = require("cyan.sandbox")
local util = require("cyan.util")

local ivalues, from, sort, keys =
util.tab.ivalues, util.tab.from, util.tab.sort_in_place, util.tab.keys

local script = {}



local function exec_wrapper(box)
   return function(name, ...)
      local ok, err = box:run(nil, name, ...)
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

local load_cache = {}
local function load_script(path)
   if not load_cache[path] then
      log.extra("Loading script: ", decoration.file_name(path))
      local p = lexical_path.from_unix(path)

      local box, err
      local ext = p:extension():lower()
      if ext == "tl" then
         local result, proc_err = tl.check_file(path, nil)
         if not result then
            return nil, proc_err
         end
         if #result.syntax_errors > 0 or
            #result.type_errors > 0 then
            return nil, result
         end
         local generated
         generated, err = tl.generate(result.ast, tl.target_from_lua_version(_VERSION))
         if not generated then
            return nil, err
         end
         box, err = sandbox.from_string(generated, path, _G)
      else
         box, err = sandbox.from_file(path, _G)
      end
      if not box then
         return nil, err
      end
      load_cache[path] = exec_wrapper(box)
   end
   return load_cache[path]
end









local registered = {}










function script.register(path, command_name, hooks)
   assert(command_name)
   assert(hooks)
   if not registered[command_name] then
      registered[command_name] = {}
   end
   local reg = registered[command_name]
   for hook in ivalues((type(hooks) == "string" and { hooks } or hooks)) do
      if not reg[hook] then
         reg[hook] = {}
      end
      table.insert(reg[hook], path)
   end
end

local function list_contains_string(list, str)
   for val in ivalues(assert(list)) do
      if val == str then
         return true
      end
   end
   return false
end



function script.ensure_loaded_for_command(name)
   local sorted_names = sort(from(keys(registered[name] or {})))
   for hook in ivalues(sorted_names) do
      for path in ivalues(registered[name][hook] or {}) do
         local loaded, err = load_script(path)
         if not loaded then
            return false, err
         end
      end
   end
   return true
end










function script.emitter(name, ...)
   assert(name, "Cannot emit nil hook")
   assert(command.running, "Attempt to emit_hook with no running command")
   assert(
   list_contains_string(command.running.script_hooks, name),
   "Command '" .. command.running.name .. "' emitted an unregistered hook: '" .. tostring(name) .. "'")

   local full = command.running.name .. ":" .. name
   local args = { n = select("#", ...), ... }
   return coroutine.wrap(function()
      local paths = (registered[command.running.name] or {})[name]
      for path in ivalues(paths or {}) do
         local loaded = assert(load_cache[path], "Internal error, script was not preloaded before execution")
         local res, err = loaded(full, _tl_table_unpack(args, 1, args.n))
         coroutine.yield(
         lexical_path.from_unix(path),
         res == 0,
         err)

      end
   end)
end




function script.emit_hook(name, ...)
   log.extra("Emitting hook: '", name, "'")
   log.debug("             ^ With ", select("#", ...), " argument(s): ", ...)
   for s, ok, err in script.emitter(name, ...) do
      if ok then
         log.info("Ran script ", decoration.file_name(s))
      else
         log.err("Error in script ", decoration.file_name(s), ":\n   ", err)
         return false, err
      end
   end
   return true
end



function script.disable()
   script.emit_hook = function() return true end
   script.emitter = function() end
   script.ensure_loaded_for_command = function() return true end
   script.register = function() end
end

return script
