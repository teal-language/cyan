
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
--- You may notice that these are nicely padded and after the first line the
--- prefix is replaced by a '...'. Another function is provided, `create_logger`,
---
---@@code
--- create_logger: function(
---    stream: FILE,
---    verbosity_threshold: Verbosity,
---    prefix: string | ColorString,
---    cont: string | ColorString,
---    inspector: function(any): string
--- ): function(...: any)
---@@end
--- to automatically generate formatted output. `cont` defaults to `"..."` and
--- `inspector` defaults to `tostring`. Prefixes will be padded to 10 characters
--- wide, so your logging may look off from the default if your prefix is longer.
---
--- Additionally, loggers will try to detect whether or not to display colors.
--- This is only handled with the `ColorString` type to avoid the many pitfalls of
--- trying to parse ANSI escape sequences. If a regular string contains any escape
--- sequences or an inspector produces them (outside of a `ColorString`) it will
--- not be handled.

local util <const> = require("cyan.util")
local cs <const> = require("cyan.colorstring")
local tab <const> = util.tab
local str <const> = util.str

local no_color_env <const> = os.getenv("NO_COLOR") ~= nil

---@desc
--- The thresholds for loggers to actually write their output
local enum Verbosity
   "quiet"
   "normal"
   "extra"
   "debug"
end

local verbosities <const>: {Verbosity} = {
   "quiet",
   "normal",
   "extra",
   "debug",
}
local verbosity_to_int <const>: {Verbosity:integer} = {
   quiet = 0,
   normal = 1,
   extra = 2,
   debug = 3,
}

local verbosity: Verbosity = "normal"

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

local as_fd <const>: {FILE:integer} = {
   [io.stdin] = 0,
   [io.stdout] = 1,
   [io.stderr] = 2,
}

local ttys <const> = {}
local function is_a_tty(fd: integer): boolean
   if ttys[fd] == nil then
      if not fd then return false end
      local ok <const>, exit <const>, signal <const> = os.execute(("test -t %d"):format(fd))
      ttys[fd] = (ok and exit == "exit") and signal == 0 or false
   end
   return ttys[fd]
end

local colorstring_mt <const> = getmetatable(cs.new())
local function is_color_string(val: any): boolean
   return getmetatable(val) == colorstring_mt
end

local function sanitizer(stream: FILE): function(any): any
   local is_not_tty <const> = not is_a_tty(as_fd[stream])
   return function(val: any): any
      if is_color_string(val) and (is_not_tty or no_color_env) then
         return (val as cs.ColorString):to_raw()
      end
      return val
   end
end

---@desc
--- Creates a logging function as described above
local function create_logger(
   stream: FILE,
   verbosity_threshold: Verbosity,
   prefix: string | cs.ColorString,
   cont: string | cs.ColorString,
   inspector: function(any): string
): function(...: any)
   inspector = inspector or tostring
   local prefix_len <const> = (prefix as string):len()
   prefix = prefix and (prefix as string) .. " " or ""
   cont = cont and (cont as string) .. " " or "... "
   local sanitize <const> = sanitizer(stream)
   local threshold <const> = verbosity_threshold and verbosity_to_int[verbosity_threshold] or -math.huge
   return function(...: any)
      if verbosity_to_int[verbosity] < threshold then return end

      stream:write(tostring(sanitize(str.pad_left(prefix, max_prefix_len))))
      for i = 1, select("#", ...) do
         local val <const> = inspector(sanitize((select(i, ...))))
         local lns <const> = tab.from(str.split(val, "\n", true))
         for j, ln in ipairs(lns) do
            stream:write(ln)
            if j < #lns then
               stream:write("\n", prefix_len > 0 and tostring(sanitize(str.pad_left(cont, max_prefix_len))) or "")
            end
         end
      end
      stream:write("\n")
   end
end

local function set_verbosity(level: Verbosity)
   verbosity = level
end

local log <const> = {
   debug = create_logger(
      io.stderr,
      "debug",
      cs.highlight(cs.colors.debug, "DEBUG"),
      cs.highlight(cs.colors.debug, "..."),
      inspect
   ),
   err = create_logger(
      io.stderr,
      nil,
      cs.highlight(cs.colors.error, "Error"),
      cs.highlight(cs.colors.error, "...")
   ),
   warn = create_logger(
      io.stderr,
      "quiet",
      cs.highlight(cs.colors.warn, "Warn"),
      cs.highlight(cs.colors.warn, "...")
   ),
   info = create_logger(
      io.stdout,
      "normal",
      cs.highlight(cs.colors.teal, "Info"),
      cs.highlight(cs.colors.teal, "...")
   ),
   extra = create_logger(
      io.stdout,
      "extra",
      cs.highlight(cs.colors.teal, "*Info"),
      cs.highlight(cs.colors.teal, "...")
   ),
   create_logger = create_logger,
   set_verbosity = set_verbosity,
   verbosities = verbosities,
   Verbosity = Verbosity,
}

return log
