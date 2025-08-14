
---@brief
--- The script loading api

local tl <const> = require("tl")

local command <const> = require("cyan.command")
local decoration <const> = require("cyan.decoration")
local fs <const> = require("cyan.fs")
local invocation_context <const> = require("cyan.invocation-context")
local lexical_path <const> = require("lexical-path")
local log <const> = require("cyan.log")
local meta <const> = require("cyan.meta")
local sandbox <const> = require("cyan.sandbox")
local util <const> = require("cyan.util")

local ivalues <const>, from <const>, sort <const>, keys <const>
   = util.tab.ivalues, util.tab.from, util.tab.sort_in_place, util.tab.keys

local script <const> = {}

local type Loaded = function(string, ...: any): integer, string

local function exec_wrapper(box: sandbox.Sandbox): Loaded
   return function(name: string, ...: any): integer, string
      local ok <const>, err <const> = box:run(nil, name, ...)
      if not ok then
         return nil, err
      end
      local res <const> = box:result()
      if res ~= nil
         and type(res) ~= "number"
         or res is number and res ~= math.floor(res)
      then
         return nil, "Script did not return an integer"
      end
      return 0
   end
end

local cache_disabled = (function(): boolean
   local env <const> = os.getenv("CYAN_DISABLE_SCRIPT_CACHE")
   if env then return env ~= "0" end
   return false
end)()

local cache_path <const> = (function(): lexical_path.Path
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

local function ensure_cache_dir_exists(): boolean, string
   if cache_disabled then return false, "Already tried and failed to get cache directory" end
   if fs.is_directory(cache_path) then
      return true
   end
   local ok <const>, err <const> = fs.make_directory(cache_path)
   if not ok then
      cache_disabled = true
   end
   return ok, err
end

local function sub_bad_chars(src: string): string
   -- various bad chars for various bad reasons
   return (src
      :gsub("_", "_u")
      :gsub("[%.|<>:/\\ \t\"\'%%$]", {
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
      })
   )
end

local version_prefix <const> = sub_bad_chars(_VERSION .. "cyan" .. meta.version .. "tl" .. tl.version())

local function script_path_to_cache_path(path: lexical_path.Path): lexical_path.Path
   assert(cache_path)
   assert(path.is_absolute)
   local path_str <const> = path:to_string("/"):sub(2, -1)
   return cache_path .. (version_prefix .. sub_bad_chars(path_str) .. ".lua")
end

local function save_to_fs_cache(src_path: lexical_path.Path, generated_lua_code: string)
   if cache_disabled then
      return
   end
   do
      local ok <const>, err <const> = ensure_cache_dir_exists()
      if not ok then
         -- "silently" fail, since this is non-essential
         log.warn("Failed to ensure cache directory ", decoration.file_name(cache_path), " exists: ", err)
         return
      end
   end
   local target_path <const> = script_path_to_cache_path(src_path)
   do
      local ok <const>, err <const> = fs.write(target_path, generated_lua_code)
      if ok then
         log.debug("Cached script ", decoration.file_name(src_path), " to ", decoration.file_name(target_path))
      else
         log.warn("Failed to cache script ", decoration.file_name(src_path), ": ", err)
      end
   end
end

local function load_from_fs_cache(src_path: lexical_path.Path): sandbox.Sandbox
   if cache_disabled then return end
   local target_path <const> = script_path_to_cache_path(src_path)

   local src_mod <const> = fs.mod_time(src_path) or 0
   local target_mod <const> = fs.mod_time(target_path) or 0

   if target_mod <= src_mod then
      return
   end

   local contents <const> = fs.read(target_path:to_string())
   if not contents then
      return
   end

   log.debug("Script cache hit of ", decoration.file_name(src_path), " via ", decoration.file_name(target_path))
   return (sandbox.from_string(contents, src_path:to_string(), _G))
end

local load_cache <const>: {string:Loaded} = {}
local function load_script(path: lexical_path.Path): Loaded, string | tl.Result
   local path_str <const> = path:to_string()
   if not load_cache[path_str] then
      log.extra("Loading script: ", decoration.file_name(path))

      local box, err: sandbox.Sandbox, string
      local ext <const> = path:extension():lower()
      if ext == "tl" then
         local from_fs_cache <const> = load_from_fs_cache(path)
         if from_fs_cache then
            box = from_fs_cache
         else
            local result <const>, proc_err <const> = tl.check_file(path_str, nil)
            if not result then
               return nil, proc_err
            end
            if #result.syntax_errors > 0
               or #result.type_errors > 0 then
               return nil, result
            end
            local generated: string
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

-- command to hook to list of filepaths
-- e.g.
-- {
--    build = {
--       pre = { "foo.tl", "bar.lua" },
--       post = { "foo.tl" },
--    },
-- }
local registered <const>: {string:{string:{lexical_path.Path}}} = {}

---@desc
--- Registers a file path as a lua/teal script to execute for the given hook(s)
--- when `script.emit_hook` is called
---
--- This is called by the cli driver to register the scripts found in the config
--- file with the relevant hooks
---
--- `path` MUST be an absolute path
---
--- Note: this function does not attempt to actually load the file. Scripts are
--- loaded all at once via `ensure_loaded_for_command`
function script.register(path: lexical_path.Path, command_name: string, hooks: string | {string})
   assert(path.is_absolute)
   assert(command_name)
   assert(hooks)

   if not registered[command_name] then
      registered[command_name] = {}
   end
   local reg <const> = registered[command_name]
   for hook in ivalues((hooks is string and {hooks} or hooks) as {string}) do
      if not reg[hook] then
         reg[hook] = {}
      end
      table.insert(reg[hook], path)
   end
end

local function list_contains_string(list: {string}, str: string): boolean
   for val in ivalues(assert(list)) do
      if val == str then
         return true
      end
   end
   return false
end

---@desc
--- Attempts to load each script that the given command may need
function script.ensure_loaded_for_command(name: string): boolean, string | tl.Result
   local sorted_names <const> = sort(from(keys(registered[name] or {})))
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

---@desc
--- Emit a hook to load and run all registered scripts that run on the given
--- hook.
---
--- This function will assert that `ensure_loaded_for_command` was called before.
---
--- Returns an iterator that will run the next script when called and returns
--- the path to the script, whether the script was loaded and ran with no
--- errors, and an error message if it didn't
function script.emitter(name: string, ...: any): function(): lexical_path.Path, boolean, string
   assert(name, "Cannot emit nil hook")
   assert(command.running, "Attempt to emit_hook with no running command")
   assert(
      list_contains_string(command.running.script_hooks, name),
      "Command '" .. command.running.name .. "' emitted an unregistered hook: '" .. tostring(name) .. "'"
   )
   local full <const> = command.running.name .. ":" .. name
   local args <const> = { n = select("#", ...), ... }
   return coroutine.wrap(function()
      local paths <const> = (registered[command.running.name] or {})[name]
      for path in ivalues(paths or {}) do
         local loaded <const> = assert(load_cache[path:to_string()], "Internal error, script was not preloaded before execution")
         local res <const>, err <const> = loaded(full, table.unpack(args, 1, args.n))
         coroutine.yield(
            path,
            res == 0,
            err
         )
      end
   end) as function(): lexical_path.Path, boolean, string
end

---@desc
--- Iterates through each loaded script and runs any with the given hook,
--- logging each script that it ran, and stopping early if any error
function script.emit_hook(context: invocation_context.InvocationContext, name: string, ...: any): boolean, string
   log.extra("Emitting hook: '", name, "'")
   log.debug("             ^ With ", select("#", ...), " argument(s): ", ...)
   for s, ok, err in script.emitter(name, ...) do
      local relative_name <const> = context.initial_directory and s:relative_to(context.initial_directory) or s
      if ok then
         log.info("Ran script ", decoration.file_name(relative_name))
      else
         log.err("Error in script ", decoration.file_name(relative_name), ":\n   ", err)
         return false, err
      end
   end
   return true
end

---@desc
--- Make everything in this library a no-op, there is currently no way to re-enable this
function script.disable()
   script.emit_hook = function(): boolean, string return true end
   script.emitter = function(): function(): lexical_path.Path, boolean, string end
   script.ensure_loaded_for_command = function(): boolean, string return true end
   script.register = function() end
end

return script
