
local sandbox <const> = require("cyan.sandbox")
local util <const> = require("cyan.util")

local keys <const>, from <const>
   = util.tab.keys, util.tab.from

local record Script
   enum Hook
      "command"
   end

   run_on: {Hook}
   reads_from: {string}
   writes_to: {string}
   exec: function
end

local script <const> = {}

local function is_valid(x: any): Script, string
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
      local valid <const>: {string:boolean} = {
         ["command"] = true,
      }
      local errmsg <const> = "script 'run_on' field must be a {Script.Hook} ( one of " .. table.concat(from(keys(valid))) .. ")"
      if type(maybe.run_on) ~= "table" then
         return nil, errmsg
      end
      for _, v in ipairs(maybe.run_on as {any}) do
         if v is string and not valid[v] then
         else
            return nil, errmsg
         end
      end
   end

   return maybe as Script
end

function script.load(path: string): Script, string
   local ok, res: boolean, any
   do
      local box <const>, err <const> = sandbox.from_file(path)
      ok, res = box:run()
      if not ok then
         return nil, err
      end
   end

   local s <const>, err <const> = is_valid(res)
   if not s then
      return nil, err
   end

   return s
end

return script
