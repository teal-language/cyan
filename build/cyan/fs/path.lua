local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local package = _tl_compat and _tl_compat.package or package; local rawlen = _tl_compat and _tl_compat.rawlen or rawlen; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table



local lfs = require("lfs")

local util = require("cyan.util")

local split, esc = util.str.split, util.str.esc
local values = util.tab.values
local xor = util.xor



local Path = {}






local PathMt = {
   __index = Path,
   __name = "cyan.fs.path.Path",
}

local path = {
   Path = Path,
   separator = package.config:sub(1, 1),
   shared_lib_ext = package.cpath:match("(%.%w+)%s*$") or ".so",
}



local function parse_string_path(s, use_os_sep)





   local sep = use_os_sep and path.separator == "\\" and
   "[\\/]" or
   "/"
   s = s:gsub(sep .. "+", sep)
   if s == "" then
      return {}
   elseif s:sub(-1) == sep then
      s = s:sub(1, -2)
   end

   local new = {}
   for chunk in split(s, sep, true) do
      if chunk == ".." then
         if #new > 0 and new[#new] ~= ".." then
            table.remove(new)
         else
            table.insert(new, chunk)
         end
      elseif chunk ~= "." then
         table.insert(new, chunk)
      end
   end
   return new
end

local function setmt(p)
   return setmetatable(p, PathMt)
end





function path.new(s, use_os_sep)
   if not s then return nil end
   return setmt(parse_string_path(s, use_os_sep))
end






function path.ensure(s, use_os_sep)
   if type(s) == "string" then
      return path.new(s, use_os_sep)
   else
      return s
   end
end

local function string_is_absolute_path(p)
   if path.separator == "/" then
      return p:sub(1, 1) == "/"
   elseif path.separator == "\\" then
      return p:match("^%a:$")
   end
end

local function chunks(p)
   return type(p) == "string" and split(p, path.separator, true) or
   values(p)
end

local function append_to_path(p, other)
   for chunk in chunks(other) do
      if chunk == ".." then
         table.remove(p)
      elseif chunk ~= "." then
         table.insert(p, chunk)
      end
   end
end
















function Path:normalize()
   for i = #self, 1, -1 do
      if self[i] == ".." then
         table.remove(self, i)
      end
   end
end





function Path:is_absolute()
   if #self < 1 then return false end
   if path.separator == "/" then
      return self[1] == ""
   elseif path.separator == "\\" then
      return self[1]:match("^%a:$")
   end
end





function Path:tostring()
   local start = self[1] == "." and 2 or 1
   return table.concat(self, "/", start)
end



function Path:to_real_path()
   local res = table.concat(self, path.separator)
   return #res > 0 and res or "." .. path.separator
end



function Path:exists()
   return lfs.attributes(self:to_real_path()) ~= nil
end











function Path:append(other)
   local p = type(other) == "string" and path.new(other) or other
   if p:is_absolute() then
      error("Attempt to append absolute path", 2)
   end
   append_to_path(self, p)
end



function Path:prepend(other)
   if self:is_absolute() then
      error("Attempt to prepend to absolute path", 2)
   end
   other = path.ensure(other)
   local other_len = #other
   table.move(self, 1, #self, other_len + 1)
   for i = 1, other_len do
      self[i] = (other)[i]
   end
end







function Path:to_absolute()
   if self:is_absolute() then
      return
   end
   self:prepend(lfs.currentdir())
end



function Path:copy()
   local new = {}
   for i = 1, #self do
      new[i] = self[i]
   end
   return setmt(new)
end





function Path:ancestors()
   local idx = 0
   return function()
      idx = idx + 1
      if idx >= #self then
         return
      end
      local p = {}
      for i = 1, idx do
         p[i] = self[i]
      end
      return setmt(p)
   end
end



function Path:is_file()
   return lfs.attributes(self:to_real_path(), "mode") == "file"
end



function Path:is_directory()
   return lfs.attributes(self:to_real_path(), "mode") == "directory"
end



function Path:mod_time()
   return lfs.attributes(self:to_real_path(), "modification")
end



function Path:mk_parent_dirs()
   for p in self:ancestors() do
      if p:exists() then
         if not p:is_directory() then
            return false, p:to_real_path() .. " exists and is not a directory"
         end
      else
         local succ, err = lfs.mkdir(p:to_real_path())
         if not succ then
            return false, err
         end
      end
   end
   return true
end




function Path:mkdir()
   local succ, err = self:mk_parent_dirs()
   if succ then
      return lfs.mkdir(self:to_real_path())
   else
      return false, err
   end
end





function Path:remove_leading(p)
   local leading = type(p) == "string" and path.new(p) or p
   if xor(leading:is_absolute(), self:is_absolute()) then
      error(("Attempt to mix absolute and non-absolute path: (%s) and (%s)"):format(self:tostring(), leading:tostring()), 2)
   end
   local ptr = 1
   for chunk in chunks(leading) do
      if self[ptr] ~= chunk then
         break
      end
      ptr = ptr + 1
   end
   if ptr < #leading then
      return
   end
   for _ = 1, ptr - 1 do
      table.remove(self, 1)
   end
end

PathMt.__concat = function(a, b)
   if (type(b) == "string" and string_is_absolute_path(b)) or (type(b) == "table" and b:is_absolute()) then
      error("Attempt to concatenate with absolute path", 2)
   end

   local new = {}
   append_to_path(new, a)
   append_to_path(new, b)

   return setmt(new)
end





function Path.eq(a, b, use_os_sep)
   if a == nil then
      return false
   end
   if b == nil then
      return false
   end
   if rawequal(a, b) then
      return true
   end

   local pa = type(a) == "string" and path.new(a, use_os_sep) or (a):copy()
   local pb = type(b) == "string" and path.new(b, use_os_sep) or (b):copy()

   pa:to_absolute()
   pb:to_absolute()

   if rawlen(pa) ~= rawlen(pb) then
      return false
   end

   for i = 1, rawlen(pa) do
      if rawget(pa, i) ~= rawget(pb, i) then
         return false
      end
   end

   return true
end

PathMt.__eq = function(a, b)
   return Path.eq(a, b, false)
end

PathMt.__tostring = Path.tostring

local function patt_escape_char(c)
   return c == "*" and ".-" or "%" .. c
end

local function process_patt_chunk(s)
   return s == "**" and
   "**" or
   "^" .. esc(s, patt_escape_char) .. "$"
end


local pattern_cache = setmetatable({}, { __mode = "kv" })
local function get_patt(patt)
   if not pattern_cache[patt] then
      local path_patt = parse_string_path(patt)



      for i = #path_patt, 2, -1 do
         if path_patt[i] == "**" and path_patt[i - 1] == "**" then
            table.remove(path_patt, i)
         end
      end

      for i, v in ipairs(path_patt) do
         path_patt[i] = process_patt_chunk(v)
      end

      pattern_cache[patt] = path_patt
   end
   return pattern_cache[patt]
end

local function match(p, path_patt)
   local path_len = #p
   local patt_len = #path_patt

   local patt_idx = 1
   local path_idx = 1

   local double_glob_stack = {}
   local function push_state()
      table.insert(double_glob_stack, { patt_idx, path_idx })
   end
   local function pop_state()
      local t = table.remove(double_glob_stack)
      if not t then return false end
      patt_idx = t[1]
      path_idx = t[2] + 1
      return true
   end

   repeat
      while patt_idx <= patt_len and path_idx <= path_len do
         local patt_chunk = path_patt[patt_idx]
         local path_chunk = p[path_idx]

         if patt_chunk == "**" then
            push_state()
            patt_idx = patt_idx + 1
         elseif path_chunk:match(patt_chunk) then
            patt_idx = patt_idx + 1
            path_idx = path_idx + 1
         elseif not pop_state() then
            return false
         end
      end

   until (patt_idx > patt_len and path_idx > path_len) or
      (not pop_state())
   return patt_idx > patt_len and
   path_idx > path_len
end









function Path:match(patt)
   return match(self, get_patt(patt))
end



function Path:match_any(patts)
   for i, patt in ipairs(patts) do
      if match(self, get_patt(patt)) then
         return i, patt
      end
   end
end






function Path:relative_to(other)
   local a, b = self:copy(), other:copy()
   if xor(a:is_absolute(), b:is_absolute()) then
      if not a:is_absolute() then
         a = path.new(lfs.currentdir(), true) .. a
      else
         b = path.new(lfs.currentdir(), true) .. b
      end
   end
   local a_len = #a
   local b_len = #b
   local mismatch = false
   local idx = 0
   for i = 1, math.min(a_len, b_len) do
      if a[i] ~= b[i] then
         mismatch = true
         break
      end
      idx = i
   end
   if b_len > a_len then
      mismatch = true
   end
   local ret = {}
   if mismatch then
      for _ = 1, b_len - idx do
         table.insert(ret, "..")
      end
   end
   for i = idx + 1, a_len do
      table.insert(ret, a[i])
   end
   return setmt(ret)
end









function Path:is_in(dirname, use_os_sep)
   if not dirname then return false end
   local dir = path.ensure(dirname, use_os_sep)

   local a, b = self, dir
   if xor(self:is_absolute(), dir:is_absolute()) then
      if self:is_absolute() then
         b = lfs.currentdir() .. b
      else
         a = lfs.currentdir() .. a
      end
   end
   if #b == 0 then
      return true
   end
   if #a < #b then
      return false
   end
   for i = 1, #b do
      if a[i] ~= b[i] then
         return false
      end
   end

   return true
end

return path
