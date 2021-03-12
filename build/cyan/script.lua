local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table
local command = require("cyan.command")
local sandbox = require("cyan.sandbox")

local Script = {}






local script = {}

function script.is_valid(x)
   if type(x) ~= "table" then
      return nil, "script did not return a table"
   end

   local maybe = {
      run_on = (x).run_on,
      exec = (x).exec,
      reads_from = (x).reads_from,
      writes_to = (x).writes_to,
   }

   if not maybe.exec or type(maybe.exec) ~= "function" then
      return nil, "script 'exec' field is required and must be a function"
   end

   if maybe.reads_from then
      if type(maybe.reads_from) ~= "table" then
         return nil, "script 'reads_from' field must be a {string}"
      end
      for _, v in ipairs(maybe.reads_from) do
         if not (type(v) == "string") then
            return nil, "script 'reads_from' field must be a {string}"
         end
      end
   end
   if maybe.writes_to then
      if type(maybe.reads_from) ~= "table" then
         return nil, "script 'writes_to' field must be a {string}"
      end
      for _, v in ipairs(maybe.writes_to) do
         if not (type(v) == "string") then
            return nil, "script 'writes_to' field must be a {string}"
         end
      end
   end
   if maybe.run_on then
      if type(maybe.run_on) ~= "table" then
         return nil, "script 'run_on' field must be a {string}"
      end
      for _, v in ipairs(maybe.run_on) do
         if not (type(v) == "string") then
            return nil, "script 'run_on' field must be a {string}"
         end
      end
   end

   return maybe
end

local loaded = {}

function script.load(path)

   local ok, res
   do

      local box, err = sandbox.from_file(path, _G)
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

function script.emit_hook(name)
   assert(name, "Cannot emit nil hook")
   assert(command.running, "Attempt to emit_hook with no running command")
   assert(
   has_hook(command.running.script_hooks, name),
   "Command '" .. command.running.name .. "' emitted an unregistered hook: '" .. tostring(name) .. "'")

   name = command.running.name .. ":" .. name

   for _, s in ipairs(loaded) do
      if has_hook(s.run_on, name) then

         local box = sandbox.new(function()
            s.exec(name)
         end)
         local ok, err = box:run()
         if not ok then
            return false, err
         end
      end
   end
   return true
end

return script