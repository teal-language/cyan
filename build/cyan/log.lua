local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pcall = _tl_compat and _tl_compat.pcall or pcall
local util = require("cyan.util")
local cs = require("cyan.colorstring")
local tab = util.tab
local str = util.str

local inspect
do
   local req = require
   local ok, actual_inspect = pcall(req, "inspect")
   local inspect_opts = {
      process = function(item, path)
         if path[#path] ~= (actual_inspect).METATABLE then
            return item
         end
      end,
   }
   if ok then
      inspect = function(x)
         if type(x) == "string" then
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
   stream,
   prefix,
   cont,
   inspector)

   inspector = inspector or tostring
   local prefix_len = #(prefix)
   longest_prefix = prefix_len > longest_prefix and
   prefix_len or
   longest_prefix
   prefix = prefix and (prefix) .. " " or ""
   cont = cont and (cont) .. " " or "... "
   return function(...)
      stream:write(tostring(str.pad_left(prefix, longest_prefix)))
      for i = 1, select("#", ...) do
         local val = inspector((select(i, ...)))
         local lns = tab.from(str.split(val, "\n", true))
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

local log = {
   debug = logfn(
   io.stderr,
   cs.highlight(cs.colors.debug, "DEBUG"),
   cs.highlight(cs.colors.error, "..."),
   inspect),

   err = logfn(
   io.stderr,
   cs.highlight(cs.colors.error, "Error"),
   cs.highlight(cs.colors.error, "...")),

   warn = logfn(
   io.stderr,
   cs.highlight(cs.colors.warn, "Warn"),
   cs.highlight(cs.colors.warn, "...")),

   info = logfn(
   io.stdout,
   cs.highlight(cs.colors.teal, "Info"),
   cs.highlight(cs.colors.teal, "...")),

}

return log