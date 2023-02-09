local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack; local command = require("cyan.command")
local log = require("cyan.log")
local cs = require("cyan.colorstring")
local util = require("cyan.util")
local gfind = util.str.gfind
local keys = util.tab.keys
local ts = require("cyan.eventtypes")

local display_kinds = {
   filename = true,
}

local Handler = ts.Handler
local Report = ts.Report
local FormatSpecifier = ts.FormatSpecifier
local DisplayKind = ts.DisplayKind

local event = {
   Handler = Handler,
   Report = Report,
   FormatSpecifier = FormatSpecifier,
   DisplayKind = DisplayKind,
}

function event.expand_log_format(log_format)
   local result = {}
   local function add(a, b)
      local str = log_format:sub(a, b)
      if #str > 0 then
         table.insert(result, str)
      end
   end

   local last_index = 1
   local iter = gfind(log_format, "%%%b()")
   while last_index <= #log_format do
      local s, e = iter()
      add(last_index, (s or 0) - 1)
      if not s then
         break
      end

      local specifier = log_format:sub(s + 2, e - 1)
      local key, rest = specifier:match("^%s*([^%s]+)%s*([^%s]*)$")
      local display_kind = display_kinds[rest] and rest or nil
      table.insert(result, {
         key = key,
         display_kind = display_kind,
      })
      last_index = e + 1
   end

   return result
end

local structured = false
function event.set_structured(to)
   structured = to
   if to then
      log.disable()
   end
end

function event.is_structured()
   return structured
end

function event.emit(name, params, logger)
   assert(command.running, "Attempt to emit event with no running command")
   local err_msg = "Command '" .. command.running.name .. "' emitted an unregistered event: '" .. name .. "'"
   assert(command.running.events, err_msg)
   local f = assert(command.running.events[name], err_msg)
   local report = f(params)

   if structured then
      local seen_tables = {}
      local function is_int(x)
         return type(x) == "number" and x == math.floor(x)
      end
      local function put(value)
         local t = type(value)

         assert(t ~= "userdata", "Attempt to serialize userdata")
         assert(t ~= "function", "Attempt to serialize function")

         if t == "table" then
            if seen_tables[value] then
               error("Attempt to serialize nested table", 2)
            end
            seen_tables[value] = true

            local used_keys = {}




            local ordered_keys = {}
            local first = true
            local only_integer_keys = true
            local highest_integer_key = 0
            for k in keys(value) do
               if is_int(k) then
                  highest_integer_key = math.floor(math.max(k, highest_integer_key))
               else
                  only_integer_keys = false
               end
               if not (type(k) == "string" or is_int(k)) then
                  error("Bad table key for serialization (" .. type(k) .. ")", 2)
               end
               local str_key = ("%q"):format(tostring(k))
               if used_keys[str_key] then
                  error("Duplicate object key " .. str_key, 2)
               end
               table.insert(ordered_keys, { str_key = str_key, actual_key = k })
            end
            table.sort(ordered_keys, function(a, b)
               return a.str_key < b.str_key
            end)

            if only_integer_keys then
               io.stdout:write("[")
               for i = 1, highest_integer_key do
                  if i > 1 then
                     io.stdout:write(",")
                  end
                  put((value)[i])
               end
               io.stdout:write("]")
            else
               io.stdout:write("{")
               for _, pair in ipairs(ordered_keys) do
                  if first then
                     first = false
                  else
                     io.stdout:write(",")
                  end
                  io.stdout:write(pair.str_key, ":")
                  put((value)[pair.actual_key])
               end
               io.stdout:write("}")
            end
            seen_tables[false] = true
         elseif type(value) == "string" then
            io.stdout:write(("%q"):format(value))
         elseif value == nil then
            io.stdout:write("null")
         else
            io.stdout:write(tostring(value))
         end
      end

      io.stdout:write(("{\"event\":%q,"):format(name))
      if report.tag then
         io.stdout:write(("\"tag\":%q,"):format(report.tag))
      end

      io.stdout:write("\"data\":")
      put(params)
      io.stdout:write("}\n")
   else
      logger = logger or log.info

      local buf = {}
      local chunks = event.expand_log_format(report.log_format)
      for i, v in ipairs(chunks) do
         if type(v) == "string" then
            buf[i] = v
         else
            if v.display_kind == "filename" then
               buf[i] = cs.highlight(cs.colors.file, logger.inspector(report.parameters[v.key]))
            else
               buf[i] = report.parameters[v.key]
            end
         end
      end

      logger(_tl_table_unpack(buf))
   end
end

return event
