local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table
local sandbox = require("cyan.sandbox")
local util = require("cyan.util")

local keys, from =
util.tab.keys, util.tab.from

local Script = {}










local script = {}

local function is_valid(x)
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
      local valid = {
         ["command"] = true,
      }
      local errmsg = "script 'run_on' field must be a {Script.Hook} ( one of " .. table.concat(from(keys(valid))) .. ")"
      if type(maybe.run_on) ~= "table" then
         return nil, errmsg
      end
      for _, v in ipairs(maybe.run_on) do
         if type(v) == "string" and not valid[v] then
         else
            return nil, errmsg
         end
      end
   end

   return maybe
end

function script.load(path)
   local ok, res
   do
      local box, err = sandbox.from_file(path)
      ok, res = box:run()
      if not ok then
         return nil, err
      end
   end

   local s, err = is_valid(res)
   if not s then
      return nil, err
   end

   return s
end

return script