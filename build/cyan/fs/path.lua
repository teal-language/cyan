local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local package = _tl_compat and _tl_compat.package or package; local rawlen = _tl_compat and _tl_compat.rawlen or rawlen; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table
local lfs = require("lfs")

local util = require("cyan.util")

local split, esc = util.str.split, util.str.esc
local values = util.tab.values

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



local function parse_string_path(s)
   s = s:gsub(path.separator .. "+$", "")
   if #s == 0 then
      return {}
   end

   local new = {}
   for chunk in split(s, path.separator, true) do
      if chunk == ".." then
         if #new > 0 then
            table.remove(new)
         else
            return nil
         end
      elseif chunk ~= "." then
         table.insert(new, chunk)
      end
   end
   return new
end

function path.new(s)
   if not s then return nil end
   local new = parse_string_path(s)
   return setmetatable(new, PathMt)
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
      table.insert(p, chunk)
   end
end

function Path:is_absolute()
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
   local i = 1
   for chunk in chunks(other) do
      table.insert(self, i, chunk)
      i = i + 1
   end
end

function Path:copy()
   local new = {}
   for i = 1, #self do
      new[i] = self[i]
   end
   return setmetatable(new, PathMt)
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
      return setmetatable(p, PathMt)
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
   if util.xor(leading:is_absolute(), self:is_absolute()) then
      error("Attempt to mix absolute and non-absolute path", 2)
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

   return setmetatable(new, PathMt)
end

PathMt.__eq = function(a, b)
   if rawequal(a, b) then
      return true
   end

   local pa = type(a) == "string" and parse_string_path(a) or a
   local pb = type(b) == "string" and parse_string_path(b) or b

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

   until (patt_idx >= patt_len and path_idx >= path_len) or
      (not pop_state())
   return patt_idx >= patt_len and
   path_idx >= path_len
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

return path
