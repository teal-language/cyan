
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
---    prefix: string | decoration.Decorated,
---    cont: string | decoration.Decorated,
---    inspector: function(any): string
--- ): Logger
---@@end
--- to automatically generate formatted output. `cont` defaults to `"..."` and
--- `inspector` defaults to `tostring`. Prefixes will be padded to 10 characters
--- wide by default, so your logging may look off from the default if your
--- prefix is longer.
---
--- Additionally, loggers will try to detect whether or not to display colors.
--- This is only handled with the `decoration.Decorated` type to avoid the many
--- pitfalls of trying to parse ANSI escape sequences. If a regular string
--- contains any escape sequences or an inspector produces them (outside of a
--- `decoration.Decorated`) it will not be handled.

local system <const> = require("system")
local util <const> = require("cyan.util")
local decoration <const> = require("cyan.decoration")
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
local verbosity_to_int <total>: {Verbosity:integer} = {
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
         end
         return actual_inspect(x, inspect_opts)
      end
   else
      inspect = tostring
   end
end

local ttys <const> = {}
local function is_a_tty(file: FILE): boolean
   if not file then return false end
   if ttys[file] == nil then
      ttys[file] = system.isatty(file)
   end
   return ttys[file]
end

local function renderer(stream: FILE): decoration.Renderer
   if no_color_env or not is_a_tty(stream) then
      return decoration.render_plain
   end
   return decoration.render_ansi
end

local function is_decorated_string(value: any): boolean
   local mt = getmetatable(value)
   if mt then
      return mt.__name == "cyan.decoration.Decorated"
   end
   return false
end

---@desc
--- The data needed for a logger to do its job.
local record Logger
   stream: FILE
   verbosity_threshold: Verbosity
   prefix: string | decoration.Decorated
   continuation: string | decoration.Decorated
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

local function rendered_prefix(
   prefix: string | decoration.Decorated,
   render: decoration.Renderer
): string
   local buf <const> = {}
   if prefix is string then
      render(buf, str.pad_left(prefix, prefix_padding), { monospace = true })
   else
      render(buf, str.pad_left(prefix.plain_content, prefix_padding), decoration.copy(prefix.decoration, { monospace = true }))
   end
   return table.concat(buf)
end

local function do_log(
   stream: FILE,
   initial_prefix: string | decoration.Decorated,
   continuation_prefix: string | decoration.Decorated,
   inspector: function(any): (string),
   end_with_newline: boolean,
   ...: any
)
   local render <const> = renderer(stream)

   local prefix <const> = rendered_prefix(initial_prefix, render)
   local continuation <const> = rendered_prefix(continuation_prefix, render)

   local new_line <const> = decoration.render_to_string(render, "\n")
   local space <const> = decoration.render_to_string(render, " ")

   stream:write(prefix, space)

   for i = 1, select("#", ...) do
      local v <const> = select(i, ...)
      local render_buf <const>: {string} = {}
      if is_decorated_string(v) then
         render(
            render_buf,
            (v as decoration.Decorated).plain_content,
            (v as decoration.Decorated).decoration
         )
      else
         render_buf[1] = decoration.render_to_string(render, inspector(v))
      end
      local rendered <const> = table.concat(render_buf)
      local first = true
      for ln in str.split(rendered, "\n", true) do
         if first then
            first = false
         else
            stream:write(new_line, continuation, space)
         end
         stream:write(ln)
      end
   end

   if end_with_newline then
      stream:write(new_line)
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
      false,
      ...
   )
end

---@desc
--- Log only using the continuation prefix.
function Logger:cont(...: any)
   if not self:should_log() then return end
   do_log(
      self.stream,
      self.continuation,
      self.continuation,
      self.inspector,
      true,
      ...
   )
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
      false,
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
      do_log(
         self.stream,
         self.prefix,
         self.continuation,
         self.inspector,
         true,
         ...
      )
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
   verbosity_threshold?: Verbosity,
   prefix?: string | decoration.Decorated,
   cont?: string | decoration.Decorated,
   inspector?: function(any): string
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

local function copy_decorated(maybe_decorated: string | decoration.Decorated): string | decoration.Decorated
   if maybe_decorated is string then
      return maybe_decorated
   end
   return {
      plain_content = maybe_decorated.plain_content,
      decoration = maybe_decorated.decoration
   }
end

---@desc
--- Create a copy of a logger, deep copying relevant data
function Logger:copy(
   new_prefix: string | decoration.Decorated,
   new_continuation: string | decoration.Decorated
): Logger
   return create_logger(
      self.stream,
      self.verbosity_threshold,
      new_prefix or copy_decorated(self.prefix),
      new_continuation or copy_decorated(self.continuation),
      self.inspector
   )
end

local log <const> = {
   debug = create_logger(
      io.stderr,
      "debug",
      decoration.decorate("DEBUG", decoration.scheme.bright_red),
      decoration.decorate("...", decoration.scheme.bright_red),
      inspect
   ),
   err = create_logger(
      io.stderr,
      nil,
      decoration.decorate("Error", decoration.scheme.error),
      decoration.decorate("...", decoration.scheme.error)
   ),
   warn = create_logger(
      io.stderr,
      "quiet",
      decoration.decorate("Error", decoration.scheme.warn),
      decoration.decorate("...", decoration.scheme.warn)
   ),
   info = create_logger(
      io.stdout,
      "normal",
      decoration.decorate("Info", decoration.scheme.teal),
      decoration.decorate("...", decoration.scheme.teal)
   ),
   extra = create_logger(
      io.stdout,
      "extra",
      decoration.decorate("*Info", decoration.scheme.teal),
      decoration.decorate("...", decoration.scheme.teal)
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
