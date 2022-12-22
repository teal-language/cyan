
---@brief
--- Console logging utils, not to be confused with log files
---
--- Each logger object has the same `__call` signature of `function(...: any)`, and
--- by default the following are provided:
---
---@@table Name     | Stream | Description
---        `info`   | stdout | General info, should be seen as the default, silenced by --quiet
---        `extra`  | stdout | Extra info that isn't strictly necessary, enabled via -v extra, silenced by --quiet
---        `warn`   | stderr | Used to display warnings, silenced by --quiet
---        `err`    | stderr | Used to display errors
---        `debug`  | stderr | Used for debugging, uses the inspect module (if it is found) to print its arguments, enabled by -v debug
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
--- ): Logger
---@@end
--- to automatically generate formatted output. `cont` defaults to `"..."` and
--- `inspector` defaults to `tostring`. Prefixes will be padded to 10 characters
--- wide by default, so your logging may look off from the default if your
--- prefix is longer.
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
local prefix_padding: integer = 10

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

local as_fd <const>: {FILE:integer} = {
   [io.stdin] = 0,
   [io.stdout] = 1,
   [io.stderr] = 2,
}

local ttys <const> = {}
local function is_a_tty(fd: integer): boolean
   if ttys[fd] == nil then
      if not fd then return false end
      -- TODO: how annoying would it be to ship a small C module that just exports isatty (_isatty on windows)?
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
--- The data needed for a logger to do its job.
local record Logger
   stream: FILE
   verbosity_threshold: Verbosity
   prefix: string | cs.ColorString
   continuation: string | cs.ColorString
   inspector: function(any): string

   metamethod __call: function(...: any)
end

---@desc
--- Returns whether the current verbosity is less than or equal to this
--- loggers verbosity threshold.
function Logger:should_log(): boolean
   local threshold <const> = self.verbosity_threshold and verbosity_to_int[self.verbosity_threshold] or -math.huge
   return verbosity_to_int[verbosity] >= threshold
end

local function do_log(
   stream: FILE,
   initial_prefix: string | cs.ColorString,
   continuation_prefix: string | cs.ColorString,
   inspector: function(any): (string),
   ...: any
)
   local sanitize <const> = sanitizer(stream)

   local prefix <const> = tostring(sanitize(str.pad_left(initial_prefix as string, prefix_padding)))
   local continuation = tostring(sanitize(str.pad_left(continuation_prefix and continuation_prefix as string, prefix_padding)))

   stream:write(prefix, " ")

   for i = 1, select("#", ...) do
      local val <const> = inspector(sanitize((select(i, ...))))
      local lns <const> = tab.from(str.split(val, "\n", true))
      for j, ln in ipairs(lns) do
         stream:write(ln)
         if j < #lns then
            stream:write("\n", continuation, " ")
         end
      end
   end
end

---@desc
--- Log only using the continuation prefix, but don't put a newline at the end.
function Logger:cont_nonl(...: any)
   if not self:should_log() then return end
   do_log(
      self.stream,
      self.continuation,
      self.continuation,
      self.inspector,
      ...
   )
end

---@desc
--- Log only using the continuation prefix.
function Logger:cont(...: any)
   if not self:should_log() then return end
   self:cont_nonl(...)
   self.stream:write("\n")
end

---@desc
--- Same as calling the logger, but don't put a newline at the end
function Logger:nonl(...: any)
   if not self:should_log() then return end
   do_log(
      self.stream,
      self.prefix,
      self.continuation,
      self.inspector,
      ...
   )
end

---@desc
--- Call `string.format` with the given arguments and log that.
function Logger:format(fmt: string, ...: any)
   self(fmt:format(...))
end

---@desc
--- Call `string.format` with the given arguments and log that, without a new line.
function Logger:format_nonl(fmt: string, ...: any)
   self:nonl(fmt:format(...))
end

local logger_metatable <const>: metatable<Logger> = {
   __call = function(self: Logger, ...: any)
      if not self:should_log() then return end
      self:nonl(...)
      self.stream:write("\n")
   end,
   __index = Logger,
}

Logger.stream = io.stdout
Logger.prefix = "???"
Logger.continuation = "..."
Logger.inspector = tostring

---@desc
--- Creates a Logger as described above
local function create_logger(
   stream: FILE,
   verbosity_threshold: Verbosity,
   prefix: string | cs.ColorString,
   cont: string | cs.ColorString,
   inspector: function(any): string
): Logger
   local result: Logger = {
      stream = stream,
      verbosity_threshold = verbosity_threshold,
      prefix = prefix,
      continuation = cont,
      inspector = inspector,
   }
   return setmetatable(result, logger_metatable)
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
   verbosities = verbosities,
   Verbosity = Verbosity,
   Logger = Logger,
}

---@desc
--- Globally set the verbosity of the logging module.
function log.set_verbosity(level: Verbosity)
   verbosity = level
end

---@desc
--- Globally set the padding of the prefixes of loggers.
function log.set_prefix_padding(padding: integer)
   if padding < 0 then
      return
   end
   prefix_padding = padding
end

return log
