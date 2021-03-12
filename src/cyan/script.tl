
local command <const> = require("cyan.command")
local sandbox <const> = require("cyan.sandbox")

local record Script
   run_on: {string}
   reads_from: {string}
   writes_to: {string}
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
      reads_from = (x as table).reads_from,
      writes_to = (x as table).writes_to,
   }

   if not maybe.exec or type(maybe.exec) ~= "function" then
      return nil, "script 'exec' field is required and must be a function"
   end

   if maybe.reads_from then
      if type(maybe.reads_from) ~= "table" then
         return nil, "script 'reads_from' field must be a {string}"
      end
      for _, v in ipairs(maybe.reads_from as {any}) do
         if not v is string then
            return nil, "script 'reads_from' field must be a {string}"
         end
      end
   end
   if maybe.writes_to then
      if type(maybe.reads_from) ~= "table" then
         return nil, "script 'writes_to' field must be a {string}"
      end
      for _, v in ipairs(maybe.writes_to as {any}) do
         if not v is string then
            return nil, "script 'writes_to' field must be a {string}"
         end
      end
   end
   if maybe.run_on then
      if type(maybe.run_on) ~= "table" then
         return nil, "script 'run_on' field must be a {string}"
      end
      for _, v in ipairs(maybe.run_on as {any}) do
         if not v is string then
            return nil, "script 'run_on' field must be a {string}"
         end
      end
   end

   return maybe as Script
end

local loaded <const> = {}

function script.load(path: string): boolean, string
   -- require"cyan.log".debug("loading script from ", path)
   local ok, res: boolean, any
   do
      -- TODO: setup real env for these
      local box <const>, err = sandbox.from_file(path, _G)
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

function script.emit_hook(name: string): boolean, string
   assert(name, "Cannot emit nil hook")
   assert(command.running, "Attempt to emit_hook with no running command")
   assert(
      has_hook(command.running.script_hooks, name),
      "Command '" .. command.running.name .. "' emitted an unregistered hook: '" .. tostring(name) .. "'"
   )
   name = command.running.name .. ":" .. name
   -- require"cyan.log".debug("Emitting hook: ", name)
   for _, s in ipairs(loaded) do
      if has_hook(s.run_on, name) then
         -- TODO: enforce io stuff
         local box <const> = sandbox.new(function()
            s.exec(name)
         end)
         local ok <const>, err <const> = box:run()
         if not ok then
            return false, err
         end
      end
   end
   return true
end

return script
