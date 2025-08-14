local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local coroutine = _tl_compat and _tl_compat.coroutine or coroutine; local math = _tl_compat and _tl_compat.math or math; local os = _tl_compat and _tl_compat.os or os; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack; local type = type



local tl = require("tl")

local command = require("cyan.command")
local decoration = require("cyan.decoration")
local fs = require("cyan.fs")
local invocation_context = require("cyan.invocation-context")
local lexical_path = require("lexical-path")
local log = require("cyan.log")
local meta = require("cyan.meta")
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

local cache_disabled = (function()
   local env = os.getenv("CYAN_DISABLE_SCRIPT_CACHE")
   if env then return env ~= "0" end
   return false
end)()

local cache_path = (function()
   local dir = os.getenv("CYAN_SCRIPT_CACHE_DIR")
   if dir then
      return (lexical_path.from_os(dir))
   end
   dir = os.getenv("XDG_CACHE_HOME")
   if dir then
      return lexical_path.from_os(dir) .. "cyan-script-cache"
   end

   if package.config:sub(1, 1) == "\\" then
      dir = os.getenv("AppData")
      return (lexical_path.from_os(dir) .. "Temp") .. "cyan-script-cache"
   end
   dir = os.getenv("HOME")
   if not dir then
      cache_disabled = true
      return
   end
   return (lexical_path.from_os(dir) .. ".cache") .. "cyan-script-cache"
end)()

function script.disable_cache()
   cache_disabled = true
end

local function ensure_cache_dir_exists()
   if cache_disabled then return false, "Already tried and failed to get cache directory" end
   if fs.is_directory(cache_path) then
      return true
   end
   local ok, err = fs.make_directory(cache_path)
   if not ok then
      cache_disabled = true
   end
   return ok, err
end

local function sub_bad_chars(src)

   return (src:
   gsub("_", "_u"):
   gsub("[%.|<>:/\\ \t\"\'%%$]", {
      ["."] = "_p",
      ["|"] = "_P",
      ["<"] = "_l",
      [">"] = "_g",
      [":"] = "_c",
      ["%"] = "_C",
      ["/"] = "_s",
      ["\\"] = "_S",
      [" "] = "_w",
      ["\t"] = "_t",
      ['"'] = "_q",
      ["'"] = "_Q",
      ["$"] = "_m",
   }))

end

local version_prefix = sub_bad_chars(_VERSION .. "cyan" .. meta.version .. "tl" .. tl.version())

local function script_path_to_cache_path(path)
   assert(cache_path)
   assert(path.is_absolute)
   local path_str = path:to_string("/"):sub(2, -1)
   return cache_path .. (version_prefix .. sub_bad_chars(path_str) .. ".lua")
end

local function save_to_fs_cache(src_path, generated_lua_code)
   if cache_disabled then
      return
   end
   do
      local ok, err = ensure_cache_dir_exists()
      if not ok then

         log.warn("Failed to ensure cache directory ", decoration.file_name(cache_path), " exists: ", err)
         return
      end
   end
   local target_path = script_path_to_cache_path(src_path)
   do
      local ok, err = fs.write(target_path, generated_lua_code)
      if ok then
         log.debug("Cached script ", decoration.file_name(src_path), " to ", decoration.file_name(target_path))
      else
         log.warn("Failed to cache script ", decoration.file_name(src_path), ": ", err)
      end
   end
end

local function load_from_fs_cache(src_path)
   if cache_disabled then return end
   local target_path = script_path_to_cache_path(src_path)

   local src_mod = fs.mod_time(src_path) or 0
   local target_mod = fs.mod_time(target_path) or 0

   if target_mod <= src_mod then
      return
   end

   local contents = fs.read(target_path:to_string())
   if not contents then
      return
   end

   log.debug("Script cache hit of ", decoration.file_name(src_path), " via ", decoration.file_name(target_path))
   return (sandbox.from_string(contents, src_path:to_string(), _G))
end

local load_cache = {}
local function load_script(path)
   local path_str = path:to_string()
   if not load_cache[path_str] then
      log.extra("Loading script: ", decoration.file_name(path))

      local box, err
      local ext = path:extension():lower()
      if ext == "tl" then
         local from_fs_cache = load_from_fs_cache(path)
         if from_fs_cache then
            box = from_fs_cache
         else
            local result, proc_err = tl.check_file(path_str, nil)
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
            save_to_fs_cache(path, generated)
            box, err = sandbox.from_string(generated, path_str, _G)
         end
      else
         box, err = sandbox.from_file(path_str, _G)
      end
      if not box then
         return nil, err
      end
      load_cache[path_str] = exec_wrapper(box)
   end
   return load_cache[path_str]
end









local registered = {}












function script.register(path, command_name, hooks)
   assert(path.is_absolute)
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
         local loaded = assert(load_cache[path:to_string()], "Internal error, script was not preloaded before execution")
         local res, err = loaded(full, _tl_table_unpack(args, 1, args.n))
         coroutine.yield(
         path,
         res == 0,
         err)

      end
   end)
end




function script.emit_hook(context, name, ...)
   log.extra("Emitting hook: '", name, "'")
   log.debug("             ^ With ", select("#", ...), " argument(s): ", ...)
   for s, ok, err in script.emitter(name, ...) do
      local relative_name = context.initial_directory and s:relative_to(context.initial_directory) or s
      if ok then
         log.info("Ran script ", decoration.file_name(relative_name))
      else
         log.err("Error in script ", decoration.file_name(relative_name), ":\n   ", err)
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
