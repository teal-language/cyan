local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack; local type = type; local ivalues = require("cyan.util").tab.ivalues

local event = { FormatSpecifier = {} }


















function event.output_buffer(into)
   local buf = into or {}
   return function(...)
      for i = 1, select("#", ...) do
         table.insert(buf, (select(i, ...)))
      end
   end, buf
end

local function is_int(x)
   return type(x) == "number" and math.floor(x) == x
end

local function value_to_json(output, param, seen)
   seen = seen or {}
   if seen[param] then
      error("Attempt to encode recursive data")
   end
   local param_mt = getmetatable(param)
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
      output(("%q"):format(param))
      return
   end
   if type(param) ~= "table" then
      error("Invalid type " .. type(param) .. " for event parameter")
      return
   end

   local t = param

   local only_integer_keys = true
   local smallest_integer_key = 0
   local largest_integer_key = 0
   for k in pairs(t) do
      if not is_int(k) then
         only_integer_keys = false
         break
      end
      largest_integer_key = math.max(largest_integer_key, k)
      smallest_integer_key = math.min(smallest_integer_key, k)
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

   local key_value_pairs = {}
   local seen_keys = {}
   for k, v in pairs(t) do
      local o, buf = event.output_buffer()
      value_to_json(o, v, seen)
      if type(k) == "string" then
         if seen_keys[k] then
            error("Duplicate integer string key " .. k)
         end
         seen_keys[k] = true
         table.insert(key_value_pairs, { k, table.concat(buf) })
      elseif type(k) == "number" then
         local as_str = tostring(k)
         if seen_keys[as_str] then
            error("Duplicate integer string key " .. as_str)
         end
         seen_keys[as_str] = true
         table.insert(key_value_pairs, { as_str, table.concat(buf) })
      end
   end

   table.sort(key_value_pairs, function(a, b)
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

function event.to_json(output, to_emit, param)
   output("{\"tag\":\"", to_emit.tag, "\",\"data\":")
   value_to_json(output, param)
   output("}")
end




local log = require("cyan.log")

function event.emit(
   to_emit,
   param)

   local buf = {}
   local function out(...)
      for i = 1, select("#", ...) do
         table.insert(buf, (select(i, ...)))
      end
   end
   event.to_json(out, to_emit, param)

   log.debug(_tl_table_unpack(buf))
end

return event
