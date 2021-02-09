
local util <const> = require("teal-cli.util")
local cs <const> = require("teal-cli.colorstring")
local tab <const> = util.tab
local str <const> = util.str

local inspect: function(any): string
do
   local ok, actual_inspect = pcall(require, "inspect") as (boolean, function(any): string)
   if ok then
      inspect = function(x: any): string
         if type(x) == "string" then
            return x as string
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
   stream: FILE,
   prefix: string,
   cont: string,
   inspector: function(any): string
): function(...: any)
   inspector = inspector or tostring
   local prefix_len <const> = #prefix
   longest_prefix = prefix_len > longest_prefix
      and prefix_len
      or longest_prefix
   prefix = prefix and prefix .. " " or ""
   cont = cont and cont .. " " or "... "
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

local log <const>: {string:function(...: any)} = {}

log.debug = logfn(
   io.stderr,
   cs.new():append_ansi_esc(31,1):append("DEBUG", 0) as string,
   cs.new(31, "...", 0) as string,
   inspect
)
log.err = logfn(
   io.stderr,
   cs.new(31, "Error", 0) as string,
   cs.new(31, "...", 0) as string
)
log.warn = logfn(
   io.stderr,
   cs.new(33, "Warn", 0) as string,
   cs.new(33, "...", 0) as string
)
log.info = logfn(
   io.stdout,
   cs.new(36, "Info", 0) as string,
   cs.new(36, "...", 0) as string
)

return log

