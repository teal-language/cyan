
---@brief
--- The script loading api

local tl <const> = require("tl")

local command <const> = require("cyan.command")
local decoration <const> = require("cyan.decoration")
local fs <const> = require("cyan.fs")
local log <const> = require("cyan.log")
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

local load_cache <const>: {string:Loaded} = {}
local function load_script(path: string): Loaded, string | tl.Result
   if not load_cache[path] then
      log.extra("Loading script: ", decoration.file_name(path))
      local p <const> = fs.path.new(path, false)

      local box, err: sandbox.Sandbox, string
      local _, ext <const> = fs.extension_split(p)
      if ext == ".tl" then
         local result <const>, proc_err <const> = tl.check_file(path, nil)
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

-- command to hook to list of filepaths
-- e.g.
-- {
--    build = {
--       pre = { "foo.tl", "bar.lua" },
--       post = { "foo.tl" },
--    },
-- }
local registered <const>: {string:{string:{string}}} = {}

---@desc
--- Registers a file path as a lua/teal script to execute for the given hook(s)
--- when `script.emit_hook` is called
---
--- This is called by the cli driver to register the scripts found in the config
--- file with the relevant hooks
---
--- Note: this function does not attempt to actually load the file. Scripts are
--- loaded all at once via `ensure_loaded_for_command`
function script.register(path: string, command_name: string, hooks: string | {string})
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
function script.emitter(name: string, ...: any): function(): fs.Path, boolean, string
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
         local loaded <const> = assert(load_cache[path], "Internal error, script was not preloaded before execution")
         local res <const>, err <const> = loaded(full, table.unpack(args, 1, args.n))
         coroutine.yield(
            fs.path.new(path, false),
            res == 0,
            err
         )
      end
   end) as function(): fs.Path, boolean, string
end

---@desc
--- Iterates through each loaded script and runs any with the given hook,
--- logging each script that it ran, and stopping early if any error
function script.emit_hook(name: string, ...: any): boolean, string
   log.extra("Emitting hook: '", name, "'")
   log.debug("             ^ With ", select("#", ...), " argument(s): ", ...)
   for s, ok, err in script.emitter(name, ...) do
      if ok then
         log.info("Ran script ", decoration.file_name(s:to_real_path()))
      else
         log.err("Error in script ", decoration.file_name(s:to_real_path()), ":\n   ", err)
         return false, err
      end
   end
   return true
end

---@desc
--- Make everything in this library a no-op, there is currently no way to re-enable this
function script.disable()
   script.emit_hook = function(): boolean, string return true end
   script.emitter = function(): function(): fs.Path, boolean, string end
   script.ensure_loaded_for_command = function(): boolean, string return true end
   script.register = function() end
end

return script
