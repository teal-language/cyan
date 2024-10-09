local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local math = _tl_compat and _tl_compat.math or math; local os = _tl_compat and _tl_compat.os or os; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table





































local system = require("system")
local util = require("cyan.util")
local decoration = require("cyan.decoration")
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
         end
         return actual_inspect(x, inspect_opts)
      end
   else
      inspect = tostring
   end
end

local ttys = {}
local function is_a_tty(file)
   if not file then return false end
   if ttys[file] == nil then
      ttys[file] = system.isatty(file)
   end
   return ttys[file]
end

local function renderer(stream)
   if no_color_env or not is_a_tty(stream) then
      return decoration.render_plain
   end
   return decoration.render_ansi
end

local function is_decorated_string(value)
   local mt = getmetatable(value)
   if mt then
      return mt.__name == "cyan.decoration.Decorated"
   end
   return false
end



local Logger = {}












function Logger:should_log()
   local threshold = self.verbosity_threshold and verbosity_to_int[self.verbosity_threshold] or -math.huge
   return verbosity_to_int[verbosity] >= threshold
end

local function rendered_prefix(
   prefix,
   render)

   local buf = {}
   if type(prefix) == "string" then
      render(buf, str.pad_left(prefix, prefix_padding), { monospace = true })
   else
      render(buf, str.pad_left(prefix.plain_content, prefix_padding), decoration.copy(prefix.decoration, { monospace = true }))
   end
   return table.concat(buf)
end

local function do_log(
   stream,
   initial_prefix,
   continuation_prefix,
   inspector,
   end_with_newline,
   ...)

   local render = renderer(stream)

   local prefix = rendered_prefix(initial_prefix, render)
   local continuation = rendered_prefix(continuation_prefix, render)

   local new_line = decoration.render_to_string(render, "\n")
   local space = decoration.render_to_string(render, " ")

   stream:write(prefix, space)

   for i = 1, select("#", ...) do
      local v = select(i, ...)
      local render_buf = {}
      if is_decorated_string(v) then
         render(
         render_buf,
         (v).plain_content,
         (v).decoration)

      else
         render_buf[1] = decoration.render_to_string(render, inspector(v))
      end
      local rendered = table.concat(render_buf)
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



function Logger:cont_nonl(...)
   if not self:should_log() then return end
   do_log(
   self.stream,
   self.continuation,
   self.continuation,
   self.inspector,
   false,
   ...)

end



function Logger:cont(...)
   if not self:should_log() then return end
   do_log(
   self.stream,
   self.continuation,
   self.continuation,
   self.inspector,
   true,
   ...)

end



function Logger:nonl(...)
   if not self:should_log() then return end
   do_log(
   self.stream,
   self.prefix,
   self.continuation,
   self.inspector,
   false,
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
      do_log(
      self.stream,
      self.prefix,
      self.continuation,
      self.inspector,
      true,
      ...)

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

local function copy_decorated(maybe_decorated)
   if type(maybe_decorated) == "string" then
      return maybe_decorated
   end
   return {
      plain_content = maybe_decorated.plain_content,
      decoration = maybe_decorated.decoration,
   }
end



function Logger:copy(
   new_prefix,
   new_continuation)

   return create_logger(
   self.stream,
   self.verbosity_threshold,
   new_prefix or copy_decorated(self.prefix),
   new_continuation or copy_decorated(self.continuation),
   self.inspector)

end

local log = {
   debug = create_logger(
   io.stderr,
   "debug",
   decoration.decorate("DEBUG", decoration.scheme.bright_red),
   decoration.decorate("...", decoration.scheme.bright_red),
   inspect),

   err = create_logger(
   io.stderr,
   nil,
   decoration.decorate("Error", decoration.scheme.error),
   decoration.decorate("...", decoration.scheme.error)),

   warn = create_logger(
   io.stderr,
   "quiet",
   decoration.decorate("Error", decoration.scheme.warn),
   decoration.decorate("...", decoration.scheme.warn)),

   info = create_logger(
   io.stdout,
   "normal",
   decoration.decorate("Info", decoration.scheme.teal),
   decoration.decorate("...", decoration.scheme.teal)),

   extra = create_logger(
   io.stdout,
   "extra",
   decoration.decorate("*Info", decoration.scheme.teal),
   decoration.decorate("...", decoration.scheme.teal)),

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
