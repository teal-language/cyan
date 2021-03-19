
local tl <const> = require("tl")

local command <const> = require("cyan.command")
local sandbox <const> = require("cyan.sandbox")
local fs <const> = require("cyan.fs")
local cs <const> = require("cyan.colorstring")
local log <const> = require("cyan.log")

local record Script
   source: fs.Path
   run_on: {string}
   exec: function(string, ...: any)
end

local script <const> = {}

function script.is_valid(x: any): Script, string
   if type(x) ~= "table" then
      return nil, "script did not return a table"
   end

   local maybe <const> = {
      run_on = (x as table).run_on,
      exec = (x as table).exec,
   }

   if not maybe.exec or type(maybe.exec) ~= "function" then
      return nil, "script 'exec' field is required and must be a function"
   end
   if not maybe.run_on or type(maybe.run_on) ~= "table" then
      return nil, "script 'run_on' field is required and must be a {string}"
   end
   for _, v in ipairs(maybe.run_on as {any}) do
      if not v is string then
         return nil, "script 'run_on' field must be a {string}"
      end
   end

   return maybe as Script
end

local loaded <const> = {}

function script.load(path: string): boolean, string
   local ok, res: boolean, any
   local p <const> = fs.path.new(path)
   do
      local box, err: sandbox.Sandbox, string
      local _, ext <const> = fs.extension_split(p)
      if ext == ".tl" then
         local r = tl.process(path)
         -- TODO: right now it is the responsibility of the user to run `{tl,cyan} check` on their scripts
         -- but we could report these a little better using prettify_error or something from tlcommon
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

   local s <const>, err <const> = script.is_valid(res)
   if not s then
      return nil, err
   end
   s.source = p
   table.insert(loaded, s)

   return true
end

local function has_hook(s: {string}, name: string): boolean
   for _, h in ipairs(s) do
      if h == name then
         return true
      end
   end
end

---@desc
--- Emit a hook to run all loaded scripts that run on the given hook. Returns
--- an iterator that will run the next script when called and returns the path to
--- the script, whether the script succeeded, and an error message if it didn't
function script.emitter(name: string, ...: any): function(): fs.Path, boolean, string
   assert(name, "Cannot emit nil hook")
   assert(command.running, "Attempt to emit_hook with no running command")
   assert(
      has_hook(command.running.script_hooks, name),
      "Command '" .. command.running.name .. "' emitted an unregistered hook: '" .. tostring(name) .. "'"
   )
   name = command.running.name .. ":" .. name
   local args <const> = {...}
   return coroutine.wrap(function()
      for _, s in ipairs(loaded) do
         if has_hook(s.run_on, name) then
            local box <const> = sandbox.new(function()
               s.exec(name, table.unpack(args))
            end)
            local ok <const>, err <const> = box:run()
            coroutine.yield(s.source, ok, err)
         end
      end
   end) as function(): fs.Path, boolean, string
end

---@desc
--- Iterates through each loaded script and runs any with the given hook, logging each script that it ran, and stopping early if any error
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

return script
