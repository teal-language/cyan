local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string





























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

local max_prefix_len = 10



local function create_logger(
   stream,
   prefix,
   cont,
   inspector)

   inspector = inspector or tostring
   local prefix_len = (prefix):len()
   prefix = prefix and (prefix) .. " " or ""
   cont = cont and (cont) .. " " or "... "
   return function(...)
      stream:write(tostring(str.pad_left(prefix, max_prefix_len)))
      for i = 1, select("#", ...) do
         local val = inspector((select(i, ...)))
         local lns = tab.from(str.split(val, "\n", true))
         for j, ln in ipairs(lns) do
            stream:write(ln)
            if j < #lns then
               stream:write("\n", prefix_len > 0 and tostring(str.pad_left(cont, max_prefix_len)) or "")
            end
         end
      end
      stream:write("\n")
   end
end

local log = {
   debug = create_logger(
   io.stderr,
   cs.highlight(cs.colors.debug, "DEBUG"),
   cs.highlight(cs.colors.error, "..."),
   inspect),

   err = create_logger(
   io.stderr,
   cs.highlight(cs.colors.error, "Error"),
   cs.highlight(cs.colors.error, "...")),

   warn = create_logger(
   io.stderr,
   cs.highlight(cs.colors.warn, "Warn"),
   cs.highlight(cs.colors.warn, "...")),

   info = create_logger(
   io.stdout,
   cs.highlight(cs.colors.teal, "Info"),
   cs.highlight(cs.colors.teal, "...")),

   create_logger = create_logger,
}

return log