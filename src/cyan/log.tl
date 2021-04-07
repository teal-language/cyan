
local util <const> = require("cyan.util")
local cs <const> = require("cyan.colorstring")
local tab <const> = util.tab
local str <const> = util.str

local inspect: function(any): string
do
   local req <const> = require
   local ok, actual_inspect = pcall(req, "inspect") as (boolean, function(any, any): string)
   local inspect_opts <const> = {
      process = function(item: any, path: {any}): any
         if path[#path] ~= (actual_inspect as {string:any}).METATABLE then
            return item
         end
      end
   }
   if ok then
      inspect = function(x: any): string
         if x is string then
            return x
         else
            return actual_inspect(x, inspect_opts)
         end
      end
   else
      inspect = tostring
   end
end

local longest_prefix = 10

local function logfn(
   stream: FILE,
   prefix: string | cs.ColorString,
   cont: string | cs.ColorString,
   inspector: function(any): string
): function(...: any)
   inspector = inspector or tostring
   local prefix_len <const> = #(prefix as string)
   longest_prefix = prefix_len > longest_prefix
      and prefix_len
      or longest_prefix
   prefix = prefix and (prefix as string) .. " " or ""
   cont = cont and (cont as string) .. " " or "... "
   return function(...: any)
      stream:write(tostring(str.pad_left(prefix, longest_prefix)))
      for i = 1, select("#", ...) do
         local val <const> = inspector((select(i, ...)))
         local lns <const> = tab.from(str.split(val, "\n", true))
         for i, ln in ipairs(lns) do
            stream:write(ln)
            if i < #lns then
               stream:write("\n", prefix_len > 0 and tostring(str.pad_left(cont, longest_prefix)) or "")
            end
         end
      end
      stream:write("\n")
   end
end

local log <const> = {
   debug = logfn(
      io.stderr,
      cs.highlight(cs.colors.debug, "DEBUG"),
      cs.highlight(cs.colors.error, "..."),
      inspect
   ),
   err = logfn(
      io.stderr,
      cs.highlight(cs.colors.error, "Error"),
      cs.highlight(cs.colors.error, "...")
   ),
   warn = logfn(
      io.stderr,
      cs.highlight(cs.colors.warn, "Warn"),
      cs.highlight(cs.colors.warn, "...")
   ),
   info = logfn(
      io.stdout,
      cs.highlight(cs.colors.teal, "Info"),
      cs.highlight(cs.colors.teal, "...")
   ),
}

return log

