local log <const> = require("cyan.log")
local ivalues <const> = require("cyan.util").tab.ivalues

local record event
   interface Prototype<Parameter>
      tag: string
      --log: function(log.Logger, Parameter)
   end

   type Output = function(string...)
   --type Encoder = function<Parameter>(output: Output, to_emit: Prototype<Parameter>, Parameter)
end

function event.output_buffer(into?: {string}): function(string...), {string}
   local buf <const> = into or {}
   return function(...: string)
      for i = 1, select("#", ...) do
         table.insert(buf, (select(i, ...)))
      end
   end, buf
end

local function is_int(x: any): boolean
   return x is number and math.floor(x) == x
end

local function value_to_json(output: event.Output, param: any, seen?: {any:boolean})
   seen = seen or {}
   if seen[param] then
      error("Attempt to encode recursive data")
   end
   local param_mt <const> = getmetatable(param)
   if param_mt and param_mt.__tostring then
      seen[param] = true
      output(("%q"):format(param_mt.__tostring(param)))
      return
   end
   if type(param) == "nil" then
      output("null")
      return
   end
   if type(param) == "number" or type(param) == "boolean" then
      output(tostring(param))
      return
   end
   if type(param) == "string" then
      output(("%q"):format(param as string))
      return
   end
   if type(param) ~= "table" then
      error("Invalid type " .. type(param) .. " for event parameter")
      return
   end

   local t = param as table

   local only_integer_keys = true
   local smallest_integer_key = 0
   local largest_integer_key = 0
   for k in pairs(t) do
      if not is_int(k) then
         only_integer_keys = false
         break
      end
      largest_integer_key = math.max(largest_integer_key, k as integer)
      smallest_integer_key = math.min(smallest_integer_key, k as integer)
   end

   if only_integer_keys and largest_integer_key >= 1 and smallest_integer_key >= 1 then
      output("[")
      for i = 1, largest_integer_key do
         if i > 1 then output(",") end
         value_to_json(output, t[i], seen)
      end
      output("]")
      return
   end

   local key_value_pairs <const>: {{string, string}} = {}
   local seen_keys <const>: {string:any} = {}
   for k, v in pairs(t) do
      local o <const>, buf <const> = event.output_buffer()
      value_to_json(o, v, seen)
      if k is string then
         if seen_keys[k] then
            error("Duplicate integer string key " .. k)
         end
         seen_keys[k] = true
         table.insert(key_value_pairs, { k, table.concat(buf) })
      elseif k is number then
         local as_str <const> = tostring(k)
         if seen_keys[as_str] then
            error("Duplicate integer string key " .. as_str)
         end
         seen_keys[as_str] = true
         table.insert(key_value_pairs, { as_str, table.concat(buf) })
      end
   end

   table.sort(key_value_pairs, function(a: {string,string}, b: {string,string}): boolean
      return a[1] < b[1]
   end)

   output("{")
   local first = true
   for pair in ivalues(key_value_pairs) do
      if first then
         first = false
      else
         output(",")
      end
      output(("%q:"):format(pair[1]), pair[2])
   end
   output("}")
end

function event.to_json<P>(output: event.Output, to_emit: event.Prototype<P>, param: P)
   output("{\"tag\":\"", to_emit.tag, "\",\"data\":")
   value_to_json(output, param)
   output("}")
end

--function event.to_plain(output: event.Output, to_emit: event.Prototype<P>, param: P)
--end

function event.emit<Parameter>(
   to_emit: event.Prototype<Parameter>,
   param: Parameter
)
   local buf = {}
   local function out(...: string)
      for i = 1, select("#", ...) do
         table.insert(buf, (select(i, ...)))
      end
   end
   event.to_json(out, to_emit, param)

   log.debug(table.unpack(buf))
end

return event
