
---@brief
--- The script loading api

local tl <const> = require("tl")

local command <const> = require("cyan.command")
local cs <const> = require("cyan.colorstring")
local fs <const> = require("cyan.fs")
local log <const> = require("cyan.log")
local sandbox <const> = require("cyan.sandbox")
local util <const> = require("cyan.util")

local ivalues <const> = util.tab.ivalues

local record Script
   run_on: {string:boolean}
   exec: function(string, ...: any): integer, string
   source: fs.Path
end

local script <const> = {}
local loaded <const>: {Script} = {}

local function exec_wrapper(box: sandbox.Sandbox): function(string, ...: any): integer, string
   return function(): integer, string
      local ok <const>, err <const> = box:run()
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

---@desc
--- Loads a file as a lua/teal script and caches it with the given flags to be
--- run when `script.emit_hook` is called
---
--- This is called by the cli driver to load the scripts found in the config
--- file with the relevant hooks
function script.load(path: string, flags: {string}): boolean, string | tl.Result
   log.extra("Loading script: ", cs.highlight(cs.colors.file, path))
   local p <const> = fs.path.new(path)

   local box, err: sandbox.Sandbox, string
   local _, ext <const> = fs.extension_split(p)
   if ext == ".tl" then
      local result <const> = tl.process(path)
      if #result.syntax_errors > 0
         or #result.type_errors > 0 then
         return nil, result
      end
      box, err = sandbox.from_string(tl.pretty_print_ast(result.ast), path, _G)
   else
      box, err = sandbox.from_file(path, _G)
   end
   if not box then
      return nil, err
   end

   local set <const> = {}
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

local function list_contains_string(list: {string}, str: string): boolean
   for val in ivalues(list) do
      if val == str then
         return true
      end
   end
   return false
end

---@desc
--- Emit a hook to run all loaded scripts that run on the given hook. Returns
--- an iterator that will run the next script when called and returns the path to
--- the script, whether the script succeeded, and an error message if it didn't
function script.emitter(name: string, ...: any): function(): fs.Path, boolean, string
   assert(name, "Cannot emit nil hook")
   assert(command.running, "Attempt to emit_hook with no running command")
   assert(
      list_contains_string(command.running.script_hooks, name),
      "Command '" .. command.running.name .. "' emitted an unregistered hook: '" .. tostring(name) .. "'"
   )
   name = command.running.name .. ":" .. name
   local args <const> = { n = select("#", ...), ... }
   return coroutine.wrap(function()
      for loaded_script in ivalues(loaded) do
         if loaded_script.run_on[name] then
            local res <const>, err <const> = loaded_script.exec(name, table.unpack(args, 1, args.n))
            coroutine.yield(
               loaded_script.source:copy(),
               res == 0,
               err
            )
         end
      end
   end) as function(): fs.Path, boolean, string
end

---@desc
--- Iterates through each loaded script and runs any with the given hook,
--- logging each script that it ran, and stopping early if any error
function script.emit_hook(name: string, ...: any): boolean, string
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

---@desc
--- Make everything in this library a no-op, there is currently no way to re-enable this
function script.disable()
   script.emit_hook = function(): boolean, string return true end
   script.emitter = function(): function(): fs.Path, boolean, string end
   script.load = function(): boolean, string return true end
end

return script
