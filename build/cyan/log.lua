local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local os = _tl_compat and _tl_compat.os or os; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string





































local util = require("cyan.util")
local cs = require("cyan.colorstring")
local tab = util.tab
local str = util.str

local no_color_env = os.getenv("NO_COLOR") ~= nil



local Verbosity = {}






local verbosities = {
   "quiet",
   "normal",
   "extra",
   "debug",
}
local verbosity_to_int = {
   quiet = 0,
   normal = 1,
   extra = 2,
   debug = 3,
}

local verbosity = "normal"
local prefix_padding = 10

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

local as_fd = {
   [io.stdin] = 0,
   [io.stdout] = 1,
   [io.stderr] = 2,
}

local ttys = {}
local function is_a_tty(fd)
   if ttys[fd] == nil then
      if not fd then return false end

      local ok, exit, signal = os.execute(("test -t %d"):format(fd))
      ttys[fd] = (ok and exit == "exit") and signal == 0 or false
   end
   return ttys[fd]
end

local colorstring_mt = getmetatable(cs.new())
local function is_color_string(val)
   return getmetatable(val) == colorstring_mt
end

local function sanitizer(stream)
   local is_not_tty = not is_a_tty(as_fd[stream])
   return function(val)
      if is_color_string(val) and (is_not_tty or no_color_env) then
         return (val):to_raw()
      end
      return val
   end
end



local Logger = {}












function Logger:should_log()
   local threshold = self.verbosity_threshold and verbosity_to_int[self.verbosity_threshold] or -math.huge
   return verbosity_to_int[verbosity] >= threshold
end

local function do_log(
   stream,
   initial_prefix,
   continuation_prefix,
   inspector,
   ...)

   local sanitize = sanitizer(stream)

   local prefix = tostring(sanitize(str.pad_left(initial_prefix, prefix_padding)))
   local continuation = tostring(sanitize(str.pad_left(continuation_prefix and continuation_prefix, prefix_padding)))

   stream:write(prefix, " ")

   for i = 1, select("#", ...) do
      local val = inspector(sanitize((select(i, ...))))
      local lns = tab.from(str.split(val, "\n", true))
      for j, ln in ipairs(lns) do
         stream:write(ln)
         if j < #lns then
            stream:write("\n", continuation, " ")
         end
      end
   end
end



function Logger:cont_nonl(...)
   if not self:should_log() then return end
   do_log(
   self.stream,
   self.continuation,
   self.continuation,
   self.inspector,
   ...)

end



function Logger:cont(...)
   if not self:should_log() then return end
   self:cont_nonl(...)
   self.stream:write("\n")
end



function Logger:nonl(...)
   if not self:should_log() then return end
   do_log(
   self.stream,
   self.prefix,
   self.continuation,
   self.inspector,
   ...)

end



function Logger:format(fmt, ...)
   self(fmt:format(...))
end



function Logger:format_nonl(fmt, ...)
   self:nonl(fmt:format(...))
end

local logger_metatable = {
   __call = function(self, ...)
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



local function create_logger(
   stream,
   verbosity_threshold,
   prefix,
   cont,
   inspector)

   local result = {
      stream = stream,
      verbosity_threshold = verbosity_threshold,
      prefix = prefix,
      continuation = cont,
      inspector = inspector,
   }
   return setmetatable(result, logger_metatable)
end

local log = {
   debug = create_logger(
   io.stderr,
   "debug",
   cs.highlight(cs.colors.debug, "DEBUG"),
   cs.highlight(cs.colors.debug, "..."),
   inspect),

   err = create_logger(
   io.stderr,
   nil,
   cs.highlight(cs.colors.error, "Error"),
   cs.highlight(cs.colors.error, "...")),

   warn = create_logger(
   io.stderr,
   "quiet",
   cs.highlight(cs.colors.warn, "Warn"),
   cs.highlight(cs.colors.warn, "...")),

   info = create_logger(
   io.stdout,
   "normal",
   cs.highlight(cs.colors.teal, "Info"),
   cs.highlight(cs.colors.teal, "...")),

   extra = create_logger(
   io.stdout,
   "extra",
   cs.highlight(cs.colors.teal, "*Info"),
   cs.highlight(cs.colors.teal, "...")),

   create_logger = create_logger,
   verbosities = verbosities,
   Verbosity = Verbosity,
   Logger = Logger,
}



function log.set_verbosity(level)
   verbosity = level
end



function log.set_prefix_padding(padding)
   if padding < 0 then
      return
   end
   prefix_padding = padding
end

return log
