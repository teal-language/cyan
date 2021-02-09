local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pcall = _tl_compat and _tl_compat.pcall or pcall
local util = require("teal-cli.util")
local cs = require("teal-cli.colorstring")
local tab = util.tab
local str = util.str

local inspect
do
   local ok, actual_inspect = pcall(require, "inspect")
   if ok then
      inspect = function(x)
         if type(x) == "string" then
            return x
         else
            return actual_inspect(x)
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
   local prefix_len = #prefix
   longest_prefix = prefix_len > longest_prefix and
   prefix_len or
   longest_prefix
   prefix = prefix and prefix .. " " or ""
   cont = cont and cont .. " " or "... "
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

local log = {}

log.debug = logfn(
io.stderr,
cs.new():append_ansi_esc(31, 1):append("DEBUG", 0),
cs.new(31, "...", 0),
inspect)

log.err = logfn(
io.stderr,
cs.new(31, "Error", 0),
cs.new(31, "...", 0))

log.warn = logfn(
io.stderr,
cs.new(33, "Warn", 0),
cs.new(33, "...", 0))

log.info = logfn(
io.stdout,
cs.new(36, "Info", 0),
cs.new(36, "...", 0))


return log