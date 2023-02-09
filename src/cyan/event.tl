local command <const> = require("cyan.command")
local log <const> = require("cyan.log")
local cs <const> = require("cyan.colorstring")
local util <const> = require("cyan.util")
local gfind <const> = util.str.gfind
local keys <const> = util.tab.keys
local type ts = require("cyan.eventtypes")

local display_kinds: {string:boolean} = {
   filename = true,
}

local type Handler = ts.Handler
local type Report = ts.Report
local type FormatSpecifier = ts.FormatSpecifier
local type DisplayKind = ts.DisplayKind

local event <const> = {
   Handler = Handler,
   Report = Report,
   FormatSpecifier = FormatSpecifier,
   DisplayKind = DisplayKind,
}

function event.expand_log_format(log_format: string): {string | FormatSpecifier}
   local result <const>: {string | FormatSpecifier} = {}
   local function add(a: integer, b: integer)
      local str <const> = log_format:sub(a, b)
      if #str > 0 then
         table.insert(result, str)
      end
   end

   local last_index = 1
   local iter <const> = gfind(log_format, "%%%b()")
   while last_index <= #log_format do
      local s <const>, e <const> = iter()
      add(last_index, (s or 0) - 1)
      if not s then
         break
      end

      local specifier = log_format:sub(s + 2, e - 1)
      local key, rest = specifier:match("^%s*([^%s]+)%s*([^%s]*)$")
      local display_kind = display_kinds[rest] and rest as DisplayKind or nil
      table.insert(result, {
         key = key,
         display_kind = display_kind,
      } as FormatSpecifier)
      last_index = e + 1
   end

   return result
end

local structured = false
function event.set_structured(to: boolean)
   structured = to
   if to then
      log.disable()
   end
end

function event.is_structured(): boolean
   return structured
end

function event.emit(name: string, params: {string:any}, logger: log.Logger)
   assert(command.running, "Attempt to emit event with no running command")
   local err_msg <const> = "Command '" .. command.running.name .. "' emitted an unregistered event: '" .. name .. "'"
   assert(command.running.events, err_msg)
   local f <const> = assert(command.running.events[name], err_msg)
   local report <const> = f(params)

   if structured then
      local seen_tables <const>: {any:boolean} = {}
      local function is_int(x: any): boolean
         return x is number and x == math.floor(x)
      end
      local function put(value: any)
         local t <const> = type(value)

         assert(t ~= "userdata", "Attempt to serialize userdata")
         assert(t ~= "function", "Attempt to serialize function")

         if t == "table" then
            if seen_tables[value] then
               error("Attempt to serialize nested table", 2)
            end
            seen_tables[value] = true
            -- for now, assume all tables should be output as objects
            local used_keys: {string:boolean} = {}
            local record KeyPair
               str_key: string
               actual_key: any
            end
            local ordered_keys: {KeyPair} = {}
            local first = true
            local only_integer_keys = true
            local highest_integer_key = 0
            for k in keys(value as table) do
               if is_int(k) then
                  highest_integer_key = math.floor(math.max(k as number, highest_integer_key))
               else
                  only_integer_keys = false
               end
               if not (k is string or is_int(k)) then
                  error("Bad table key for serialization (" .. type(k) .. ")", 2)
               end
               local str_key <const> = ("%q"):format(tostring(k))
               if used_keys[str_key] then
                  error("Duplicate object key " .. str_key, 2)
               end
               table.insert(ordered_keys, { str_key = str_key, actual_key = k })
            end
            table.sort(ordered_keys, function(a: KeyPair, b: KeyPair): boolean
               return a.str_key < b.str_key
            end)

            if only_integer_keys then
               io.stdout:write("[")
               for i = 1, highest_integer_key do
                  if i > 1 then
                     io.stdout:write(",")
                  end
                  put((value as {any})[i])
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
                  put((value as table)[pair.actual_key])
               end
               io.stdout:write("}")
            end
            seen_tables[false] = true
         elseif value is string then
            io.stdout:write(("%q"):format(value))
         elseif value is nil then
            io.stdout:write("null")
         else
            io.stdout:write(tostring(value))
         end
      end

      io.stdout:write(("{\"event\":%q,"):format(name))
      if report.tag then
         io.stdout:write(("\"tag\":%q,"):format(report.tag))
      end
      -- io.stdout:write(("\"log\":%q,"):format(report.log_format))
      io.stdout:write("\"data\":")
      put(params)
      io.stdout:write("}\n")
   else
      logger = logger or log.info

      local buf <const>: {any} = {}
      local chunks <const> = event.expand_log_format(report.log_format)
      for i, v in ipairs(chunks) do
         if v is string then
            buf[i] = v
         else
            if v.display_kind == "filename" then
               buf[i] = cs.highlight(cs.colors.file, logger.inspector(report.parameters[v.key]))
            else
               buf[i] = report.parameters[v.key]
            end
         end
      end

      logger(table.unpack(buf))
   end
end

return event
