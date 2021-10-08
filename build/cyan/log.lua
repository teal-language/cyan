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



local function create_logger(
   stream,
   verbosity_threshold,
   prefix,
   cont,
   inspector)

   inspector = inspector or tostring
   local prefix_len = (prefix):len()
   prefix = prefix and (prefix) .. " " or ""
   cont = cont and (cont) .. " " or "... "
   local sanitize = sanitizer(stream)
   local threshold = verbosity_threshold and verbosity_to_int[verbosity_threshold] or -math.huge
   return function(...)
      if verbosity_to_int[verbosity] < threshold then return end

      stream:write(tostring(sanitize(str.pad_left(prefix, max_prefix_len))))
      for i = 1, select("#", ...) do
         local val = inspector(sanitize((select(i, ...))))
         local lns = tab.from(str.split(val, "\n", true))
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

local function set_verbosity(level)
   verbosity = level
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
   set_verbosity = set_verbosity,
   verbosities = verbosities,
   Verbosity = Verbosity,
}

return log
