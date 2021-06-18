
---@brief
--- Console logging utils, not to be confused with log files
---
--- Each logging function has the same signature of `function(...: any)`, and
--- by default the following are provided:
---
---@@table Name     | Stream | Description
---        `info`   | stdout | General info, should be seen as the default, silenced by --quiet
---        `warn`   | stderr | Used to display warnings, silenced by --quiet
---        `err`    | stderr | Used to display errors
---        `debug`  | stderr | Used for debugging, uses the inspect module (if it is found) to print its arguments
---@@end
---
--- You may notice that these are nicely padded and after the first line the prefix is replaced by a '...'
--- Another function is provided, `create_logger`,
---
---@@code
--- create_logger: function(
---    stream: FILE,
---    prefix: string | ColorString,
---    cont: string | ColorString,
---    inspector: function(any): string
--- ): function(...: any)
---@@end
--- to automatically generate formatted output. `cont` defaults to `"..."` and
--- `inspector` defaults to `tostring`. Prefixes will be padded to 10 characters
--- wide, so your logging may look off from the default if your prefix is longer.


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

local max_prefix_len <const> = 10

---@desc
--- Creates a logging function as described above
local function create_logger(
   stream: FILE,
   prefix: string | cs.ColorString,
   cont: string | cs.ColorString,
   inspector: function(any): string
): function(...: any)
   inspector = inspector or tostring
   local prefix_len <const> = #(prefix as string)
   prefix = prefix and (prefix as string) .. " " or ""
   cont = cont and (cont as string) .. " " or "... "
   return function(...: any)
      stream:write(tostring(str.pad_left(prefix, max_prefix_len)))
      for i = 1, select("#", ...) do
         local val <const> = inspector((select(i, ...)))
         local lns <const> = tab.from(str.split(val, "\n", true))
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

local log <const> = {
   debug = create_logger(
      io.stderr,
      cs.highlight(cs.colors.debug, "DEBUG"),
      cs.highlight(cs.colors.error, "..."),
      inspect
   ),
   err = create_logger(
      io.stderr,
      cs.highlight(cs.colors.error, "Error"),
      cs.highlight(cs.colors.error, "...")
   ),
   warn = create_logger(
      io.stderr,
      cs.highlight(cs.colors.warn, "Warn"),
      cs.highlight(cs.colors.warn, "...")
   ),
   info = create_logger(
      io.stdout,
      cs.highlight(cs.colors.teal, "Info"),
      cs.highlight(cs.colors.teal, "...")
   ),
   create_logger = create_logger,
}

return log

